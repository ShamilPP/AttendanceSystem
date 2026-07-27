import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A scan that was valid on the device but never reached the server.
class PendingScan {
  const PendingScan({required this.action, required this.attemptedAt});

  /// `CHECK_IN` or `CHECK_OUT`.
  final String action;

  /// When the employee actually scanned — the time that should be recorded.
  final DateTime attemptedAt;

  Map<String, dynamic> toJson() => {
        'action': action,
        'attemptedAt': attemptedAt.toIso8601String(),
      };

  static PendingScan? fromJson(Map<String, dynamic> json) {
    final action = json['action'];
    final at = DateTime.tryParse('${json['attemptedAt']}');
    if (action is! String || at == null) return null;
    return PendingScan(action: action, attemptedAt: at);
  }
}

/// Remembers a scan that failed because the network was unreachable.
///
/// Deliberately **not** a replay queue. `POST /attendance/scan` timestamps the
/// record when the server receives it, so silently retrying an hour later
/// would file a check-in at the wrong time — worse than losing it, because it
/// looks correct. Instead the attempt is stored, and the next time the app
/// opens it offers to file a regularization request pre-filled with the real
/// scan time. That path takes an explicit timestamp and goes through admin
/// review, which is exactly what a disputed time should do.
///
/// Only genuine connectivity failures are recorded. A scan the server
/// *rejected* (bad QR, outside the geofence, already checked in) is not
/// pending — it is answered.
class PendingScanService {
  PendingScanService._();

  static final PendingScanService instance = PendingScanService._();

  static const String _key = 'pending_scan';

  Future<PendingScan?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final pending = PendingScan.fromJson(Map<String, dynamic>.from(decoded));
      // A scan older than a day is no longer worth surfacing; the day it
      // belonged to is closed and the admin has likely already resolved it.
      if (pending != null &&
          DateTime.now().difference(pending.attemptedAt).inHours > 24) {
        await clear();
        return null;
      }
      return pending;
    } catch (e) {
      debugPrint('Could not read pending scan: $e');
      return null;
    }
  }

  Future<void> save(PendingScan scan) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(scan.toJson()));
    } catch (e) {
      debugPrint('Could not save pending scan: $e');
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (e) {
      debugPrint('Could not clear pending scan: $e');
    }
  }
}
