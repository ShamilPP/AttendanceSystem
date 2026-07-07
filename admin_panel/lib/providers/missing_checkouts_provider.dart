import 'package:flutter/foundation.dart';

import '../models/attendance.dart';
import '../services/api_client.dart';
import '../utils/formats.dart';

/// Records with a check-in but no check-out for a chosen date.
class MissingCheckoutsProvider extends ChangeNotifier {
  MissingCheckoutsProvider()
      : date = DateTime.now().subtract(const Duration(days: 1));

  final ApiClient _api = ApiClient.instance;

  DateTime date; // defaults to yesterday per the contract
  List<Attendance> records = const [];
  bool loading = false;
  String? error;

  Future<void> fetch() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await _api
          .get('/attendance/missing-checkouts', query: {'date': isoDay(date)});
      records = result.dataList.map(Attendance.fromJson).toList();
    } on ApiException catch (e) {
      error = e.fullMessage;
    }
    loading = false;
    notifyListeners();
  }

  Future<void> setDate(DateTime value) async {
    date = value;
    await fetch();
  }

  /// `PUT /attendance/:id/resolve-checkout`.
  Future<void> resolve(String id, String checkOutIso, String note) async {
    await _api.put('/attendance/$id/resolve-checkout',
        body: {'checkOut': checkOutIso, 'note': note});
    await fetch();
  }
}
