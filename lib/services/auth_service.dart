import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService with ChangeNotifier {
  static const String _authTokenKey = 'auth_token';
  bool _isAuthenticated = false;

  bool get isAuthenticated => _isAuthenticated;

  AuthService() {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _isAuthenticated = prefs.getString(_authTokenKey) != null;
    print('AuthService: isAuthenticated initialized to $_isAuthenticated'); // NEW
    notifyListeners();
  }

  Future<void> saveAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_authTokenKey, token);
    _isAuthenticated = true;
    print('AuthService: Token saved. isAuthenticated: $_isAuthenticated'); // NEW
    notifyListeners();
  }

  Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_authTokenKey);
    print('AuthService: getAuthToken returned: $token'); // NEW
    return token;
  }

  Future<void> clearAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authTokenKey);
    _isAuthenticated = false;
    print('AuthService: Token cleared. isAuthenticated: $_isAuthenticated'); // NEW
    notifyListeners();
  }
}

