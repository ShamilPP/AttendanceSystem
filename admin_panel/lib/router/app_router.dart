import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../screens/attendance_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/kiosk_screen.dart';
import '../screens/login_screen.dart';
import '../screens/office_settings_screen.dart';
import '../screens/people_screen.dart';
import '../screens/qr_display_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/requests_screen.dart';
import '../screens/shell_screen.dart';
import '../widgets/states.dart';
import 'routes.dart';

/// Builds the router. [auth] drives redirects and is used as the refresh
/// listenable so login/logout navigates without any manual `go()` calls.
GoRouter buildRouter(AuthProvider auth) {
  return GoRouter(
    initialLocation: Routes.overview,
    refreshListenable: auth,
    redirect: (context, state) {
      final loggingIn = state.matchedLocation == Routes.login;
      switch (auth.status) {
        case AuthStatus.restoring:
          // Hold on the splash route until the token check resolves.
          return null;
        case AuthStatus.authenticated:
          return loggingIn ? Routes.overview : null;
        case AuthStatus.unauthenticated:
        case AuthStatus.authenticating:
          if (loggingIn) return null;
          // Remember where they were headed so login can return them there.
          final from = state.uri.toString();
          return from == Routes.overview
              ? Routes.login
              : '${Routes.login}?from=${Uri.encodeComponent(from)}';
      }
    },
    routes: [
      GoRoute(
        path: Routes.login,
        pageBuilder: (context, state) => NoTransitionPage(
          child: auth.status == AuthStatus.restoring
              ? const Scaffold(
                  body: LoadingState(message: 'Restoring your session…'))
              : LoginScreen(from: state.uri.queryParameters['from']),
        ),
      ),
      GoRoute(
        path: Routes.kiosk,
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: KioskScreen()),
      ),
      ShellRoute(
        // One shell instance for every section: nav switches no longer rebuild
        // (and reset the filters/scroll of) the screen you are leaving.
        builder: (context, state, child) => ShellScreen(child: child),
        routes: [
          GoRoute(
            path: Routes.overview,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: DashboardScreen()),
          ),
          GoRoute(
            path: Routes.attendance,
            redirect: (context, state) => state.matchedLocation ==
                    Routes.attendance
                ? Routes.attendanceLive
                : null,
            routes: [
              GoRoute(
                path: 'live',
                pageBuilder: (context, state) => const NoTransitionPage(
                    child: AttendanceScreen(tab: AttendanceTab.live)),
              ),
              GoRoute(
                path: 'logs',
                pageBuilder: (context, state) => const NoTransitionPage(
                    child: AttendanceScreen(tab: AttendanceTab.logs)),
              ),
              GoRoute(
                path: 'missing',
                pageBuilder: (context, state) => const NoTransitionPage(
                    child: AttendanceScreen(tab: AttendanceTab.missing)),
              ),
            ],
          ),
          GoRoute(
            path: Routes.requests,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: RequestsScreen()),
          ),
          GoRoute(
            path: Routes.people,
            redirect: (context, state) =>
                state.matchedLocation == Routes.people
                    ? Routes.peopleEmployees
                    : null,
            routes: [
              GoRoute(
                path: 'employees',
                pageBuilder: (context, state) => const NoTransitionPage(
                    child: PeopleScreen(tab: PeopleTab.employees)),
              ),
              GoRoute(
                path: 'catalog',
                pageBuilder: (context, state) => const NoTransitionPage(
                    child: PeopleScreen(tab: PeopleTab.catalog)),
              ),
            ],
          ),
          GoRoute(
            path: Routes.reports,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ReportsScreen()),
          ),
          GoRoute(
            path: Routes.qr,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: QrDisplayScreen()),
          ),
          GoRoute(
            path: Routes.settings,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: OfficeSettingsScreen()),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: ErrorState(
        message: 'No page matches "${state.uri}".',
        onRetry: () => context.go(Routes.overview),
      ),
    ),
  );
}
