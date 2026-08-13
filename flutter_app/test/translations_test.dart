import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_coach/core/l10n/translations/en.dart';
import 'package:ai_coach/core/l10n/translations/pt.dart';
import 'package:ai_coach/core/l10n/translations/fr.dart';
import 'package:ai_coach/core/l10n/translations/am.dart';
import 'package:ai_coach/core/l10n/translations/sw.dart';

void main() {
  group('Portuguese completeness', () {
    // The requirement from the Mato Grosso coordinators was explicit: "No
    // English should be visible on the screen in the Portuguese version."
    //
    // English is the fallback language (AppStrings._t: map[key] ?? en[key]), so
    // any key present in en.dart but missing from pt.dart renders as English in
    // the Portuguese build. This test is that requirement, enforced.
    test('pt.dart defines every key in en.dart', () {
      final missing = en.keys.where((key) => !pt.containsKey(key)).toList()
        ..sort();

      expect(
        missing,
        isEmpty,
        reason: 'These keys fall back to English in the Portuguese build:\n'
            '${missing.join('\n')}',
      );
    });

    test('pt.dart has no empty values', () {
      final blank = pt.entries
          .where((e) => e.value.trim().isEmpty)
          .map((e) => e.key)
          .toList()
        ..sort();

      expect(blank, isEmpty, reason: 'Blank Portuguese values: ${blank.join(', ')}');
    });

    test('pt.dart defines no keys that en.dart lacks', () {
      // A pt-only key means either a typo or a key whose English source was
      // deleted — both leave dead weight that no lookup will ever reach.
      final orphans = pt.keys.where((key) => !en.containsKey(key)).toList()
        ..sort();

      expect(orphans, isEmpty,
          reason: 'Keys in pt.dart with no en.dart counterpart: '
              '${orphans.join(', ')}');
    });
  });

  group('placeholder consistency', () {
    // A translation that drops or renames a {placeholder} silently renders the
    // literal braces to the user.
    final placeholder = RegExp(r'\{(\w+)\}');

    Set<String> placeholdersIn(String value) =>
        placeholder.allMatches(value).map((m) => m.group(1)!).toSet();

    test('pt placeholders match en placeholders', () {
      final mismatches = <String>[];

      for (final entry in en.entries) {
        final ptValue = pt[entry.key];
        if (ptValue == null) continue; // covered by the completeness test

        final expected = placeholdersIn(entry.value);
        final actual = placeholdersIn(ptValue);
        if (!setEquals(expected, actual)) {
          mismatches.add('${entry.key}: en has $expected, pt has $actual');
        }
      }

      expect(mismatches, isEmpty, reason: mismatches.join('\n'));
    });
  });

  group('other languages', () {
    // fr / am / sw are NOT held to full parity. They carry the TEACH
    // terminology from W2a and the pre-existing UI strings, and fall back to
    // English for anything newer. Not a regression — those strings were
    // hardcoded English before. Tracked as a follow-up.
    //
    // What IS asserted: no orphan keys, and no blank values, so the fallback
    // chain stays predictable.
    final others = <String, Map<String, String>>{'fr': fr, 'am': am, 'sw': sw};

    for (final entry in others.entries) {
      test('${entry.key}.dart defines no keys that en.dart lacks', () {
        final orphans =
            entry.value.keys.where((key) => !en.containsKey(key)).toList()
              ..sort();

        expect(orphans, isEmpty,
            reason: 'Keys in ${entry.key}.dart with no en.dart counterpart: '
                '${orphans.join(', ')}');
      });

      test('${entry.key}.dart has no empty values', () {
        final blank = entry.value.entries
            .where((e) => e.value.trim().isEmpty)
            .map((e) => e.key)
            .toList()
          ..sort();

        expect(blank, isEmpty,
            reason: 'Blank ${entry.key} values: ${blank.join(', ')}');
      });
    }
  });
}
