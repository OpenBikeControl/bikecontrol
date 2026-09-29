// On a phone the "Help & Support" pill floated over the home screen's scroll
// view, so at rest it sat on top of whatever card was behind it — on a fresh
// home, the Smart Trainer card's title. The bottom padding only let the last
// card scroll clear of it; nothing stopped it covering content before that.
// The pill now has its own footer space: the home content ends above it.
import 'package:bike_control/main.dart';
import 'package:bike_control/pages/navigation.dart';
import 'package:bike_control/pages/overview.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/widgets/ui/help_button.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  testWidgets('the mobile help pill never sits on top of the home content', (tester) async {
    core.actionHandler = StubActions();
    core.actionHandler.init(MyWhoosh());
    core.settings.setTrainerApp(MyWhoosh());
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const BikeControlApp(customChild: Navigation()));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    final pill = tester.getRect(find.byType(HelpButton));
    final content = tester.getRect(find.byType(OverviewPage));
    expect(content.bottom, lessThanOrEqualTo(pill.top + 0.5), reason: 'content $content, pill $pill');

    await tester.pumpWidget(const SizedBox());
  });
}
