import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:protobuf/protobuf.dart' as $pb;
import 'package:swift_control/bluetooth/devices/zwift/zwift_device.dart';
import 'package:swift_control/bluetooth/devices/zwift_clickv2.dart';
import 'package:swift_control/bluetooth/messages/ride_notification.dart';
import 'package:swift_control/bluetooth/protocol/zp_vendor.pb.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../main.dart';
import '../ble.dart';
import '../messages/notification.dart';
import '../protocol/zp.pb.dart';

class ZwiftRide extends ZwiftDevice {
  /// Minimum absolute analog value (0-100) required to trigger paddle button press.
  /// Values below this threshold are ignored to prevent accidental triggers from
  /// analog drift or light touches.
  static const int analogPaddleThreshold = 25;

  ZwiftRide(super.scanResult)
    : super(
        availableButtons: [
          ControllerButton.navigationLeft,
          ControllerButton.navigationRight,
          ControllerButton.navigationUp,
          ControllerButton.navigationDown,
          ControllerButton.a,
          ControllerButton.b,
          ControllerButton.y,
          ControllerButton.z,
          ControllerButton.shiftUpLeft,
          ControllerButton.shiftDownLeft,
          ControllerButton.shiftUpRight,
          ControllerButton.shiftDownRight,
          ControllerButton.powerUpLeft,
          ControllerButton.powerUpRight,
          ControllerButton.onOffLeft,
          ControllerButton.onOffRight,
          ControllerButton.paddleLeft,
          ControllerButton.paddleRight,
        ],
      );

  @override
  String get customServiceId => BleUuid.ZWIFT_RIDE_CUSTOM_SERVICE_UUID;

  @override
  bool get supportsEncryption => false;

  RideNotification? _lastControllerNotification;

  @override
  Future<void> processData(Uint8List bytes) async {
    Opcode? opcode;
    Uint8List message;

    if (supportsEncryption) {
      final counter = bytes.sublist(0, 4); // Int.SIZE_BYTES is 4
      final payload = bytes.sublist(4);

      if (zapEncryption.encryptionKeyBytes == null) {
        actionStreamInternal.add(
          LogNotification(
            'Encryption not initialized, yet. You may need to update the firmware of your device with the Zwift Companion app.',
          ),
        );
        return;
      }

      final data = zapEncryption.decrypt(counter, payload);
      opcode = Opcode.valueOf(data[0]);
      message = data.sublist(1);
    } else {
      opcode = Opcode.valueOf(bytes[0]);
      message = bytes.sublist(1);
    }

    if (kDebugMode) {
      print(
        '${DateTime.now().toString().split(" ").last} Received $opcode: ${bytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')} => ${String.fromCharCodes(bytes)} ',
      );
    }

    if (bytes.startsWith(Constants.RESPONSE_STOPPED_CLICK_V2) && this is ZwiftClickV2) {
      actionStreamInternal.add(
        LogNotification(
          'Your Zwift Click V2 no longer sends events. Connect it in the Zwift app once per day. Resetting the device now.',
        ),
      );
      sendCommand(Opcode.RESET, null);
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
          connection.signalChange(this);
        }
        break;
      case Opcode.CONTROLLER_NOTIFICATION:
        processClickNotification(message)
            .then((buttonsClicked) async {
              return handleButtonsClicked(buttonsClicked);
            })
            .catchError((e) {
              actionStreamInternal.add(LogNotification(e.toString()));
            });
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
  Future<List<ControllerButton>?> processClickNotification(Uint8List message) async {
    final RideNotification clickNotification = RideNotification(
      message,
      analogPaddleThreshold: analogPaddleThreshold,
    );

    if (_lastControllerNotification == null || _lastControllerNotification != clickNotification) {
      _lastControllerNotification = clickNotification;

      if (clickNotification.buttonsClicked.isNotEmpty) {
        actionStreamInternal.add(clickNotification);
      }
      return clickNotification.buttonsClicked;
    } else {
      return null;
    }
  }

  Future<void> sendCommand(Opcode opCode, $pb.GeneratedMessage? message) async {
    final buffer = Uint8List.fromList([opCode.value, ...message?.writeToBuffer() ?? []]);
    if (kDebugMode) {
      print("Sending $opCode: ${buffer.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}");
    }
    await UniversalBle.write(
      device.deviceId,
      customServiceId,
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
      customServiceId,
      syncRxCharacteristic!.uuid,
      buffer,
      withoutResponse: true,
    );
  }
}
