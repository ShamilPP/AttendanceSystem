import 'package:flutter/foundation.dart';

import '../models/user.dart';
import '../services/api_client.dart';
import '../utils/json_utils.dart';

enum AuthStatus { restoring, unauthenticated, authenticating, authenticated }

/// Session state: login, token restore on reload, logout.
class AuthProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient.instance;

  AuthStatus status = AuthStatus.restoring;
  User? user;
  String? error;

  /// Validates a persisted token against `GET /auth/me`.
  Future<void> restore() async {
    if (!_api.hasToken) {
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    try {
      final result = await _api.get('/auth/me');
      final me = User.fromJson(result.data);
      if (me.isAdmin) {
        user = me;
        status = AuthStatus.authenticated;
      } else {
        await _api.setToken(null);
        status = AuthStatus.unauthenticated;
      }
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        await _api.setToken(null);
      }
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  /// Logs in and rejects non-admin accounts with a clear message.
  Future<bool> login(String email, String password) async {
    status = AuthStatus.authenticating;
    error = null;
    notifyListeners();
    try {
      final result = await _api
          .post('/auth/login', body: {'email': email, 'password': password});
      final payload = result.dataMap;
      final loggedIn = User.fromJson(payload['user']);
      if (!loggedIn.isAdmin) {
        error =
            'This panel is for administrators only. Please sign in with an admin account.';
        status = AuthStatus.unauthenticated;
        notifyListeners();
        return false;
      }
      await _api.setToken(jsonString(payload['token']));
      user = loggedIn;
      status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      error = e.fullMessage;
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _api.setToken(null);
    user = null;
    error = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
