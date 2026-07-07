/// Central place for API configuration.
class ApiConfig {
  ApiConfig._();

  /// Base URL of the backend REST API.
  ///
  /// NOTE:
  /// - Android *emulators* cannot reach the host machine via `localhost`;
  ///   use `http://10.0.2.2:5000/api/v1` instead.
  /// - iOS simulators can use `localhost` directly.
  /// - Physical devices need the host machine's LAN IP,
  ///   e.g. `http://192.168.1.10:5000/api/v1`.
  static const String baseUrl = 'http://localhost:5000/api/v1';

  /// Default request timeout for normal JSON calls.
  static const Duration requestTimeout = Duration(seconds: 30);

  /// Timeout for uploads / downloads.
  static const Duration transferTimeout = Duration(minutes: 2);
}
