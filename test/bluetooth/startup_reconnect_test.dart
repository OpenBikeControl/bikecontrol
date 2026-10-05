// Right after launch BikeControl reconnects the devices it remembers on its
// own. For that window the home screen shows them as placeholders that are
// "Connecting…" rather than "Out of range", so their cards are already where
// the live ones will be. The window closes when every one of them is back, or
// when it times out — then the screen tells the plain truth again.
import 'package:bike_control/bluetooth/devices/zwift/zwift_play.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_ble/universal_ble.dart';

import '../widget_snapshot.dart';

void main() {
  // The fake clock, so the window's timer runs out on a pump.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(ensureSnapshotAppState);

  late ZwiftPlay play;
  setUp(() {
    play = ZwiftPlay(BleDevice(name: 'Zwift Play', deviceId: 'startup-play'), deviceType: ZwiftDeviceType.playLeft);
    core.connection.debugRememberController(play);
  });
  tearDown(() {
    core.connection.endStartupReconnect();
    core.connection.debugForgetOfflineControllers();
    core.connection.devices.clear();
  });

  testWidgets('starts with every remembered device and closes when it times out', (tester) async {
    core.connection.beginStartupReconnect(window: const Duration(seconds: 20));
    expect(core.connection.startupReconnecting.value, contains(play.uniqueId));

    await tester.pump(const Duration(seconds: 19));
    expect(core.connection.startupReconnecting.value, contains(play.uniqueId));

    await tester.pump(const Duration(seconds: 1));
    expect(core.connection.startupReconnecting.value, isEmpty);
  });

  testWidgets('a device that comes back leaves the window; the last one closes it', (tester) async {
    core.connection.beginStartupReconnect(window: const Duration(seconds: 20));

    core.connection.noteReconnected(play.uniqueId);
    expect(core.connection.startupReconnecting.value, isEmpty);
    // Nothing left pending.
    await tester.pump(const Duration(seconds: 20));
  });

  testWidgets('nothing remembered: no window at all', (tester) async {
    core.connection.debugForgetOfflineControllers();
    final trainer = core.connection.rememberedTrainer;
    core.connection.rememberedTrainer = null;
    addTearDown(() => core.connection.rememberedTrainer = trainer);

    core.connection.beginStartupReconnect(window: const Duration(seconds: 20));
    expect(core.connection.startupReconnecting.value, isEmpty);
  });
}
