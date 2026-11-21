import 'dart:convert';

import 'package:bike_control/services/overlay/desktop_overlay_controller.dart';
import 'package:bike_control/services/overlay/desktop_overlay_window.dart';
import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

/// Every trainer (re)connect builds a fresh FitnessBikeDefinition. On Windows a
/// trainer that dropped and reconnected at the start of a ride left the
/// floating overlay on the old, now silent definition: shifting kept working,
/// the gear readout stayed frozen all ride (support a1c3592b).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.coditas.multi_window_native/pluginChannel');
  final pushedGears = <int>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
    pushedGears.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == kStateMethod) {
        final state = jsonDecode(call.arguments as String) as Map<String, dynamic>;
        pushedGears.add((state['gear'] as num).toInt());
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  FitnessBikeDefinition makeDefinition() {
    final scanResult = BleDevice(
      deviceId: 'vanrysel',
      name: 'VANRYSEL-HT',
      services: const [FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID],
    );
    return FitnessBikeDefinition(
      connectedDevice: scanResult,
      connectedDeviceServices: [BleService(FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID, [])],
      data: ValueNotifier(''),
    );
  }

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 150));

  test('a shift on the shown definition reaches the overlay', () async {
    final controller = DesktopOverlayController();
    final def = makeDefinition();
    await controller.show(def, {OverlayField.power}, liveDef: ValueNotifier(def));

    def.setTargetGear(def.currentGear.value + 1);
    await settle();

    expect(pushedGears.last, def.currentGear.value);
    await controller.hide();
  });

  test('the overlay follows the definition the reconnect built', () async {
    final controller = DesktopOverlayController();
    final before = makeDefinition();
    final live = ValueNotifier<FitnessBikeDefinition?>(before);
    await controller.show(before, {OverlayField.power}, liveDef: live);

    final after = makeDefinition();
    live.value = after;
    after.setTargetGear(before.currentGear.value + 3);
    await settle();

    expect(pushedGears.last, after.currentGear.value);
    await controller.hide();
  });

  test('a show while already showing moves the display to the given definition', () async {
    final controller = DesktopOverlayController();
    final before = makeDefinition();
    await controller.show(before, {OverlayField.power});

    final after = makeDefinition();
    await controller.show(after, {OverlayField.power});
    after.setTargetGear(before.currentGear.value + 2);
    await settle();

    expect(pushedGears.last, after.currentGear.value);
    await controller.hide();
  });

  test('after hide, the old trainer no longer pushes', () async {
    final controller = DesktopOverlayController();
    final before = makeDefinition();
    final live = ValueNotifier<FitnessBikeDefinition?>(before);
    await controller.show(before, {OverlayField.power}, liveDef: live);
    await controller.hide();
    pushedGears.clear();

    live.value = makeDefinition()..setTargetGear(7);
    before.setTargetGear(9);
    await settle();

    expect(pushedGears, isEmpty);
  });
}
