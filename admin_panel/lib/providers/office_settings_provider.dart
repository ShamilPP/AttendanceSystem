import 'package:flutter/foundation.dart';

import '../models/office_settings.dart';
import '../services/api_client.dart';

/// Office settings singleton form state.
class OfficeSettingsProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient.instance;

  OfficeSettings? settings;
  bool loading = false;
  bool saving = false;
  String? error;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await _api.get('/office-settings');
      settings = OfficeSettings.fromJson(result.data);
    } on ApiException catch (e) {
      error = e.fullMessage;
    }
    loading = false;
    notifyListeners();
  }

  /// `PUT /office-settings`; rethrows so the form can show field errors.
  Future<void> save(OfficeSettings value) async {
    saving = true;
    notifyListeners();
    try {
      final result = await _api.put('/office-settings', body: value.toJson());
      settings = OfficeSettings.fromJson(result.data);
    } finally {
      saving = false;
      notifyListeners();
    }
  }
}
