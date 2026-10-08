import 'package:bike_control/bluetooth/devices/openbikecontrol/obc_steering_angle.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/protocol_parser.dart';
import 'package:bike_control/bluetooth/devices/steering_device.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// A steering device whose angle the test sets directly. Angle in the
/// SteeringDevice convention: positive ⇒ LEFT.
class _FakeSteering implements SteeringDevice {
  @override
  final ValueNotifier<double> steeringAngle = ValueNotifier(0.0);
  @override
  final ValueNotifier<bool> steeringCalibrated = ValueNotifier(false);
  @override
  double get steeringThreshold => 5;
  @override
  final ControllerButton steerLeftButton = ControllerButton('fakeLeftSteer', action: InGameAction.steerLeft);
  @override
  final ControllerButton steerRightButton = ControllerButton('fakeRightSteer', action: InGameAction.steerRight);

  /// Steers [deg] degrees to the RIGHT (protocol convention).
  void steerRight(double deg) => steeringAngle.value = -deg;
}

class _FakeSink implements SteeringAngleSink {
  _FakeSink(AppInfo? app) : connectedApp = ValueNotifier(app);

  @override
  final ValueNotifier<AppInfo?> connectedApp;

  bool connected = true;

  @override
  bool get canSendSteeringAngle => connected && connectedApp.value != null;

  final List<int> sent = [];

  /// When set, each send is stamped with the (fake) time it went out.
  Duration Function()? clock;
  final List<Duration> sentAt = [];

  @override
  Future<void> sendSteeringAngle(int value) async {
    sent.add(value);
    if (clock != null) sentAt.add(clock!());
  }
}

AppInfo _app(List<int> ids) => OpenBikeProtocolParser.parseAppInfo(
  Uint8List.fromList([
    OpenBikeProtocolParser.MSG_TYPE_APP_INFO,
    0x01,
    3,
    ...'app'.codeUnits,
    1,
    ...'1'.codeUnits,
    ids.length,
    ...ids,
  ]),
);

