/// Every addressable location in the admin panel.
///
/// The panel is a **web** app, so each section owns a real URL: the browser
/// back button, bookmarks and deep links all work, and a reload lands the
/// admin back where they were instead of on the dashboard.
///
/// Deliberately free of imports. Screens need these constants to link to each
/// other, and if they lived in `app_router.dart` — which imports every screen
/// — any one screen would transitively pull in all of them (including the
/// web-only download helper, which cannot compile under `flutter test`).
abstract final class Routes {
  static const String login = '/login';
  static const String overview = '/';

  static const String attendance = '/attendance';
  static const String attendanceLive = '/attendance/live';
  static const String attendanceLogs = '/attendance/logs';
  static const String attendanceMissing = '/attendance/missing';

  static const String requests = '/requests';

  static const String people = '/people';
  static const String peopleEmployees = '/people/employees';
  static const String peopleCatalog = '/people/catalog';

  static const String reports = '/reports';
  static const String qr = '/qr';
  static const String settings = '/settings';

  /// Fullscreen QR kiosk — deliberately outside the shell so it can be left
  /// on a display at the office entrance with no admin chrome around it.
  static const String kiosk = '/kiosk';
}
