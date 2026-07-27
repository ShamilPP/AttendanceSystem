import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/office_settings.dart';
import '../services/api_client.dart';
import '../services/location_service.dart';

/// How the device currently stands relative to the office geofence.
enum PresenceState {
  /// Not checked yet this session.
  unknown,

  /// Fetching office settings or a GPS fix.
  checking,

  /// Inside the geofence — a scan will pass the location check.
  atOffice,

  /// Outside the geofence — a scan would be rejected with a 403.
  away,

  /// Location permission is denied (recoverable by asking again).
  permissionDenied,

  /// Permission permanently denied or GPS off — needs a settings trip.
  blocked,

  /// Something else failed (office settings unreachable, GPS timeout).
  unavailable,
}

/// Answers "can I actually check in from here?" *before* the camera opens.
///
/// The old flow discovered a geofence failure only after the employee had
/// tapped Check In, granted a permission, waited for a GPS fix and posted a
/// scan — five steps to learn something knowable at step zero. This provider
/// resolves the office geofence and the device position up front so Home can
/// say "You're at the office" or "240 m away" before anything is tapped.
///
/// The server remains the sole authority: this is a hint, never a gate. A scan
/// is always allowed to proceed, because GPS drift should not lock somebody
/// out of their own attendance.
class PresenceProvider extends ChangeNotifier {
  PresenceProvider(this._api);

  final ApiClient _api;
  final LocationService _location = const LocationService();

  OfficeSettings? _office;
  PresenceState _state = PresenceState.unknown;
  double? _distanceMeters;
  String? _message;
  DateTime? _lastChecked;

  OfficeSettings? get office => _office;
  PresenceState get state => _state;
  DateTime? get lastChecked => _lastChecked;

  /// Metres from the office centre, when a fix was obtained.
  double? get distanceMeters => _distanceMeters;

  /// Explanatory text for the states that need one.
  String? get message => _message;

  bool get isAtOffice => _state == PresenceState.atOffice;
  bool get isChecking => _state == PresenceState.checking;

  /// True when opening the OS settings page is the way out.
  bool get needsSettings => _state == PresenceState.blocked;

  /// Distance rendered for humans: "40 m" / "1.2 km".
  String? get distanceLabel {
    final d = _distanceMeters;
    if (d == null) return null;
    if (d < 1000) return '${d.round()} m';
    return '${(d / 1000).toStringAsFixed(1)} km';
  }

  /// Resolves office settings (cached for the session) and the current fix.
  ///
  /// [askPermission] false performs a silent check that never raises the OS
  /// permission dialog — used on the first Home load so the prompt is tied to
  /// a deliberate tap instead of ambushing the employee.
  Future<void> refresh({bool askPermission = true}) async {
    _state = PresenceState.checking;
    _message = null;
    notifyListeners();

    try {
      _office ??= await _fetchOffice();
    } on ApiException catch (e) {
      _state = PresenceState.unavailable;
      _message = e.message;
      notifyListeners();
      return;
    }

    if (!askPermission) {
      final permission = await Geolocator.checkPermission();
      final granted = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      if (!granted) {
        _state = permission == LocationPermission.deniedForever
            ? PresenceState.blocked
            : PresenceState.permissionDenied;
        _message = 'Allow location access to see whether you are at the office.';
        notifyListeners();
        return;
      }
    }

    try {
      final position = await _location.getCurrentPosition();
      final office = _office!;
      _distanceMeters = distanceMetersBetween(
        position.latitude,
        position.longitude,
        office.latitude,
        office.longitude,
      );
      _state = _distanceMeters! <= office.radiusMeters
          ? PresenceState.atOffice
          : PresenceState.away;
      _message = null;
      _lastChecked = DateTime.now();
    } on LocationException catch (e) {
      _state = e.canOpenSettings
          ? PresenceState.blocked
          : PresenceState.permissionDenied;
      _message = e.message;
    }
    notifyListeners();
  }

  Future<void> openSettings() => _location.openAppSettings();

  Future<OfficeSettings> _fetchOffice() async {
    final res = await _api.get('/office-settings');
    return OfficeSettings.fromJson(res.data as Map<String, dynamic>);
  }

  /// Great-circle distance in metres — the same haversine the backend uses to
  /// judge the fence, so the app's hint and the server's verdict agree.
  ///
  /// Public so the agreement can be asserted in tests: if these two drift
  /// apart, employees get told they are inside a fence the server rejects.
  static double distanceMetersBetween(
      double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000.0;
    double toRad(double deg) => deg * math.pi / 180.0;

    final dLat = toRad(lat2 - lat1);
    final dLon = toRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(toRad(lat1)) *
            math.cos(toRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  void reset() {
    _office = null;
    _state = PresenceState.unknown;
    _distanceMeters = null;
    _message = null;
    _lastChecked = null;
    notifyListeners();
  }
}
