import 'package:flutter/foundation.dart';

import '../models/attendance_request.dart';
import '../models/pagination.dart';
import '../services/api_client.dart';

/// Attendance regularization requests (admin review).
class RequestsProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient.instance;

  String status = 'PENDING'; // active tab
  List<AttendanceRequest> records = const [];
  Pagination? pagination;
  bool loading = false;
  String? error;
  int page = 1;

  Future<void> fetch({String? toStatus, int? toPage}) async {
    if (toStatus != null && toStatus != status) {
      status = toStatus;
      page = 1;
    }
    page = toPage ?? page;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await _api.get('/attendance/requests',
          query: {'status': status, 'page': '$page'});
      records = result.dataList.map(AttendanceRequest.fromJson).toList();
      pagination = result.pagination;
    } on ApiException catch (e) {
      error = e.fullMessage;
    }
    loading = false;
    notifyListeners();
  }

  /// `PUT /attendance/requests/:id` with APPROVED or REJECTED.
  Future<void> review(String id, String decision, String? note) async {
    await _api.put('/attendance/requests/$id', body: {
      'status': decision,
      if (note != null && note.isNotEmpty) 'reviewNote': note,
    });
    await fetch();
  }
}
