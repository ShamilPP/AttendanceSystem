import 'package:flutter/foundation.dart';

import '../models/user.dart';
import '../services/api_client.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

/// Authentication state: token restore, login, logout, change password.
class AuthProvider extends ChangeNotifier {
  AuthProvider(this._api);

  final ApiClient _api;

  AuthStatus _status = AuthStatus.unknown;
  User? _user;

  AuthStatus get status => _status;
  User? get user => _user;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// Validates any stored token against `GET /auth/me`.
  ///
  /// Returns true when a session was restored. Throws [ApiException] on
  /// network failures so the splash screen can offer a retry.
  Future<bool> tryRestoreSession() async {
    final token = await _api.readToken();
    if (token == null || token.isEmpty) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
    try {
      final res = await _api.get('/auth/me');
      _user = User.fromJson(res.data as Map<String, dynamic>);
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      if (e.isNetwork) rethrow;
      // Invalid/expired token or any server-side rejection: force re-login.
      await _api.clearToken();
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  /// `POST /auth/login` — stores the JWT and the user on success.
  /// Throws [ApiException] with the server message on failure.
  Future<void> login(String email, String password) async {
    final res = await _api.post(
      '/auth/login',
      body: {'email': email.trim(), 'password': password},
      auth: false,
    );
    final data = res.data as Map<String, dynamic>? ?? const {};
    final token = data['token'] as String?;
    if (token == null || token.isEmpty) {
      throw const ApiException(0, 'Login response did not include a token.');
    }
    await _api.saveToken(token);
    _user = User.fromJson(data['user'] as Map<String, dynamic>? ?? const {});
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  /// Refreshes the current user from `GET /auth/me`.
  Future<void> refreshMe() async {
    final res = await _api.get('/auth/me');
    _user = User.fromJson(res.data as Map<String, dynamic>);
    notifyListeners();
  }

  /// `POST /auth/change-password` — returns the server's message.
  Future<String> changePassword(
      String currentPassword, String newPassword) async {
    final res = await _api.post('/auth/change-password', body: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
    final data = res.data;
    if (data is Map<String, dynamic> && data['message'] is String) {
      return data['message'] as String;
    }
    return 'Password changed successfully.';
  }

  Future<void> logout() async {
    await _api.clearToken();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
