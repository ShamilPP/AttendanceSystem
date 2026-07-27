import 'json_helpers.dart';

/// `GET /office-settings` — readable by any authenticated user.
///
/// The employee app needs the geofence so it can tell you *before* you open
/// the camera whether a scan can possibly succeed. The server still enforces
/// the fence on every scan; this copy is purely for the pre-flight hint.
class OfficeSettings {
  const OfficeSettings({
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.workStartTime,
    required this.workEndTime,
    required this.timezone,
  });

  final double latitude;
  final double longitude;
  final int radiusMeters;

  /// `HH:mm` in the office [timezone].
  final String workStartTime;
  final String workEndTime;
  final String timezone;

  factory OfficeSettings.fromJson(Map<String, dynamic> json) => OfficeSettings(
        latitude: asDouble(json['latitude']),
        longitude: asDouble(json['longitude']),
        radiusMeters: asInt(json['radiusMeters'], 150),
        workStartTime: asString(json['workStartTime'], '09:00'),
        workEndTime: asString(json['workEndTime'], '18:00'),
        timezone: asString(json['timezone'], 'UTC'),
      );
}
