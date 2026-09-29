import 'dart:typed_data';

import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' show LucideIcons;

class ZwiftConstants {
  static const ZWIFT_CUSTOM_SERVICE_UUID = "00000001-19CA-4651-86E5-FA29DCDD09D1";
  static const ZWIFT_CUSTOM_SERVICE_SHORT_UUID = "0001";
  static const ZWIFT_RIDE_CUSTOM_SERVICE_UUID = "0000fc82-0000-1000-8000-00805f9b34fb";
  static const ZWIFT_RIDE_CUSTOM_SERVICE_UUID_SHORT = "fc82";
  static const ZWIFT_ASYNC_CHARACTERISTIC_UUID = "00000002-19CA-4651-86E5-FA29DCDD09D1";
  static const ZWIFT_SYNC_RX_CHARACTERISTIC_UUID = "00000003-19CA-4651-86E5-FA29DCDD09D1";
  static const ZWIFT_SYNC_TX_CHARACTERISTIC_UUID = "00000004-19CA-4651-86E5-FA29DCDD09D1";

  static const ZWIFT_MANUFACTURER_ID = 2378; // Zwift, Inc => 0x094A

  /// Controller firmware can only be updated through the Zwift Companion app.
  /// The landing page localizes itself and forwards to the right app store.
  static const ZWIFT_COMPANION_URL = "https://www.zwift.com/companion";

  // Zwift Play = RC1
  static const RC1_LEFT_SIDE = 0x03;
  static const RC1_RIGHT_SIDE = 0x02;
  static const RC1_FW2 = 0x0E;

  // Zwift Ride
  static const RIDE_RIGHT_SIDE = 0x07;
  static const RIDE_LEFT_SIDE = 0x08;

  // Zwift Click = BC1
  static const BC1 = 0x09;

  // Zwift Click v2 Right (unconfirmed)
  static const CLICK_V2_RIGHT_SIDE = 0x0A;
  // Zwift Click v2 Right (unconfirmed)
  static const CLICK_V2_LEFT_SIDE = 0x0B;

  static final RIDE_ON = Uint8List.fromList([0x52, 0x69, 0x64, 0x65, 0x4f, 0x6e]);
  static final VIBRATE_PATTERN = Uint8List.fromList([0x12, 0x12, 0x08, 0x0A, 0x06, 0x08, 0x02, 0x10, 0x00, 0x18]);

  // these don't actually seem to matter, its just the header has to be 7 bytes RIDEON + 2
  static final REQUEST_START = Uint8List.fromList([0x00, 0x09]); //byteArrayOf(1, 2)
  static final RESPONSE_START_CLICK = Uint8List.fromList([0x01, 0x03]); // from device
  static final RESPONSE_START_PLAY = Uint8List.fromList([0x01, 0x04]); // from device
  static final RESPONSE_START_CLICK_V2 = Uint8List.fromList([0x02, 0x03]); // from device
  static final RESPONSE_STOPPED_CLICK_V2_VARIANT_1 = Uint8List.fromList([0xff, 0x05, 0x00, 0xea, 0x05]); // from device
  static final RESPONSE_STOPPED_CLICK_V2_VARIANT_2 = Uint8List.fromList([0xff, 0x05, 0x00, 0xfa, 0x05]); // from device

  // Message types received from device
  static const CONTROLLER_NOTIFICATION_MESSAGE_TYPE = 07;
  static const EMPTY_MESSAGE_TYPE = 21; // 0x15
  static const BATTERY_LEVEL_TYPE = 25;
  static const UNKNOWN_CLICKV2_TYPE = 0x3C;

  // not figured out the protobuf type this really is, the content is just two varints.
  static const int CLICK_NOTIFICATION_MESSAGE_TYPE = 55; // 0x37
  static const int PLAY_NOTIFICATION_MESSAGE_TYPE = 7;
  static const int RIDE_NOTIFICATION_MESSAGE_TYPE = 35; // 0x23

  // see this if connected to Core then Zwift connects to it. just one byte
  static const DISCONNECT_MESSAGE_TYPE = 0xFE;
}

