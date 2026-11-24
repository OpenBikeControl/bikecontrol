import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/configuration.dart';
import 'package:bike_control/utils/host_platform.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/wahoo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The Wahoo app skips Bluetooth trainers whose advertisement carries no
/// name, and a Mac bridge sends none — so on a Mac the rider is told to run
/// the bridge elsewhere instead of searching for an entry that never appears.
void main() {
  tearDown(() => debugHostPlatformOverride = null);

  test('only a name-gated app on a Mac gets the note', () {
    debugHostPlatformOverride = TargetPlatform.macOS;
    expect(showsMacBridgeUnnamedNote(WahooApp()), isTrue);
    expect(showsMacBridgeUnnamedNote(MyWhoosh()), isFalse);

    for (final other in [TargetPlatform.android, TargetPlatform.windows, TargetPlatform.iOS]) {
      debugHostPlatformOverride = other;
      expect(showsMacBridgeUnnamedNote(WahooApp()), isFalse, reason: '$other');
    }
  });

  testWidgets('names the app and where to run the bridge instead', (tester) async {
    await AppLocalizations.load(const Locale('en'));
    final app = WahooApp();
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(child: Builder(builder: (context) => macBridgeUnnamedNote(context, app))),
      ),
    );
    expect(find.text(AppLocalizations.current.warningMacBridgeUnnamed(app.name)), findsOneWidget);
  });
}
