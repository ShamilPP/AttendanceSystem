import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/api_config.dart';
import '../models/json_helpers.dart';

/// A single field-level validation error from the API envelope.
class ApiFieldError {
  const ApiFieldError({required this.field, required this.message});

  final String field;
  final String message;

  factory ApiFieldError.fromJson(Map<String, dynamic> json) => ApiFieldError(
        field: asString(json['field']),
        message: asString(json['message']),
      );
}

/// Typed exception carrying the server's human-readable message.
///
/// `statusCode == 0` means the request never reached the server
/// (network / timeout).
class ApiException implements Exception {
  const ApiException(this.statusCode, this.message,
      [this.errors = const []]);

  final int statusCode;
  final String message;
  final List<ApiFieldError> errors;

  bool get isUnauthorized => statusCode == 401;
  bool get isNetwork => statusCode == 0;

  @override
  String toString() => message;
}

/// `pagination` block of paginated responses.
class Pagination {
  const Pagination({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  final int page;
  final int limit;
  final int total;
  final int totalPages;

  factory Pagination.fromJson(Map<String, dynamic> json) => Pagination(
        page: asInt(json['page'], 1),
        limit: asInt(json['limit'], 20),
        total: asInt(json['total']),
        totalPages: asInt(json['totalPages'], 1),
      );
}

/// Decoded success envelope: `{ success: true, data, pagination? }`.
class ApiResponse {
  const ApiResponse({this.data, this.pagination});

  final dynamic data;
  final Pagination? pagination;
}

/// HTTP wrapper for the attendance API.
///
/// - Injects the `Authorization: Bearer <JWT>` header from secure storage.
/// - Decodes the `{ success, data, message, errors, pagination }` envelope.
/// - Throws [ApiException] with the server's message on any failure.
class ApiClient {
  ApiClient({FlutterSecureStorage? storage, http.Client? httpClient})
      : _storage = storage ?? const FlutterSecureStorage(),
        _http = httpClient ?? http.Client();

  static const String _tokenKey = 'attendance_jwt_token';

  final FlutterSecureStorage _storage;
  final http.Client _http;

  // --- Token management -----------------------------------------------------

  Future<String?> readToken() async {
    try {
      return await _storage.read(key: _tokenKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<void> clearToken() => _storage.delete(key: _tokenKey);

  // --- JSON endpoints -------------------------------------------------------

  Future<ApiResponse> get(String path,
      {Map<String, String>? query, bool auth = true}) async {
    final res = await _guard(() async => _http
        .get(_uri(path, query), headers: await _headers(auth: auth))
        .timeout(ApiConfig.requestTimeout));
    return _decode(res);
  }

  Future<ApiResponse> post(String path,
      {Object? body, bool auth = true}) async {
    final res = await _guard(() async => _http
        .post(_uri(path),
            headers: await _headers(auth: auth, json: true),
            body: body == null ? null : jsonEncode(body))
        .timeout(ApiConfig.requestTimeout));
    return _decode(res);
  }

  Future<ApiResponse> put(String path,
      {Object? body, bool auth = true}) async {
    final res = await _guard(() async => _http
        .put(_uri(path),
            headers: await _headers(auth: auth, json: true),
            body: body == null ? null : jsonEncode(body))
        .timeout(ApiConfig.requestTimeout));
    return _decode(res);
  }

  Future<ApiResponse> delete(String path,
      {Map<String, String>? query, bool auth = true}) async {
    final res = await _guard(() async => _http
        .delete(_uri(path, query), headers: await _headers(auth: auth))
        .timeout(ApiConfig.requestTimeout));
    return _decode(res);
  }

  // --- Multipart upload -----------------------------------------------------

  /// Uploads a single file with additional form [fields]
  /// (e.g. `POST /documents` with `file`, `type`, `name`).
  Future<ApiResponse> uploadFile(
    String path, {
    required String filePath,
    required String fileName,
    Map<String, String> fields = const {},
    String fileField = 'file',
  }) async {
    final res = await _guard(() async {
      final request = http.MultipartRequest('POST', _uri(path));
      request.headers.addAll(await _headers());
      request.fields.addAll(fields);
      request.files.add(await http.MultipartFile.fromPath(
        fileField,
        filePath,
        filename: fileName,
        contentType: _contentTypeFor(fileName),
      ));
      final streamed =
          await request.send().timeout(ApiConfig.transferTimeout);
      return http.Response.fromStream(streamed);
    });
    return _decode(res);
  }

  // --- Binary download ------------------------------------------------------

  /// Downloads raw bytes (e.g. `GET /documents/:id/download`).
  Future<List<int>> downloadBytes(String path) async {
    final res = await _guard(() async => _http
        .get(_uri(path), headers: await _headers())
        .timeout(ApiConfig.transferTimeout));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return res.bodyBytes;
    }
    // Non-2xx: the body should be the JSON error envelope.
    _decode(res); // always throws for non-2xx
    throw ApiException(
        res.statusCode, 'Download failed (HTTP ${res.statusCode}).');
  }

  // --- Internals ------------------------------------------------------------

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: {...uri.queryParameters, ...query});
  }

  Future<Map<String, String>> _headers(
      {bool auth = true, bool json = false}) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (json) headers['Content-Type'] = 'application/json';
    if (auth) {
      final token = await readToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Future<http.Response> _guard(
      Future<http.Response> Function() request) async {
    try {
      return await request();
    } on SocketException {
      throw const ApiException(0,
          'Cannot reach the server. Check your connection and the API URL.');
    } on TimeoutException {
      throw const ApiException(
          0, 'The server took too long to respond. Please try again.');
    } on http.ClientException catch (e) {
      throw ApiException(0, 'Network error: ${e.message}');
    } on HandshakeException {
      throw const ApiException(0, 'Secure connection to the server failed.');
    }
  }

  ApiResponse _decode(http.Response res) {
    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {
      body = null;
    }

    final isHttpOk = res.statusCode >= 200 && res.statusCode < 300;
    final isEnvelopeOk = body != null && body['success'] == true;

    if (isHttpOk && isEnvelopeOk) {
      return ApiResponse(
        data: body['data'],
        pagination: body['pagination'] is Map
            ? Pagination.fromJson(asMap(body['pagination']))
            : null,
      );
    }

    final message = asString(
      body?['message'],
      isHttpOk
          ? 'Unexpected response from the server.'
          : 'Request failed (HTTP ${res.statusCode}).',
    );
    final errors = asList(body?['errors'])
        .map((e) => ApiFieldError.fromJson(asMap(e)))
        .toList();
    throw ApiException(res.statusCode, message, errors);
  }

  MediaType? _contentTypeFor(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final ext =
        dot == -1 ? '' : fileName.substring(dot + 1).toLowerCase();
    switch (ext) {
      case 'pdf':
        return MediaType('application', 'pdf');
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      default:
        return null;
    }
  }
}
