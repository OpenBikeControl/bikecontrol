// The steering page says the trainer app follows the exact angle only while
// an OpenBikeControl app that listed 0x1B is attached and reachable.
import 'package:bike_control/bluetooth/devices/openbikecontrol/obc_steering_angle.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/protocol_parser.dart';
import 'package:bike_control/widgets/controller/steering_gauge.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _Sink implements SteeringAngleSink {
  _Sink(AppInfo? app, {this.canSendSteeringAngle = true}) : connectedApp = ValueNotifier(app);

  @override
  final ValueNotifier<AppInfo?> connectedApp;

  @override
  final bool canSendSteeringAngle;

  @override
  Future<void> sendSteeringAngle(int value) async {}
}

AppInfo _app({required bool angle}) => AppInfo(
  appId: 'app',
  appVersion: '1',
  supportedButtons: const [],
  supportedActions: const [],
  supportedButtonIds: [0x18, 0x19, if (angle) OpenBikeProtocolParser.STEERING_ANGLE_BUTTON_ID],
);

void main() {
  test('an app that listed 0x1B and can be reached takes the angle', () {
    expect(steeringAngleReachesApp([_Sink(_app(angle: true))]), isTrue);
  });

  test('an app without 0x1B, no app, or an unreachable one does not', () {
    expect(steeringAngleReachesApp([_Sink(_app(angle: false))]), isFalse);
    expect(steeringAngleReachesApp([_Sink(null)]), isFalse);
    expect(steeringAngleReachesApp([_Sink(_app(angle: true), canSendSteeringAngle: false)]), isFalse);
    expect(steeringAngleReachesApp(const []), isFalse);
  });
}
