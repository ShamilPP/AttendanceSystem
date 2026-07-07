import 'package:flutter/foundation.dart';

import '../models/live_attendance.dart';
import '../services/api_client.dart';

/// Live attendance board state (screen owns the auto-refresh timer).
class LiveAttendanceProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient.instance;

  LiveAttendance? data;
  String? departmentId;
  bool loading = false;
  String? error;
  DateTime? lastUpdated;

  Future<void> fetch({bool silent = false}) async {
    if (!silent) {
      loading = true;
      notifyListeners();
    }
    try {
      final result = await _api
          .get('/attendance/live', query: {'departmentId': departmentId});
      data = LiveAttendance.fromJson(result.data);
      lastUpdated = DateTime.now();
      error = null;
    } on ApiException catch (e) {
      error = e.fullMessage;
    }
    loading = false;
    notifyListeners();
  }

  Future<void> setDepartment(String? id) async {
    departmentId = id;
    await fetch();
  }
}
