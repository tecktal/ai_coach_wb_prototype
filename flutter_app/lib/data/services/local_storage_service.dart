import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user.dart';

class LocalStorageService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';
  static const String _onboardingKey = 'onboarding_completed';

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  Future<User?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      try {
        return User.fromJson(jsonDecode(userJson));
      } catch (_) {
        // Cache is corrupted (e.g. missing fields from old app version).
        // Clear it so loadUser() falls through to the network fetch.
        await prefs.remove(_userKey);
        return null;
      }
    }
    return null;
  }

  /// Wipes ALL user-scoped data from SharedPreferences on logout.
  /// Device-level prefs (dark mode, onboarding) are intentionally preserved.
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    for (final key in allKeys) {
      // Preserve device-level settings that are not tied to any user account.
      if (key == _onboardingKey) continue;
      if (key == 'is_dark_mode') continue;
      await prefs.remove(key);
    }
  }

  /// Removes only the auth token, preserving cached user data.
  /// Used by the Dio interceptor on 401 — full logout is handled by AuthProvider.
  Future<void> removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> setOnboardingCompleted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, value);
  }

  Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingKey) ?? false;
  }

  Future<void> setIsDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', value);
  }

  Future<bool> getIsDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_dark_mode') ?? false;
  }
}
