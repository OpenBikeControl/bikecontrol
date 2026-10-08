// The companion page's action tiles on a 414 px phone: three to a row, so a
// tile is narrow, and a long German word used to break inside it
// ("Kameraw" / "inkel", with "ändern" clipped away). Every tile's label reads
// whole, broken only between words, in every locale.
import 'package:bike_control/pages/button_simulator.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/requirements/multi.dart' show Target;
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/text_breaks.dart';
import '../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  for (final locale in const ['en', 'de', 'es', 'fr', 'it', 'pl']) {
    testWidgets('414 px: every action tile\'s label reads whole ($locale)', (tester) async {
      core.settings.setTrainerApp(MyWhoosh());
      core.settings.setKeyMap(MyWhoosh());
      core.settings.setLastTarget(Target.thisDevice);
      core.settings.setMyWhooshLinkEnabled(true);
      core.whooshLink.isConnected.value = true;
      addTearDown(() {
        core.whooshLink.isConnected.value = false;
        core.settings.setMyWhooshLinkEnabled(false);
      });

      await captureWidget(
        tester,
        name: 'button_simulator_tiles_$locale',
        width: 414,
        height: 2400,
        padding: EdgeInsets.zero,
        locales: [locale],
        settle: false,
        builder: (_) => const ButtonSimulator(),
      );

      final tiles = find.byType(Button);
      expect(core.logic.enabledNonLocalTrainerConnections, isNotEmpty, reason: 'a connection to send over');
      expect(tiles, findsWidgets);
      for (final tile in tiles.evaluate().toList()) {
        expectReadsWhole(tester, find.byElementPredicate((e) => identical(e, tile)), reason: '[$locale]');
      }
    });
  }
}
