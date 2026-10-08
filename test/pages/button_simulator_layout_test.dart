// The companion page is used mid-ride: shifting leads and is the biggest
// target, steering follows it (it used to sit below "Other", off the first
// screen), the remaining actions are an even grid, and an action's quick
// values sit in its own row instead of floating under a tile.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/button_simulator.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/requirements/multi.dart' show Target;
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:flutter/foundation.dart';

import '../helpers/text_breaks.dart';
import '../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  void connectMyWhoosh() {
    core.settings.setTrainerApp(MyWhoosh());
    core.settings.setKeyMap(MyWhoosh());
    core.settings.setLastTarget(Target.thisDevice);
    core.settings.setMyWhooshLinkEnabled(true);
    core.whooshLink.isConnected.value = true;
    addTearDown(() {
      core.whooshLink.isConnected.value = false;
      core.settings.setMyWhooshLinkEnabled(false);
    });
  }

  Rect pad(WidgetTester tester, InGameAction action) =>
      tester.getRect(find.ancestor(of: find.text(action.title).first, matching: find.byType(Button)).first);

  Future<void> render(WidgetTester tester, {String locale = 'en', double width = 414}) => captureWidget(
    tester,
    name: 'button_simulator_layout_$locale',
    width: width,
    height: 2400,
    padding: EdgeInsets.zero,
    locales: [locale],
    settle: false,
    outputDir: 'build/snapshots',
    builder: (_) => const ButtonSimulator(),
  );

  testWidgets('shifting leads and is the biggest target; steering comes before the other actions', (tester) async {
    connectMyWhoosh();
    await render(tester);

    final up = pad(tester, InGameAction.shiftUp);
    final down = pad(tester, InGameAction.shiftDown);
    final left = pad(tester, InGameAction.steerLeft);
    final tuck = pad(tester, InGameAction.tuck);
    final uturn = pad(tester, InGameAction.uturn);

    expect(down.center.dx, lessThan(up.center.dx), reason: '− left, + right, as on Ride');
    expect(up.height, greaterThan(left.height));
    expect(up.height, greaterThan(tuck.height));
    expect(left.top, greaterThan(up.bottom));
    expect(left.bottom, lessThan(tuck.top), reason: 'steering sits above the other actions');
    expect(tuck.height, uturn.height, reason: 'the other actions are an even grid');
  });

  testWidgets('quick values sit in their action\'s own row', (tester) async {
    connectMyWhoosh();
    await render(tester);

    final row = find.byKey(ValueKey('quick-values-${InGameAction.cameraAngle.name}'));
    expect(row, findsOneWidget);
    final title = tester.getRect(find.descendant(of: row, matching: find.text(InGameAction.cameraAngle.title)));
    final chips = find.descendant(of: row, matching: find.byType(Button));
    expect(chips, findsAtLeastNWidgets(2));
    for (final chip in chips.evaluate()) {
      final r = tester.getRect(find.byElementPredicate((e) => identical(e, chip)));
      expect((r.center.dy - title.center.dy).abs(), lessThan(r.height / 2), reason: 'chips beside the title');
      expect(r.height, greaterThanOrEqualTo(44), reason: 'a sweaty thumb needs a 44 pt target');
    }
  });

  testWidgets('with no connection the page says so in the rider\'s language', (tester) async {
    core.settings.setMyWhooshLinkEnabled(false);
    core.settings.setTrainerApp(MyWhoosh());
    await render(tester, locale: 'de');
    expect(find.text(AppLocalizations.current.trainerControlsNoConnection), findsOneWidget);
  });

  for (final locale in const ['en', 'de', 'fr']) {
    testWidgets('on a phone every shortcut row reads whole ($locale)', (tester) async {
      connectMyWhoosh();
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await render(tester, locale: locale);
        final rows = find.byType(BkGroupedRow);
        expect(rows, findsWidgets);
        for (final row in rows.evaluate().toList()) {
          expectReadsWhole(tester, find.byElementPredicate((e) => identical(e, row)), reason: '[$locale]');
        }
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  testWidgets('on a phone a shortcut is cleared from its edit state', (tester) async {
    connectMyWhoosh();
    await core.settings.setButtonSimulatorHotkeys({InGameAction.shiftUp: '1'});
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await render(tester);
      final l10n = AppLocalizations.current;
      final row = find.ancestor(of: find.text(l10n.setShortcut), matching: find.byType(BkGroupedRow)).first;
      expect(find.descendant(of: row, matching: find.text(l10n.clear)), findsNothing);
      await tester.tap(find.descendant(of: row, matching: find.text(l10n.setShortcut)));
      await tester.pump();
      expect(find.text(l10n.pressAKey), findsOneWidget);
      await tester.tap(find.text(l10n.clear));
      await tester.pump();
      expect(core.settings.getButtonSimulatorHotkeys().containsKey(InGameAction.shiftUp), isFalse);
      expect(find.text(l10n.pressAKey), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
