import 'package:bike_control/bluetooth/devices/openbikecontrol/obc_bike_definition.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/openbikecontrol_device.dart';
import 'package:flutter_test/flutter_test.dart';

class _Recorder implements OnMessage {
  final messages = <List<int>>[];

  @override
  void onMessage(List<int> message) => messages.add(message);
}

void main() {
  test('DirCon OBC service exposes the haptic characteristic', () {
    final definition = ObcBikeDefinition(onMessageCallback: _Recorder());
    final uuids = definition.getCharacteristics(OpenBikeControlConstants.SERVICE_UUID).map((c) => c.uuid.toLowerCase());
    expect(uuids, contains(OpenBikeControlConstants.HAPTIC_CHARACTERISTIC_UUID));
  });

  test('haptic writes reach the message handler', () {
    final recorder = _Recorder();
    ObcBikeDefinition(
      onMessageCallback: recorder,
    ).onWriteRequest(OpenBikeControlConstants.HAPTIC_CHARACTERISTIC_UUID.toUpperCase(), [0x03, 0x01, 0x00, 0x00]);
    expect(recorder.messages, [
      [0x03, 0x01, 0x00, 0x00],
    ]);
  });
}
