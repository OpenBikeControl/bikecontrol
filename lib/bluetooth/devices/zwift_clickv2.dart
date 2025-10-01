import 'dart:typed_data';

import 'package:swift_control/bluetooth/devices/zwift_ride.dart';
import 'package:swift_control/bluetooth/protocol/zp.pb.dart';

import '../ble.dart';

class ZwiftClickV2 extends ZwiftRide {
  ZwiftClickV2(super.scanResult);

  @override
  bool get supportsEncryption => false;

  @override
  List<int> get startCommand => Constants.RIDE_ON + Constants.RESPONSE_START_CLICK_V2;

  @override
  Future<void> setupHandshake() async {
    super.setupHandshake();
    await sendCommandBuffer(Uint8List.fromList([0xFF, 0x04, 0x00]));
  }

  Future<void> test() async {
    await sendCommand(Opcode.RESET, null);
    //await sendCommand(Opcode.GET, Get(dataObjectId: VendorDO.PAGE_DEVICE_PAIRING.value)); // 0008 82E0 03

    /*await sendCommand(Opcode.GET, Get(dataObjectId: DO.PAGE_DEV_INFO.value)); // 0008 00
    await sendCommand(Opcode.LOG_LEVEL_SET, LogLevelSet(logLevel: LogLevel.LOGLEVEL_TRACE)); // 4108 05

    await sendCommand(Opcode.GET, Get(dataObjectId: DO.PAGE_CLIENT_SERVER_CONFIGURATION.value)); // 0008 10
    await sendCommand(Opcode.GET, Get(dataObjectId: DO.PAGE_CLIENT_SERVER_CONFIGURATION.value)); // 0008 10
    await sendCommand(Opcode.GET, Get(dataObjectId: DO.PAGE_CLIENT_SERVER_CONFIGURATION.value)); // 0008 10

    await sendCommand(Opcode.GET, Get(dataObjectId: DO.PAGE_CONTROLLER_INPUT_CONFIG.value)); // 0008 80 08

    await sendCommand(Opcode.GET, Get(dataObjectId: DO.BATTERY_STATE.value)); // 0008 83 06

    // 	Value: FF04 000A 1540 E9D9 C96B 7463 C27F 1B4E 4D9F 1CB1 205D 882E D7CE
    // 	Value: FF04 000A 15B2 6324 0A31 D6C6 B81F C129 D6A4 E99D FFFC B9FC 418D
    await sendCommandBuffer(
      Uint8List.fromList([
        0xFF,
        0x04,
        0x00,
        0x0A,
        0x15,
        0x40,
        0xE9,
        0xD9,
        0xC9,
        0x6B,
        0x74,
        0x63,
        0xC2,
        0x7F,
        0x1B,
        0x4E,
        0x4D,
        0x9F,
        0x1C,
        0xB1,
        0x20,
        0x5D,
        0x88,
        0x2E,
        0xD7,
        0xCE,
      ]),
    );*/
  }
}
