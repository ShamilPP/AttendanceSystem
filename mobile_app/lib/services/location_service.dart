import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Thrown when the device location cannot be obtained, with a
/// user-presentable [message].
class LocationException implements Exception {
  const LocationException(this.message, {this.canOpenSettings = false});

  final String message;

  /// True when sending the user to app/location settings could fix it.
  final bool canOpenSettings;

  @override
  String toString() => message;
}

/// Fetches the current GPS position, handling permissions and
/// disabled services with clear, actionable messages.
class LocationService {
  const LocationService();

  Future<Position> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationException(
        'Location services are turned off. Please enable GPS/location '
        'services on your device and try again.',
        canOpenSettings: true,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException(
        'Location permission was denied. Attendance requires your current '
        'location to verify you are at the office.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'Location permission is permanently denied. Open the app settings '
        'and allow location access to mark attendance.',
        canOpenSettings: true,
      );
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 25),
        ),
      );
    } on TimeoutException {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
      throw const LocationException(
        'Could not determine your location in time. Move to an area with '
        'better GPS signal and try again.',
      );
    } on LocationServiceDisabledException {
      throw const LocationException(
        'Location services were turned off while locating you. Please '
        're-enable them and try again.',
        canOpenSettings: true,
      );
    }
  }

  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  Future<void> openAppSettings() => Geolocator.openAppSettings();
}
