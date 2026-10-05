import 'package:prop/utils/wahoo_climb.dart';
import 'package:universal_ble/universal_ble.dart';

import '../emulated_ble_platform.dart';
import '../emulated_peripherals.dart';
import '../emulation_profile.dart';

// Kickr Bike Shift (detection is by NAME, no advertised service needed).
const _kickrShiftServiceUuid = 'a026ee0d-0a7d-4ab3-97fa-f1500f9feb8b';
const _kickrShiftCharacteristicUuid = 'a026e03c-0a7d-4ab3-97fa-f1500f9feb8b';

/// The Wahoo shifter characteristic, for tests that push button frames
/// straight through the fake platform.
const kickrShiftCharacteristicUuid = _kickrShiftCharacteristicUuid;

// Headwind.
const _headwindServiceUuid = 'a026ee0c-0a7d-4ab3-97fa-f1500f9feb8b';
const _headwindCharacteristicUuid = 'a026e038-0a7d-4ab3-97fa-f1500f9feb8b';

/// Button prefixes from WahooKickrBikeShift.prefixToButton
/// (wahoo_kickr_bike_shift.dart:115-128).
const _kickrShiftButtons = <String, int>{
  'Right up': 0x0001,
  'Right down': 0x8000,
  'Right steer': 0x0008,
  'Left up': 0x0200,
  'Left down': 0x0400,
  'Left steer': 0x2000,
  'Shift up right': 0x0004,
  'Shift down right': 0x0002,
  'Shift up left': 0x1000,
  'Shift down left': 0x0800,
  'Right brake': 0x4000,
  'Left brake': 0x0100,
};

int _kickrSeq = 0;

/// 3-byte Kickr Bike Shift frame: 16-bit button prefix, then a byte whose MSB
/// is the pressed flag and whose low 7 bits are a rolling dedupe sequence.
List<int> kickrBikeShiftFrame(int prefix, {required bool pressed}) {
  _kickrSeq = (_kickrSeq + 1) & 0x7f;
  return [(prefix >> 8) & 0xff, prefix & 0xff, (pressed ? 0x80 : 0x00) | _kickrSeq];
}

final wahooKickrBikeShiftProfile = EmulationProfile(
  name: 'Wahoo Kickr Bike Shift',
  category: EmulationCategory.controller,
  build: () {
    final peripheral = FakePeripheral(deviceId: 'emulated:kickr-bike-shift', name: 'KICKR BIKE SHIFT 1337');
    peripheral.services.addAll([
      BleService(_kickrShiftServiceUuid, [
        bleChar(_kickrShiftCharacteristicUuid, [CharacteristicProperty.notify]),
      ]),
      ...deviceInfoServices(peripheral),
    ]);
    return peripheral;
  },
  inputs: (session) => [
    for (final entry in _kickrShiftButtons.entries)
      EmulatedButton(
        entry.key,
        onDown: () =>
            session.notify(_kickrShiftCharacteristicUuid, kickrBikeShiftFrame(entry.value, pressed: true)),
        onUp: () =>
            session.notify(_kickrShiftCharacteristicUuid, kickrBikeShiftFrame(entry.value, pressed: false)),
      ),
  ],
);

/// A KICKR BIKE: one peripheral that is both a smart trainer (the FTMS +
/// Cycling Power GATT of [buildFtmsTrainer]) and the host of its own shifters
/// (the Wahoo shifter service). Detection is by NAME — the advertisement
/// carries no service UUIDs by default, so the trainer side has to be found
/// in the GATT database at connect time, not in the scan result.
///
/// [withTrainerServices] false leaves only the shifter service, i.e. a bike
/// that exposes no trainer service BikeControl can drive.
FakePeripheral buildKickrBike({
  String deviceId = 'emulated:kickr-bike',
  String name = 'KICKR BIKE 1337',
  bool withTrainerServices = true,
  List<String> advertisedServices = const [],
}) {
  final peripheral = withTrainerServices
      ? buildFtmsTrainer(deviceId: deviceId, name: name)
      : FakePeripheral(deviceId: deviceId, name: name);
  peripheral.advertisedServices
    ..clear()
    ..addAll(advertisedServices);
  if (!withTrainerServices) peripheral.services.addAll(deviceInfoServices(peripheral));
  peripheral.services.add(
    BleService(_kickrShiftServiceUuid, [
      bleChar(_kickrShiftCharacteristicUuid, [CharacteristicProperty.notify]),
    ]),
  );
  return peripheral;
}

