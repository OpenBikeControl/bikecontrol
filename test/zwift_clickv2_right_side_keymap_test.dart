import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2_right_side.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

ZwiftClickV2RightSide _rightSide() => ZwiftClickV2RightSide(
  BleDevice(deviceId: 'right-1337', name: 'Zwift Click', manufacturerDataList: const [], services: const []),
);

InGameAction? _action(SupportedApp? app, ControllerButton button) =>
    app?.keymap.getKeyPair(button, trigger: ButtonTrigger.singleClick)?.inGameAction;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Right-side-only keymap', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      core.actionHandler = StubActions();
      core.settings.prefs = await SharedPreferences.getInstance();
    });

    test('forks a built-in profile into a custom copy so the remap persists', () async {
      core.actionHandler.supportedApp = Zwift();

      _rightSide().configureRightSideShiftingKeymap();

      // The active app is now an editable custom copy (built-in profiles are
      // read-only templates that reset on restart).
      final active = core.actionHandler.supportedApp;
      expect(active, isA<CustomApp>());
      expect(active!.name, 'Zwift (Copy)');

      // + still shifts up, B now shifts down.
      expect(_action(active, ZwiftButtons.shiftUpRight), InGameAction.shiftUp);
      expect(_action(active, ZwiftButtons.b), InGameAction.shiftDown);

      // And it survives a reload from storage (the reported bug: it didn't).
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final reloaded = core.settings.getKeyMap();
      expect(reloaded, isA<CustomApp>());
      expect(reloaded!.name, 'Zwift (Copy)');
      expect(_action(reloaded, ZwiftButtons.b), InGameAction.shiftDown);
      expect(_action(reloaded, ZwiftButtons.shiftUpRight), InGameAction.shiftUp);
    });

    test('edits the custom profile in place when one is already active', () async {
      final custom = CustomApp(profileName: 'My Profile');
      core.actionHandler.supportedApp = custom;

      _rightSide().configureRightSideShiftingKeymap();

      // No "(Copy)" fork — the already-custom profile is edited directly.
      final active = core.actionHandler.supportedApp;
      expect(active, same(custom));
      expect(_action(active, ZwiftButtons.b), InGameAction.shiftDown);
      expect(_action(active, ZwiftButtons.shiftUpRight), InGameAction.shiftUp);
    });
  });
}
