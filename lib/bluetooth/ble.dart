import 'package:flutter/services.dart';
import 'package:swift_control/utils/keymap/buttons.dart';

class BleUuid {
  static final DEVICE_INFORMATION_SERVICE_UUID = "0000180a-0000-1000-8000-00805f9b34fb".toLowerCase();
  static final DEVICE_INFORMATION_CHARACTERISTIC_FIRMWARE_REVISION = "00002a26-0000-1000-8000-00805f9b34fb"
      .toLowerCase();

  static final DEVICE_BATTERY_SERVICE_UUID = "0000180f-0000-1000-8000-00805f9b34fb".toLowerCase();
  static final DEVICE_INFORMATION_CHARACTERISTIC_BATTERY_LEVEL = "00002a19-0000-1000-8000-00805f9b34fb".toLowerCase();
  static final ZWIFT_CUSTOM_SERVICE_UUID = "00000001-19CA-4651-86E5-FA29DCDD09D1".toLowerCase();
  static final ZWIFT_RIDE_CUSTOM_SERVICE_UUID = "0000fc82-0000-1000-8000-00805f9b34fb".toLowerCase();
  static final ZWIFT_ASYNC_CHARACTERISTIC_UUID = "00000002-19CA-4651-86E5-FA29DCDD09D1".toLowerCase();
  static final ZWIFT_SYNC_RX_CHARACTERISTIC_UUID = "00000003-19CA-4651-86E5-FA29DCDD09D1".toLowerCase();
  static final ZWIFT_SYNC_TX_CHARACTERISTIC_UUID = "00000004-19CA-4651-86E5-FA29DCDD09D1".toLowerCase();
}

class SquareConstants {
  static const String DEVICE_NAME = "SQUARE";
  static const String CHARACTERISTIC_UUID = "347b0043-7635-408b-8918-8ff3949ce592";
  static const String SERVICE_UUID = "347b0001-7635-408b-8918-8ff3949ce592";
  static const int RECONNECT_DELAY = 5; // seconds between reconnection attempts

  // Button mapping https://images.bike24.com/i/mb/c7/36/d9/elite-square-smart-frame-indoor-bike-3-1724305.jpg
  static const Map<String, ControllerButton> BUTTON_MAPPING = {
    "00000200": ControllerButton.navigationUp, //"Up",
    "00000100": ControllerButton.navigationLeft, //"Left",
    "00000800": ControllerButton.navigationDown, // "Down",
    "00000400": ControllerButton.navigationRight, //"Right",
    "00002000": ControllerButton.powerUpLeft, //"X",
    "00001000": ControllerButton.sideButtonLeft, // "Square",
    "00008000": ControllerButton.campagnoloLeft, // "Left Campagnolo",
    "00004000": ControllerButton.onOffLeft, //"Left brake",
    "00000002": ControllerButton.shiftDownLeft, //"Left shift 1",
    "00000001": ControllerButton.paddleLeft, // "Left shift 2",
    "02000000": ControllerButton.y, // "Y",
    "01000000": ControllerButton.a, //"A",
    "08000000": ControllerButton.b, // "B",
    "04000000": ControllerButton.z, // "Z",
    "20000000": ControllerButton.powerUpRight, // "Circle",
    "10000000": ControllerButton.sideButtonRight, //"Triangle",
    "80000000": ControllerButton.campagnoloRight, // "Right Campagnolo",
    "40000000": ControllerButton.onOffRight, //"Right brake",
    "00020000": ControllerButton.sideButtonRight, //"Right shift 1",
    "00010000": ControllerButton.paddleRight, //"Right shift 2",
  };

  // Key mapping for button presses
  static const Map<String, LogicalKeyboardKey> KEY_MAPPING = {
    "Up": LogicalKeyboardKey.arrowUp,
    "Left": LogicalKeyboardKey.arrowLeft,
    "Down": LogicalKeyboardKey.arrowDown,
    "Right": LogicalKeyboardKey.arrowRight,
    "Square": LogicalKeyboardKey.keyR,
    "Left Campagnolo": LogicalKeyboardKey.arrowLeft,
    "Left brake": LogicalKeyboardKey.digit6,
    "Y": LogicalKeyboardKey.keyG,
    "A": LogicalKeyboardKey.enter,
    "B": LogicalKeyboardKey.escape,
    "Z": LogicalKeyboardKey.keyT,
    "Triangle": LogicalKeyboardKey.space,
    "Right Campagnolo": LogicalKeyboardKey.arrowRight,
    "Right brake": LogicalKeyboardKey.digit1,
  };
}

class Constants {
  static const ZWIFT_MANUFACTURER_ID = 2378; // Zwift, Inc => 0x094A

  // Zwift Play = RC1
  static const RC1_LEFT_SIDE = 0x03;
  static const RC1_RIGHT_SIDE = 0x02;

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
  static final REQUEST_START = Uint8List.fromList([0, 9]); //byteArrayOf(1, 2)
  static final RESPONSE_START_CLICK = Uint8List.fromList([1, 3]); // from device
  static final RESPONSE_START_PLAY = Uint8List.fromList([1, 4]); // from device
  static final RESPONSE_START_CLICK_V2 = Uint8List.fromList([0x02, 0x03]); // from device
  static final RESPONSE_STOPPED_CLICK_V2 = Uint8List.fromList([
    0xff,
    0x05,
    0x00,
    0xea,
    0x05,
    0x19,
    0x0a,
    0x0c,
    0x35,
    0x38,
    0x44,
    0x31,
    0x35,
    0x41,
    0x42,
    0x42,
    0x34,
    0x33,
    0x36,
    0x33,
    0x10,
    0x01,
    0x18,
    0x84,
    0x07,
    0x20,
    0x08,
    0x28,
    0x09,
    0x30,
  ]); // from device

  // Message types received from device
  static const CONTROLLER_NOTIFICATION_MESSAGE_TYPE = 07;
  static const EMPTY_MESSAGE_TYPE = 21;
  static const BATTERY_LEVEL_TYPE = 25;
  static const UNKNOWN_CLICKV2_TYPE = 0x3C;

  // not figured out the protobuf type this really is, the content is just two varints.
  static const int CLICK_NOTIFICATION_MESSAGE_TYPE = 55;
  static const int PLAY_NOTIFICATION_MESSAGE_TYPE = 7;
  static const int RIDE_NOTIFICATION_MESSAGE_TYPE = 35; // 0x23

  // see this if connected to Core then Zwift connects to it. just one byte
  static const DISCONNECT_MESSAGE_TYPE = 0xFE;
}

enum DeviceType {
  click,
  clickV2Right,
  clickV2Left,
  playLeft,
  playRight,
  rideRight,
  rideLeft;

  @override
  String toString() {
    return super.toString().split('.').last;
  }

  // add constructor
  static DeviceType? fromManufacturerData(int data) {
    switch (data) {
      case Constants.BC1:
        return DeviceType.click;
      case Constants.CLICK_V2_RIGHT_SIDE:
        return DeviceType.clickV2Right;
      case Constants.CLICK_V2_LEFT_SIDE:
        return DeviceType.clickV2Left;
      case Constants.RC1_LEFT_SIDE:
        return DeviceType.playLeft;
      case Constants.RC1_RIGHT_SIDE:
        return DeviceType.playRight;
      case Constants.RIDE_RIGHT_SIDE:
        return DeviceType.rideRight;
      case Constants.RIDE_LEFT_SIDE:
        return DeviceType.rideLeft;
    }
    return null;
  }
}
