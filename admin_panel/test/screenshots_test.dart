@Tags(['screenshots'])
library;

import 'dart:io';

import 'package:attendance_admin/models/dashboard.dart';
import 'package:attendance_admin/models/office_settings.dart';
import 'package:attendance_admin/providers/attention_provider.dart';
import 'package:attendance_admin/providers/catalog_provider.dart';
import 'package:attendance_admin/providers/dashboard_provider.dart';
import 'package:attendance_admin/providers/employees_provider.dart';
import 'package:attendance_admin/providers/live_attendance_provider.dart';
import 'package:attendance_admin/providers/office_settings_provider.dart';
import 'package:attendance_admin/providers/reports_provider.dart';
import 'package:attendance_admin/providers/requests_provider.dart';
import 'package:attendance_admin/screens/attendance_screen.dart';
import 'package:attendance_admin/screens/dashboard_screen.dart';
import 'package:attendance_admin/screens/office_settings_screen.dart';
import 'package:attendance_admin/screens/people_screen.dart';
import 'package:attendance_admin/screens/reports_screen.dart';
import 'package:attendance_admin/screens/requests_screen.dart';
import 'package:attendance_admin/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

/// Renders screens to PNGs so layout can be reviewed without a running
/// backend. Not a pass/fail suite — a way to actually *look* at the UI.
///
///   flutter test --tags screenshots --update-goldens
///
/// Output lands in test/goldens/. Providers here are stubbed by setting their
/// public fields directly, so nothing touches the network.
Future<void> main() async {
  setUpAll(() async {
    // google_fonts otherwise tries to fetch Inter over the network mid-test.
    GoogleFonts.config.allowRuntimeFetching = false;

    // Without a real font every glyph renders as a filled box, which makes
    // the output useless for reviewing. The theme asks for Inter (which is
    // not bundled), so a system face is registered under both that family and
    // the default so every lookup resolves to real glyphs.
    for (final family in ['Inter', 'Roboto']) {
      final loader = FontLoader(family);
      var any = false;
      for (final path in [
        '/System/Library/Fonts/Supplemental/Arial.ttf',
        '/System/Library/Fonts/Supplemental/Arial Bold.ttf',
      ]) {
        final file = File(path);
        if (file.existsSync()) {
          any = true;
          loader.addFont(
              file.readAsBytes().then((b) => ByteData.view(b.buffer)));
        }
      }
      if (any) await loader.load();
    }
  });

  Future<void> shot(
    WidgetTester tester,
    String name,
    Widget child, {
    required List<ChangeNotifierProvider> providers,
    Size size = const Size(1280, 860),
    Brightness brightness = Brightness.dark,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // google_fonts registers families as "Inter_regular" etc. and cannot fetch
    // offline, so its glyphs come out as boxes. Swap in the loaded system face
    // for review purposes — sizes, weights and every other theme token stay
    // exactly as production.
    final base =
        brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light();
    final theme = base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: Scaffold(body: child),
        ),
      ),
    );
    // Let one frame of layout settle without waiting on the screens' own
    // network calls (which fail fast against no server).
    await tester.pump(const Duration(milliseconds: 50));
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
  }

  testWidgets('office settings', (tester) async {
    final settings = OfficeSettingsProvider()
      ..settings = const OfficeSettings(
        latitude: 25.1972,
        longitude: 55.2744,
        radiusMeters: 150,
        workStartTime: '09:00',
        workEndTime: '18:00',
        lateToleranceMinutes: 10,
        earlyLeaveToleranceMinutes: 10,
        timezone: 'Asia/Dubai',
      )
      ..loading = false;

    await shot(
      tester,
      'office_settings_dark',
      const OfficeSettingsScreen(),
      providers: [
        ChangeNotifierProvider<OfficeSettingsProvider>.value(value: settings),
      ],
    );
  });

  testWidgets('attendance - live board', (tester) async {
    await shot(
      tester,
      'attendance_live_dark',
      const AttendanceScreen(tab: AttendanceTab.live),
      providers: [
        ChangeNotifierProvider<AttentionProvider>(
            create: (_) => AttentionProvider()..missingCheckouts = 2),
        ChangeNotifierProvider<LiveAttendanceProvider>(
            create: (_) => LiveAttendanceProvider()),
        ChangeNotifierProvider<CatalogProvider>(
            create: (_) => CatalogProvider()),
      ],
    );
  });

  testWidgets('people - employees', (tester) async {
    await shot(
      tester,
      'people_employees_dark',
      const PeopleScreen(tab: PeopleTab.employees),
      providers: [
        ChangeNotifierProvider<EmployeesProvider>(
            create: (_) => EmployeesProvider()),
        ChangeNotifierProvider<CatalogProvider>(
            create: (_) => CatalogProvider()),
      ],
    );
  });

  testWidgets('reports', (tester) async {
    await shot(
      tester,
      'reports_dark',
      const ReportsScreen(),
      providers: [
        ChangeNotifierProvider<ReportsProvider>(create: (_) => ReportsProvider()),
        ChangeNotifierProvider<CatalogProvider>(
            create: (_) => CatalogProvider()),
      ],
    );
  });

  testWidgets('requests', (tester) async {
    await shot(
      tester,
      'requests_dark',
      const RequestsScreen(),
      providers: [
        ChangeNotifierProvider<RequestsProvider>(
            create: (_) => RequestsProvider()..loading = false),
      ],
    );
  });

  testWidgets('dashboard', (tester) async {
    final dash = DashboardProvider()
      ..stats = const DashboardStats(
        totalEmployees: 8,
        present: 5,
        late: 1,
        absent: 1,
        onLeave: 1,
        checkedOut: 3,
        averageWorkMinutes: 462,
        attendanceRate: 87.5,
      )
      ..loadingStats = false
      ..loadingTrends = false
      ..lastUpdated = DateTime(2026, 7, 27, 9, 41);

    final attention = AttentionProvider()
      ..pendingRequests = 3
      ..missingCheckouts = 2;

    await shot(
      tester,
      'dashboard_dark',
      const DashboardScreen(),
      providers: [
        ChangeNotifierProvider<DashboardProvider>.value(value: dash),
        ChangeNotifierProvider<AttentionProvider>.value(value: attention),
        ChangeNotifierProvider<CatalogProvider>(
            create: (_) => CatalogProvider()),
      ],
    );
  });
}
