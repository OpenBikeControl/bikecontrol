// Ride's list of buttons beside (or under) the pods: a button whose action
// sits on another trigger than a single click names that trigger under the
// button's name, and the action alone reads whole at the row's end.
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
  const left = ZwiftButtons.navigationLeft;
  const right = ZwiftButtons.navigationRight;

  Future<AppLocalizations> pump(WidgetTester tester) async {
    await AppLocalizations.load(const Locale('de'));
    addTearDown(() => AppLocalizations.load(const Locale('en')));
    final keymap = Keymap(
      keyPairs: [
        KeyPair(
          buttons: [left],
          physicalKey: null,
          logicalKey: null,
          inGameAction: InGameAction.steerLeft,
          trigger: ButtonTrigger.longPress,
        ),
        KeyPair(buttons: [right], physicalKey: null, logicalKey: null, inGameAction: InGameAction.shiftUp),
      ],
    );
    final device = ZwiftPlay(
      BleDevice(name: 'Zwift Play', deviceId: 'list'),
      deviceType: ZwiftDeviceType.playLeft,
    );
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ShadcnApp(
        locale: const Locale('de'),
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        theme: BkTheme.build(Brightness.dark),
        home: Scaffold(
          child: SingleChildScrollView(
            child: ControllerButtonsCard(
              device: device,
              keymap: keymap,
              presses: ValueNotifier((button: null, generation: 0)),
              onUpdate: () {},
              onEdit: () {},
              showButtonList: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return AppLocalizations.current;
  }

  testWidgets('a long press is named under the button; the value is the action alone', (tester) async {
    final l = await pump(tester);
    final row = find.byKey(ValueKey('ride-button-row-${left.name}'));
    expect(row, findsOneWidget);
    expect(find.descendant(of: row, matching: find.text(l.actionSteerLeft)), findsOneWidget);
    final subtitle = find.descendant(of: row, matching: find.text(l.triggerLongPress));
    expect(subtitle, findsOneWidget);
    final name = find.descendant(of: row, matching: find.text(left.displayName));
    expect(tester.getRect(subtitle).top, greaterThanOrEqualTo(tester.getRect(name).bottom - 1));
  });

  testWidgets('a single click has no subtitle', (tester) async {
    final l = await pump(tester);
    final row = find.byKey(ValueKey('ride-button-row-${right.name}'));
    expect(find.descendant(of: row, matching: find.text(InGameAction.shiftUp.title)), findsOneWidget);
    expect(find.descendant(of: row, matching: find.text(l.triggerSingleClick)), findsNothing);
  });
}
