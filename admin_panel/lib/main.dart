import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/attendance_logs_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/catalog_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/employees_provider.dart';
import 'providers/live_attendance_provider.dart';
import 'providers/missing_checkouts_provider.dart';
import 'providers/office_settings_provider.dart';
import 'providers/reports_provider.dart';
import 'providers/requests_provider.dart';
import 'screens/login_screen.dart';
import 'screens/shell_screen.dart';
import 'services/api_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiClient.instance.init();
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..restore()),
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
      child: MaterialApp(
        title: 'Attendance Admin',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF2A78D6),
          visualDensity: VisualDensity.comfortable,
          scaffoldBackgroundColor: const Color(0xFFF9F9F7),
          dataTableTheme: const DataTableThemeData(
            headingRowHeight: 44,
            dataRowMinHeight: 44,
            dataRowMaxHeight: 56,
          ),
          cardTheme: const CardThemeData(
            color: Colors.white,
            surfaceTintColor: Colors.transparent,
          ),
        ),
        home: const _RootGate(),
      ),
    );
  }
}

/// Routes between the splash spinner, login and the admin shell.
class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    switch (auth.status) {
      case AuthStatus.restoring:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case AuthStatus.authenticated:
        return const ShellScreen();
      case AuthStatus.unauthenticated:
      case AuthStatus.authenticating:
        return const LoginScreen();
    }
  }
}
