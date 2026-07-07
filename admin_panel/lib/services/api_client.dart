import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/pagination.dart';
import '../utils/json_utils.dart';

/// One field-level validation error from the API.
class FieldError {
  const FieldError({required this.field, required this.message});

  final String field;
  final String message;

  static List<FieldError> listFrom(dynamic json) => jsonList(json)
      .map((e) => FieldError(
            field: jsonString(jsonMap(e)['field']),
            message: jsonString(jsonMap(e)['message']),
          ))
      .toList();
}

/// Typed API error carrying the HTTP status, message and validation errors.
class ApiException implements Exception {
  const ApiException(this.statusCode, this.message, {this.errors = const []});

  /// HTTP status code; 0 means the server could not be reached.
  final int statusCode;
  final String message;
  final List<FieldError> errors;

  bool get isUnauthorized => statusCode == 401;
  bool get isConflict => statusCode == 409;

  /// Message plus field errors, suitable for a snackbar.
  String get fullMessage {
    if (errors.isEmpty) return message;
    final details = errors.map((e) => '${e.field}: ${e.message}').join(' · ');
    return '$message — $details';
  }

  @override
  String toString() => message;
}

/// Decoded `{ success, data, pagination, message }` envelope.
class ApiResult {
  const ApiResult({this.data, this.pagination, this.message});

  final dynamic data;
  final Pagination? pagination;
  final String? message;

  List<dynamic> get dataList => jsonList(data);
  Map<String, dynamic> get dataMap => jsonMap(data);
}

/// Raw bytes downloaded from a file endpoint plus the resolved filename.
class DownloadedBytes {
  const DownloadedBytes({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;
}

/// HTTP client for the attendance API. Holds the JWT in memory and persists
/// it via shared_preferences so a page reload keeps the session.
class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  static const String _tokenKey = 'attendance_admin_token';
  static const Duration _timeout = Duration(seconds: 30);

  final http.Client _http = http.Client();
  String? _token;

  bool get hasToken => _token != null && _token!.isNotEmpty;

  /// Restores a persisted token; call once before `runApp`.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_tokenKey);
      _token = (stored == null || stored.isEmpty) ? null : stored;
    } catch (_) {
      _token = null;
    }
  }

  /// Sets (and persists) or clears the bearer token.
  Future<void> setToken(String? token) async {
    _token = (token == null || token.isEmpty) ? null : token;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_token == null) {
        await prefs.remove(_tokenKey);
      } else {
        await prefs.setString(_tokenKey, _token!);
      }
    } catch (_) {
      // In-memory token still works if persistence is unavailable.
    }
  }

  Uri _uri(String path, [Map<String, String?>? query]) {
    final base = Uri.parse('${ApiConfig.baseUrl}$path');
    final params = <String, String>{...base.queryParameters};
    query?.forEach((key, value) {
      if (value != null && value.isNotEmpty) params[key] = value;
    });
    return base.replace(queryParameters: params.isEmpty ? null : params);
  }

  Map<String, String> _headers({bool jsonBody = false}) => {
        'Accept': 'application/json',
        if (jsonBody) 'Content-Type': 'application/json',
        if (hasToken) 'Authorization': 'Bearer $_token',
      };

  Future<ApiResult> get(String path, {Map<String, String?>? query}) =>
      _send(() => _http.get(_uri(path, query), headers: _headers()));

  Future<ApiResult> post(String path, {Object? body}) => _send(() => _http.post(
        _uri(path),
        headers: _headers(jsonBody: true),
        body: jsonEncode(body ?? const <String, dynamic>{}),
      ));

  Future<ApiResult> put(String path, {Object? body}) => _send(() => _http.put(
        _uri(path),
        headers: _headers(jsonBody: true),
        body: jsonEncode(body ?? const <String, dynamic>{}),
      ));

  Future<ApiResult> delete(String path, {Map<String, String?>? query}) =>
      _send(() => _http.delete(_uri(path, query), headers: _headers()));

  /// Multipart upload (e.g. `POST /employees/import` with field `file`).
  Future<ApiResult> uploadMultipart(
    String path, {
    required Uint8List bytes,
    required String filename,
    String field = 'file',
    Map<String, String> fields = const {},
  }) async {
    final request = http.MultipartRequest('POST', _uri(path))
      ..headers.addAll(_headers())
      ..fields.addAll(fields)
      ..files.add(http.MultipartFile.fromBytes(field, bytes, filename: filename));
    http.Response response;
    try {
      final streamed = await request.send().timeout(_timeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw const ApiException(0, 'The server did not respond in time.');
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
          0, 'Cannot reach the server. Is the backend running on port 5000?');
    }
    return _decode(response);
  }

  /// Downloads raw bytes (xlsx exports, report files). The filename comes
  /// from `Content-Disposition` when the browser exposes it, otherwise
  /// [fallbackName] is used.
  Future<DownloadedBytes> downloadBytes(
    String path, {
    Map<String, String?>? query,
    required String fallbackName,
  }) async {
    http.Response response;
    try {
      response = await _http
          .get(_uri(path, query), headers: {
            'Accept': '*/*',
            if (hasToken) 'Authorization': 'Bearer $_token',
          })
          .timeout(_timeout);
    } on TimeoutException {
      throw const ApiException(0, 'The server did not respond in time.');
    } catch (_) {
      throw const ApiException(
          0, 'Cannot reach the server. Is the backend running on port 5000?');
    }
    if (response.statusCode >= 400) {
      // Error responses are JSON envelopes even on file endpoints.
      _decode(response); // always throws for >= 400
    }
    final disposition = response.headers['content-disposition'];
    return DownloadedBytes(
      bytes: response.bodyBytes,
      filename: _filenameFromDisposition(disposition) ?? fallbackName,
    );
  }

  static String? _filenameFromDisposition(String? disposition) {
    if (disposition == null) return null;
    final starMatch =
        RegExp("filename\\*=(?:UTF-8'')?([^;]+)", caseSensitive: false)
            .firstMatch(disposition);
    if (starMatch != null) {
      final raw = starMatch.group(1)!.trim().replaceAll('"', '');
      try {
        return Uri.decodeComponent(raw);
      } catch (_) {
        return raw;
      }
    }
    final match = RegExp('filename="?([^";]+)"?', caseSensitive: false)
        .firstMatch(disposition);
    return match?.group(1)?.trim();
  }

  Future<ApiResult> _send(Future<http.Response> Function() request) async {
    http.Response response;
    try {
      response = await request().timeout(_timeout);
    } on TimeoutException {
      throw const ApiException(0, 'The server did not respond in time.');
    } catch (_) {
      throw const ApiException(
          0, 'Cannot reach the server. Is the backend running on port 5000?');
    }
    return _decode(response);
  }

  ApiResult _decode(http.Response response) {
    Map<String, dynamic>? envelope;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) envelope = decoded;
    } catch (_) {
      envelope = null;
    }

    final ok = response.statusCode >= 200 && response.statusCode < 300;
    if (envelope == null) {
      if (ok) return const ApiResult();
      throw ApiException(
          response.statusCode, 'Request failed (HTTP ${response.statusCode}).');
    }

    if (!ok || envelope['success'] != true) {
      throw ApiException(
        response.statusCode,
        jsonString(envelope['message'],
            'Request failed (HTTP ${response.statusCode}).'),
        errors: FieldError.listFrom(envelope['errors']),
      );
    }

    return ApiResult(
      data: envelope['data'],
      pagination: envelope['pagination'] == null
          ? null
          : Pagination.fromJson(envelope['pagination']),
      message: jsonStringOrNull(envelope['message']),
    );
  }
}
