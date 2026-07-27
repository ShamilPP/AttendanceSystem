import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'providers/attendance_logs_provider.dart';
import 'providers/attention_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/catalog_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/employees_provider.dart';
import 'providers/live_attendance_provider.dart';
import 'providers/missing_checkouts_provider.dart';
import 'providers/office_settings_provider.dart';
import 'providers/reports_provider.dart';
import 'providers/requests_provider.dart';
import 'router/app_router.dart';
import 'services/api_client.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiClient.instance.init();
  runApp(const AdminApp());
}

class AdminApp extends StatefulWidget {
  const AdminApp({super.key});

  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  // Auth lives above the router because the router redirects on it and uses
  // it as its refreshListenable.
  late final AuthProvider _auth = AuthProvider()..restore();
  late final GoRouter _router = buildRouter(_auth);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _auth),
        ChangeNotifierProvider(create: (_) => AttentionProvider()),
        ChangeNotifierProvider(create: (_) => CatalogProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => LiveAttendanceProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceLogsProvider()),
        ChangeNotifierProvider(create: (_) => RequestsProvider()),
        ChangeNotifierProvider(create: (_) => MissingCheckoutsProvider()),
        ChangeNotifierProvider(create: (_) => EmployeesProvider()),
        ChangeNotifierProvider(create: (_) => OfficeSettingsProvider()),
        ChangeNotifierProvider(create: (_) => ReportsProvider()),
      ],
      child: MaterialApp.router(
        title: 'NexCrew Admin',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        routerConfig: _router,
      ),
    );
  }
}