void main() {
  group('encodeSteeringAngle (degrees, positive = right)', () {
    int enc(double? d) => OpenBikeProtocolParser.encodeSteeringAngle(d);

    test('center is 0x80', () {
      expect(enc(0), 0x80);
      expect(enc(-0.0), 0x80);
    });
    test('0.5° steps around center', () {
      expect(enc(0.5), 0x81);
      expect(enc(-0.5), 0x7F);
    });
    test('protocol examples', () {
      expect(enc(10), 0x94);
      expect(enc(-4.5), 0x77);
    });
    test('±63° are the ends of the range', () {
      expect(enc(63), 0xFE);
      expect(enc(-63), 0x02);
    });
    test('beyond ±63° clamps', () {
      expect(enc(90), 0xFE);
      expect(enc(63.4), 0xFE);
      expect(enc(-90), 0x02);
      expect(enc(-1000), 0x02);
    });
    test('rounds to the nearest 0.5°', () {
      expect(enc(10.2), 0x94);
      expect(enc(10.3), 0x95);
      expect(enc(-0.2), 0x80);
    });
    test('unavailable (null / NaN / infinite) is 0x00', () {
      expect(enc(null), 0x00);
      expect(enc(double.nan), 0x00);
      expect(enc(double.infinity), 0x00);
    });
    test('never emits the reserved 0x01 or 0xFF', () {
      for (var d = -100.0; d <= 100; d += 0.25) {
        expect(enc(d), isNot(anyOf(0x01, 0xFF)), reason: '$d°');
      }
    });
    test('message is [button-state, 0x1B, value]', () {
      expect(OpenBikeProtocolParser.encodeSteeringAngleState(0x94), [0x01, 0x1B, 0x94]);
    });
  });

  group('AppInfo steering-angle support', () {
    test('an app listing 0x1B steers from the angle', () {
      expect(_app([0x18, 0x19, 0x1B]).supportsSteeringAngle, isTrue);
      expect(_app([0x1B]).supportsSteeringAngle, isTrue);
    });
    test('an app without 0x1B does not', () {
      expect(_app([0x18, 0x19]).supportsSteeringAngle, isFalse);
    });
    test('0x1B is not turned into a pressable button', () {
      final app = _app([0x1B]);
      expect(app.supportedButtons, isEmpty);
      expect(app.supportedActions, isEmpty);
    });
  });

  group('ObcSteeringAngleBroadcaster', () {
    late _FakeSteering device;
    late _FakeSink sink;
    late bool allowed;

    ObcSteeringAngleBroadcaster build({List<SteeringAngleSink>? sinks}) => ObcSteeringAngleBroadcaster(
      sinks: () => sinks ?? [sink],
      isAllowed: (_) => allowed,
    );

    setUp(() {
      device = _FakeSteering();
      sink = _FakeSink(_app([0x18, 0x19]));
      allowed = true;
    });

    test('sends nothing before calibration, center once calibrated', () {
      fakeAsync((async) {
        final b = build()..attach(device);
        device.steerRight(12);
        async.elapse(const Duration(milliseconds: 100));
        expect(sink.sent, isEmpty, reason: 'uncalibrated values must not be sent');

        device.steeringAngle.value = 0;
        device.steeringCalibrated.value = true;
        async.elapse(const Duration(milliseconds: 100));
        expect(sink.sent, [0x80]);
        b.dispose();
      });
    });

    test('converts the gauge convention (positive = left) to protocol (positive = right)', () {
      fakeAsync((async) {
        final b = build()..attach(device);
        device.steeringCalibrated.value = true;
        async.elapse(const Duration(milliseconds: 100));
        device.steerRight(10);
        async.elapse(const Duration(milliseconds: 100));
        device.steerRight(-4.5);
        async.elapse(const Duration(milliseconds: 100));
        device.steerRight(0);
        async.elapse(const Duration(milliseconds: 100));
        expect(sink.sent, [0x80, 0x94, 0x77, 0x80]);
        b.dispose();
      });
    });

    test('only sends when the encoded value changes', () {
      fakeAsync((async) {
        final b = build()..attach(device);
        device.steeringCalibrated.value = true;
        async.elapse(const Duration(milliseconds: 100));
        device.steerRight(10.0);
        async.elapse(const Duration(milliseconds: 100));
        device.steerRight(10.1);
        async.elapse(const Duration(milliseconds: 100));
        device.steerRight(9.9);
        async.elapse(const Duration(milliseconds: 100));
        expect(sink.sent, [0x80, 0x94]);
        b.dispose();
      });
    });

    test('rate-limits to at most 30 Hz and always sends the settled value', () {
      fakeAsync((async) {
        final b = build()..attach(device);
        device.steeringCalibrated.value = true;
        async.elapse(const Duration(seconds: 1));
        sink.sent.clear();
        sink.clock = () => async.elapsed;

        // 1 kHz of changing angles for one second.
        for (var i = 0; i < 1000; i++) {
          device.steerRight((i % 100) / 2); // 0..49.5° in 0.5° steps
          async.elapse(const Duration(milliseconds: 1));
        }
        final sendTimes = sink.sentAt;
        expect(sink.sent.length, lessThanOrEqualTo(30));
        expect(sink.sent.length, greaterThan(20), reason: 'still streams while moving');
        for (var i = 1; i < sendTimes.length; i++) {
          expect(sendTimes[i] - sendTimes[i - 1], greaterThanOrEqualTo(const Duration(microseconds: 33334)));
        }

        // Settle on a final angle: it must arrive even though it came mid-window.
        device.steerRight(21);
        async.elapse(const Duration(milliseconds: 200));
        expect(sink.sent.last, OpenBikeProtocolParser.encodeSteeringAngle(21));
        b.dispose();
      });
    });

    test('a quick burst inside one window still ends on the last value', () {
      fakeAsync((async) {
        final b = build()..attach(device);
        device.steeringCalibrated.value = true; // sends 0x80, opens a window
        device.steerRight(5);
        device.steerRight(6);
        device.steerRight(7);
        expect(sink.sent, [0x80]);
        async.elapse(const Duration(milliseconds: 40));
        expect(sink.sent, [0x80, OpenBikeProtocolParser.encodeSteeringAngle(7)]);
        async.elapse(const Duration(milliseconds: 200));
        expect(sink.sent.length, 2);
        b.dispose();
      });
    });

    test('recalibrating sends 0x00, then center again once calibrated', () {
      fakeAsync((async) {
        final b = build()..attach(device);
        device.steeringCalibrated.value = true;
        async.elapse(const Duration(milliseconds: 100));
        device.steerRight(15);
        async.elapse(const Duration(milliseconds: 100));

        device.steeringCalibrated.value = false;
        device.steeringAngle.value = 0;
        async.elapse(const Duration(milliseconds: 100));
        expect(sink.sent.last, 0x00);

        // Raw values while recalibrating are not sent.
        device.steerRight(30);
        async.elapse(const Duration(milliseconds: 100));
        expect(sink.sent.last, 0x00);

        device.steeringAngle.value = 0;
        device.steeringCalibrated.value = true;
        async.elapse(const Duration(milliseconds: 100));
        expect(sink.sent.last, 0x80);
        b.dispose();
      });
    });

    test('detaching (device disconnect) sends 0x00', () {
      fakeAsync((async) {
        final b = build()..attach(device);
        device.steeringCalibrated.value = true;
        async.elapse(const Duration(milliseconds: 100));
        device.steerRight(15);
        async.elapse(const Duration(milliseconds: 100));

        b.detach(device);
        async.elapse(const Duration(milliseconds: 100));
        expect(sink.sent.last, 0x00);

        // No longer listening.
        device.steerRight(20);
        async.elapse(const Duration(milliseconds: 100));
        expect(sink.sent.last, 0x00);
        b.dispose();
      });
    });

    test('detaching a device that never sent an angle sends nothing', () {
      fakeAsync((async) {
        final b = build()..attach(device);
        b.detach(device);
        async.elapse(const Duration(milliseconds: 100));
        expect(sink.sent, isEmpty);
        b.dispose();
      });
    });

    test('when the gate is closed (no steering mapping, limit reached), the angle stops: 0x00', () {
      fakeAsync((async) {
        final b = build()..attach(device);
        device.steeringCalibrated.value = true;
        async.elapse(const Duration(milliseconds: 100));
        device.steerRight(15);
        async.elapse(const Duration(milliseconds: 100));

        allowed = false;
        device.steerRight(16);
        async.elapse(const Duration(milliseconds: 100));
        device.steerRight(17);
        async.elapse(const Duration(milliseconds: 100));
        expect(sink.sent, [0x80, OpenBikeProtocolParser.encodeSteeringAngle(15), 0x00]);
        b.dispose();
      });
    });

    test('never gated in: nothing is sent at all', () {
      fakeAsync((async) {
        allowed = false;
        final b = build()..attach(device);
        device.steeringCalibrated.value = true;
        device.steerRight(15);
        async.elapse(const Duration(milliseconds: 100));
        expect(sink.sent, isEmpty);
        b.dispose();
      });
    });

    test('apps without any steering support get no angle', () {
      fakeAsync((async) {
        sink = _FakeSink(_app([0x01, 0x02]));
        final b = build()..attach(device);
        device.steeringCalibrated.value = true;
        device.steerRight(15);
        async.elapse(const Duration(milliseconds: 100));
        expect(sink.sent, isEmpty);
        b.dispose();
      });
    });

    test('apps listing only 0x1B get the angle', () {
      fakeAsync((async) {
        sink = _FakeSink(_app([0x1B]));
        final b = build()..attach(device);
        device.steeringCalibrated.value = true;
        async.elapse(const Duration(milliseconds: 100));
        expect(sink.sent, [0x80]);
        b.dispose();
      });
    });

    test('an app that connects later gets the current angle right away', () {
      fakeAsync((async) {
        final laterSink = _FakeSink(null);
        final b = build(sinks: [sink, laterSink])
          ..watchApps([sink, laterSink])
          ..attach(device);
        device.steeringCalibrated.value = true;
        async.elapse(const Duration(milliseconds: 100));
        device.steerRight(10);
        async.elapse(const Duration(milliseconds: 100));
        expect(laterSink.sent, isEmpty);

        laterSink.connectedApp.value = _app([0x1B]);
        async.elapse(const Duration(milliseconds: 1));
        expect(laterSink.sent, [0x94]);
        b.dispose();
      });
    });

    test('coversSteeringButton: only the steering buttons of a device with a live angle', () {
      fakeAsync((async) {
        final b = build()..attach(device);
        expect(b.coversSteeringButton(device.steerLeftButton), isFalse, reason: 'no angle sent yet');

        device.steeringCalibrated.value = true;
        async.elapse(const Duration(milliseconds: 100));
        expect(b.coversSteeringButton(device.steerLeftButton), isTrue);
        expect(b.coversSteeringButton(device.steerRightButton), isTrue);
        expect(
          b.coversSteeringButton(ControllerButton('otherSteer', action: InGameAction.steerLeft)),
          isFalse,
          reason: 'a plain controller button mapped to steer is not an angle input',
        );

        device.steeringCalibrated.value = false;
        async.elapse(const Duration(milliseconds: 100));
        expect(b.coversSteeringButton(device.steerLeftButton), isFalse, reason: 'angle unavailable');
        b.dispose();
      });
    });
  });
}
