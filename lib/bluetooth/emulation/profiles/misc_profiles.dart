import 'dart:async';

import 'package:prop/utils/cps_measurement.dart';
import 'package:prop/utils/csc_measurement.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../devices/sram/sram_axs.dart' show SramAxsConstants;
import '../../../services/sensors/ble_sensor_source.dart';
import '../emulated_ble_platform.dart';
import '../emulated_peripherals.dart';
import '../emulation_profile.dart';

// Cycplus BC2 — Nordic UART service.
const _cycplusServiceUuid = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
const _cycplusTxUuid = '6e400003-b5a3-f393-e0a9-e50e24dcca9e';
const _cycplusRxUuid = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';

/// 8-byte CYCPLUS frame: byte 6 = shift-up state, byte 7 = shift-down state,
/// 0x01 = pressed (idle observed as 0x03 in real captures).
List<int> cycplusFrame({required bool upPressed, required bool downPressed}) =>
    [0xfe, 0xef, 0xff, 0xee, 0x02, 0x06, upPressed ? 0x01 : 0x03, downPressed ? 0x01 : 0x03];

final cycplusBc2Profile = EmulationProfile(
  name: 'Cycplus BC2',
  category: EmulationCategory.controller,
  build: () {
    final peripheral = FakePeripheral(deviceId: 'emulated:cycplus-bc2', name: 'CYCPLUS BC2');
    peripheral.services.addAll([
      BleService(_cycplusServiceUuid, [
        bleChar(_cycplusTxUuid, [CharacteristicProperty.notify]),
        bleChar(_cycplusRxUuid, [CharacteristicProperty.write, CharacteristicProperty.writeWithoutResponse]),
      ]),
      ...deviceInfoServices(peripheral),
    ]);
    return peripheral;
  },
  inputs: (session) => [
    EmulatedButton(
      'Shift up',
      onDown: () => session.notify(_cycplusTxUuid, cycplusFrame(upPressed: true, downPressed: false)),
      onUp: () => session.notify(_cycplusTxUuid, cycplusFrame(upPressed: false, downPressed: false)),
    ),
    EmulatedButton(
      'Shift down',
      onDown: () => session.notify(_cycplusTxUuid, cycplusFrame(upPressed: false, downPressed: true)),
      onUp: () => session.notify(_cycplusTxUuid, cycplusFrame(upPressed: false, downPressed: false)),
    ),
  ],
);

// ThinkRider VS200 — fixed 5-byte patterns, self-releasing (device clicks).
const _thinkRiderServiceUuid = '0000fea0-0000-1000-8000-00805f9b34fb';
const _thinkRiderCharacteristicUuid = '0000fea1-0000-1000-8000-00805f9b34fb';

final thinkRiderVs200Profile = EmulationProfile(
  name: 'ThinkRider VS200',
  category: EmulationCategory.controller,
  build: () {
    final peripheral = FakePeripheral(deviceId: 'emulated:thinkrider-vs200', name: 'THINK VS01-0000285');
    peripheral.services.addAll([
      BleService(_thinkRiderServiceUuid, [
        bleChar(_thinkRiderCharacteristicUuid, [CharacteristicProperty.notify]),
      ]),
      ...deviceInfoServices(peripheral),
    ]);
    return peripheral;
  },
  inputs: (session) => [
    EmulatedAction(
      'Shift up',
      run: () => session.notify(_thinkRiderCharacteristicUuid, const [0xf3, 0x05, 0x03, 0x01, 0xfc]),
    ),
    EmulatedAction(
      'Shift down',
      run: () => session.notify(_thinkRiderCharacteristicUuid, const [0xf3, 0x05, 0x03, 0x00, 0xfb]),
    ),
  ],
);

// SRAM AXS — detected by advertised fe51; subscribed on the d905… trigger.
// Only the 1-byte 0xFF edge counts as a press (§6.1) — anything else is treated
// as a read-response echo and ignored. Without a bond the press stays undecoded
// and registers as the generic 'SRAM Button'.
const _sramAdvertisedServiceUuid = '0000fe51-0000-1000-8000-00805f9b34fb';
const _sramRelevantServiceUuid = 'd9050053-90aa-4c7c-b036-1e01fb8eb7ee';
const _sramTriggerUuid = 'd9050054-90aa-4c7c-b036-1e01fb8eb7ee';

