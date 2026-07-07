import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../models/attendance.dart';
import '../models/attendance_request.dart';
import '../models/attendance_summary.dart';
import '../models/json_helpers.dart';
import '../services/api_client.dart';

/// Result of a successful `POST /attendance/scan`.
class ScanOutcome {
  const ScanOutcome({this.attendance, required this.message});

  final Attendance? attendance;
  final String message;
}

/// Attendance state: today's record + scan, history, monthly summary and
/// regularization requests.
class AttendanceProvider extends ChangeNotifier {
  AttendanceProvider(this._api);

  final ApiClient _api;
  static final DateFormat _ymd = DateFormat('yyyy-MM-dd');

  // --- Today ----------------------------------------------------------------

  Attendance? _today;
  bool _todayLoading = false;
  bool _todayLoaded = false;
  String? _todayError;

  Attendance? get today => _today;
  bool get todayLoading => _todayLoading;
  bool get todayLoaded => _todayLoaded;
  String? get todayError => _todayError;

  /// Action availability derived from the current state
  /// (server remains the source of truth).
  bool get canCheckIn => _todayLoaded && (_today?.checkIn == null);
  bool get canCheckOut =>
      _todayLoaded && _today?.checkIn != null && _today?.checkOut == null;

  /// The context-aware action for the single Home button:
  /// CHECK_IN when there's no open record, CHECK_OUT when checked in,
  /// null once the day is complete (checked out).
  AttendanceAction? get nextAction {
    if (!_todayLoaded) return null;
    if (canCheckIn) return AttendanceAction.checkIn;
    if (canCheckOut) return AttendanceAction.checkOut;
    return null;
  }

  /// True when today's record is complete (checked in and out).
  bool get isDoneForToday =>
      _todayLoaded && _today?.checkIn != null && _today?.checkOut != null;

  Future<void> loadToday() async {
    _todayLoading = true;
    _todayError = null;
    notifyListeners();
    try {
      final res = await _api.get('/attendance/today');
      _today = res.data == null
          ? null
          : Attendance.fromJson(res.data as Map<String, dynamic>);
      _todayLoaded = true;
      _todayError = null;
    } on ApiException catch (e) {
      _todayError = e.message;
    }
    _todayLoading = false;
    notifyListeners();
  }

  /// `POST /attendance/scan`. Throws [ApiException] with the server's
  /// message (geofence / QR / state errors) on rejection.
  Future<ScanOutcome> scan({
    required String qrData,
    required AttendanceAction action,
    required double latitude,
    required double longitude,
  }) async {
    final res = await _api.post('/attendance/scan', body: {
      'qrData': qrData,
      'action': action.apiValue,
      'latitude': latitude,
      'longitude': longitude,
    });
    final data = asMap(res.data);
    Attendance? attendance;
    if (data['attendance'] != null) {
      attendance = Attendance.fromJson(asMap(data['attendance']));
      _today = attendance;
      _todayLoaded = true;
      notifyListeners();
    }
    return ScanOutcome(
      attendance: attendance,
      message: asString(data['message'], '${action.label} recorded.'),
    );
  }

  // --- History ----------------------------------------------------------------

  final List<Attendance> _history = [];
  bool _historyLoading = false;
  bool _historyLoadingMore = false;
  bool _historyLoaded = false;
  String? _historyError;
  int _historyPage = 1;
  int _historyTotalPages = 1;
  DateTime? _historyFrom;
  DateTime? _historyTo;

  List<Attendance> get history => List.unmodifiable(_history);
  bool get historyLoading => _historyLoading;
  bool get historyLoadingMore => _historyLoadingMore;
  bool get historyLoaded => _historyLoaded;
  String? get historyError => _historyError;
  bool get historyHasMore => _historyPage < _historyTotalPages;
  DateTime? get historyFrom => _historyFrom;
  DateTime? get historyTo => _historyTo;
  bool get historyFiltered => _historyFrom != null || _historyTo != null;

  Map<String, String> _historyQuery(int page) => {
        'page': '$page',
        'limit': '20',
        if (_historyFrom != null) 'from': _ymd.format(_historyFrom!),
        if (_historyTo != null) 'to': _ymd.format(_historyTo!),
      };

  Future<void> loadHistory({bool refresh = false}) async {
    if (_historyLoading) return;
    if (refresh || !_historyLoaded) {
      _historyPage = 1;
      _historyTotalPages = 1;
    }
    _historyLoading = true;
    _historyError = null;
    notifyListeners();
    try {
      final res = await _api.get('/attendance/history',
          query: _historyQuery(1));
      _history
        ..clear()
        ..addAll(asList(res.data).map((e) => Attendance.fromJson(asMap(e))));
      _historyPage = res.pagination?.page ?? 1;
      _historyTotalPages = res.pagination?.totalPages ?? 1;
      _historyLoaded = true;
    } on ApiException catch (e) {
      _historyError = e.message;
    }
    _historyLoading = false;
    notifyListeners();
  }

  Future<void> loadMoreHistory() async {
    if (_historyLoading || _historyLoadingMore || !historyHasMore) return;
    _historyLoadingMore = true;
    notifyListeners();
    try {
      final next = _historyPage + 1;
      final res = await _api.get('/attendance/history',
          query: _historyQuery(next));
      _history
          .addAll(asList(res.data).map((e) => Attendance.fromJson(asMap(e))));
      _historyPage = res.pagination?.page ?? next;
      _historyTotalPages = res.pagination?.totalPages ?? _historyTotalPages;
    } on ApiException catch (e) {
      _historyError = e.message;
    }
    _historyLoadingMore = false;
    notifyListeners();
  }

