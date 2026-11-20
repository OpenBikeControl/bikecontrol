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

import '../../helpers/text_breaks.dart';
import '../../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();
  const left = ZwiftButtons.navigationLeft;
  const right = ZwiftButtons.navigationRight;

  Future<AppLocalizations> pump(WidgetTester tester, {KeyPair? extra}) async {
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
        KeyPair(
          buttons: [right],
          physicalKey: null,
          logicalKey: null,
          inGameAction: InGameAction.shiftDown,
          trigger: ButtonTrigger.doubleClick,
        ),
        ?extra,
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
              presses: ValueNotifier((button: null, generation: 0, trigger: null)),
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

  testWidgets('a long press is named before its action, under the button', (tester) async {
    final l = await pump(tester);
    final row = find.byKey(ValueKey('ride-button-row-${left.name}'));
    expect(row, findsOneWidget);
    final line = find.byKey(ValueKey('ride-button-row-${left.name}-${ButtonTrigger.longPress.name}'));
    expect(
      find.descendant(
        of: line,
        matching: find.text('${l.triggerLongPress} · ${l.actionSteerLeft}', findRichText: true),
      ),
      findsOneWidget,
    );
    final name = find.descendant(of: row, matching: find.text(left.plainName));
    expect(tester.getRect(line).top, greaterThanOrEqualTo(tester.getRect(name).bottom - 1));
  });

  testWidgets('a single click has no subtitle', (tester) async {
    final l = await pump(tester);
    final row = find.byKey(ValueKey('ride-button-row-${right.name}'));
    expect(find.descendant(of: row, matching: find.text(InGameAction.shiftUp.title)), findsOneWidget);
    expect(find.descendant(of: row, matching: find.text(l.triggerSingleClick)), findsNothing);
  });

  testWidgets('a double click is a line under the single click, the name said once', (tester) async {
    final l = await pump(tester);
    final block = find.byKey(ValueKey('ride-button-row-${right.name}'));
    final double = find.byKey(ValueKey('ride-button-row-${right.name}-${ButtonTrigger.doubleClick.name}'));
    expect(find.descendant(of: block, matching: double), findsOneWidget);
    expect(
      find.descendant(
        of: double,
        matching: find.text('${l.triggerDoubleClick} · ${InGameAction.shiftDown.title}', findRichText: true),
      ),
      findsOneWidget,
    );
    // The name once, for both.
    final name = find.descendant(of: block, matching: find.text(right.plainName));
    expect(name, findsOneWidget);
    expect(tester.getRect(double).top, greaterThanOrEqualTo(tester.getRect(name).bottom - 1));
  });

  testWidgets('a long action wraps between words, never inside one', (tester) async {
    // "Headwind-Geschwindigkeit erhöhen" broke as "Headwind-Ges" / "chwindigkeit".
    await pump(
      tester,
      extra: KeyPair(
        buttons: [right],
        physicalKey: null,
        logicalKey: null,
        inGameAction: InGameAction.headwindSpeedInc,
        trigger: ButtonTrigger.longPress,
      ),
    );
    expectReadsWhole(tester, find.byKey(const ValueKey('ride-button-list')));
  });

  test("a button's device id is left off while no other controller has that button", () {
    const button = ControllerButton('shiftUp', sourceDeviceId: 'AA:BB:C9:E9');
    expect(button.displayName, 'Shift Up');
  });
}
