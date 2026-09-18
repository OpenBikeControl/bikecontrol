import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart' show ftmsEmulator;
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/dircon_emulator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

/// TrainerRoad's desktop WFTNP client hard-dials DirCon port 36866, so the
/// trainer bridge serves there for TrainerRoad riders, who pick "Other" —
/// see [[trainerroad-dircon-behavior]]. Every named app keeps the
/// auto-assigned port: MyWhoosh on Windows stopped connecting when the bridge
/// moved to 36866 for everyone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
  });

  group('"Other" (TrainerRoad) serves the Wahoo standard DirCon port (36866)', () {
    setUp(() => core.settings.setTrainerApp(CustomApp()));

    test('proxy-mode bridge', () {
      final device = ProxyDevice(BleDevice(deviceId: 'trainer', name: 'KICKR CORE A93D'));
      // Default retrofit mode is proxy, so `emulator` is the proxy bridge.
      expect(device.emulator.preferredPort, kWahooDirconStandardPort);
    });

    test('Virtual-Shifting bridge (global ftmsEmulator)', () {
      expect(ftmsEmulator.preferredPort, kWahooDirconStandardPort);
    });
  });

  group('named apps keep the auto-assigned port', () {
    for (final app in [MyWhoosh(), Zwift()]) {
      test('$app: proxy-mode bridge and Virtual-Shifting bridge', () {
        core.settings.setTrainerApp(app);
        final device = ProxyDevice(BleDevice(deviceId: 'trainer', name: 'KICKR CORE A93D'));
        expect(device.emulator.preferredPort, isNot(kWahooDirconStandardPort));
        expect(ftmsEmulator.preferredPort, isNot(kWahooDirconStandardPort));
      });
    }
  });
}
