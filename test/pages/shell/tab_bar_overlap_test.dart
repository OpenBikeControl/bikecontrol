// On a phone the old "Help & Support" pill floated over the home screen's
// scroll view and sat on top of whatever card was behind it. Its successor,
// the bottom tab bar, has its own footer space: the content ends above it.
import 'package:bike_control/main.dart';
import 'package:bike_control/pages/navigation.dart';
import 'package:bike_control/pages/shell/app_shell.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  testWidgets('the tab bar never sits on top of the content', (tester) async {
    core.actionHandler = StubActions();
    core.actionHandler.init(MyWhoosh());
    core.settings.setTrainerApp(MyWhoosh());
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    tester.view.padding = const FakeViewPadding(bottom: 34 * 2);
    tester.view.viewPadding = const FakeViewPadding(bottom: 34 * 2);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const BikeControlApp(customChild: Navigation()));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    final bar = tester.getRect(find.byType(ShellTabBar));
    final content = tester.getRect(find.byKey(const ValueKey('shell-content')));
    expect(content.bottom, lessThanOrEqualTo(bar.top + 0.5), reason: 'content $content, bar $bar');
    expect(bar.bottom, closeTo(844, 0.5), reason: 'the bar reaches the bottom edge, past the home indicator');

    await tester.pumpWidget(const SizedBox());
  });
}
