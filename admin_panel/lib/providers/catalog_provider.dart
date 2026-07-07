import 'package:flutter/foundation.dart';

import '../models/catalog_item.dart';
import '../services/api_client.dart';

/// Departments & designations shared by filters, dialogs and the CRUD screen.
class CatalogProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient.instance;

  List<CatalogItem> departments = const [];
  List<CatalogItem> designations = const [];
  bool loading = false;
  bool _loaded = false;
  String? error;

  /// Loads both lists once; used by screens that only need the dropdowns.
  Future<void> ensureLoaded() async {
    if (_loaded || loading) return;
    await refresh();
  }

  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait(
          [_api.get('/departments'), _api.get('/designations')]);
      departments = results[0].dataList.map(CatalogItem.fromJson).toList();
      designations = results[1].dataList.map(CatalogItem.fromJson).toList();
      _loaded = true;
    } on ApiException catch (e) {
      error = e.fullMessage;
    }
    loading = false;
    notifyListeners();
  }

  /// [kind] is `departments` or `designations` (the API path segment).
  Future<void> create(String kind, String name, String? description) async {
    await _api.post('/$kind', body: {
      'name': name,
      if (description != null && description.isNotEmpty)
        'description': description,
    });
    await refresh();
  }

  Future<void> rename(
      String kind, String id, String name, String? description) async {
    await _api.put('/$kind/$id', body: {
      'name': name,
      if (description != null && description.isNotEmpty)
        'description': description,
    });
    await refresh();
  }

  /// Throws [ApiException] with status 409 when the item is in use.
  Future<void> remove(String kind, String id) async {
    await _api.delete('/$kind/$id');
    await refresh();
  }
}
