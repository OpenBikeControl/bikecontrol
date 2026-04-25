import 'package:bike_control/bluetooth/devices/trainer_connection.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeConnection extends TrainerConnection {
  final TrainerConnectionType? _transport;
  _FakeConnection({
    required super.title,
    required super.type,
    TrainerConnectionType? transport,
  })  : _transport = transport,
        super(supportedActions: const []);

  @override
  TrainerConnectionType? get virtualShiftingTransport => _transport;

  @override
  Future<ActionResult> sendAction(KeyPair keyPair, {required bool isKeyDown, required bool isKeyUp}) async =>
      NotHandled('');

  @override
  Widget getTile() => const SizedBox.shrink();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
  });

  test('returns null when no enabled connections expose a transport', () {
    expect(core.logic.preferredBridgeTransport([]), isNull);
  });

  test('prefers bluetooth when any enabled connection rides BLE', () {
    final list = <TrainerConnection>[
      _FakeConnection(title: 'mdns', type: ConnectionMethodType.network, transport: TrainerConnectionType.wifi),
      _FakeConnection(title: 'ble', type: ConnectionMethodType.bluetooth, transport: TrainerConnectionType.bluetooth),
    ];
    expect(core.logic.preferredBridgeTransport(list), TrainerConnectionType.bluetooth);
  });

  test('falls back to wifi when only network connections are enabled', () {
    final list = <TrainerConnection>[
      _FakeConnection(title: 'mdns', type: ConnectionMethodType.network, transport: TrainerConnectionType.wifi),
    ];
    expect(core.logic.preferredBridgeTransport(list), TrainerConnectionType.wifi);
  });

  test('ignores connections with null transport (local, etc.)', () {
    final list = <TrainerConnection>[
      _FakeConnection(title: 'local', type: ConnectionMethodType.local, transport: null),
    ];
    expect(core.logic.preferredBridgeTransport(list), isNull);
  });
}
