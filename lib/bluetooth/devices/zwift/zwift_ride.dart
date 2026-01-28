import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_device.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/prop.dart';
import 'package:protobuf/protobuf.dart' as $pb;
import 'package:universal_ble/universal_ble.dart';

class ZwiftRide extends ZwiftDevice {
  /// Minimum absolute analog value (0-100) required to trigger paddle button press.
  /// Values below this threshold are ignored to prevent accidental triggers from
  /// analog drift or light touches.
  static const int analogPaddleThreshold = 25;

  ZwiftRide(super.scanResult, {super.isBeta, List<ControllerButton>? availableButtons})
    : super(
        availableButtons:
            availableButtons ??
            [
              ZwiftButtons.navigationLeft,
              ZwiftButtons.navigationRight,
              ZwiftButtons.navigationUp,
              ZwiftButtons.navigationDown,
              ZwiftButtons.a,
              ZwiftButtons.b,
              ZwiftButtons.y,
              ZwiftButtons.z,
              ZwiftButtons.shiftUpLeft,
              ZwiftButtons.shiftDownLeft,
              ZwiftButtons.shiftUpRight,
              ZwiftButtons.shiftDownRight,
              ZwiftButtons.powerUpLeft,
              ZwiftButtons.powerUpRight,
              ZwiftButtons.onOffLeft,
              ZwiftButtons.onOffRight,
              ZwiftButtons.paddleLeft,
              ZwiftButtons.paddleRight,
            ],
      );

  @override
  String get latestFirmwareVersion => '1.2.0';

  @override
  bool get canVibrate => true;

  @override
  Future<void> processData(Uint8List bytes) async {
    Opcode? opcode = Opcode.valueOf(bytes[0]);
    Uint8List message = bytes.sublist(1);

    if (kDebugMode) {
      print(
        '${DateTime.now().toString().split(" ").last} Received $opcode: ${bytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}',
      );
    }

    switch (opcode) {
      case Opcode.RIDE_ON:
        //print("Empty RideOn response - unencrypted mode");

        break;
      case Opcode.STATUS_RESPONSE:
        final status = StatusResponse.fromBuffer(message);
        if (kDebugMode) {
          print('StatusResponse: ${status.command} status: ${Status.valueOf(status.status)}');
        }
        break;
      case Opcode.GET_RESPONSE:
        final response = GetResponse.fromBuffer(message);
        final dataObjectType = DO.valueOf(response.dataObjectId);
        if (kDebugMode) {
          print(
            'GetResponse: ${dataObjectType?.value.toRadixString(16).padLeft(4, '0') ?? response.dataObjectId} $dataObjectType',
          );
        }

        switch (dataObjectType) {
          case DO.PAGE_DEV_INFO:
            final pageDevInfo = DevInfoPage.fromBuffer(response.dataObjectData);
            if (kDebugMode) {
              print('PageDevInfo: $pageDevInfo');
            }
            break;
          case DO.PAGE_DATE_TIME:
            final pageDateTime = DateTimePage.fromBuffer(response.dataObjectData);
            if (kDebugMode) {
              print('PageDateTime: $pageDateTime');
            }
            break;
          case DO.PAGE_CONTROLLER_INPUT_CONFIG:
            final pageDateTime = ControllerInputConfigPage.fromBuffer(response.dataObjectData);
            if (kDebugMode) {
              print('PageDateTime: $pageDateTime');
            }
            break;
          case null:
            final vendorDO = VendorDO.valueOf(response.dataObjectId);
            if (kDebugMode) {
              print('VendorDO: $vendorDO');
            }
            switch (vendorDO) {
              case VendorDO.DEVICE_COUNT:
                // TODO: Handle this case.
                break;
              case VendorDO.NO_CLUE:
                // TODO: Handle this case.
                break;
              case VendorDO.PAGE_DEVICE_PAIRING:
                final page = DevicePairingDataPage.fromBuffer(response.dataObjectData);
                if (kDebugMode) {
                  // this should show the right click device
                  // pairingStatus = 1 => connected and paired, otherwise it can be paired but not connected
                  print(
                    'PageDevicePairing: $page => ${page.pairingDevList.map((e) => e.device.reversed.map((d) => d.toRadixString(16).padLeft(2, '0'))).join(', ')}',
                  );
                }
                break;
              case VendorDO.PAIRED_DEVICE:
                // TODO: Handle this case.
                break;
              case VendorDO.PAIRING_STATUS:
                break;
            }
            break;
          default:
            break;
        }
        break;
      case Opcode.VENDOR_MESSAGE:
        final vendorOpCode = VendorOpcode.valueOf(message.second);
        print('VendorOpcode: $vendorOpCode');
        break;
      case Opcode.LOG_DATA:
        final logMessage = LogDataNotification.fromBuffer(message);
        if (kDebugMode) {
          actionStreamInternal.add(LogNotification(logMessage.toString()));
        }
        break;
      case Opcode.BATTERY_NOTIF:
        final notification = BatteryNotification.fromBuffer(message);
        if (batteryLevel != notification.newPercLevel) {
          batteryLevel = notification.newPercLevel;
          core.connection.signalChange(this);
        }
        break;
      case Opcode.CONTROLLER_NOTIFICATION:
        try {
          final buttonsClicked = processClickNotification(message);
          handleButtonsClicked(buttonsClicked);
        } catch (e) {
          actionStreamInternal.add(LogNotification(e.toString()));
        }
        break;
      case null:
        if (bytes[0] == 0x1A) {
          final batteryStatus = BatteryStatus.fromBuffer(message);
          if (kDebugMode) {
            print('BatteryStatus: $batteryStatus');
          }
        }
        break;
    }
  }

