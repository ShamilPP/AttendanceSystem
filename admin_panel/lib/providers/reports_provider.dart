import 'package:flutter/foundation.dart';

import '../services/api_client.dart';
import '../utils/formats.dart';
import '../utils/json_utils.dart';

enum ReportType { daily, weekly, monthly, workingHours, lateArrivals, earlyCheckouts }

extension ReportTypeInfo on ReportType {
  String get label {
    switch (this) {
      case ReportType.daily:
        return 'Daily';
      case ReportType.weekly:
        return 'Weekly';
      case ReportType.monthly:
        return 'Monthly';
      case ReportType.workingHours:
        return 'Working Hours';
      case ReportType.lateArrivals:
        return 'Late Arrivals';
      case ReportType.earlyCheckouts:
        return 'Early Check-outs';
    }
  }
}

/// Reports screen state: type, date controls, rows, Excel export.
class ReportsProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient.instance;

  ReportType type = ReportType.daily;
  DateTime date = DateTime.now(); // daily
  DateTime from = DateTime.now().subtract(const Duration(days: 6)); // ranges
  DateTime to = DateTime.now();
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month); // monthly
  String? departmentId; // attendance reports only

  List<Map<String, dynamic>> rows = const [];
  bool loading = false;
  bool exporting = false;
  bool hasRun = false;
  String? error;

  void setType(ReportType value) {
    if (type == value) return;
    type = value;
    rows = const [];
    hasRun = false;
    error = null;
    notifyListeners();
  }

  void setParams({
    DateTime? date,
    DateTime? from,
    DateTime? to,
    DateTime? month,
    bool clearDepartment = false,
    String? departmentId,
  }) {
    if (date != null) this.date = date;
    if (from != null) this.from = from;
    if (to != null) this.to = to;
    if (month != null) this.month = month;
    if (clearDepartment) {
      this.departmentId = null;
    } else if (departmentId != null) {
      this.departmentId = departmentId;
    }
    notifyListeners();
  }

  String get _path {
    switch (type) {
      case ReportType.daily:
      case ReportType.weekly:
      case ReportType.monthly:
        return '/reports/attendance';
      case ReportType.workingHours:
        return '/reports/working-hours';
      case ReportType.lateArrivals:
        return '/reports/late-arrivals';
      case ReportType.earlyCheckouts:
        return '/reports/early-checkouts';
    }
  }

  Map<String, String?> _query() {
    switch (type) {
      case ReportType.daily:
        return {
          'type': 'daily',
          'date': isoDay(date),
          'departmentId': departmentId,
        };
      case ReportType.weekly:
        return {
          'type': 'weekly',
          'from': isoDay(from),
          'to': isoDay(to),
          'departmentId': departmentId,
        };
      case ReportType.monthly:
        return {
          'type': 'monthly',
          'month': isoMonth(month),
          'departmentId': departmentId,
        };
      case ReportType.workingHours:
        return {'month': isoMonth(month)};
      case ReportType.lateArrivals:
      case ReportType.earlyCheckouts:
        return {'from': isoDay(from), 'to': isoDay(to)};
    }
  }

  String get _exportName {
    switch (type) {
      case ReportType.daily:
        return 'attendance-daily-${isoDay(date)}.xlsx';
      case ReportType.weekly:
        return 'attendance-weekly-${isoDay(from)}_${isoDay(to)}.xlsx';
      case ReportType.monthly:
        return 'attendance-monthly-${isoMonth(month)}.xlsx';
      case ReportType.workingHours:
        return 'working-hours-${isoMonth(month)}.xlsx';
      case ReportType.lateArrivals:
        return 'late-arrivals-${isoDay(from)}_${isoDay(to)}.xlsx';
      case ReportType.earlyCheckouts:
        return 'early-checkouts-${isoDay(from)}_${isoDay(to)}.xlsx';
    }
  }

  Future<void> run() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await _api.get(_path, query: _query());
      rows = result.dataList.map(jsonMap).toList();
      hasRun = true;
    } on ApiException catch (e) {
      error = e.fullMessage;
      rows = const [];
    }
    loading = false;
    notifyListeners();
  }

  /// Same query with `format=xlsx`; caller hands bytes to the download helper.
  Future<DownloadedBytes> exportXlsx() async {
    exporting = true;
    notifyListeners();
    try {
      return await _api.downloadBytes(
        _path,
        query: {..._query(), 'format': 'xlsx'},
        fallbackName: _exportName,
      );
    } finally {
      exporting = false;
      notifyListeners();
    }
  }
}
