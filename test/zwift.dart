import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:bike_control/bluetooth/devices/zwift/ftms_mdns_emulator.dart';
import 'package:bike_control/bluetooth/devices/zwift/protocol/zp.pb.dart';

void main() {
  group('Zwift Emulation', () {
    test('compare bytes', () {
      final devInfo = DevInfoPage(
        deviceName: 'BikeControl'.codeUnits,
        deviceUid: '58D15ABB4363'.codeUnits,
        manufacturerId: 0x01,
        serialNumber: '0B-58D15ABB4363'.codeUnits,
        protocolVersion: 515,
        systemFwVersion: [0, 0, 1, 1],
        productId: 11,
        systemHwRevision: 'B.0'.codeUnits,
        deviceCapabilities: [DevInfoPage_DeviceCapabilities(deviceType: 2, capabilities: 1)],
      );

      final getResponse = GetResponse(
        dataObjectId: DO.PAGE_DEV_INFO.value,
        dataObjectData: devInfo.writeToBuffer(),
      );

      final serverInfoResponse = Uint8List.fromList([
        Opcode.GET_RESPONSE.value,
        ...getResponse.writeToBuffer(),
      ]);
      final expected = Uint8List.fromList(
        hexToBytes(
          '3C080012460A440883041204000001011A0B42696b65436f6e74726f6c320F30422D3538443135414242343336333A03422E304204080210014801500B5A0C353844313541424234333633',
        ),
      );

      final parsed = GetResponse.fromBuffer(expected.sublist(1));
      //expect(parsed, equals(getResponse));

      final parsedDo = DevInfoPage.fromBuffer(parsed.dataObjectData);
      expect(parsedDo.writeToBuffer(), equals(devInfo.writeToBuffer()));
      expect(parsedDo, equals(devInfo));

      //expect(serverInfoResponse, equals(expected));
    });
  });
}
