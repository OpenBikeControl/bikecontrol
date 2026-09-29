// Picking a media key for a button replaces what the button did before. A
// button that still carried its in-game action (the Ride's Y opens MyWhoosh's
// menu) kept sending that action instead: the trainer-app path runs first,
// so the media key never fired.
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/button_edit.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/actions/desktop.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import 'widget_snapshot.dart';

Future<void> main() async {
  // Binding, plugin mocks and core.settings (incl. Supabase) bootstrap.
  await ensureSnapshotHarness();

  setUp(() async {
    IAPManager.instance.setProForTesting(enabled: true);
    core.settings.setTrainerApp(MyWhoosh());
    await core.settings.setLastTarget(Target.thisDevice);
    core.settings.setLocalEnabled(true);
    core.actionHandler = DesktopActions()..init(MyWhoosh());
  });

  tearDown(() {
    IAPManager.instance.setProForTesting(enabled: false);
    core.actionHandler = StubActions();
  });

  for (final (label, key) in [
    ('Play/Pause', PhysicalKeyboardKey.mediaPlayPause),
    ('Next', PhysicalKeyboardKey.mediaTrackNext),
  ]) {
    testWidgets('a media key ($label) replaces the button\'s in-game action', (tester) async {
      if (defaultTargetPlatform != TargetPlatform.macOS) debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final keymap = MyWhoosh().keymap;
      final keyPair = KeyPair(
        buttons: [ZwiftButtons.y],
        physicalKey: null,
        logicalKey: null,
        inGameAction: InGameAction.menu,
      );
      tester.view.physicalSize = const Size(400, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ShadcnApp(
          localizationsDelegates: const [
            ...ShadcnLocalizations.localizationsDelegates,
            OtherLocalizationsDelegate(),
            AppLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          theme: ThemeData(colorScheme: ColorSchemes.lightSlate, radius: 0.7),
          home: Align(
            alignment: Alignment.topLeft,
            child: ButtonEditPage(
              device: ZwiftRide(BleDevice(name: 'Zwift Ride', deviceId: 'media-key-ride')),
              keyPair: keyPair,
              keymap: keymap,
              trigger: ButtonTrigger.singleClick,
              onUpdate: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      final l10n = AppLocalizations.current;
      await tester.tap(find.text(l10n.simulateMediaKey));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text(label == 'Next' ? l10n.next : l10n.playPause));
      await tester.pump(const Duration(seconds: 1));

      expect(keyPair.physicalKey, key);
      expect(keyPair.inGameAction, isNull, reason: 'the media key replaces the in-game action');
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
