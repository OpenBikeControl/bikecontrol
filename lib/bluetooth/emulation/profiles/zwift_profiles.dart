import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart' show RideButtonMask;
import 'package:prop/prop.dart' hide RideButtonMask;
import 'package:universal_ble/universal_ble.dart';

import '../emulated_ble_platform.dart';
import '../emulated_peripherals.dart';
import '../emulation_manager.dart';
import '../emulation_profile.dart';

void _clickFrame(EmulationSession session, {required bool plus, required bool minus}) {
  session.notify(
    ZwiftConstants.ZWIFT_ASYNC_CHARACTERISTIC_UUID,
    zwiftClickNotification(plusPressed: plus, minusPressed: minus),
  );
}

final zwiftClickProfile = EmulationProfile(
  name: 'Zwift Click',
  category: EmulationCategory.controller,
  build: () => buildZwiftClick(deviceId: 'emulated:zwift-click'),
  onRegistered: autoRespondToZwiftHandshake,
  inputs: (session) => [
    EmulatedButton(
      'Shift Up (+)',
      onDown: () => _clickFrame(session, plus: true, minus: false),
      onUp: () => _clickFrame(session, plus: false, minus: false),
    ),
    EmulatedButton(
      'Shift Down (−)',
      onDown: () => _clickFrame(session, plus: false, minus: true),
      onUp: () => _clickFrame(session, plus: false, minus: false),
    ),
  ],
);

/// Ride-protocol press/release inputs, one per app-side [RideButtonMask] bit.
/// Shared by every device speaking the Ride protobuf (Ride, Click V2 sides,
/// Play FW2).
List<EmulatedInput> rideMaskInputs(EmulationSession session, List<RideButtonMask> masks) {
  void send(List<RideButtonMask> pressed) {
    session.notify(ZwiftConstants.ZWIFT_ASYNC_CHARACTERISTIC_UUID, zwiftRideNotification(pressed: pressed));
  }

  return [
    for (final mask in masks)
      EmulatedButton(mask.name, onDown: () => send([mask]), onUp: () => send(const [])),
  ];
}

/// Inputs for a Ride-protocol device's analog paddles, both directions of
/// each. The release sends the paddle back at 0.
List<EmulatedInput> ridePaddleInputs(EmulationSession session) {
  void send(RideAnalogLocation location, int value) {
    session.notify(
      ZwiftConstants.ZWIFT_ASYNC_CHARACTERISTIC_UUID,
      zwiftRideNotification(paddles: {location: value}),
    );
  }

  return [
    for (final location in [RideAnalogLocation.LEFT, RideAnalogLocation.RIGHT])
      for (final inward in [true, false])
        EmulatedButton(
          '${location == RideAnalogLocation.LEFT ? 'Left' : 'Right'} paddle ${inward ? 'inward' : 'outward'}',
          onDown: () => send(location, ZwiftPaddle.value(right: location == RideAnalogLocation.RIGHT, inward: inward)),
          onUp: () => send(location, 0),
        ),
  ];
}

final zwiftRideProfile = EmulationProfile(
  name: 'Zwift Ride',
  category: EmulationCategory.controller,
  build: () => buildZwiftRide(deviceId: 'emulated:zwift-ride'),
  onRegistered: (ble, peripheral) =>
      autoRespondToZwiftHandshake(ble, peripheral, startResponse: ZwiftConstants.RESPONSE_START_PLAY),
  inputs: (session) => [...rideMaskInputs(session, RideButtonMask.values), ...ridePaddleInputs(session)],
);

/// Generic Zwift-controller peripheral: custom service with async / syncTx /
/// syncRx, plus optional extra writable characteristics (Click V2 unlock).
FakePeripheral buildZwiftController({
  required String deviceId,
  required String name,
  required int manufacturerType,
  List<String> extraCharacteristicUuids = const [],
}) {
  final peripheral = FakePeripheral(
    deviceId: deviceId,
    name: name,
    advertisedServices: [lcUuid(ZwiftConstants.ZWIFT_CUSTOM_SERVICE_UUID)],
    manufacturerData: ManufacturerData(
      ZwiftConstants.ZWIFT_MANUFACTURER_ID,
      Uint8List.fromList([manufacturerType]),
    ),
  );
  peripheral.services.addAll([
    BleService(lcUuid(ZwiftConstants.ZWIFT_CUSTOM_SERVICE_UUID), [
      bleChar(ZwiftConstants.ZWIFT_ASYNC_CHARACTERISTIC_UUID, [CharacteristicProperty.notify]),
      bleChar(ZwiftConstants.ZWIFT_SYNC_TX_CHARACTERISTIC_UUID, [CharacteristicProperty.indicate]),
      bleChar(ZwiftConstants.ZWIFT_SYNC_RX_CHARACTERISTIC_UUID, [
        CharacteristicProperty.write,
        CharacteristicProperty.writeWithoutResponse,
      ]),
      for (final uuid in extraCharacteristicUuids)
        bleChar(uuid, [CharacteristicProperty.write, CharacteristicProperty.writeWithoutResponse]),
    ]),
    ...deviceInfoServices(peripheral, firmware: '1.3.0'),
  ]);
  return peripheral;
}

