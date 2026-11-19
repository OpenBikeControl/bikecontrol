// The phone's large title sits at the same height on every tab: the plan
// badge and (?) on Ride, or Activity's "Clear log", must not make the bar
// taller and push the title down when switching tabs.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/shell/app_shell.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:flutter/services.dart' show StandardMessageCodec;
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../helpers/shell_harness.dart';
import '../../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();
  quietShellEnvironment();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
    'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
    (_) async => const StandardMessageCodec().encodeMessage(<Object?>[null]),
  );

  AppLocalizations l10n() => AppLocalizations.current;

  for (final trial in [true, false]) {
    testWidgets('phone (${trial ? 'trial' : 'Pro'}): the title has the same top on every tab and segment', (
      tester,
    ) async {
      if (trial) {
        IAPManager.instance.setProForTesting(enabled: false);
        IAPManager.instance.isPurchased.value = false;
      } else {
        IAPManager.instance.setProForTesting(enabled: true);
      }
      addTearDown(() {
        IAPManager.instance.setProForTesting(enabled: false);
        IAPManager.instance.isPurchased.value = true;
      });
      await pumpShell(tester, const Size(390, 844));
      await tester.loadAssets();
      await tester.pump();

      final bar = find.byType(ShellTopBar);
      double titleTop(String title) => tester.getTopLeft(find.descendant(of: bar, matching: find.text(title))).dy;
      Future<void> open(String label) async {
        await tester.tap(find.descendant(of: find.byType(ShellTabBar), matching: find.text(label)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
      }

      final tops = <String, double>{'ride': titleTop('BikeControl')};
      await open(l10n().navDevices);
      tops['devices'] = titleTop(l10n().navDevices);
      await open(l10n().activity);
      tops['activity'] = titleTop(l10n().activity);
      await open(l10n().navSettings);
      tops['settings'] = titleTop(l10n().navSettings);

      for (final entry in tops.entries) {
        expect(entry.value, moreOrLessEquals(tops['ride']!, epsilon: 0.5), reason: '${entry.key}: $tops');
      }
      await disposeShell(tester);
    });
  }
}
