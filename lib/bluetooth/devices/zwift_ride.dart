import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:protobuf/protobuf.dart' as $pb;
import 'package:swift_control/bluetooth/devices/base_device.dart';
import 'package:swift_control/bluetooth/devices/zwift_clickv2.dart';
import 'package:swift_control/bluetooth/messages/ride_notification.dart';
import 'package:swift_control/bluetooth/protocol/protobuf_parser.dart';
import 'package:swift_control/bluetooth/protocol/zp_vendor.pb.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../main.dart';
import '../ble.dart';
import '../messages/notification.dart';
import '../protocol/zp.pb.dart';

class ZwiftRide extends BaseDevice {
  /// Minimum absolute analog value (0-100) required to trigger paddle button press.
  /// Values below this threshold are ignored to prevent accidental triggers from
  /// analog drift or light touches.
  static const int analogPaddleThreshold = 25;

  ZwiftRide(super.scanResult)
    : super(
        availableButtons: [
          ZwiftButton.navigationLeft,
          ZwiftButton.navigationRight,
          ZwiftButton.navigationUp,
          ZwiftButton.navigationDown,
          ZwiftButton.a,
          ZwiftButton.b,
          ZwiftButton.y,
          ZwiftButton.z,
          ZwiftButton.shiftUpLeft,
          ZwiftButton.shiftDownLeft,
          ZwiftButton.shiftUpRight,
          ZwiftButton.shiftDownRight,
          ZwiftButton.powerUpLeft,
          ZwiftButton.powerUpRight,
          ZwiftButton.onOffLeft,
          ZwiftButton.onOffRight,
          ZwiftButton.paddleLeft,
          ZwiftButton.paddleRight,
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
      if (!kDebugMode) {
        sendCommand(Opcode.RESET, null);
      }
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
  Future<List<ZwiftButton>?> processClickNotification(Uint8List message) async {
    final RideNotification clickNotification = RideNotification(message);

    // Parse embedded analog paddle data from controller notification message.
    // The Zwift Ride paddles send analog pressure values (-100 to 100) that need to be
    // extracted from the raw Protocol Buffer message structure.
    //
    // Message structure (after button map at offset 7):
    // - Location 0 (left paddle): Embedded directly without 0x1a prefix
    // - Location 1-3 (right paddle, unused): Prefixed with 0x1a marker
    //
    // This implementation mirrors the JavaScript reference from:
    // https://www.makinolo.com/blog/2024/07/26/zwift-ride-protocol/
    final allAnalogValues = <int, int>{};
    var offset = 7; // Skip message type (1), field number (1), and button map (5)

    // Parse first analog location (L0 - left paddle) which appears directly
    // in the message without the 0x1a section marker
    if (offset < message.length && message[offset] != 0x1a) {
      try {
        final firstAnalog = ProtobufParser.parseKeyGroup(message.sublist(offset));
        allAnalogValues.addAll(firstAnalog);

        // Advance to next 0x1a section
        while (offset < message.length && message[offset] != 0x1a) {
          offset++;
        }
      } catch (e) {
        // Skip to 0x1a sections on parse error
        while (offset < message.length && message[offset] != 0x1a) {
          offset++;
        }
      }
    }

    // Parse remaining analog locations (L1, L2, L3, etc.) which are wrapped
    // in Protocol Buffer message sections prefixed with 0x1a
    while (offset < message.length) {
      if (offset < message.length && message[offset] == 0x1a) {
        try {
          final analogData = message.sublist(offset);
          // Each analog section starts with 0x1a, skip it and parse the rest
          if (analogData.isNotEmpty && analogData[0] == 0x1a) {
            final parsedData = ProtobufParser.parseKeyGroup(analogData.sublist(1));
            allAnalogValues.addAll(parsedData);
          }

          offset += ProtobufParser.findNextMarker(analogData, 0x1a);
        } catch (e) {
          offset++;
        }
      } else {
        offset++;
      }
    }

    // Convert analog values to button presses when they exceed threshold.
    // Location 0 = left paddle, Location 1 = right paddle
    // Values range from -100 to 100, we use absolute value for threshold check
    for (final entry in allAnalogValues.entries) {
      if (entry.value.abs() >= analogPaddleThreshold) {
        final button = switch (entry.key) {
          0 => ZwiftButton.paddleLeft,
          1 => ZwiftButton.paddleRight,
          _ => null,
        };

        if (button != null) {
          clickNotification.buttonsClicked.add(button);
          clickNotification.analogButtons.add(button);
        }
      }
    }

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
