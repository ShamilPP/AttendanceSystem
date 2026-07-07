import '../utils/json_utils.dart';

/// Office settings singleton — see API contract.
class OfficeSettings {
  const OfficeSettings({
    this.latitude = 0,
    this.longitude = 0,
    this.radiusMeters = 150,
    this.workStartTime = '09:00',
    this.workEndTime = '18:00',
    this.lateToleranceMinutes = 10,
    this.earlyLeaveToleranceMinutes = 10,
    this.qrRefreshSeconds = 30,
    this.timezone = 'Asia/Dubai',
  });

  final double latitude;
  final double longitude;
  final int radiusMeters;
  final String workStartTime; // HH:mm
  final String workEndTime; // HH:mm
  final int lateToleranceMinutes;
  final int earlyLeaveToleranceMinutes;
  final int qrRefreshSeconds;
  final String timezone;

  factory OfficeSettings.fromJson(dynamic json) {
    final map = jsonMap(json);
    return OfficeSettings(
      latitude: jsonDouble(map['latitude']),
      longitude: jsonDouble(map['longitude']),
      radiusMeters: jsonInt(map['radiusMeters'], 150),
      workStartTime: jsonString(map['workStartTime'], '09:00'),
      workEndTime: jsonString(map['workEndTime'], '18:00'),
      lateToleranceMinutes: jsonInt(map['lateToleranceMinutes'], 10),
      earlyLeaveToleranceMinutes: jsonInt(map['earlyLeaveToleranceMinutes'], 10),
      qrRefreshSeconds: jsonInt(map['qrRefreshSeconds'], 30),
      timezone: jsonString(map['timezone'], 'Asia/Dubai'),
    );
  }

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'radiusMeters': radiusMeters,
        'workStartTime': workStartTime,
        'workEndTime': workEndTime,
        'lateToleranceMinutes': lateToleranceMinutes,
        'earlyLeaveToleranceMinutes': earlyLeaveToleranceMinutes,
        'qrRefreshSeconds': qrRefreshSeconds,
        'timezone': timezone,
      };
}