  Future<void> setHistoryRange(DateTime? from, DateTime? to) {
    _historyFrom = from;
    _historyTo = to;
    return loadHistory(refresh: true);
  }

  // --- Monthly summary --------------------------------------------------------

  AttendanceSummary? _summary;
  bool _summaryLoading = false;
  String? _summaryError;
  String? _summaryMonth;

  AttendanceSummary? get summary => _summary;
  bool get summaryLoading => _summaryLoading;
  String? get summaryError => _summaryError;
  String? get summaryMonth => _summaryMonth;

  /// [month] must be `YYYY-MM`.
  Future<void> loadSummary(String month) async {
    _summaryMonth = month;
    _summaryLoading = true;
    _summaryError = null;
    notifyListeners();
    try {
      final res =
          await _api.get('/attendance/summary', query: {'month': month});
      _summary = AttendanceSummary.fromJson(asMap(res.data));
    } on ApiException catch (e) {
      _summaryError = e.message;
      _summary = null;
    }
    _summaryLoading = false;
    notifyListeners();
  }

  // --- Requests ----------------------------------------------------------------

  final List<AttendanceRequest> _requests = [];
  bool _requestsLoading = false;
  bool _requestsLoadingMore = false;
  bool _requestsLoaded = false;
  String? _requestsError;
  int _requestsPage = 1;
  int _requestsTotalPages = 1;
  String? _requestsStatusFilter;

  List<AttendanceRequest> get requests => List.unmodifiable(_requests);
  bool get requestsLoading => _requestsLoading;
  bool get requestsLoadingMore => _requestsLoadingMore;
  bool get requestsLoaded => _requestsLoaded;
  String? get requestsError => _requestsError;
  bool get requestsHasMore => _requestsPage < _requestsTotalPages;
  String? get requestsStatusFilter => _requestsStatusFilter;

  Map<String, String> _requestsQuery(int page) => {
        'page': '$page',
        'status': ?_requestsStatusFilter,
      };

  Future<void> loadRequests({bool refresh = false}) async {
    if (_requestsLoading) return;
    if (refresh || !_requestsLoaded) {
      _requestsPage = 1;
      _requestsTotalPages = 1;
    }
    _requestsLoading = true;
    _requestsError = null;
    notifyListeners();
    try {
      final res = await _api.get('/attendance/requests/me',
          query: _requestsQuery(1));
      _requests
        ..clear()
        ..addAll(
            asList(res.data).map((e) => AttendanceRequest.fromJson(asMap(e))));
      _requestsPage = res.pagination?.page ?? 1;
      _requestsTotalPages = res.pagination?.totalPages ?? 1;
      _requestsLoaded = true;
    } on ApiException catch (e) {
      _requestsError = e.message;
    }
    _requestsLoading = false;
    notifyListeners();
  }

  Future<void> loadMoreRequests() async {
    if (_requestsLoading || _requestsLoadingMore || !requestsHasMore) return;
    _requestsLoadingMore = true;
    notifyListeners();
    try {
      final next = _requestsPage + 1;
      final res = await _api.get('/attendance/requests/me',
          query: _requestsQuery(next));
      _requests.addAll(
          asList(res.data).map((e) => AttendanceRequest.fromJson(asMap(e))));
      _requestsPage = res.pagination?.page ?? next;
      _requestsTotalPages = res.pagination?.totalPages ?? _requestsTotalPages;
    } on ApiException catch (e) {
      _requestsError = e.message;
    }
    _requestsLoadingMore = false;
    notifyListeners();
  }

  Future<void> setRequestsStatusFilter(String? status) {
    _requestsStatusFilter = status;
    return loadRequests(refresh: true);
  }

  /// `POST /attendance/requests`. Throws [ApiException] on validation errors.
  Future<void> createRequest({
    required DateTime date,
    required String type,
    DateTime? requestedCheckIn,
    DateTime? requestedCheckOut,
    required String reason,
  }) async {
    await _api.post('/attendance/requests', body: {
      'date': _ymd.format(date),
      'type': type,
      if (requestedCheckIn != null)
        'requestedCheckIn': requestedCheckIn.toUtc().toIso8601String(),
      if (requestedCheckOut != null)
        'requestedCheckOut': requestedCheckOut.toUtc().toIso8601String(),
      'reason': reason,
    });
    await loadRequests(refresh: true);
  }

  // --- Lifecycle ---------------------------------------------------------------

  /// Clears all cached state (used on logout).
  void reset() {
    _today = null;
    _todayLoading = false;
    _todayLoaded = false;
    _todayError = null;
    _history.clear();
    _historyLoading = false;
    _historyLoadingMore = false;
    _historyLoaded = false;
    _historyError = null;
    _historyPage = 1;
    _historyTotalPages = 1;
    _historyFrom = null;
    _historyTo = null;
    _summary = null;
    _summaryLoading = false;
    _summaryError = null;
    _summaryMonth = null;
    _requests.clear();
    _requestsLoading = false;
    _requestsLoadingMore = false;
    _requestsLoaded = false;
    _requestsError = null;
    _requestsPage = 1;
    _requestsTotalPages = 1;
    _requestsStatusFilter = null;
    notifyListeners();
  }
}
