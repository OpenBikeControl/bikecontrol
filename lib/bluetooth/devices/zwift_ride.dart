import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:protobuf/protobuf.dart' as $pb;
import 'package:swift_control/bluetooth/devices/base_device.dart';
import 'package:swift_control/bluetooth/messages/ride_notification.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../main.dart';
import '../ble.dart';
import '../messages/notification.dart';
import '../protocol/zp.pb.dart';

class ZwiftRide extends BaseDevice {
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

    if (bytes.startsWith(Constants.RESPONSE_STOPPED_CLICK_V2)) {
      print('no more events');
      //connect();
    }

    switch (opcode) {
      case Opcode.RIDE_ON:
        //print("Empty RideOn response - unencrypted mode");
        //_sendCommand(Opcode.GET, Get(dataObjectId: DO.PAGE_DEV_INFO.value)); // 0008 00

        //_sendCommand(Opcode.LOG_LEVEL_SET, LogLevelSet(logLevel: LogLevel.LOGLEVEL_TRACE)); // 4108 05

        //await _sendCommand(Opcode.GET, Get(dataObjectId: DO.PAGE_CLIENT_SERVER_CONFIGURATION.value)); // 0008 10

        /*
          final buffer = Uint8List.fromList([Opcode.GET.value, ...[0x80, 0x08]]); // 0008 8008
          if (kDebugMode) {
            print("Sending ${buffer.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}");
          }
          await UniversalBle.write(
            device.deviceId,
            customServiceId,
            syncRxCharacteristic!.uuid,
            buffer,
            withoutResponse: true,
          );*/

        /*
          final buffer = Uint8List.fromList([Opcode.GET.value, ...[0x83, 0x06]]); // 0008 8306
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
           */
        break;
      case Opcode.STATUS_RESPONSE:
        final status = StatusResponse.fromBuffer(message);
        print('StatusResponse: ${status.command} status: ${Status.valueOf(status.status)}');
        break;
      case Opcode.GET_RESPONSE:
        final response = GetResponse.fromBuffer(message);
        final dataObjectType = DO.valueOf(response.dataObjectId);
        print('GetResponse: $dataObjectType');

        switch (dataObjectType) {
          case DO.PAGE_DEV_INFO:
            final pageDevInfo = DevInfoPage.fromBuffer(response.dataObjectData);
            print('PageDevInfo: $pageDevInfo');
            break;
          case DO.PAGE_DATE_TIME:
            final pageDateTime = DateTimePage.fromBuffer(response.dataObjectData);
            print('PageDateTime: $pageDateTime');
            break;
          default:
            break;
        }
        break;
      case Opcode.VENDOR_MESSAGE:
        break;
      case Opcode.LOG_DATA:
        final logMessage = LogDataNotification.fromBuffer(message);
        actionStreamInternal.add(LogNotification(logMessage.toString()));
        break;
      case Opcode.BATTERY_NOTIF:
        final notification = BatteryNotification.fromBuffer(message);
        if (batteryLevel != notification.newPercLevel) {
          batteryLevel = notification.newPercLevel;
          connection.signalChange(this);
        }
        break;
      case null: // the old Zwift Click acts differently
      case Opcode.CONTROLLER_NOTIFICATION:
        processClickNotification(message)
            .then((buttonsClicked) async {
              return handleButtonsClicked(buttonsClicked);
            })
            .catchError((e) {
              actionStreamInternal.add(LogNotification(e.toString()));
            });
        break;
    }
    return super.processData(bytes);
  }

  @override
  Future<List<ZwiftButton>?> processClickNotification(Uint8List message) async {
    final RideNotification clickNotification = RideNotification(message);
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

  Future<void> _sendCommand(Opcode opCode, $pb.GeneratedMessage message) async {
    final buffer = Uint8List.fromList([opCode.value, ...message.writeToBuffer()]);
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
  }
}
