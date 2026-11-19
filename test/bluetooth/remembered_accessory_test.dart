import 'package:bike_control/models/remembered_device.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Older versions remembered a Rizer as a controller, before it became an
/// accessory. It must not come back as a sleeping "Controller".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
    core.connection.debugForgetOfflineControllers();
  });

  tearDown(() => core.connection.debugForgetOfflineControllers());

  test('an accessory (here a Headwind; a Rizer takes the same path) remembered as a controller is dropped, not shown as one', () async {
    await core.rememberedDevices.remember(
      RememberedDevice(
        deviceId: 'headwind-1',
        name: 'HEADWIND 1234',
        kind: RememberedDeviceKind.controller,
        lastConnected: DateTime(2026, 11, 1),
      ),
    );

    core.connection.loadRememberedDevices();
    await pumpEventQueue();

    expect(core.connection.offlineControllers, isEmpty);
    expect(core.rememberedDevices.load(), isEmpty);
  });
}
