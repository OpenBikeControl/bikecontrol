import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/bluetooth/emulation/emulated_ble_platform.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/sensor_definition.dart';
import 'package:prop/emulators/definitions/zwift_click_definition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

ZwiftClickDefinition _clickDefinition() => ZwiftClickDefinition(
  services: const <BleService>[],
  device: BleDevice(deviceId: 'click-v2', name: 'Zwift Click'),
  data: ValueNotifier<String>(''),
  vendorMessage: null,
  isUnlocked: ValueNotifier<bool>(false),
  alreadyUnlocked: ValueNotifier<bool>(false),
  waiting: ValueNotifier<bool>(false),
  isStarted: ValueNotifier<bool>(true),
  connectionDate: DateTime(2026),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppLocalizations.load(const Locale('en'));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
  });

  test('the Click definition rides on the bridge for Zwift, not for Rouvy', () {
    final click = ZwiftClickV2(BleDevice(deviceId: 'click-v2', name: 'Zwift Click'));

    core.settings.setTrainerApp(Zwift());
    expect(click.attachesClickDefToBridge, isTrue);

    core.settings.setTrainerApp(Rouvy());
    expect(click.attachesClickDefToBridge, isFalse);
  });

  test('switching apps takes the Click definition on and off the bridge composite', () {
    final click = ZwiftClickV2(BleDevice(deviceId: 'click-v2', name: 'Zwift Click'));
    final def = _clickDefinition();
    click.debugSetClickDef(def);
    addTearDown(() => ftmsEmulator.composite.detach(def));

    // Connected under Zwift: the definition sits on the shared composite.
    core.settings.setTrainerApp(Zwift());
    ftmsEmulator.composite.attach(def);

    // Zwift → Rouvy must take it off — the bridge advertises only its own
    // trainer services again.
    core.settings.setTrainerApp(Rouvy());
    click.onTrainerAppChanged();
    expect(ftmsEmulator.composite.children, isNot(contains(def)));

    // Rouvy → Zwift puts it back.
    core.settings.setTrainerApp(Zwift());
    click.onTrainerAppChanged();
    expect(ftmsEmulator.composite.children, contains(def));
  });

  // Wave 2 introduced the shared `hasNothingToServe` predicate (composite
  // children that are all SensorDefinition count as "nothing") specifically
  // so a lingering heart-rate-only definition can't ghost the bridge after
  // the last real definition leaves it — but shipped this call site with no
  // dedicated test. Without the fix, `disconnect()` would see a non-empty
  // composite (the SensorDefinition still riding along) and leave the bridge
  // advertising under the trainer's old name with nothing but a heart-rate
  // service on it.
  test('disconnecting the Click stops the shared bridge when only a lingering SensorDefinition is left', () async {
    UniversalBle.setInstance(FakeUniversalBlePlatform());
    final click = ZwiftClickV2(BleDevice(deviceId: 'click-v2', name: 'Zwift Click'));
    final clickDef = _clickDefinition();
    click.debugSetClickDef(clickDef);
    final sensorDef = SensorDefinition();

    ftmsEmulator.composite.attach(clickDef);
    ftmsEmulator.composite.attach(sensorDef);
    ftmsEmulator.isStarted.value = true;
    addTearDown(() {
      ftmsEmulator.composite.detach(clickDef);
      ftmsEmulator.composite.detach(sensorDef);
      ftmsEmulator.isStarted.value = false;
    });

    await click.disconnect();

    expect(ftmsEmulator.isStarted.value, isFalse);
    expect(ftmsEmulator.composite.children, isNot(contains(clickDef)));
  });
}
