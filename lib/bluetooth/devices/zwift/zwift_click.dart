import 'package:flutter/foundation.dart';
import 'package:swift_control/bluetooth/devices/zwift/protocol/zwift.pb.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_device.dart';
import 'package:swift_control/utils/crypto/local_key_provider.dart';
import 'package:swift_control/utils/crypto/zap_crypto.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../messages/notification.dart';
import 'constants.dart';

class ZwiftClick extends ZwiftDevice {
  ZwiftClick(super.scanResult) : super(availableButtons: [ZwiftButtons.shiftUpRight, ZwiftButtons.shiftDownLeft]);

  final zapEncryption = ZapCrypto(LocalKeyProvider());

  @override
  List<ControllerButton> processClickNotification(Uint8List message) {
    final status = ClickKeyPadStatus.fromBuffer(message);
    final buttonsClicked = [
      if (status.buttonPlus == PlayButtonStatus.ON) ZwiftButtons.shiftUpRight,
      if (status.buttonMinus == PlayButtonStatus.ON) ZwiftButtons.shiftDownLeft,
    ];
    return buttonsClicked;
  }

  @override
  String get latestFirmwareVersion => '1.1.0';

  @override
  Future<void> setupHandshake() async {
    await UniversalBle.write(
      device.deviceId,
      customServiceId,
      syncRxCharacteristic!.uuid,
      Uint8List.fromList([
        ...ZwiftConstants.RIDE_ON,
        ...ZwiftConstants.REQUEST_START,
        ...zapEncryption.localKeyProvider.getPublicKeyBytes(),
      ]),
      withoutResponse: true,
    );
  }

  @override
  void processDevicePublicKeyResponse(Uint8List bytes) {
    final devicePublicKeyBytes = bytes.sublist(
      ZwiftConstants.RIDE_ON.length + ZwiftConstants.RESPONSE_START_CLICK.length,
    );
    if (kDebugMode) {
      print("Device Public Key - ${devicePublicKeyBytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}");
    }
    zapEncryption.initialise(devicePublicKeyBytes);
  }

  @override
  Future<void> processData(Uint8List bytes) async {
    int type;
    Uint8List message;

    print('Processing encrypted data: ${bytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}');

    final counter = bytes.sublist(0, 4); // Int.SIZE_BYTES is 4
    final payload = bytes.sublist(4);

    print(
      'Counter: ${counter.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}',
    );
    print(
      'Payload: ${payload.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}',
    );

    if (zapEncryption.encryptionKeyBytes == null) {
      actionStreamInternal.add(
        LogNotification(
          'Encryption not initialized, yet. You may need to update the firmware of your device with the Zwift Companion app.',
        ),
      );
    }

    final data = zapEncryption.decrypt(counter, payload);
    type = data[0];
    message = data.sublist(1);

    print(
      'Decrypted Data: ${data.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}',
    );
  }
}