/// Encodes a Zwift Play keypad notification. ON (= pressed) is the protobuf
/// default, so every field is set explicitly — the all-OFF frame is the
/// release frame. [analogLR] of ±100 emulates a full paddle deflection.
List<int> zwiftPlayNotification({
  required bool rightPad,
  bool primary = false, // Y (right pad) / nav up (left pad)
  bool secondary = false, // Z / nav left
  bool tertiary = false, // A / nav right
  bool quaternary = false, // B / nav down
  bool shoulder = false, // side button
  bool onOff = false,
  int analogLR = 0,
}) {
  PlayButtonStatus s(bool pressed) => pressed ? PlayButtonStatus.ON : PlayButtonStatus.OFF;
  final status = PlayKeyPadStatus(
    rightPad: s(rightPad),
    buttonYUp: s(primary),
    buttonZLeft: s(secondary),
    buttonARight: s(tertiary),
    buttonBDown: s(quaternary),
    buttonShift: s(shoulder),
    buttonOn: s(onOff),
    analogLR: analogLR,
    analogUD: 0,
  );
  return [ZwiftConstants.PLAY_NOTIFICATION_MESSAGE_TYPE, ...status.writeToBuffer()];
}

EmulationProfile _zwiftPlayProfile({required bool right}) {
  final side = right ? 'right' : 'left';
  return EmulationProfile(
    name: 'Zwift Play ($side)',
    category: EmulationCategory.controller,
    build: () => buildZwiftController(
      deviceId: 'emulated:zwift-play-$side',
      name: 'Zwift Play',
      manufacturerType: right ? ZwiftConstants.RC1_RIGHT_SIDE : ZwiftConstants.RC1_LEFT_SIDE,
    ),
    onRegistered: (ble, peripheral) =>
        autoRespondToZwiftHandshake(ble, peripheral, startResponse: ZwiftConstants.RESPONSE_START_PLAY),
    inputs: (session) {
      void send({
        bool primary = false,
        bool secondary = false,
        bool tertiary = false,
        bool quaternary = false,
        bool shoulder = false,
        bool onOff = false,
        int analogLR = 0,
      }) {
        session.notify(
          ZwiftConstants.ZWIFT_ASYNC_CHARACTERISTIC_UUID,
          zwiftPlayNotification(
            rightPad: right,
            primary: primary,
            secondary: secondary,
            tertiary: tertiary,
            quaternary: quaternary,
            shoulder: shoulder,
            onOff: onOff,
            analogLR: analogLR,
          ),
        );
      }

      EmulatedButton button(String label, void Function() down) =>
          EmulatedButton(label, onDown: down, onUp: () => send());

      return [
        button(right ? 'Y' : 'Nav Up', () => send(primary: true)),
        button(right ? 'Z' : 'Nav Left', () => send(secondary: true)),
        button(right ? 'A' : 'Nav Right', () => send(tertiary: true)),
        button(right ? 'B' : 'Nav Down', () => send(quaternary: true)),
        button('Side button', () => send(shoulder: true)),
        button('On/Off', () => send(onOff: true)),
        button('Paddle inward', () => send(analogLR: ZwiftPaddle.value(right: right, inward: true))),
        button('Paddle outward', () => send(analogLR: ZwiftPaddle.value(right: right, inward: false))),
      ];
    },
  );
}

final zwiftPlayLeftProfile = _zwiftPlayProfile(right: false);
final zwiftPlayRightProfile = _zwiftPlayProfile(right: true);

final zwiftPlayFw2Profile = EmulationProfile(
  name: 'Zwift Play (FW2)',
  category: EmulationCategory.controller,
  build: () => buildZwiftController(
    deviceId: 'emulated:zwift-play-fw2',
    name: 'Zwift Play',
    manufacturerType: ZwiftConstants.RC1_FW2,
  ),
  onRegistered: autoRespondToZwiftHandshake,
  inputs: (session) => [...rideMaskInputs(session, RideButtonMask.values), ...ridePaddleInputs(session)],
);

const _clickV2UnlockCharacteristics = [
  '00000100-19ca-4651-86e5-fa29dcdd09d1',
  '00000101-19ca-4651-86e5-fa29dcdd09d1',
];

final zwiftClickV2LeftProfile = EmulationProfile(
  name: 'Zwift Click V2 (left)',
  category: EmulationCategory.controller,
  build: () => buildZwiftController(
    deviceId: 'emulated:zwift-clickv2-left',
    name: 'Zwift Click',
    manufacturerType: ZwiftConstants.CLICK_V2_LEFT_SIDE,
    extraCharacteristicUuids: _clickV2UnlockCharacteristics,
  ),
  onRegistered: (ble, peripheral) =>
      autoRespondToZwiftHandshake(ble, peripheral, startResponse: ZwiftConstants.RESPONSE_START_CLICK_V2),
  inputs: (session) => rideMaskInputs(session, [
    RideButtonMask.UP_BTN,
    RideButtonMask.DOWN_BTN,
    RideButtonMask.LEFT_BTN,
    RideButtonMask.RIGHT_BTN,
    RideButtonMask.SHFT_UP_L_BTN,
  ]),
);

final zwiftClickV2RightProfile = EmulationProfile(
  name: 'Zwift Click V2 (right)',
  category: EmulationCategory.controller,
  build: () => buildZwiftController(
    deviceId: 'emulated:zwift-clickv2-right',
    name: 'Zwift Click',
    manufacturerType: ZwiftConstants.CLICK_V2_RIGHT_SIDE,
    extraCharacteristicUuids: _clickV2UnlockCharacteristics,
  ),
  onRegistered: (ble, peripheral) =>
      autoRespondToZwiftHandshake(ble, peripheral, startResponse: ZwiftConstants.RESPONSE_START_CLICK_V2),
  inputs: (session) => rideMaskInputs(session, [
    RideButtonMask.A_BTN,
    RideButtonMask.B_BTN,
    RideButtonMask.Y_BTN,
    RideButtonMask.Z_BTN,
    RideButtonMask.SHFT_UP_R_BTN,
  ]),
);
