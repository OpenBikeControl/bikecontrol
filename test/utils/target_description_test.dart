// The "Other device" description on the setup guide's `where` step is one
// full sentence per case (plain, OpenBikeControl, MyWhoosh Link) in every
// locale, with the app name set off by spaces or punctuation.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  const locales = ['en', 'de', 'es', 'fr', 'it', 'pl'];
  final apps = <SupportedApp?>[null, ...SupportedApp.supportedApps];

  for (final locale in locales) {
    test('$locale: every "Other device" description reads as one clean sentence', () async {
      await AppLocalizations.load(Locale(locale));
      addTearDown(() => AppLocalizations.load(const Locale('en')));
      final seen = <String>{};
      for (final app in apps) {
        for (final target in Target.values) {
          final text = target.getDescription(app);
          seen.add(text);
          final reason = '$locale ${app?.name} ${target.name}: "$text"';
          expect(text, isNot(contains('{')), reason: reason);
          expect(text, isNot(contains('}')), reason: reason);
          expect(text, isNot(contains('  ')), reason: reason);
          expect(text, isNot(matches(RegExp(r'\s[.,:;]'))), reason: reason);
          expect(text.trim(), text, reason: reason);
          expect(text, endsWith('.'), reason: reason);
          expect(text.substring(0, 1), text.substring(0, 1).toUpperCase(), reason: reason);
          if (app != null) {
            final bounded = RegExp('(^|[\\s"„«“])${RegExp.escape(app.name)}(\$|[\\s,.»"”])');
            expect(bounded.hasMatch(text), isTrue, reason: '$reason — "${app.name}" not set off by spaces');
          } else {
            expect(text, isNot(contains('Trainer app')), reason: '$reason — untranslated fallback name');
          }
        }
      }
      expect(seen, isNotEmpty);
    });
  }
}
