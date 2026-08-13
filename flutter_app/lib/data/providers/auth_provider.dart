import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/l10n/app_strings.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';
import 'locale_provider.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _api = ApiService();
  final LocalStorageService _storage = LocalStorageService();

  User? _user;
  bool _isLoading = false;
  String? _error;
  LocaleProvider? _localeProvider;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  /// Inject the [LocaleProvider] so auth events auto-switch the app locale.
  /// Call this once from a ProxyProvider or directly after construction.
  void attachLocaleProvider(LocaleProvider lp) => _localeProvider = lp;

  Future<String?> getToken() => _storage.getToken();

  Future<bool> login(String username, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final response = await _api.login(username, password);
      await _storage.saveToken(response['token']);
      _user = User.fromJson(response['user']);
      await _storage.saveUser(_user!);
      _syncLocale();
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _getErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(Map<String, dynamic> data) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await _api.register(data);
      await _storage.saveToken(response['token']);
      _user = User.fromJson(response['user']);
      await _storage.saveUser(_user!);
      _syncLocale();
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _getErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyEmail(String code) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      if (_user == null) throw Exception('User not logged in');
      if (_user!.email == null || _user!.email!.isEmpty) throw Exception('No email associated with account');
      
      await _api.verifyEmail(_user!.email!, code);
      
      // Refresh user profile to get updated status
      final response = await _api.getMe();
      _user = User.fromJson(response);
      await _storage.saveUser(_user!);
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _getErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> resendVerification() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      if (_user == null) throw Exception('User not logged in');
      if (_user!.email == null || _user!.email!.isEmpty) throw Exception('No email associated with account');

      await _api.resendVerification(_user!.email!);
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _getErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> forgotPassword(String email) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _api.forgotPassword(email);
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _getErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword(String token, String newPassword) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _api.resetPassword(token, newPassword);
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _getErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Pure cache-first auth — like WhatsApp.
  /// If token + cached user exist locally → authenticate instantly, zero network.
  /// Only makes a network call on the very first boot after login (no cache yet).
  /// Background refresh is intentionally removed: it was causing silent session
  /// wipes when the server returned 401 after a redeploy (JWT secret change).
  Future<void> loadUser() async {
    try {
      final hasToken = await _storage.hasToken();
      debugPrint('[AUTH] hasToken=$hasToken');
      if (!hasToken) {
        _user = null;
        notifyListeners();
        return;
      }

      // ── Fast path: cached user found (works fully offline) ──────────────
      final cachedUser = await _storage.getUser();
      debugPrint('[AUTH] cachedUser=${cachedUser?.username}');
      if (cachedUser != null) {
        _user = cachedUser;
        _syncLocale();
        notifyListeners();
        return;
      }

      // ── Slow path: no cached user, must go online ───────────────────────
      debugPrint('[AUTH] No cached user, trying network...');
      try {
        final response = await _api.getMe();
        _user = User.fromJson(response);
        await _storage.saveUser(_user!);
        _syncLocale();
        debugPrint('[AUTH] User fetched and cached: ${_user?.username}');
      } on DioException catch (e) {
        debugPrint('[AUTH] DioException status=${e.response?.statusCode}');
        if (_is401(e)) {
          await _storage.clearAll();
          _user = null;
        }
      } catch (e) {
        debugPrint('[AUTH] Unknown error: $e');
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[AUTH] Outer catch: $e');
      _user = null;
      notifyListeners();
    }
  }

  bool _is401(dynamic error) {
    if (error is DioException) {
      return error.response?.statusCode == 401;
    }
    return error.toString().contains('401');
  }

  Future<bool> ensureAuthenticated() async {
    if (isAuthenticated) {
      // Validate token
      if (await _storage.hasToken()) return true;
    }
    return false;
  }

  Future<void> logout() async {
    await _storage.clearAll();
    _user = null;
    notifyListeners();
  }

  Future<bool> changePassword(String currentPassword, String newPassword) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _api.changePassword(currentPassword, newPassword);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _is401(e)
          ? _strings.errCurrentPasswordIncorrect
          : _getErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProfile({
    String? firstName,
    String? lastName,
    String? email,
    String? schoolName,
    String? country,
    String? languagePreference,
    String? feedbackAudience,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final data = <String, dynamic>{};
      if (firstName != null) data['first_name'] = firstName;
      if (lastName != null) data['last_name'] = lastName;
      if (email != null) data['email'] = email;
      if (schoolName != null) data['school_name'] = schoolName;
      if (country != null) data['country'] = country;
      // Only change the language when it is explicitly provided — never silently
      // re-derive it from the country (that reverts the user's manual choice).
      if (languagePreference != null) {
        data['language_preference'] = languagePreference;
      }
      if (feedbackAudience != null) {
        data['feedback_audience'] = feedbackAudience;
      }

      final response = await _api.updateProfile(data);
      _user = User.fromJson(response);
      await _storage.saveUser(_user!);
      _syncLocale();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _getErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Seed the [LocaleProvider] from the user's stored language_preference.
  ///
  /// Only seeds the locale until the user has explicitly picked a language;
  /// after that, the user's choice is authoritative and is never overridden by
  /// the server/country default (which would otherwise revert e.g. a Seychelles
  /// teacher back to French on every launch).
  void _syncLocale() {
    final lp = _localeProvider;
    if (lp == null) return;
    if (lp.userSelected) return; // user chose a language — do not override
    final langPref = _user?.languagePreference;
    if (langPref != null && langPref.isNotEmpty) {
      lp.setLocale(langPref);
    } else if (_user?.country != null) {
      lp.setLocaleFromCountry(_user!.country);
    }
  }

  /// Strings resolved without a [BuildContext], using the locale held by the
  /// injected [LocaleProvider]. Falls back to English before login, when no
  /// locale provider has been attached yet.
  AppStrings get _strings =>
      AppStrings(_localeProvider?.locale ?? const Locale('en'));

  String _getErrorMessage(dynamic error) {
    final s = _strings;

    if (error is DioException) {
      // ── Connection-level errors (no response from server) ──────────────────
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.connectionError) {
        return s.errCannotReachServer;
      }

      final statusCode = error.response?.statusCode;

      // ── Status-code specific messages, translated ──────────────────────────
      // These take precedence over the server's `error` field, which is always
      // English (backend/internal/handlers/*.go). Showing it would put English
      // on a Portuguese screen.
      if (statusCode == 401) return s.errWrongCredentials;
      if (statusCode == 409) return s.errAccountExists;
      if (statusCode == 400) return s.errCheckInformation;
      if (statusCode != null && statusCode >= 500) return s.errServerError;

      // ── No localized message for this status — the server's untranslated
      // text is still better than a generic one.
      final data = error.response?.data;
      if (data is Map && data['error'] != null && data['error'].toString().isNotEmpty) {
        return data['error'].toString();
      }

      return s.errSomethingWentWrong;
    }

    // Fallback for non-Dio errors
    final msg = error.toString();
    if (msg.contains('401')) return s.errWrongCredentials;
    if (msg.contains('SocketException') || msg.contains('Connection refused')) {
      return s.errCannotReachServer;
    }
    return msg;
  }
}
