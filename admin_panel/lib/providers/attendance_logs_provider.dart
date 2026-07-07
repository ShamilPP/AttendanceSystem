import 'package:flutter/foundation.dart';

import '../models/attendance.dart';
import '../models/pagination.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../utils/formats.dart';

/// Attendance logs table: filters, pagination and admin edits.
class AttendanceLogsProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient.instance;

  List<Attendance> records = const [];
  Pagination? pagination;
  bool loading = false;
  String? error;

  // Filters.
  User? employee;
  DateTime? from;
  DateTime? to;
  String? status;
  int page = 1;
  static const int limit = 20;

  Future<void> fetch({int? toPage}) async {
    page = toPage ?? page;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await _api.get('/attendance/logs', query: {
        'employeeId': employee?.employeeId,
        'from': from == null ? null : isoDay(from!),
        'to': to == null ? null : isoDay(to!),
        'status': status,
        'page': '$page',
        'limit': '$limit',
      });
      records = result.dataList.map(Attendance.fromJson).toList();
      pagination = result.pagination;
    } on ApiException catch (e) {
      error = e.fullMessage;
    }
    loading = false;
    notifyListeners();
  }

  Future<void> applyFilters({
    required User? employee,
    required DateTime? from,
    required DateTime? to,
    required String? status,
  }) async {
    this.employee = employee;
    this.from = from;
    this.to = to;
    this.status = status;
    await fetch(toPage: 1);
  }

  /// `PUT /attendance/:id/correct` — note required by the contract.
  Future<void> correct(String id, Map<String, dynamic> body) async {
    await _api.put('/attendance/$id/correct', body: body);
    await fetch();
  }

  /// `POST /attendance/manual`.
  Future<void> manualEntry(Map<String, dynamic> body) async {
    await _api.post('/attendance/manual', body: body);
    await fetch(toPage: 1);
  }
}
