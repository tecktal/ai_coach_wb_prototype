import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../presentation/widgets/country_customization.dart';

/// Holds and persists the current app locale.
///
/// - Auto-switched when a teacher selects their country.
/// - Persisted to SharedPreferences so it survives restarts.
/// - Notify listeners so [MaterialApp.locale] updates reactively.
class LocaleProvider extends ChangeNotifier {
  static const _key = 'app_language_code';
  static const _userSetKey = 'app_language_user_set';

  Locale _locale = const Locale('en');

  /// True once the user has *explicitly* chosen a language (as opposed to it
  /// being auto-derived from their country). Once true, the language is never
  /// overridden by the server/country default. Persisted across restarts.
  bool _userSelected = false;

  Locale get locale => _locale;

  bool get userSelected => _userSelected;

  String get languageCode => _locale.languageCode;

  /// Human-readable name of the current language (in that language).
  String get languageName {
    switch (_locale.languageCode) {
      case 'pt':
        return 'Português';
      case 'fr':
        return 'Français';
      case 'am':
        return 'አማርኛ';
      case 'sw':
        return 'Kiswahili';
      default:
        return 'English';
    }
  }

  // ── Initialisation ────────────────────────────────────────────────────────

  /// Call once at startup to restore the saved locale.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userSelected = prefs.getBool(_userSetKey) ?? false;
      final saved = prefs.getString(_key);
      if (saved != null && _isSupported(saved)) {
        _locale = Locale(saved);
        notifyListeners();
      }
    } catch (_) {
      // If prefs fail, stay on English — never crash startup.
    }
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Set locale by language code (e.g. 'pt', 'fr', 'en').
  /// Ignores unsupported codes rather than crashing.
  ///
  /// Pass [userSelected] = true when the change is an explicit user choice
  /// (e.g. from the Profile language picker). This latches the [userSelected]
  /// flag so the language is never again overridden by the country/server
  /// default.
  Future<void> setLocale(String languageCode, {bool userSelected = false}) async {
    if (!_isSupported(languageCode)) return;

    // Latch the "user chose a language" flag even if the code is unchanged.
    if (userSelected && !_userSelected) {
      _userSelected = true;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_userSetKey, true);
      } catch (_) {
        // Non-fatal — the flag still holds in memory for this session.
      }
    }

    if (_locale.languageCode == languageCode) return;

    _locale = Locale(languageCode);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, languageCode);
    } catch (_) {
      // Persist failure is non-fatal — locale is still active in memory.
    }
  }

  /// Auto-select locale based on a country name.
  /// Uses [CountryCustomization.getLanguageCode].
  Future<void> setLocaleFromCountry(String? country) async {
    if (country == null || country.isEmpty) return;
    final code = CountryCustomization.getLanguageCode(country);
    await setLocale(code);
  }

  // ── Private ───────────────────────────────────────────────────────────────

  static const _supported = {'en', 'pt', 'fr', 'am', 'sw'};

  bool _isSupported(String code) => _supported.contains(code);
}