final wahooKickrBikeProfile = EmulationProfile(
  name: 'Wahoo Kickr Bike (trainer + shifters)',
  category: EmulationCategory.controller,
  build: buildKickrBike,
  inputs: (session) => [
    for (final entry in _kickrShiftButtons.entries)
      EmulatedButton(
        entry.key,
        onDown: () =>
            session.notify(_kickrShiftCharacteristicUuid, kickrBikeShiftFrame(entry.value, pressed: true)),
        onUp: () =>
            session.notify(_kickrShiftCharacteristicUuid, kickrBikeShiftFrame(entry.value, pressed: false)),
      ),
  ],
);

final wahooKickrClimbProfile = EmulationProfile(
  name: 'Wahoo Kickr Climb',
  category: EmulationCategory.accessory,
  build: () {
    final peripheral = FakePeripheral(
      deviceId: 'emulated:kickr-climb',
      name: 'KICKR CLIMB 1337',
      advertisedServices: [lcUuid(wahooClimbServiceUuid)],
    );
    peripheral.services.addAll([
      BleService(lcUuid(wahooClimbServiceUuid), [
        bleChar(wahooClimbCharacteristicUuid, [
          CharacteristicProperty.notify,
          CharacteristicProperty.write,
          CharacteristicProperty.writeWithoutResponse,
        ]),
      ]),
      ...deviceInfoServices(peripheral),
    ]);
    return peripheral;
  },
  decodeWrite: (characteristicUuid, value) {
    if (characteristicUuid != lcUuid(wahooClimbCharacteristicUuid)) return null;
    if (value.length == 1 && value[0] == wahooClimbRequestControlOpcode) return 'Request control';
    if (value.length == 3 && value[0] == wahooClimbSetInclineOpcode) {
      var grade001 = value[1] | (value[2] << 8);
      if (grade001 >= 0x8000) grade001 -= 0x10000;
      return 'Set incline ${(grade001 / 100).toStringAsFixed(1)}%';
    }
    return null;
  },
);

final wahooKickrHeadwindProfile = EmulationProfile(
  name: 'Wahoo Kickr Headwind',
  category: EmulationCategory.accessory,
  build: () {
    final peripheral = FakePeripheral(
      deviceId: 'emulated:kickr-headwind',
      name: 'HEADWIND 1337',
      advertisedServices: const [_headwindServiceUuid],
    );
    peripheral.services.addAll([
      BleService(_headwindServiceUuid, [
        bleChar(_headwindCharacteristicUuid, [
          CharacteristicProperty.notify,
          CharacteristicProperty.write,
          CharacteristicProperty.writeWithoutResponse,
        ]),
      ]),
      ...deviceInfoServices(peripheral),
    ]);
    return peripheral;
  },
  // Echo a status frame [0xFD, 0x01, speed, mode] so the app's mode tracking
  // behaves like the real fan (otherwise it re-sends manual mode every time).
  onRegistered: (ble, peripheral) {
    var speed = 0;
    peripheral.onWrite = (service, characteristic, value) {
      if (characteristic.toLowerCase() != _headwindCharacteristicUuid || value.length < 2) return;
      if (value[0] == 0x02) {
        speed = value[1];
        ble.notify(peripheral.deviceId, _headwindCharacteristicUuid, [0xfd, 0x01, speed, 0x04]);
      } else if (value[0] == 0x04) {
        ble.notify(peripheral.deviceId, _headwindCharacteristicUuid, [0xfd, 0x01, speed, value[1]]);
      }
    };
  },
  decodeWrite: (characteristicUuid, value) {
    if (characteristicUuid != _headwindCharacteristicUuid || value.length < 2) return null;
    if (value[0] == 0x04 && value[1] == 0x04) return 'Manual mode';
    if (value[0] == 0x04 && value[1] == 0x02) return 'Heart-rate mode';
    if (value[0] == 0x02) return 'Fan speed ${value[1]}%';
    return null;
  },
);
