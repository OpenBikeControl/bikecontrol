import 'package:bike_control/bluetooth/devices/zwift/zwift_unlock.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/training_peaks.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/ble_definition.dart';
import 'package:prop/emulators/definitions/proxy_bike_definition.dart';
import 'package:prop/emulators/definitions/zwift_click_definition.dart';
import 'package:prop/emulators/dircon_emulator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

/// TrainingPeaks Virtual takes the controller from OpenBikeControl's DirCon
/// endpoint, advertised as `_wahoo-fitness-tnp._tcp "BikeControl"`. A bridge
/// the unlock page started for a lone Click V2 advertises the very same name
/// and type, and left running after the page closes it shadows the controller
/// endpoint: TPV resolves only one of the two and never lists the controller.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
  });

  ZwiftClickDefinition clickDef() => ZwiftClickDefinition(
    services: const [],
    isUnlocked: ValueNotifier(false),
    alreadyUnlocked: ValueNotifier(false),
    waiting: ValueNotifier(false),
    isStarted: ValueNotifier(false),
    connectionDate: DateTime(2026, 11, 2),
    vendorMessage: null,
    device: BleDevice(deviceId: 'click', name: 'Zwift Click'),
    data: ValueNotifier(''),
  );

  DirconEmulator bridgeWith(List<BleDefinition> definitions) {
    final bridge = DirconEmulator();
    for (final def in definitions) {
      bridge.composite.attach(def);
    }
    return bridge;
  }

  test('stops a bridge it started for the controller alone when TPV is selected', () {
    core.settings.setTrainerApp(TrainingPeaks());

    expect(unlockBridgeStopsOnClose(startedByPage: true, emulator: bridgeWith([clickDef()])), isTrue);
    // Its name is exactly what the controller endpoint advertises.
    expect(bridgeWith([clickDef()]).advertisementName, 'BikeControl');
  });

  test('leaves a bridge that was already running before the page opened', () {
    core.settings.setTrainerApp(TrainingPeaks());

    expect(unlockBridgeStopsOnClose(startedByPage: false, emulator: bridgeWith([clickDef()])), isFalse);
  });

  test('leaves a bridge that also serves a trainer', () {
    core.settings.setTrainerApp(TrainingPeaks());
    final trainer = ProxyBikeDefinition(
      services: const [],
      device: BleDevice(deviceId: 'trainer', name: 'KICKR CORE 73D3'),
      data: ValueNotifier(''),
    );

    expect(unlockBridgeStopsOnClose(startedByPage: true, emulator: bridgeWith([clickDef(), trainer])), isFalse);
  });

  test('leaves the bridge for apps that do not take the controller over DirCon', () {
    for (final app in [Zwift(), MyWhoosh()]) {
      core.settings.setTrainerApp(app);

      expect(
        unlockBridgeStopsOnClose(startedByPage: true, emulator: bridgeWith([clickDef()])),
        isFalse,
        reason: '${app.runtimeType}',
      );
    }
  });
}
