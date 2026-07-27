import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/attendance_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/documents_provider.dart';
import 'providers/presence_provider.dart';
import 'screens/splash_screen.dart';
import 'services/api_client.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Loads the timezone database and the notifications plugin. Never prompts —
  // permission is only requested when the employee turns reminders on.
  await NotificationService.instance.init();
  runApp(const AttendanceApp());
}

/// Root widget: providers + the shared Material 3 theme (light + dark,
/// following the system setting).
class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>(create: (_) => ApiClient()),
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(context.read<ApiClient>()),
        ),
        ChangeNotifierProvider<AttendanceProvider>(
          create: (context) => AttendanceProvider(context.read<ApiClient>()),
        ),
        ChangeNotifierProvider<DocumentsProvider>(
          create: (context) => DocumentsProvider(context.read<ApiClient>()),
        ),
        ChangeNotifierProvider<PresenceProvider>(
          create: (context) => PresenceProvider(context.read<ApiClient>()),
        ),
      ],
      child: MaterialApp(
        title: 'NexCrew Attendance',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: const SplashScreen(),
      ),
    );
  }
}
