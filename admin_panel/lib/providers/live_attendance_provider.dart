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

  /// `NOT_IN | WORKING | CHECKED_OUT | ON_LEAVE`, or null for everyone.
  ///
  /// The live endpoint has no status parameter, so this filters the fetched
  /// rows client-side. It exists so a dashboard stat tile can hand the board
  /// a status and answer "who?" without another round trip.
  String? statusFilter;

  /// Rows after the status filter — what the table should render.
  List<LiveRecord> get visibleRecords {
    final all = data?.records ?? const <LiveRecord>[];
    if (statusFilter == null) return all;
    return all.where((r) => r.liveStatus == statusFilter).toList();
  }

  void setStatusFilter(String? status) {
    if (statusFilter == status) return;
    statusFilter = status;
    notifyListeners();
  }

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
