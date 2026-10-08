// Button mapping on a controller's page: on a phone one list, a group per
// button that opens into its three triggers; from 860 wide a master–detail,
// the buttons on the left and the picked button's triggers and actions on
// the right. Without Pro, a button's triggers beyond its one action carry
// the PRO badge.
import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_play.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate, shownKeymapName;
import 'package:bike_control/pages/button_edit.dart';
import 'package:bike_control/pages/controller_settings.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/widgets/keymap/mapping.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/pro_badge.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart' show ScreenshotTester;
import 'package:prop/utils/prefs.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../helpers/page_column.dart';
import '../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  final device = ZwiftClickV2(BleDevice(name: 'Zwift Click', deviceId: 'mapping-click'))
    ..firmwareVersion = '1.2.0'
    ..isConnected = true
    ..batteryLevel = 81;

  setUp(() async {
    core.connection.devices
      ..clear()
      ..add(device);
    core.settings.setTrainerApp(MyWhoosh());
    core.settings.setKeyMap(MyWhoosh());
    core.actionHandler.init(MyWhoosh());
    await core.settings.setClickV2OnboardingDone(true);
    propPrefs.setZwiftClickV2LastUnlock(device.scanResult.deviceId, DateTime.now());
  });
  tearDown(() => core.connection.devices.clear());

  Future<AppLocalizations> pump(
    WidgetTester tester,
    Size size, {
    bool realFonts = false,
    BaseDevice? controller,
    Locale? locale,
  }) async {
    if (locale != null) {
      await AppLocalizations.load(locale);
      addTearDown(() => AppLocalizations.load(const Locale('en')));
    }
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final app = ShadcnApp(
      debugShowCheckedModeBanner: false,
      scaling: BkTheme.scaling,
      theme: BkTheme.build(Brightness.dark),
      locale: locale,
      localizationsDelegates: [
        ...ShadcnLocalizations.localizationsDelegates,
        const OtherLocalizationsDelegate(),
        AppLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      home: BkComponentThemes(child: ControllerSettingsPage(device: controller ?? device)),
    );
    await tester.pumpWidget(app);
    if (realFonts) {
      // Widths are measured: lay out with the app's fonts, not the test font.
      await tester.loadAssets();
      await remountWithLoadedFonts(tester, app);
    }
    await tester.pump(const Duration(milliseconds: 500));
    return AppLocalizations.of(tester.element(find.byType(ControllerSettingsPage)));
  }

  /// Opens [row]'s group unless it is the one already open.
  Future<void> openRow(WidgetTester tester, Finder row) async {
    final name = (tester.widget(row).key! as ValueKey<String>).value.replaceFirst('mapping-row-', '');
    if (find.byKey(ValueKey('mapping-trigger-$name-singleClick')).evaluate().isNotEmpty) return;
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pump(const Duration(milliseconds: 400));
  }

  final buttons = mappingButtonsOf(device);
  final keymap = MyWhoosh().keymap;
  // A button MyWhoosh gives a single-click action.
  final mapped = buttons.firstWhere((b) {
    final kp = keymap.getKeyPair(b, trigger: ButtonTrigger.singleClick);
    return kp != null && !kp.hasNoAction;
  });

  testWidgets('390 wide: one list, a group per button that opens into its triggers', (tester) async {
    await pump(tester, const Size(390, 844));
    expect(find.byKey(const ValueKey('mapping-list')), findsOneWidget);
    expect(find.byKey(const ValueKey('mapping-detail')), findsNothing);
    for (final b in buttons) {
      expect(find.byKey(ValueKey('mapping-row-${b.name}')), findsOneWidget, reason: b.name);
    }

    // It opens on the first button; another one opens in its place.
    expect(find.byKey(ValueKey('mapping-trigger-${buttons.first.name}-singleClick')), findsOneWidget);
    final row = find.byKey(ValueKey('mapping-row-${mapped.name}'));
    await openRow(tester, row);
    for (final trigger in ButtonTrigger.values) {
      expect(find.byKey(ValueKey('mapping-trigger-${mapped.name}-${trigger.name}')), findsOneWidget);
    }
    final single = tester.getRect(find.byKey(ValueKey('mapping-trigger-${mapped.name}-singleClick')));
    expect(single.top, greaterThan(tester.getRect(row).top), reason: 'the triggers open under their button');
  });

  testWidgets('with reduced motion, opening another button resizes the list without an error', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pump(tester, const Size(390, 844));
    await openRow(tester, find.byKey(ValueKey('mapping-row-${mapped.name}')));
    expect(tester.takeException(), isNull);
    expect(find.byKey(ValueKey('mapping-trigger-${mapped.name}-singleClick')), findsOneWidget);
  });

  /// The paragraph in [within] whose text contains [text].
  RenderParagraph paragraphIn(WidgetTester tester, Finder within, String text) => find
      .descendant(of: within, matching: find.byType(RichText))
      .evaluate()
      .map((e) => e.renderObject! as RenderParagraph)
      .firstWhere((p) => p.text.toPlainText().contains(text));

  /// The keymap the page shows (the device's, not a fresh copy of the app's).
  Keymap shown() => core.actionHandler.supportedApp!.keymap;
  String actionOf(ControllerButton b) => shown().getKeyPair(b, trigger: ButtonTrigger.singleClick).toString();

  testWidgets('390 wide: a short button\'s row reads its whole summary ("B · Single Click · Back")', (tester) async {
    await pump(tester, const Size(390, 844), realFonts: true);
    final short = buttons.where((b) {
      final kp = shown().getKeyPair(b, trigger: ButtonTrigger.singleClick);
      return b.displayName.length <= 2 && b.name != buttons.first.name && kp != null && !kp.hasNoAction;
    });
    expect(short, isNotEmpty);
    for (final b in short) {
      final row = find.byKey(ValueKey('mapping-row-${b.name}'));
      await tester.ensureVisible(row);
      final summary = paragraphIn(tester, row, actionOf(b));
      expect(summary.didExceedMaxLines, isFalse, reason: '${b.name}: "${summary.text.toPlainText()}" is cut');
    }
  });

  group('a button whose action is on another trigger', () {
    const left = ZwiftButtons.navigationLeft;
    setUp(() async {
      final app = CustomApp(profileName: 'Trigger subtitle');
      app.keymap.keyPairs.add(
        KeyPair(
          buttons: [left],
          physicalKey: null,
          logicalKey: null,
          inGameAction: InGameAction.steerLeft,
          trigger: ButtonTrigger.longPress,
        ),
      );
      await core.settings.setKeyMap(app);
      core.actionHandler.init(app);
      app.keymap.keyPairs.removeWhere((k) => k.buttons.contains(left) && k.trigger != ButtonTrigger.longPress);
    });

    // German, the longest of the six: "Navigation Left" over "Langes Drücken",
    // and "Nach links lenken" whole at the row's end.
    for (final size in const [Size(390, 844), Size(1280, 800)]) {
      testWidgets('${size.width.toInt()} wide: the trigger is a subtitle; the action reads whole', (tester) async {
        final l = await pump(tester, size, realFonts: true, locale: const Locale('de'));
        final row = find.byKey(ValueKey('mapping-row-${left.name}'));
        await tester.ensureVisible(row);
        await tester.pump();
        final action = paragraphIn(tester, row, l.actionSteerLeft);
        expect(action.text.toPlainText(), isNot(contains(l.triggerLongPress)), reason: 'the value is the action only');
        expect(action.didExceedMaxLines, isFalse, reason: '"${action.text.toPlainText()}" is cut');
        final subtitle = find.descendant(of: row, matching: find.text(l.triggerLongPress));
        expect(subtitle, findsOneWidget);
        final name = find.descendant(of: row, matching: find.text(left.displayName));
        expect(tester.getRect(subtitle).top, greaterThanOrEqualTo(tester.getRect(name).bottom - 1));
        expect(tester.getRect(subtitle).left, moreOrLessEquals(tester.getRect(name).left, epsilon: 1));
      });
    }

    testWidgets('a single click has no subtitle', (tester) async {
      final l = await pump(tester, const Size(1280, 800), locale: const Locale('de'));
      final b = buttons.firstWhere((b) {
        final active = mappingActiveTriggers(shown(), b);
        return active.isNotEmpty && active.first == ButtonTrigger.singleClick && b.name != left.name;
      });
      final row = find.byKey(ValueKey('mapping-row-${b.name}'));
      expect(find.descendant(of: row, matching: find.textContaining(l.triggerSingleClick)), findsNothing);
    });
  });

  testWidgets('390 wide: a trigger with nothing on it says (none), on one line', (tester) async {
    final l = await pump(tester, const Size(390, 844));
    await openRow(tester, find.byKey(ValueKey('mapping-row-${mapped.name}')));
    final empty = ButtonTrigger.values.firstWhere((t) {
      final kp = shown().getKeyPair(mapped, trigger: t);
      return kp == null || kp.hasNoAction;
    });
    final row = find.byKey(ValueKey('mapping-trigger-${mapped.name}-${empty.name}'));
    final none = find.descendant(of: row, matching: find.text(l.noActionAssignedShort));
    expect(none, findsOneWidget);
    expect(find.descendant(of: row, matching: find.text(l.noActionAssigned)), findsNothing);
    final lineHeight = tester.getSize(find.descendant(of: row, matching: find.text(empty.title)));
    expect(tester.getSize(none).height, lessThanOrEqualTo(lineHeight.height + 1), reason: 'one line');
  });

  testWidgets('1280 wide: a row\'s value sits at the row\'s end, not mid-row', (tester) async {
    await pump(tester, const Size(1280, 800));
    for (final b in buttons.take(3)) {
      final kp = shown().getKeyPair(b, trigger: ButtonTrigger.singleClick);
      if (kp == null || kp.hasNoAction) continue;
      final row = find.byKey(ValueKey('mapping-row-${b.name}'));
      final summary = paragraphIn(tester, row, actionOf(b));
      final text = tester.getRect(find.byWidgetPredicate((w) => w is RichText && identical(w.text, summary.text)));
      // The inset, the chevron and its gap are all that follow the value.
      expect(tester.getRect(row).right - text.right, lessThan(44), reason: b.name);
    }
  });

  testWidgets('without Pro, the triggers beyond a button\'s one action carry PRO', (tester) async {
    await pump(tester, const Size(390, 844));
    await openRow(tester, find.byKey(ValueKey('mapping-row-${mapped.name}')));
    Finder badgeIn(ButtonTrigger t) => find.descendant(
      of: find.byKey(ValueKey('mapping-trigger-${mapped.name}-${t.name}')),
      matching: find.byType(ProBadge),
    );
    expect(badgeIn(ButtonTrigger.singleClick), findsNothing);
    expect(badgeIn(ButtonTrigger.doubleClick), findsOneWidget);
    expect(badgeIn(ButtonTrigger.longPress), findsOneWidget);
  });

  testWidgets('1600 wide: the master–detail keeps its 1240 column, centred, header on its edge', (tester) async {
    await pump(tester, const Size(1600, 900));
    expect(find.byKey(const ValueKey('mapping-detail')), findsOneWidget);
    expectCentredPageColumn(tester, maxWidth: 1240);
  });

  testWidgets('1180 wide: master–detail — buttons left, the picked one\'s triggers right', (tester) async {
    await pump(tester, const Size(1180, 820));
    final list = find.byKey(const ValueKey('mapping-list'));
    final detail = find.byKey(const ValueKey('mapping-detail'));
    expect(list, findsOneWidget);
    expect(detail, findsOneWidget);
    expect(tester.getRect(detail).left, greaterThan(tester.getRect(list).right));
    var empties = 0;
    for (final trigger in ButtonTrigger.values) {
      final card = find.byKey(ValueKey('mapping-trigger-card-${trigger.name}'));
      expect(card, findsOneWidget);
      final kp = shown().getKeyPair(buttons.first, trigger: trigger);
      if (kp == null || kp.hasNoAction) {
        // An empty slot says so compactly, as in the phone's list.
        final none = find.text(AppLocalizations.current.noActionAssignedShort);
        expect(find.descendant(of: card, matching: none), findsOneWidget);
        empties++;
      }
    }
    expect(empties, greaterThan(0));

    // Picking another button shows its detail.
    final other = buttons.firstWhere((b) => b.name != buttons.first.name);
    await tester.tap(find.byKey(ValueKey('mapping-row-${other.name}')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.descendant(of: detail, matching: find.byKey(ValueKey('mapping-detail-${other.name}'))),
      findsOneWidget,
    );
    // No trigger rows inline: the detail carries them.
    expect(find.byKey(ValueKey('mapping-trigger-${other.name}-singleClick')), findsNothing);
  });

  testWidgets('1180 wide: a built-in mapping asks to be copied; a custom one shows the actions inline', (
    tester,
  ) async {
    final l = await pump(tester, const Size(1180, 820));
    expect(find.text(l.mappingEditMakesCopy(shownKeymapName('MyWhoosh'))), findsOneWidget);
    expect(find.byType(ButtonEditPage), findsNothing);

    await tester.tap(find.byKey(const ValueKey('mapping-trigger-card-singleClick')));
    await tester.pump(const Duration(milliseconds: 600));
    expect(core.actionHandler.supportedApp, isA<CustomApp>(), reason: 'editing copies the built-in mapping');
    expect(find.byType(ButtonEditPage), findsOneWidget, reason: 'the action picker is inline');
  });

  group('hover, press and focus', () {
    /// Every fill painted in [target] and under it — including shadcn
    /// Clickable's own (private) decorated box, which paints the washes.
    bool isClickableBox(Widget w) => w.runtimeType.toString() == '_DecoratedBox';
    Set<Color> fillsIn(WidgetTester tester, Finder target) => {
      for (final e in [
        ...target.evaluate(),
        ...find
            .descendant(
              of: target,
              matching: find.byWidgetPredicate((w) => w is DecoratedBox || w is ColoredBox || isClickableBox(w)),
            )
            .evaluate(),
      ])
        ...switch (e.widget) {
          DecoratedBox(decoration: BoxDecoration(:final color?)) => [color],
          ColoredBox(:final color) => [color],
          final w when isClickableBox(w) => [
            if ((w as dynamic).decoration case BoxDecoration(:final color?)) color,
          ],
          _ => const <Color>[],
        },
    };

    /// [target]'s surface paints the card washes for hover and press and
    /// shows the click cursor; then a real press shows the pressed wash.
    Future<void> expectHoverAndPress(WidgetTester tester, Finder target) async {
      await tester.ensureVisible(target);
      await tester.pump();
      final context = tester.element(target);
      final hover = bkCardHover(context);
      final pressed = bkCardPressed(context);
      expect(fillsIn(tester, target), isNot(contains(hover)), reason: '$target at rest');

      // The target's own surface: the outermost Clickable under it.
      final clickable = tester.widget<Clickable>(find.descendant(of: target, matching: find.byType(Clickable)).first);
      Color? fillWhen(Set<WidgetState> states) => switch (clickable.decoration?.resolve(states)) {
        BoxDecoration(:final color) => color,
        _ => null,
      };
      expect(fillWhen({WidgetState.hovered}), hover, reason: '$target hovered');
      expect(fillWhen({WidgetState.hovered, WidgetState.pressed}), pressed, reason: '$target pressed');
      expect(clickable.mouseCursor?.resolve({}), SystemMouseCursors.click, reason: '$target cursor');

      final press = await tester.startGesture(tester.getCenter(target));
      // Past the tap's press timeout, then the frame that paints it.
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      expect(fillsIn(tester, target), contains(pressed), reason: '$target pressed for real');
      await press.cancel();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('390 wide: a button row and its trigger rows wash on hover and press', (tester) async {
      await pump(tester, const Size(390, 844));
      await openRow(tester, find.byKey(ValueKey('mapping-row-${mapped.name}')));
      await expectHoverAndPress(tester, find.byKey(ValueKey('mapping-row-${mapped.name}')));
      for (final trigger in ButtonTrigger.values) {
        await expectHoverAndPress(tester, find.byKey(ValueKey('mapping-trigger-${mapped.name}-${trigger.name}')));
      }
    });

    testWidgets('1280 wide: the trigger cards wash on hover and press, and take the focus ring', (tester) async {
      await pump(tester, const Size(1280, 800));
      for (final trigger in ButtonTrigger.values) {
        await expectHoverAndPress(tester, find.byKey(ValueKey('mapping-trigger-card-${trigger.name}')));
      }

      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
      final card = find.byKey(const ValueKey('mapping-trigger-card-doubleClick'));
      final inner = find.descendant(of: card, matching: find.byType(Text)).first;
      Focus.of(tester.element(inner)).requestFocus();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester
            .widgetList<FocusOutline>(find.descendant(of: card, matching: find.byType(FocusOutline)))
            .any((o) => o.focused),
        isTrue,
      );
    });
  });

  group('vibration on shift', () {
    ZwiftPlay vibratingController() =>
        ZwiftPlay(
            BleDevice(name: 'Zwift Play', deviceId: 'mapping-play'),
            deviceType: ZwiftDeviceType.playLeft,
          )
          ..isConnected = true
          ..batteryLevel = 70;

    testWidgets('is a grouped row with a switch, right above Reset to defaults', (tester) async {
      final play = vibratingController();
      core.connection.devices.add(play);
      await core.settings.setVibrationEnabled(true);
      final l = await pump(tester, const Size(390, 844), controller: play);

      expect(find.byType(Checkbox), findsNothing, reason: 'no loose checkbox');
      final row = find.widgetWithText(BkGroupedRow, l.enableVibrationFeedback);
      expect(row, findsOneWidget);
      final toggle = find.descendant(of: row, matching: find.byType(Switch));
      expect(toggle, findsOneWidget);

      final reset = find.widgetWithText(BkGroupedRow, l.resetToDefaults);
      expect(reset, findsOneWidget);
      final section = find.ancestor(of: reset, matching: find.byType(BkGroupedSection));
      expect(
        find.descendant(of: section, matching: row),
        findsOneWidget,
        reason: 'the same group as Reset',
      );
      final rowRect = tester.getRect(row);
      final resetRect = tester.getRect(reset);
      expect(rowRect.bottom, lessThanOrEqualTo(resetRect.top));
      expect(resetRect.top - rowRect.bottom, lessThan(2), reason: 'directly above it');

      // Read as its title and on/off.
      expect(
        tester.getSemantics(toggle),
        containsSemantics(label: l.enableVibrationFeedback, hasToggledState: true, isToggled: true),
      );

      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pump();
      expect(core.settings.getVibrationEnabled(), isFalse);
      expect(tester.widget<Switch>(toggle).value, isFalse);
    });

    testWidgets('is not offered for a controller that cannot vibrate', (tester) async {
      final l = await pump(tester, const Size(390, 844));
      expect(find.widgetWithText(BkGroupedRow, l.enableVibrationFeedback), findsNothing);
    });
  });
}
