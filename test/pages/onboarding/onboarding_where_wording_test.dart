// The Where step is the rider's first look at how BikeControl connects, so it
// can't lean on method names ("Local", "Network") introduced only two steps
// later, and help texts that tell the rider which tile to pick must name the
// tile the way the tile itself is labelled.
import 'package:bike_control/gen/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final locale in AppLocalizations.delegate.supportedLocales) {
    group('$locale', () {
      late AppLocalizations l;
      setUp(() async => l = await AppLocalizations.load(locale));

      test('the Where tiles describe what happens, not a method name', () {
        for (final text in [l.onboardingWhereEnablesLocal('Zwift'), l.onboardingWhereEnablesNetwork('Zwift')]) {
          expect(text, contains('Zwift'), reason: 'say what happens with the rider\'s own app');
          expect(text, isNot(contains(l.onboardingMethodLocal)));
          expect(text, isNot(contains(l.onboardingMethodNetwork)));
        }
      });

      test('help texts point at the tile by its own label', () {
        expect(l.onboardingHelpWhereBody, contains(l.targetOtherDevice));
        expect(l.onboardingVsBlockedAltAppBody('Zwift'), contains(l.targetOtherDevice));
      });
    });
  }
}
