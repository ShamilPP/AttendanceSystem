import 'package:flutter/foundation.dart';

import '../models/document.dart';
import '../models/json_helpers.dart';
import '../services/api_client.dart';

/// Employee documents: list, upload, download, delete.
class DocumentsProvider extends ChangeNotifier {
  DocumentsProvider(this._api);

  final ApiClient _api;

  final List<EmployeeDocument> _documents = [];
  bool _loading = false;
  bool _loaded = false;
  bool _uploading = false;
  String? _error;

  List<EmployeeDocument> get documents => List.unmodifiable(_documents);
  bool get loading => _loading;
  bool get loaded => _loaded;
  bool get uploading => _uploading;
  String? get error => _error;

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _api.get('/documents/me');
      _documents
        ..clear()
        ..addAll(
            asList(res.data).map((e) => EmployeeDocument.fromJson(asMap(e))));
      _loaded = true;
    } on ApiException catch (e) {
      _error = e.message;
    }
    _loading = false;
    notifyListeners();
  }

  /// Uploads a document (`POST /documents`, multipart `file`, `type`, `name`).
  /// Throws [ApiException] on rejection (size/type validation happens
  /// client-side first, but the server also validates).
  Future<void> upload({
    required String filePath,
    required String fileName,
    required String name,
    required String type,
  }) async {
    _uploading = true;
    notifyListeners();
    try {
      await _api.uploadFile(
        '/documents',
        filePath: filePath,
        fileName: fileName,
        fields: {'type': type, 'name': name},
      );
      await load();
    } finally {
      _uploading = false;
      notifyListeners();
    }
  }

  /// Streams the file bytes from `GET /documents/:id/download`.
  Future<List<int>> download(EmployeeDocument doc) =>
      _api.downloadBytes('/documents/${doc.id}/download');

  Future<void> delete(EmployeeDocument doc) async {
    await _api.delete('/documents/${doc.id}');
    _documents.removeWhere((d) => d.id == doc.id);
    notifyListeners();
  }

  /// Clears cached state (used on logout).
  void reset() {
    _documents.clear();
    _loading = false;
    _loaded = false;
    _uploading = false;
    _error = null;
    notifyListeners();
  }
}
