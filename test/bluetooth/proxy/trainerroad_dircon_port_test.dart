import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart' show ftmsEmulator;
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/dircon_emulator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

/// The trainer bridge must serve DirCon on the standard Wahoo port so clients
/// that hard-dial it (rather than honoring the mDNS SRV port) can connect.
/// TrainerRoad's desktop WFTNP client is the motivating case — see
/// [[trainerroad-dircon-behavior]].
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
  });

  test('proxy-mode bridge prefers the Wahoo standard DirCon port (36866)', () {
    final device = ProxyDevice(BleDevice(deviceId: 'trainer', name: 'KICKR CORE A93D'));
    // Default retrofit mode is proxy, so `emulator` is the proxy bridge.
    expect(device.emulator.preferredPort, kWahooDirconStandardPort);
  });

  test('Virtual-Shifting bridge (global ftmsEmulator) prefers 36866', () {
    expect(ftmsEmulator.preferredPort, kWahooDirconStandardPort);
  });
}
