import 'package:bike_control/bluetooth/devices/openbikecontrol/obc_gear.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/protocol_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSink implements GearStateSink {
  _FakeSink(AppInfo? app) : connectedApp = ValueNotifier(app);

  @override
  final ValueNotifier<AppInfo?> connectedApp;

  bool connected = true;

  @override
  bool get canSendGearState => connected && connectedApp.value != null;

  final List<List<int>> sent = [];

  @override
  Future<void> sendGearState(Uint8List message) async => sent.add(message.toList());
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

const _gearSet = 0x03;
const _chainringSet = 0x04;
const _cassetteSet = 0x05;

void main() {
  group('obcGearPosition', () {
    test('without front shifting the flat gear is the gear', () {
      final p = obcGearPosition(currentGear: 12, maxGear: 24, frontShiftEnabled: false, largeRing: false);
      expect(p, const ObcGearPosition(flat: 12));
    });

    test('front shifting: small ring keeps the rear index, large ring follows it', () {
      expect(
        obcGearPosition(currentGear: 7, maxGear: 12, frontShiftEnabled: true, largeRing: false),
        const ObcGearPosition(flat: 7, chainring: 1, cassette: 7),
      );
      expect(
        obcGearPosition(currentGear: 7, maxGear: 12, frontShiftEnabled: true, largeRing: true),
        const ObcGearPosition(flat: 19, chainring: 2, cassette: 7),
      );
    });
  });

  group('encodeGearState', () {
    test('gear n goes out as n + 1', () {
      final app = _app([_gearSet]);
      expect(
        OpenBikeProtocolParser.encodeGearState(const ObcGearPosition(flat: 1), app),
        [0x01, _gearSet, 0x02],
      );
      expect(
        OpenBikeProtocolParser.encodeGearState(const ObcGearPosition(flat: 12), app),
        [0x01, _gearSet, 0x0D],
      );
    });

    test('positions past 254 clamp to 0xFF', () {
      expect(
        OpenBikeProtocolParser.encodeGearState(const ObcGearPosition(flat: 400), _app([_gearSet])),
        [0x01, _gearSet, 0xFF],
      );
    });

    test('chainring and cassette only for an app that listed them', () {
      const p = ObcGearPosition(flat: 19, chainring: 2, cassette: 7);
      expect(OpenBikeProtocolParser.encodeGearState(p, _app([_gearSet])), [0x01, _gearSet, 20]);
      expect(
        OpenBikeProtocolParser.encodeGearState(p, _app([_gearSet, _chainringSet, _cassetteSet])),
        [0x01, _gearSet, 20, _chainringSet, 3, _cassetteSet, 8],
      );
      expect(
        OpenBikeProtocolParser.encodeGearState(p, _app([_chainringSet, _cassetteSet])),
        [0x01, _chainringSet, 3, _cassetteSet, 8],
      );
    });

    test('nothing for an app that listed none of the gear ids', () {
      expect(OpenBikeProtocolParser.encodeGearState(const ObcGearPosition(flat: 3), _app([0x01, 0x02])), isNull);
    });

    test('an app that sent an empty list (all buttons) does not get gear values', () {
      expect(OpenBikeProtocolParser.encodeGearState(const ObcGearPosition(flat: 3), _app([])), isNull);
    });
  });

  group('ObcGearBroadcaster', () {
    late ValueNotifier<ObcGearPosition?> position;
    late _FakeSink wants;
    late _FakeSink ignores;
    late ObcGearBroadcaster broadcaster;

    setUp(() {
      position = ValueNotifier(null);
      wants = _FakeSink(_app([_gearSet]));
      ignores = _FakeSink(_app([0x01, 0x02]));
      broadcaster = ObcGearBroadcaster(sinks: () => [wants, ignores], position: position)..watchApps([wants, ignores]);
    });

    tearDown(() => broadcaster.dispose());

    test('sends each gear change to apps that listed Gear Set only', () {
      position.value = const ObcGearPosition(flat: 5);
      position.value = const ObcGearPosition(flat: 6);
      expect(wants.sent, [
        [0x01, _gearSet, 6],
        [0x01, _gearSet, 7],
      ]);
      expect(ignores.sent, isEmpty);
    });

    test('the same gear is not sent twice', () {
      position.value = const ObcGearPosition(flat: 5);
      position.value = const ObcGearPosition(flat: 5);
      expect(wants.sent, hasLength(1));
    });

    test('no gear source sends nothing', () {
      position.value = const ObcGearPosition(flat: 5);
      position.value = null;
      expect(wants.sent, hasLength(1));
    });

    test('the gear is re-sent once a source comes back, even if unchanged', () {
      position.value = const ObcGearPosition(flat: 5);
      position.value = null;
      position.value = const ObcGearPosition(flat: 5);
      expect(wants.sent, hasLength(2));
    });

    test('a sink that cannot send right now is skipped', () {
      wants.connected = false;
      position.value = const ObcGearPosition(flat: 5);
      expect(wants.sent, isEmpty);
    });

    test('an app connecting later gets the current gear at once', () {
      final late = _FakeSink(null);
      broadcaster.dispose();
      broadcaster = ObcGearBroadcaster(sinks: () => [late], position: position)..watchApps([late]);
      position.value = const ObcGearPosition(flat: 9);
      expect(late.sent, isEmpty);
      late.connectedApp.value = _app([_gearSet]);
      expect(late.sent, [
        [0x01, _gearSet, 10],
      ]);
    });

    test('the current gear goes out when the broadcaster starts', () {
      broadcaster.dispose();
      position.value = const ObcGearPosition(flat: 4);
      broadcaster = ObcGearBroadcaster(sinks: () => [wants], position: position);
      expect(wants.sent, [
        [0x01, _gearSet, 5],
      ]);
    });

    test('after dispose nothing is sent', () {
      broadcaster.dispose();
      position.value = const ObcGearPosition(flat: 5);
      wants.connectedApp.value = _app([_gearSet, 0x01]);
      expect(wants.sent, isEmpty);
    });
  });
}
