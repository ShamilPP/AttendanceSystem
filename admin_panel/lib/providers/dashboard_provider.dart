import 'package:flutter/foundation.dart';

import '../models/dashboard.dart';
import '../services/api_client.dart';
import '../utils/json_utils.dart';

/// Dashboard stats + trends chart state.
class DashboardProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient.instance;

  DashboardStats? stats;
  List<TrendPoint> points = const [];
  String period = 'daily'; // daily | weekly | monthly
  bool loadingStats = false;
  bool loadingTrends = false;
  String? error;

  Future<void> load() async {
    loadingStats = true;
    loadingTrends = true;
    error = null;
    notifyListeners();
    await Future.wait([_fetchStats(), _fetchTrends()]);
    notifyListeners();
  }

  Future<void> setPeriod(String value) async {
    if (period == value) return;
    period = value;
    loadingTrends = true;
    notifyListeners();
    await _fetchTrends();
    notifyListeners();
  }

  Future<void> _fetchStats() async {
    try {
      final result = await _api.get('/dashboard/stats');
      stats = DashboardStats.fromJson(result.data);
    } on ApiException catch (e) {
      error = e.fullMessage;
    } finally {
      loadingStats = false;
    }
  }

  Future<void> _fetchTrends() async {
    try {
      final result =
          await _api.get('/dashboard/trends', query: {'period': period});
      final map = result.dataMap;
      points = jsonList(map['points']).map(TrendPoint.fromJson).toList();
    } on ApiException catch (e) {
      error = e.fullMessage;
    } finally {
      loadingTrends = false;
    }
  }
}
