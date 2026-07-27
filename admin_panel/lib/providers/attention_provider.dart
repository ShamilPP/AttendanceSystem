import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/api_client.dart';
import '../utils/formats.dart';

/// Counts the two things an admin actually has to *act* on every day:
/// pending regularization requests and yesterday's unresolved check-outs.
///
/// The shell uses these for navigation badges and the dashboard surfaces them
/// in the "Needs your attention" card, so neither queue can pile up unseen.
/// Both counts are cheap (page 1, limit 1 — only the pagination total is read
/// for requests) and refresh on a slow timer.
class AttentionProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient.instance;

  static const Duration refreshInterval = Duration(minutes: 2);

  int pendingRequests = 0;
  int missingCheckouts = 0;
  bool loading = false;
  DateTime? lastUpdated;

  Timer? _timer;

  /// The date the missing-checkout count refers to (yesterday, per contract).
  DateTime get missingCheckoutDate =>
      DateTime.now().subtract(const Duration(days: 1));

  bool get hasWork => pendingRequests > 0 || missingCheckouts > 0;

  /// Starts (once) the background refresh loop and does an immediate fetch.
  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(refreshInterval, (_) => refresh());
    refresh();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    pendingRequests = 0;
    missingCheckouts = 0;
    lastUpdated = null;
  }

  Future<void> refresh() async {
    if (loading) return;
    loading = true;
    notifyListeners();
    await Future.wait([_fetchPending(), _fetchMissing()]);
    lastUpdated = DateTime.now();
    loading = false;
    notifyListeners();
  }

  Future<void> _fetchPending() async {
    try {
      final result = await _api.get('/attendance/requests',
          query: {'status': 'PENDING', 'page': '1', 'limit': '1'});
      // Prefer the envelope total; fall back to the returned row count.
      pendingRequests = result.pagination?.total ?? result.dataList.length;
    } on ApiException {
      // Badges are ambient: a failed poll keeps the last known value rather
      // than flashing a misleading zero.
    }
  }

  Future<void> _fetchMissing() async {
    try {
      final result = await _api.get('/attendance/missing-checkouts',
          query: {'date': isoDay(missingCheckoutDate)});
      missingCheckouts = result.dataList.length;
    } on ApiException {
      // See above.
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
