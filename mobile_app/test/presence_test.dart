import 'package:attendance_mobile/models/office_settings.dart';
import 'package:attendance_mobile/providers/presence_provider.dart';
import 'package:attendance_mobile/services/pending_scan_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('geofence distance', () {
    // Seeded office (Dubai) from the backend seed script.
    const officeLat = 25.1972;
    const officeLng = 55.2744;

    test('is zero at the office centre', () {
      expect(
        PresenceProvider.distanceMetersBetween(
            officeLat, officeLng, officeLat, officeLng),
        closeTo(0, 0.001),
      );
    });

    test('matches a known separation', () {
      // ~0.001 degrees of latitude is ~111 m anywhere on Earth.
      final d = PresenceProvider.distanceMetersBetween(
          officeLat, officeLng, officeLat + 0.001, officeLng);
      expect(d, closeTo(111.2, 1.0));
    });

    test('is symmetric', () {
      final ab = PresenceProvider.distanceMetersBetween(
          officeLat, officeLng, 25.20, 55.28);
      final ba = PresenceProvider.distanceMetersBetween(
          25.20, 55.28, officeLat, officeLng);
      expect(ab, closeTo(ba, 0.001));
    });

    test('classifies inside and outside the seeded 150 m radius', () {
      // ~55 m north — inside.
      final near = PresenceProvider.distanceMetersBetween(
          officeLat, officeLng, officeLat + 0.0005, officeLng);
      // ~555 m north — outside.
      final far = PresenceProvider.distanceMetersBetween(
          officeLat, officeLng, officeLat + 0.005, officeLng);
      expect(near, lessThan(150));
      expect(far, greaterThan(150));
    });
  });

  group('OfficeSettings', () {
    test('parses the contract shape', () {
      final settings = OfficeSettings.fromJson(const {
        'latitude': 25.1972,
        'longitude': 55.2744,
        'radiusMeters': 150,
        'workStartTime': '09:00',
        'workEndTime': '18:00',
        'timezone': 'Asia/Dubai',
      });
      expect(settings.latitude, 25.1972);
      expect(settings.longitude, 55.2744);
      expect(settings.radiusMeters, 150);
      expect(settings.workStartTime, '09:00');
      expect(settings.workEndTime, '18:00');
      expect(settings.timezone, 'Asia/Dubai');
    });

    test('falls back to sane defaults on missing fields', () {
      final settings = OfficeSettings.fromJson(const {});
      expect(settings.radiusMeters, 150);
      expect(settings.workStartTime, '09:00');
      expect(settings.workEndTime, '18:00');
    });

    test('tolerates numeric strings', () {
      final settings = OfficeSettings.fromJson(const {
        'latitude': '25.1972',
        'longitude': '55.2744',
        'radiusMeters': '200',
      });
      expect(settings.latitude, closeTo(25.1972, 1e-9));
      expect(settings.radiusMeters, 200);
    });
  });

  group('PendingScan', () {
    test('round-trips through JSON', () {
      final at = DateTime.utc(2026, 7, 27, 9, 4, 12);
      final restored =
          PendingScan.fromJson(PendingScan(action: 'CHECK_IN', attemptedAt: at)
              .toJson());
      expect(restored, isNotNull);
      expect(restored!.action, 'CHECK_IN');
      expect(restored.attemptedAt.toUtc(), at);
    });

    test('rejects malformed payloads rather than inventing a time', () {
      expect(PendingScan.fromJson(const {}), isNull);
      expect(
        PendingScan.fromJson(const {'action': 'CHECK_IN', 'attemptedAt': 'x'}),
        isNull,
      );
      expect(
        PendingScan.fromJson(const {'action': 7, 'attemptedAt': '2026-07-27'}),
        isNull,
      );
    });
  });
}
