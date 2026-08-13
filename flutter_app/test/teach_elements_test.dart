import 'package:flutter_test/flutter_test.dart';

import 'package:ai_coach/core/teach/teach_elements.dart';
import 'package:ai_coach/core/l10n/translations/en.dart';
import 'package:ai_coach/core/l10n/translations/pt.dart';
import 'package:ai_coach/core/l10n/translations/fr.dart';
import 'package:ai_coach/core/l10n/translations/am.dart';
import 'package:ai_coach/core/l10n/translations/sw.dart';

/// The nine canonical keys, duplicated here on purpose.
///
/// They must match `gemini.CanonicalElements`
/// (backend/internal/services/gemini/teach_types_enhanced.go), the `analyses`
/// table columns, and `TEACH_ELEMENTS` in
/// monitoring-dashboard/src/lib/teach.ts. Writing them out again means a change
/// on one side fails here instead of silently disagreeing at runtime — which is
/// exactly how three elements went unparsed for months.
const _expectedCanonicalKeys = [
  'supportive_environment',
  'positive_expectations',
  'lesson_facilitation',
  'checks_understanding',
  'feedback',
  'critical_thinking',
  'autonomy',
  'perseverance',
  'social_collaborative',
];

void main() {
  group('TEACH registry', () {
    test('canonical keys match the backend and dashboard, in order', () {
      final actual = kTeachElements.map((e) => e.canonicalKey).toList();
      expect(actual, _expectedCanonicalKeys);
    });

    test('every element belongs to exactly one domain group', () {
      final grouped = kTeachElementsByDomain.values
          .expand((elements) => elements)
          .map((e) => e.canonicalKey)
          .toList();
      expect(grouped.length, kTeachElements.length);
      expect(grouped.toSet(), _expectedCanonicalKeys.toSet());
    });

    test('behavior keys are unique across all elements', () {
      final keys = kTeachElements
          .expand((e) => e.behaviors)
          .map((b) => b.key)
          .toList();
      expect(keys.toSet().length, keys.length,
          reason: 'a duplicate behavior key would make teachBehaviorByKey ambiguous');
    });

    test('behavior form numbers follow their element position', () {
      for (var i = 0; i < kTeachElements.length; i++) {
        final element = kTeachElements[i];
        for (var j = 0; j < element.behaviors.length; j++) {
          expect(
            element.behaviors[j].number,
            '${i + 1}.${j + 1}',
            reason: 'behavior numbering must match the TEACH form for '
                '${element.canonicalKey}',
          );
        }
      }
    });

    test('lookups resolve, and unknown keys return null rather than throwing', () {
      expect(teachElementByKey('feedback')?.canonicalKey, 'feedback');
      expect(teachBehaviorByKey('adjusts_teaching')?.number, '4.3');

      expect(teachElementByKey('not_a_real_element'), isNull);
      expect(teachBehaviorByKey('not_a_real_behavior'), isNull);
    });
  });

  group('translation coverage', () {
    // Element and behavior names are short and terminological, so every
    // language carries them.
    final allLanguages = <String, Map<String, String>>{
      'en': en,
      'pt': pt,
      'fr': fr,
      'am': am,
      'sw': sw,
    };

    for (final entry in allLanguages.entries) {
      test('${entry.key} has every element and behavior label', () {
        final missing = <String>[];

        for (final element in kTeachElements) {
          if (!entry.value.containsKey(element.labelKey)) {
            missing.add(element.labelKey);
          }
          for (final behavior in element.behaviors) {
            if (!entry.value.containsKey(behavior.labelKey)) {
              missing.add(behavior.labelKey);
            }
          }
        }

        expect(missing, isEmpty,
            reason: '${entry.key}.dart is missing: ${missing.join(', ')}');
      });

      test('${entry.key} has the three domain labels and rating letters', () {
        for (final domain in TeachDomain.values) {
          expect(entry.value.containsKey(domain.labelKey), isTrue,
              reason: '${entry.key}.dart is missing ${domain.labelKey}');
        }
        for (final key in ['ratingHigh', 'ratingMedium', 'ratingLow']) {
          expect(entry.value.containsKey(key), isTrue,
              reason: '${entry.key}.dart is missing $key');
        }
      });
    }

    // Coaching tips are pedagogical prose. English and Portuguese are written;
    // the other languages fall back to English until a reviewer signs them off
    // (W2b), so they are deliberately NOT asserted here.
    for (final entry in {'en': en, 'pt': pt}.entries) {
      test('${entry.key} has a coaching tip for every element', () {
        final missing = kTeachElements
            .map((e) => 'teachTip_${e.canonicalKey}')
            .where((key) => !entry.value.containsKey(key))
            .toList();

        expect(missing, isEmpty,
            reason: '${entry.key}.dart is missing: ${missing.join(', ')}');
      });
    }

    test('Portuguese rating letters are B/M/A as the coordinators requested', () {
      // 'A' (Alto) maps to the stored 'H'. This is a per-value translation,
      // not a reversal of the scale.
      expect(pt['ratingHigh'], 'A');
      expect(pt['ratingMedium'], 'M');
      expect(pt['ratingLow'], 'B');
    });
  });
}
