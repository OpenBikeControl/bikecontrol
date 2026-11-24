import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/utils/actions/remote.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/apps/wahoo.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:bike_control/utils/trainer_setup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

/// The Wahoo app takes no controller input and finds trainers over Bluetooth
/// only, so BikeControl is a Bluetooth trainer to it on a second device and
/// does the virtual shifting itself.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = RemoteActions();
  });

  test('is offered in the trainer-app chooser', () {
    expect(SupportedApp.supportedApps.whereType<WahooApp>(), hasLength(1));
  }, skip: 'The Wahoo app is hidden from the chooser for now (c010a2c63 "wahoo not yet"); re-enable with it');

  test('delivers no button events to the app', () {
    final app = WahooApp();
    expect(app.connections, isEmpty);
    expect(app.keymap.keyPairs, isEmpty);
    expect(app.acceptsSimulatedInput, isFalse);
    for (final method in AppConnectionMethod.values) {
      expect(app.supports(method), isFalse, reason: '$method');
    }
  });

  test('virtual shifting is Bluetooth-only, from another device', () {
    final app = WahooApp();
    expect(app.virtualShiftingTransports, {TrainerConnectionType.bluetooth});
    expect(vsSameDeviceBlock(app), VsSameDeviceBlock.bluetoothOnly);
    expect(Target.supportedFor(app), [Target.otherDevice]);
  });

  test('selecting it pins the target to another device and needs no connection method', () async {
    await core.settings.setLastTarget(Target.thisDevice);

    await applyTrainerAppSelection(WahooApp());

    expect(core.settings.getLastTarget(), Target.otherDevice);
    expect(core.logic.hasNoConnectionMethod, isFalse);
  }, skip: 'The Wahoo app is hidden from the chooser for now (c010a2c63 "wahoo not yet"); re-enable with it');

  test('the bridge keeps its usual name', () {
    core.settings.setTrainerApp(WahooApp());
    expect(ProxyDevice(BleDevice(deviceId: 'trainer', name: 'KICKR CORE 73D3')).bridgeAdvertisementName(), isNull);
  });
}