final sramAxsProfile = EmulationProfile(
  name: 'SRAM AXS',
  category: EmulationCategory.controller,
  build: () {
    final peripheral = FakePeripheral(
      deviceId: 'emulated:sram-axs',
      name: 'SRAM AXS',
      advertisedServices: const [_sramAdvertisedServiceUuid],
    );
    peripheral.services.addAll([
      BleService(_sramRelevantServiceUuid, [
        bleChar(_sramTriggerUuid, [CharacteristicProperty.notify]),
      ]),
      ...deviceInfoServices(peripheral),
    ]);
    return peripheral;
  },
  inputs: (session) => [
    EmulatedAction('Tap', run: () => session.notify(_sramTriggerUuid, const [SramAxsConstants.triggerEdge])),
    EmulatedAction('Double tap', run: () {
      session.notify(_sramTriggerUuid, const [SramAxsConstants.triggerEdge]);
      // The delayed second edge is dropped by session.notify if the session
      // was stopped in the meantime.
      unawaited(
        Future<void>.delayed(
          const Duration(milliseconds: 100),
          () => session.notify(_sramTriggerUuid, const [SramAxsConstants.triggerEdge]),
        ),
      );
    }),
  ],
);

// OpenBikeControl — button-state notify + haptic/app-info write chars.
const _obcServiceUuid = 'd273f680-d548-419d-b9d1-fa0472345229';
const _obcButtonStateUuid = 'd273f681-d548-419d-b9d1-fa0472345229';
const _obcHapticUuid = 'd273f682-d548-419d-b9d1-fa0472345229';
const _obcAppInfoUuid = 'd273f683-d548-419d-b9d1-fa0472345229';

/// Button IDs from OpenBikeProtocolParser.BUTTON_NAMES (protocol_parser.dart:26-70).
const _obcButtons = <String, int>{
  'Shift Up': 0x01,
  'Shift Down': 0x02,
  'Up': 0x10,
  'Down': 0x11,
  'Select': 0x14,
  'Back': 0x15,
  'Menu': 0x16,
  'Home': 0x17,
  'Steer Left': 0x18,
  'Steer Right': 0x19,
};

final openBikeControlProfile = EmulationProfile(
  name: 'OpenBikeControl',
  category: EmulationCategory.controller,
  build: () {
    final peripheral = FakePeripheral(
      deviceId: 'emulated:openbikecontrol',
      name: 'OpenBike',
      advertisedServices: const [_obcServiceUuid],
    );
    peripheral.services.addAll([
      BleService(_obcServiceUuid, [
        bleChar(_obcButtonStateUuid, [CharacteristicProperty.notify]),
        bleChar(_obcHapticUuid, [CharacteristicProperty.write, CharacteristicProperty.writeWithoutResponse]),
        bleChar(_obcAppInfoUuid, [CharacteristicProperty.write, CharacteristicProperty.writeWithoutResponse]),
      ]),
      ...deviceInfoServices(peripheral),
    ]);
    return peripheral;
  },
  inputs: (session) => [
    for (final entry in _obcButtons.entries)
      EmulatedButton(
        entry.key,
        // [msgType 0x01, buttonId, state] — state 1 = pressed, 0 = released.
        onDown: () => session.notify(_obcButtonStateUuid, [0x01, entry.value, 0x01]),
        onUp: () => session.notify(_obcButtonStateUuid, [0x01, entry.value, 0x00]),
      ),
  ],
);

// Shimano Di2 — D-Fly channel bitmasks over indications; a fresh app-side
// device instance treats its first frame as baseline, so every press leads
// with one to guard against a mid-ride reconnect resetting that state.
const _di2DFlyChannelUuid = '00002ac2-5348-494d-414e-4f5f424c4500';

