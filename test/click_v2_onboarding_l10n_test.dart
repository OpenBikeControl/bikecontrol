import 'dart:convert';
import 'dart:io';
import 'package:bike_control/gen/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('click-v2 onboarding strings have complete translations in all languages',
      () {
    // Read every shipped arb file and parse as JSON
    final arbFiles = {
      'en': File('lib/i10n/intl_en.arb'),
      'de': File('lib/i10n/intl_de.arb'),
      'es': File('lib/i10n/intl_es.arb'),
      'fr': File('lib/i10n/intl_fr.arb'),
      'it': File('lib/i10n/intl_it.arb'),
      'pl': File('lib/i10n/intl_pl.arb'),
      'zh': File('lib/i10n/intl_zh.arb'),
    };

    final arbMaps = <String, Map<String, dynamic>>{};
    for (final entry in arbFiles.entries) {
      final content = entry.value.readAsStringSync();
      arbMaps[entry.key] = jsonDecode(content);
    }

    // Get the reference set from English (exactly 24 keys)
    final enKeys = arbMaps['en']!
        .keys
        .where((k) => k.startsWith('clickV2Onboarding_'))
        .toSet();
    expect(
      enKeys.length,
      24,
      reason:
          'English arb should have exactly 24 clickV2Onboarding_ keys, but has ${enKeys.length}',
    );

    // Verify all other locales have the same key set
    for (final locale in ['de', 'es', 'fr', 'it', 'pl', 'zh']) {
      final localeKeys = arbMaps[locale]!
          .keys
          .where((k) => k.startsWith('clickV2Onboarding_'))
          .toSet();

      expect(
        localeKeys,
        enKeys,
        reason:
            'Locale $locale has mismatched keys. Missing: ${enKeys.difference(localeKeys)}, Extra: ${localeKeys.difference(enKeys)}',
      );
    }

    // Verify all values are non-empty strings in every locale
    for (final entry in arbMaps.entries) {
      for (final key in enKeys) {
        final value = entry.value[key];
        expect(
          value,
          isA<String>().having((s) => s.isNotEmpty, 'is non-empty', true),
          reason:
              'Locale ${entry.key}: key $key has empty or non-string value',
        );
      }
    }
  });

  // Smoke test: verifies getters resolve at runtime.
  // This only proves codegen ran and getters exist; it cannot catch missing keys
  // due to Intl's fallback behavior, so it is not a substitute for arb-file parity
  // verification above. Keep it as a basic sanity check, but primary guard is
  // the key-set and value verification test above.
  test('onboarding strings resolve at runtime in every shipped language',
      () async {
    for (final code in ['en', 'de', 'es', 'fr', 'it', 'pl', 'zh']) {
      final l10n = await AppLocalizations.load(Locale(code));
      final strings = [
        l10n.clickV2Onboarding_cardTitle,
        l10n.clickV2Onboarding_cardSubtitle,
        l10n.clickV2Onboarding_title,
        l10n.clickV2Onboarding_intro,
        l10n.clickV2Onboarding_whyLink,
        l10n.clickV2Onboarding_rightOnlyTitle,
        l10n.clickV2Onboarding_rightOnlyPro1,
        l10n.clickV2Onboarding_rightOnlyPro2,
        l10n.clickV2Onboarding_rightOnlyCon1,
        l10n.clickV2Onboarding_rightOnlyCta,
        l10n.clickV2Onboarding_zwiftTitle,
        l10n.clickV2Onboarding_zwiftPro1,
        l10n.clickV2Onboarding_zwiftPro2,
        l10n.clickV2Onboarding_zwiftCon1,
        l10n.clickV2Onboarding_zwiftCon2,
        l10n.clickV2Onboarding_zwiftCta,
        l10n.clickV2Onboarding_alternativesLink,
        l10n.clickV2Onboarding_setUpAgain,
        l10n.clickV2Onboarding_swipeHint,
        l10n.clickV2Onboarding_decisionTitle,
        l10n.clickV2Onboarding_decisionSubtitle,
        l10n.clickV2Onboarding_rightOnlyRecap,
        l10n.clickV2Onboarding_zwiftRecap,
        l10n.clickV2Onboarding_connectFailed,
      ];
      for (final value in strings) {
        expect(value, isNotEmpty, reason: 'empty string for locale $code');
      }
    }
  });
}
