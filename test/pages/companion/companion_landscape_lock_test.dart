// A phone on a short out-front mount only fits sideways, and with a charging
// cable it stays that way for the whole ride. The companion page can hold
// itself in landscape, even with the system's rotation lock on, and lets go
// again when the rider leaves it.
import 'package:bike_control/pages/button_simulator.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/host_platform.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../widget_snapshot.dart';

const _landscapeOnly = ['DeviceOrientation.landscapeLeft', 'DeviceOrientation.landscapeRight'];
const _all = [
  'DeviceOrientation.portraitUp',
  'DeviceOrientation.portraitDown',
  'DeviceOrientation.landscapeLeft',
  'DeviceOrientation.landscapeRight',
];

Future<void> main() async {
  await ensureSnapshotHarness();

  late List<List<String>> orientationCalls;

  setUp(() async {
    await core.settings.setCompanionForceLandscape(false);
    core.settings.setTrainerApp(Rouvy());
    core.settings.setKeyMap(Rouvy());
  });

  void stagePhone(WidgetTester tester, TargetPlatform platform) {
    debugHostPlatformOverride = platform;
    orientationCalls = [];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setPreferredOrientations') {
        orientationCalls.add((call.arguments as List).cast<String>());
      }
      return null;
    });
    addTearDown(() {
      debugHostPlatformOverride = null;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });
  }

  Future<void> render(WidgetTester tester, {bool fullScreen = false}) => captureWidget(
    tester,
    name: 'companion_landscape_lock',
    width: 414,
    height: 860,
    padding: EdgeInsets.zero,
    settle: false,
    outputDir: 'build/snapshots',
    builder: (_) => ButtonSimulator(startFullScreen: fullScreen),
  );

  const toggle = ValueKey('companion-landscape');

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('${platform.name}: the toggle holds the page in landscape, leaving lets go', (tester) async {
      stagePhone(tester, platform);
      await render(tester);
      expect(orientationCalls, isEmpty, reason: 'nothing is locked until the rider asks');

      await tester.tap(find.byKey(toggle));
      await tester.pump();
      expect(orientationCalls.last, _landscapeOnly);
      expect(core.settings.getCompanionForceLandscape(), isTrue);

      await tester.pumpWidget(const SizedBox());
      expect(orientationCalls.last, _all);
    });
  }

  testWidgets('a rider who locked it gets landscape again the next time', (tester) async {
    stagePhone(tester, TargetPlatform.iOS);
    await core.settings.setCompanionForceLandscape(true);
    await render(tester);
    expect(orientationCalls.last, _landscapeOnly);

    await tester.tap(find.byKey(toggle));
    await tester.pump();
    expect(orientationCalls.last, _all);
    expect(core.settings.getCompanionForceLandscape(), isFalse);
  });

  testWidgets('full screen has the toggle too, next to exit', (tester) async {
    stagePhone(tester, TargetPlatform.iOS);
    await render(tester, fullScreen: true);
    await tester.tap(find.byKey(toggle));
    await tester.pump();
    expect(orientationCalls.last, _landscapeOnly);
  });

  testWidgets('desktop windows have no rotation to lock', (tester) async {
    await render(tester);
    expect(find.byKey(toggle), findsNothing);
  });
}