class ZwiftButtons {
  // left controller. The pod shows the side, so the labels don't: "P", not "P←".
  static const ControllerButton navigationUp = ControllerButton(
    'navigationUp',
    action: InGameAction.up,
    icon: LucideIcons.chevronUp,
    color: Colors.black,
  );
  static const ControllerButton navigationDown = ControllerButton(
    'navigationDown',
    action: InGameAction.down,
    icon: LucideIcons.chevronDown,
    color: Colors.black,
  );
  static const ControllerButton navigationLeft = ControllerButton(
    'navigationLeft',
    action: InGameAction.steerLeft,
    icon: LucideIcons.chevronLeft,
    color: Colors.black,
  );
  static const ControllerButton navigationRight = ControllerButton(
    'navigationRight',
    action: InGameAction.steerRight,
    icon: LucideIcons.chevronRight,
    color: Colors.black,
  );
  static const ControllerButton onOffLeft = ControllerButton(
    'onOffLeft',
    action: InGameAction.toggleUi,
    icon: LucideIcons.power,
  );
  static const ControllerButton sideButtonLeft = ControllerButton(
    'sideButtonLeft',
    action: InGameAction.shiftDown,
    label: 'SB',
  );
  static const ControllerButton paddleLeft = ControllerButton('paddleLeft', action: InGameAction.shiftDown, label: 'P');

  // zwift ride only
  static const ControllerButton shiftUpLeft = ControllerButton(
    'shiftUpLeft',
    action: InGameAction.shiftDown,
    icon: LucideIcons.minus,
    color: Colors.black,
  );
  static const ControllerButton shiftDownLeft = ControllerButton(
    'shiftDownLeft',
    action: InGameAction.shiftDown,
    label: 'SD',
  );
  static const ControllerButton powerUpLeft = ControllerButton(
    'powerUpLeft',
    action: InGameAction.shiftDown,
    icon: LucideIcons.zap,
  );

  // right controller
  static const ControllerButton a = ControllerButton('a', action: InGameAction.select, color: Colors.lightGreen);
  static const ControllerButton b = ControllerButton('b', action: InGameAction.back, color: Colors.pinkAccent);
  static const ControllerButton z = ControllerButton(
    'z',
    action: InGameAction.rideOnBomb,
    color: Colors.deepOrangeAccent,
  );
  static const ControllerButton y = ControllerButton('y', action: InGameAction.menu, color: Colors.lightBlue);
  static const ControllerButton onOffRight = ControllerButton(
    'onOffRight',
    action: InGameAction.toggleUi,
    icon: LucideIcons.power,
  );
  static const ControllerButton sideButtonRight = ControllerButton(
    'sideButtonRight',
    action: InGameAction.shiftUp,
    label: 'SB',
  );
  static const ControllerButton paddleRight = ControllerButton('paddleRight', action: InGameAction.shiftUp, label: 'P');

  // zwift ride only
  static const ControllerButton shiftUpRight = ControllerButton(
    'shiftUpRight',
    action: InGameAction.shiftUp,
    icon: LucideIcons.plus,
    color: Colors.black,
  );
  static const ControllerButton shiftDownRight = ControllerButton(
    'shiftDownRight',
    action: InGameAction.shiftUp,
    label: 'SD',
  );
  static const ControllerButton powerUpRight = ControllerButton(
    'powerUpRight',
    action: InGameAction.shiftUp,
    icon: LucideIcons.zap,
  );

  static List<ControllerButton> get values => [
    // left
    navigationUp,
    navigationDown,
    navigationLeft,
    navigationRight,
    onOffLeft,
    sideButtonLeft,
    paddleLeft,
    shiftUpLeft,
    shiftDownLeft,
    powerUpLeft,
    // right
    a,
    b,
    z,
    y,
    onOffRight,
    sideButtonRight,
    paddleRight,
    shiftUpRight,
    shiftDownRight,
    powerUpRight,
  ];
}

enum ZwiftDeviceType {
  click,
  clickV2Right,
  clickV2Left,
  playLeft,
  playRight,
  playFw2,
  rideRight,
  rideLeft;

  @override
  String toString() {
    return super.toString().split('.').last;
  }

  // add constructor
  static ZwiftDeviceType? fromManufacturerData(int data) {
    switch (data) {
      case ZwiftConstants.BC1:
        return ZwiftDeviceType.click;
      case ZwiftConstants.CLICK_V2_RIGHT_SIDE:
        return ZwiftDeviceType.clickV2Right;
      case ZwiftConstants.CLICK_V2_LEFT_SIDE:
        return ZwiftDeviceType.clickV2Left;
      case ZwiftConstants.RC1_LEFT_SIDE:
        return ZwiftDeviceType.playLeft;
      case ZwiftConstants.RC1_RIGHT_SIDE:
        return ZwiftDeviceType.playRight;
      case ZwiftConstants.RIDE_RIGHT_SIDE:
        return ZwiftDeviceType.rideRight;
      case ZwiftConstants.RIDE_LEFT_SIDE:
        return ZwiftDeviceType.rideLeft;
      case ZwiftConstants.RC1_FW2:
        return ZwiftDeviceType.playFw2;
    }
    return null;
  }
}
