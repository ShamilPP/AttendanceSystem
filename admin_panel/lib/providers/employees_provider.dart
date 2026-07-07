import 'package:flutter/foundation.dart';

import '../models/import_result.dart';
import '../models/pagination.dart';
import '../models/user.dart';
import '../services/api_client.dart';

/// Employee management: list with filters, CRUD, Excel import/export.
class EmployeesProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient.instance;

  List<User> records = const [];
  Pagination? pagination;
  bool loading = false;
  String? error;

  // Filters.
  String search = '';
  String? departmentId;
  String? designationId;
  String? isActive; // 'true' | 'false' | null (all)
  int page = 1;
  static const int limit = 20;

  Future<void> fetch({int? toPage}) async {
    page = toPage ?? page;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await _api.get('/employees', query: {
        'search': search,
        'departmentId': departmentId,
        'designationId': designationId,
        'isActive': isActive,
        'page': '$page',
        'limit': '$limit',
      });
      records = result.dataList.map(User.fromJson).toList();
      pagination = result.pagination;
    } on ApiException catch (e) {
      error = e.fullMessage;
    }
    loading = false;
    notifyListeners();
  }

  Future<void> applyFilters({
    required String search,
    required String? departmentId,
    required String? designationId,
    required String? isActive,
  }) async {
    this.search = search;
    this.departmentId = departmentId;
    this.designationId = designationId;
    this.isActive = isActive;
    await fetch(toPage: 1);
  }

  Future<void> create(Map<String, dynamic> body) async {
    await _api.post('/employees', body: body);
    await fetch();
  }

  Future<void> update(String id, Map<String, dynamic> body) async {
    await _api.put('/employees/$id', body: body);
    await fetch();
  }

  /// Soft delete — the backend sets `isActive: false`.
  Future<void> softDelete(String id) async {
    await _api.delete('/employees/$id');
    await fetch();
  }

  /// `POST /employees/import` (multipart, field `file`).
  Future<ImportResult> importXlsx(Uint8List bytes, String filename) async {
    final result = await _api.uploadMultipart('/employees/import',
        bytes: bytes, filename: filename);
    await fetch(toPage: 1);
    return ImportResult.fromJson(result.data);
  }

  /// `GET /employees/export` — returns xlsx bytes for the download helper.
  Future<DownloadedBytes> exportXlsx() =>
      _api.downloadBytes('/employees/export', fallbackName: 'employees.xlsx');
}
