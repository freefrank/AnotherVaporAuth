import 'dart:ui' show Locale;

import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/app/app.dart';
import 'package:ava/src/app/providers.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adding a language means touching three places that no compiler connects:
/// the ARB (which gen-l10n turns into `supportedLocales`), the settings
/// picker list, and the Steam language map. Miss the third and the UI
/// translates while Steam-served item names stay English — a gap nothing
/// else in the suite would notice.
void main() {
  group('shipped locales stay in sync', () {
    test('every picker entry has generated localizations behind it', () {
      for (final entry in kSelectableLocales) {
        expect(
          AppLocalizations.supportedLocales.any((l) =>
              l.languageCode == entry.locale.languageCode &&
              l.scriptCode == entry.locale.scriptCode),
          isTrue,
          reason: '${entry.label} (${entry.locale.toLanguageTag()}) is offered '
              'in Settings but has no ARB — picking it falls back to English',
        );
      }
    });

    test('every generated locale is reachable from the picker', () {
      for (final locale in AppLocalizations.supportedLocales) {
        expect(
          kSelectableLocales.any((e) =>
              e.locale.languageCode == locale.languageCode &&
              e.locale.scriptCode == locale.scriptCode),
          isTrue,
          reason: '${locale.toLanguageTag()} has an ARB but no picker entry — '
              'the translation only ever shows for matching system locales',
        );
      }
    });

    test('every shipped locale maps to a real Steam language slug', () {
      // Valve's own slugs. A locale that falls through to 'english' here reads
      // as half-translated: our strings localised, Steam's strings not.
      const bySlug = {
        'en': 'english',
        'de': 'german',
        'fr': 'french',
        'es': 'spanish',
        'ru': 'russian',
      };
      for (final entry in kSelectableLocales) {
        final slug = steamLanguageFor(entry.locale);
        final expected = entry.locale.languageCode == 'zh'
            ? (entry.locale.scriptCode == 'Hant' ? 'tchinese' : 'schinese')
            : bySlug[entry.locale.languageCode];
        expect(expected, isNotNull,
            reason: '${entry.label} has no expected slug in this test — add '
                'it here and to steamLanguageFor()');
        expect(slug, expected, reason: entry.label);
      }
    });

    test('Traditional Chinese does not collapse into Simplified', () {
      // The specific bug this guards: scriptCode being ignored anywhere in
      // the chain would serve 简体 item names inside a 繁體 UI.
      const hant = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
      expect(steamLanguageFor(hant), 'tchinese');
      expect(steamLanguageFor(const Locale('zh')), 'schinese');
      expect(hant, isNot(const Locale('zh')));
    });

    test('an unshipped locale still yields a usable slug', () {
      expect(steamLanguageFor(const Locale('ja')), 'english');
    });
  });
}