final shimanoDi2Profile = EmulationProfile(
  name: 'Shimano Di2',
  category: EmulationCategory.controller,
  build: () => buildShimanoDi2(deviceId: 'emulated:di2'),
  inputs: (session) {
    void send(List<int> channels) => session.notify(_di2DFlyChannelUuid, [0x00, ...channels]);
    List<int> single(int index, int value) => [for (var i = 0; i < 3; i++) i == index ? value : 0x00];

    return [
      for (var channel = 0; channel < 3; channel++)
        EmulatedButton(
          'D-Fly Channel ${channel + 1}',
          // A fresh ShimanoDi2 instance (built on every connect, including a
          // drop-connection/auto-reconnect) treats its first-ever frame as
          // baseline and swallows it — lead every press with the idle frame
          // so the press frame right after it always reads as a change.
          onDown: () {
            send(const [0x00, 0x00, 0x00]);
            send(single(channel, 0x10)); // 0x10 = short press
          },
          onUp: () => send(single(channel, 0x00)),
        ),
    ];
  },
);

// Heart rate strap — notifies heart rate measurement over the standard
// Heart Rate Service. Simulates a continuous stream of BPM readings.
final heartRateStrapProfile = EmulationProfile(
  name: 'Heart Rate Monitor',
  category: EmulationCategory.accessory,
  build: () => heartRateStrapPeripheral(),
  inputs: (session) => [
    EmulatedAction(
      'Notify 100 bpm',
      run: () => session.notify(BleSensorSource.heartRateMeasurementUuid, const [0x00, 100]),
    ),
    EmulatedAction(
      'Notify 140 bpm',
      run: () => session.notify(BleSensorSource.heartRateMeasurementUuid, const [0x00, 140]),
    ),
    EmulatedAction(
      'Notify 180 bpm',
      run: () => session.notify(BleSensorSource.heartRateMeasurementUuid, const [0x00, 180]),
    ),
  ],
);

// Cadence sensor — notifies crank revolution data over the standard Cycling
// Speed and Cadence Service. CSC reports a cumulative counter, not an
// instantaneous rpm (see CrankCounter's doc comment), so each action advances
// a counter shared across the session's presses and sends the resulting
// frame — the first press after (re)connecting only establishes a baseline
// and yields no cadence yet, exactly like a real sensor's first notification;
// the rpm shows up starting with the second press.
final cadenceSensorProfile = EmulationProfile(
  name: 'Cadence Sensor',
  category: EmulationCategory.accessory,
  build: () => cadenceSensorPeripheral(),
  inputs: (session) {
    final counter = CrankCounter();
    void notifyRpm(int rpm) {
      counter.advance(rpm);
      session.notify(
        BleSensorSource.cscMeasurementUuid,
        buildCscMeasurement(counter.revs, counter.eventTime1024),
      );
    }

    return [
      EmulatedAction('Notify 70 rpm', run: () => notifyRpm(70)),
      EmulatedAction('Notify 90 rpm', run: () => notifyRpm(90)),
      EmulatedAction('Notify 110 rpm', run: () => notifyRpm(110)),
    ];
  },
);

// Power meter — notifies instantaneous power plus the same crank revolution
// data the cadence sensor above uses (BlePowerDevice reads cadence from this
// characteristic's own crank sub-field, never a separate CSC service — see
// BleSensorSource.ingestCpsMeasurement). Same baseline caveat as the cadence
// sensor: the first press yields power only, cadence starts on the second.
final powerMeterProfile = EmulationProfile(
  name: 'Power Meter',
  category: EmulationCategory.accessory,
  build: () => powerMeterPeripheral(),
  inputs: (session) {
    final counter = CrankCounter();
    void notifyPower(int watts, int rpm) {
      counter.advance(rpm);
      session.notify(
        BleSensorSource.cyclingPowerMeasurementUuid,
        buildCyclingPowerMeasurement(watts, crankRevs: counter.revs, eventTime1024: counter.eventTime1024),
      );
    }

    return [
      EmulatedAction('Notify 150 W @ 80 rpm', run: () => notifyPower(150, 80)),
      EmulatedAction('Notify 250 W @ 90 rpm', run: () => notifyPower(250, 90)),
      EmulatedAction('Notify 300 W @ 100 rpm', run: () => notifyPower(300, 100)),
    ];
  },
);
