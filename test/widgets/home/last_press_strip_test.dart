// "Just pressed <button> → <action>": the action never breaks mid-phrase. It
// sits on the same line when it fits, else whole on the next line — never
// "Shift / Down".
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_play.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/widgets/home/your_buttons.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();
  const long = ControllerButton('shiftUpLeftOnTheBigHandlebarRemote', action: InGameAction.shiftDown);
  const short = ControllerButton('plus', action: InGameAction.shiftDown);

  Future<void> pump(WidgetTester tester, double width, ControllerButton button) async {
    await AppLocalizations.load(const Locale('en'));
    final keymap = Keymap(
      keyPairs: [
        KeyPair(buttons: [button], physicalKey: null, logicalKey: null, inGameAction: InGameAction.shiftDown),
      ],
    );
    final device = ZwiftPlay(
      BleDevice(name: 'Zwift Play', deviceId: 'strip'),
      deviceType: ZwiftDeviceType.playLeft,
    );
    tester.view.physicalSize = Size(width + 40, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        theme: BkTheme.build(Brightness.dark),
        home: Scaffold(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: LastPressStrip(
                device: device,
                keymap: keymap,
                presses: ValueNotifier((button: button, generation: 1)),
                onUpdate: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  // The strip's width in Ride's buttons card on a phone (390) and in the
  // left column at 1180.
  for (final width in [326.0, 372.0, 520.0]) {
    for (final button in [long, short]) {
      testWidgets('at $width, ${button.name}: the action stays whole', (tester) async {
        await pump(tester, width, button);
        final action = find.text(InGameAction.shiftDown.title);
        expect(action, findsOneWidget, reason: 'the action is its own run of text');
        final text = tester.widget<Text>(action);
        expect(text.maxLines, 1);
        final lead = find.byKey(const ValueKey('last-press-lead'));
        final leadRect = tester.getRect(lead);
        final actionRect = tester.getRect(action);
        final sameLine = (actionRect.top - leadRect.top).abs() < 2;
        final nextLine = actionRect.top >= leadRect.bottom - 1;
        expect(sameLine || nextLine, isTrue, reason: 'lead $leadRect, action $actionRect');
        expect(tester.widget<Text>(lead).maxLines, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
