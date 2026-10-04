// Toasts on a phone used to land on top of the bottom tab bar. They sit above
// it now, the width of the content; from 600 they sit bottom-right — above the
// tab bar below 840, in the content area clear of the sidebar from there.
import 'package:bike_control/main.dart';
import 'package:bike_control/pages/navigation.dart';
import 'package:bike_control/pages/shell/app_shell.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/prop.dart' show LogLevel;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  Future<void> pumpApp(WidgetTester tester, Size size, {double bottomInset = 0}) async {
    core.actionHandler = StubActions();
    core.actionHandler.init(MyWhoosh());
    core.settings.setTrainerApp(MyWhoosh());
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    tester.view.padding = FakeViewPadding(bottom: bottomInset * 2);
    tester.view.viewPadding = FakeViewPadding(bottom: bottomInset * 2);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const BikeControlApp(customChild: Navigation()));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  Future<Rect> showAndMeasure(WidgetTester tester) async {
    buildToast(level: LogLevel.LOGLEVEL_WARNING, title: 'Trainer lost', subtitle: 'Reconnecting');
    // Past the entry animation.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final toast = find.byType(BkToastCard);
    expect(toast, findsOneWidget);
    return tester.getRect(toast);
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  }

  testWidgets('phone: the toast sits above the tab bar, full width less the margins', (tester) async {
    await pumpApp(tester, const Size(390, 844), bottomInset: 34);
    final bar = tester.getRect(find.byType(ShellTabBar));
    final toast = await showAndMeasure(tester);

    expect(toast.bottom, lessThanOrEqualTo(bar.top), reason: 'toast $toast, bar $bar');
    expect(bar.top - toast.bottom, closeTo(8, 1), reason: 'an 8 px gap above the bar');
    expect(toast.left, closeTo(16, 0.5));
    expect(toast.right, closeTo(390 - 16, 0.5));
    await finish(tester);
  });

  for (final size in const [Size(700, 1000), Size(839, 1000)]) {
    testWidgets('${size.width.toInt()}: the toast sits above the bottom tab bar, bottom-right', (tester) async {
      await pumpApp(tester, size);
      final bar = tester.getRect(find.byType(ShellTabBar));
      final toast = await showAndMeasure(tester);

      expect(toast.bottom, lessThanOrEqualTo(bar.top), reason: 'toast $toast, bar $bar');
      expect(bar.top - toast.bottom, closeTo(8, 1), reason: 'an 8 px gap above the bar');
      expect(size.width - toast.right, closeTo(24, 0.5));
      await finish(tester);
    });
  }

  testWidgets('desktop: the toast sits bottom-right, clear of the sidebar', (tester) async {
    await pumpApp(tester, const Size(1280, 800));
    final sidebar = tester.getRect(find.byType(ShellSidebar));
    final toast = await showAndMeasure(tester);

    expect(toast.left, greaterThan(sidebar.right));
    expect(1280 - toast.right, closeTo(24, 0.5));
    expect(800 - toast.bottom, closeTo(24, 0.5));
    await finish(tester);
  });

  testWidgets('the toast leads with its status icon and carries its action', (tester) async {
    await pumpApp(tester, const Size(390, 844));
    var undone = 0;
    buildToast(title: 'Removed', closeTitle: 'Undo', onClose: () => undone++);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final card = find.byType(BkToastCard);
    expect(find.descendant(of: card, matching: find.byIcon(LucideIcons.info)), findsOneWidget);
    await tester.tap(find.descendant(of: card, matching: find.text('Undo')));
    await tester.pump(const Duration(milliseconds: 600));
    expect(undone, 1);
    await finish(tester);
  });
}
