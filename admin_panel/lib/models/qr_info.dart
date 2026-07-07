import '../utils/json_utils.dart';

/// `GET /qr/current` payload.
class QrInfo {
  const QrInfo({
    required this.qrData,
    this.expiresAt,
    this.refreshSeconds = 30,
  });

  final String qrData;
  final DateTime? expiresAt;
  final int refreshSeconds;

  factory QrInfo.fromJson(dynamic json) {
    final map = jsonMap(json);
    return QrInfo(
      qrData: jsonString(map['qrData']),
      expiresAt: jsonDateTime(map['expiresAt']),
      refreshSeconds: jsonInt(map['refreshSeconds'], 30),
    );
  }
}
