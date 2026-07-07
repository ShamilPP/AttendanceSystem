import '../utils/json_utils.dart';

/// `GET /qr/current` / `POST /qr/regenerate` payload.
///
/// The QR code is permanent: `qrData` stays stable until an admin regenerates
/// it, at which point `version` increments and the old code is invalidated.
class QrInfo {
  const QrInfo({
    required this.qrData,
    this.version = 1,
    this.generatedAt,
  });

  final String qrData;
  final int version;
  final DateTime? generatedAt;

  factory QrInfo.fromJson(dynamic json) {
    final map = jsonMap(json);
    return QrInfo(
      qrData: jsonString(map['qrData']),
      version: jsonInt(map['version'], 1),
      generatedAt: jsonDateTime(map['generatedAt']),
    );
  }
}
