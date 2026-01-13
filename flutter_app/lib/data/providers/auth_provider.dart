import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _api = ApiService();
  final LocalStorageService _storage = LocalStorageService();

  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    
    // MOCK LOGIN FOR TESTING
    await Future.delayed(const Duration(seconds: 1));
    _user = User(
      id: 'test-user-1',
      email: email,
      firstName: 'Test',
      lastName: 'Teacher',
      schoolName: 'Demo School',
      country: 'US',
      languagePreference: 'en',
      createdAt: DateTime.now(),
    );
    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<bool> register(Map<String, dynamic> data) async {
    _isLoading = true;
    notifyListeners();

    // MOCK REGISTER FOR TESTING
    await Future.delayed(const Duration(seconds: 1));
    _user = User(
      id: 'test-user-1',
      email: data['email'] ?? 'test@example.com',
      firstName: data['first_name'] ?? 'Test',
      lastName: data['last_name'] ?? 'Teacher',
      schoolName: data['school_name'],
      country: data['country'],
      languagePreference: 'en',
      createdAt: DateTime.now(),
    );
    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<void> loadUser() async {
    try {
      // 1. Try to use existing token
      if (await _storage.hasToken()) {
        try {
          final response = await _api.getMe();
          _user = User.fromJson(response);
          await _storage.saveUser(_user!);
          notifyListeners();
          return;
        } catch (e) {
          // Token invalid, clear and proceed to auto-login
          await _storage.clearAll();
        }
      }

      // 2. Silent Auto-Login (Test Mode)
      const testEmail = 'test@example.com';
      const testPass = 'password123';
      
      try {
        // Try Login
        final response = await _api.login(testEmail, testPass);
        await _storage.saveToken(response['token']);
        _user = User.fromJson(response['user']);
      } catch (e) {
        // Login failed, try Register
        try {
          final regResponse = await _api.register({
            'email': testEmail,
            'password': testPass,
            'first_name': 'Test',
            'last_name': 'User',
            'school_name': 'Demo School',
            'country': 'US',
            'language_preference': 'en'
          });
          await _storage.saveToken(regResponse['token']);
          _user = User.fromJson(regResponse['user']);
        } catch (regError) {
          debugPrint('Auto-auth failed: $regError');
          rethrow;
        }
      }
      
      if (_user != null) {
        await _storage.saveUser(_user!);
      }
      notifyListeners();
      
    } catch (e) {
      debugPrint('Load user error: $e');
      _user = User(
        id: 'offline-user',
        email: 'offline@demo.com',
        firstName: 'Offline',
        lastName: 'User',
        languagePreference: 'en',
        createdAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  Future<bool> ensureAuthenticated() async {
    if (isAuthenticated && _user?.id != 'offline-user') {
      // Validate token
      if (await _storage.hasToken()) return true;
    }

    // Force re-login
    try {
      const testEmail = 'test@example.com';
      const testPass = 'password123';
      
      try {
        final response = await _api.login(testEmail, testPass);
        await _storage.saveToken(response['token']);
        _user = User.fromJson(response['user']);
      } catch (e) {
        final regResponse = await _api.register({
          'email': testEmail,
          'password': testPass,
          'first_name': 'Test',
          'last_name': 'User',
          'school_name': 'Demo School',
          'country': 'US',
          'language_preference': 'en'
        });
        await _storage.saveToken(regResponse['token']);
        _user = User.fromJson(regResponse['user']);
      }
      
      if (_user != null) {
        await _storage.saveUser(_user!);
      }
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Ensure auth failed: $e');
      return false;
    }
  }

  Future<void> logout() async {
    await _storage.clearAll();
    _user = null;
    notifyListeners();
  }

  String _getErrorMessage(dynamic error) {
    if (error.toString().contains('DioException')) {
      return 'Network error. Please check your connection.';
    }
    return error.toString();
  }
}
