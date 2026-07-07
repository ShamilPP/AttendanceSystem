import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/attendance_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/documents_provider.dart';
import 'screens/splash_screen.dart';
import 'services/api_client.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AttendanceApp());
}

/// Root widget: providers + Material 3 theme.
class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  static const Color _seedColor = Color(0xFF1B5FA7);

  ThemeData _buildTheme(Brightness brightness) {
    final scheme =
        ColorScheme.fromSeed(seedColor: _seedColor, brightness: brightness);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: const AppBarTheme(centerTitle: false),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        filled: true,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

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
      ],
      child: MaterialApp(
        title: 'Attendance',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        home: const SplashScreen(),
      ),
    );
  }
}
