import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class CountryCustomization {
  static const List<String> _customizedCountries = [
    'Ethiopia',
    'Mozambique',
    'Senegal',
    'Tanzania',
    'Seychelles',
  ];

  /// Returns true if the user's country is customized.
  static bool isCustomized(String? country) {
    if (country == null) return false;
    return _customizedCountries.contains(country);
  }

  /// Returns a primary accent color extracted from the country's flag.
  /// Falls back to the app's default primary color if not customized.
  static Color getAccentColor(String? country) {
    switch (country) {
      case 'Ethiopia':
        return const Color(0xFF009A44); // Green
      case 'Mozambique':
        return const Color(0xFF009A44); // Green (Mozambique flag)
      case 'Senegal':
        return const Color(0xFFE3122C); // Red
      case 'Tanzania':
        return const Color(0xFF00A3DD); // Blue
      case 'Seychelles':
        return const Color(0xFF003D88); // Dark Blue
      default:
        return AppTheme.primaryColor;
    }
  }

  /// Countries where the app asks, at registration, whether the user is a
  /// teacher or a pedagogy coordinator.
  ///
  /// Everywhere else the question is not shown and the role defaults to teacher,
  /// so no existing deployment changes. Interim mechanism: a per-deployment
  /// config replaces this once a second programme runs coordinators.
  static const Set<String> coordinatorCountries = {'Brazil'};

  /// True when the registration flow should offer the teacher/coordinator choice.
  static bool offersCoordinatorRole(String? country) =>
      country != null && coordinatorCountries.contains(country);

  /// Returns the BCP-47 language code for a given country name.
  /// Defaults to 'en' (English) for any country not in the mapping.
  static String getLanguageCode(String? country) {
    switch (country) {
      // Portuguese-speaking countries. Names must match the spellings in
      // country_dropdown.dart exactly, or they fall through to English.
      //
      // Brazil was missing here until the Mato Grosso rollout: it is selectable
      // in the dropdown but fell through to 'en', which meant registration sent
      // language_preference='en' and every AI-generated analysis and chat reply
      // came back in English regardless of the UI language.
      case 'Brazil':
      case 'Mozambique':
      case 'Portugal':
      case 'Angola':
      case 'Cabo Verde':
      case 'Guinea-Bissau':
      case 'Sao Tome and Principe':
      case 'Timor-Leste':
        return 'pt'; // Portuguese
      case 'Senegal':
      case 'Seychelles':
      case 'Cameroon':
      case 'Ivory Coast':
      case "Côte d'Ivoire":
      case 'Mali':
      case 'Burkina Faso':
      case 'Guinea':
      case 'Niger':
      case 'Chad':
      case 'Democratic Republic of the Congo':
      case 'Republic of the Congo':
      case 'Gabon':
      case 'Benin':
      case 'Togo':
      case 'Rwanda':
      case 'Burundi':
      case 'Madagascar':
      case 'Djibouti':
      case 'Comoros':
        return 'fr'; // French
      case 'Ethiopia':
        return 'am'; // Amharic
      case 'Tanzania':
      case 'Kenya':
      case 'Uganda':
        return 'sw'; // Swahili
      default:
        return 'en'; // English
    }
  }
}
