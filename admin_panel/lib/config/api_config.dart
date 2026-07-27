/// Central API configuration for the admin panel.
class ApiConfig {
  ApiConfig._();

  /// Compile-time override: `--dart-define=API_BASE_URL=/api/v1`.
  /// A relative value (e.g. `/api/v1`) targets the SAME origin the app is
  /// served from — used in production behind an nginx `/api/` reverse proxy,
  /// which avoids CORS and mixed-content entirely.
  static const String _override = String.fromEnvironment('API_BASE_URL');

  /// Base URL of the backend REST API (see docs/API_CONTRACT.md).
  /// Defaults to local dev; production web builds pass `API_BASE_URL=/api/v1`.
  static String get baseUrl =>
      _override.isNotEmpty ? _override : 'https://attendance-api.nexserve.tech/api/v1';
}