  @override
  List<ControllerButton> processClickNotification(Uint8List message) {
    final status = RideKeyPadStatus.fromBuffer(message);

    // Debug: Log all button mask detections (moved to ZwiftRide.processClickNotification)

    // Process DIGITAL buttons separately
    final buttonsClicked = [
      if (status.buttonMap & RideButtonMask.LEFT_BTN.mask == PlayButtonStatus.ON.value) ZwiftButtons.navigationLeft,
      if (status.buttonMap & RideButtonMask.RIGHT_BTN.mask == PlayButtonStatus.ON.value) ZwiftButtons.navigationRight,
      if (status.buttonMap & RideButtonMask.UP_BTN.mask == PlayButtonStatus.ON.value) ZwiftButtons.navigationUp,
      if (status.buttonMap & RideButtonMask.DOWN_BTN.mask == PlayButtonStatus.ON.value) ZwiftButtons.navigationDown,
      if (status.buttonMap & RideButtonMask.A_BTN.mask == PlayButtonStatus.ON.value) ZwiftButtons.a,
      if (status.buttonMap & RideButtonMask.B_BTN.mask == PlayButtonStatus.ON.value) ZwiftButtons.b,
      if (status.buttonMap & RideButtonMask.Y_BTN.mask == PlayButtonStatus.ON.value) ZwiftButtons.y,
      if (status.buttonMap & RideButtonMask.Z_BTN.mask == PlayButtonStatus.ON.value) ZwiftButtons.z,
      if (status.buttonMap & RideButtonMask.SHFT_UP_L_BTN.mask == PlayButtonStatus.ON.value) ZwiftButtons.shiftUpLeft,
      if (status.buttonMap & RideButtonMask.SHFT_DN_L_BTN.mask == PlayButtonStatus.ON.value) ZwiftButtons.shiftDownLeft,
      if (status.buttonMap & RideButtonMask.SHFT_UP_R_BTN.mask == PlayButtonStatus.ON.value) ZwiftButtons.shiftUpRight,
      if (status.buttonMap & RideButtonMask.SHFT_DN_R_BTN.mask == PlayButtonStatus.ON.value)
        ZwiftButtons.shiftDownRight,
      if (status.buttonMap & RideButtonMask.POWERUP_L_BTN.mask == PlayButtonStatus.ON.value) ZwiftButtons.powerUpLeft,
      if (status.buttonMap & RideButtonMask.POWERUP_R_BTN.mask == PlayButtonStatus.ON.value) ZwiftButtons.powerUpRight,
      if (status.buttonMap & RideButtonMask.ONOFF_L_BTN.mask == PlayButtonStatus.ON.value) ZwiftButtons.onOffLeft,
      if (status.buttonMap & RideButtonMask.ONOFF_R_BTN.mask == PlayButtonStatus.ON.value) ZwiftButtons.onOffRight,
    ];

    // Process ANALOG inputs separately - now properly separated from digital
    // All analog paddles (L0-L3) appear in field 3 as repeated RideAnalogKeyPress
    final List<ControllerButton> analogButtons = [];
    try {
      for (final paddle in status.analogPaddles) {
        if (paddle.hasLocation() && paddle.hasAnalogValue()) {
          if (paddle.analogValue.abs() >= analogPaddleThreshold) {
            final button = switch (paddle.location.value) {
              0 => ZwiftButtons.paddleLeft, // L0 = left paddle
              1 => ZwiftButtons.paddleRight, // L1 = right paddle
              _ => null, // L2, L3 unused
            };

            if (button != null) {
              buttonsClicked.add(button);
              analogButtons.add(button);
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing analog paddle data: $e');
      }
    }
    return buttonsClicked;
  }

  Future<void> sendCommand(Opcode opCode, $pb.GeneratedMessage? message) async {
    final buffer = Uint8List.fromList([opCode.value, ...message?.writeToBuffer() ?? []]);
    if (kDebugMode) {
      print("Sending $opCode: ${buffer.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}");
    }
    await UniversalBle.write(
      device.deviceId,
      customService!.uuid,
      syncRxCharacteristic!.uuid,
      buffer,
      withoutResponse: true,
    );
    await Future.delayed(Duration(milliseconds: 500));
  }

  Future<void> sendCommandBuffer(Uint8List buffer) async {
    if (kDebugMode) {
      print("Sending ${buffer.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}");
    }
    await UniversalBle.write(
      device.deviceId,
      customService!.uuid,
      syncRxCharacteristic!.uuid,
      buffer,
      withoutResponse: true,
    );
  }
}

enum RideButtonMask {
  LEFT_BTN(0x00001),
  UP_BTN(0x00002),
  RIGHT_BTN(0x00004),
  DOWN_BTN(0x00008),

  A_BTN(0x00010),
  B_BTN(0x00020),
  Y_BTN(0x00040),
  Z_BTN(0x00080),

  SHFT_UP_L_BTN(0x00100),
  SHFT_DN_L_BTN(0x00200),
  SHFT_UP_R_BTN(0x01000),
  SHFT_DN_R_BTN(0x02000),

  POWERUP_L_BTN(0x00400),
  POWERUP_R_BTN(0x04000),
  ONOFF_L_BTN(0x00800),
  ONOFF_R_BTN(0x08000);

  final int mask;

  const RideButtonMask(this.mask);
}
