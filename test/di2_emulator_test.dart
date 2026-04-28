import 'package:bike_control/bluetooth/devices/shimano/di2_emulator.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart' show Locale, ValueNotifier;
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/di2_definition.dart';
import 'package:prop/emulators/transporter/bluetooth_transporter.dart';

/// Mock BluetoothTransporter for testing. Avoids platform-specific
/// initialization (PeripheralManager) which isn't available in test env.
class _StubBluetoothTransporter implements BluetoothTransporter {
  _StubBluetoothTransporter(this.definition) {
    definition.transporter = this;
  }

  @override
  final Di2Definition definition;

  bool started = false;
  bool disposed = false;
  final List<({String uuid, List<int> data})> sent = [];

  @override
  String get advertisementName => 'Test Di2';

  final ValueNotifier<bool> _hasSubscribers = ValueNotifier(false);

  @override
  ValueListenable<bool> get hasSubscribers => _hasSubscribers;

  @override
  Future<void> start({bool advertise = true}) async {
    started = true;
  }

  @override
  Future<void> startAdvertising() async {}

  @override
  Future<void> stopAdvertising() async {}

  @override
  Future<void> stop() async {}

  @override
  void dispose() {
    disposed = true;
  }

  @override
  void sendCharacteristicNotification(
    String characteristicUUID,
    List<int> data, {
    int responseCode = 0,
  }) {
    sent.add((uuid: characteristicUUID, data: List.of(data)));
  }
}

KeyPair _channelPair(InGameAction action, {bool longPress = false}) {
  return KeyPair(
    buttons: [ControllerButton('Test', action: action)],
    physicalKey: null,
    logicalKey: null,
    inGameAction: action,
    isLongPress: longPress,
  );
}

void main() {
  setUpAll(() async {
    await AppLocalizations.load(const Locale('en'));
  });

  group('Di2Emulator.sendAction', () {
    late Di2Emulator emulator;
    late _StubBluetoothTransporter transporter;

    setUp(() async {
      emulator = Di2Emulator();
      transporter = _StubBluetoothTransporter(emulator.definition);
      emulator.transporterFactory = (_) => transporter;
      await emulator.startAdvertising();
    });

    tearDown(() async {
      await emulator.stopAdvertising();
    });

    test('supportedActions covers exactly the four D-Fly channel actions', () {
      expect(emulator.supportedActions, [
        InGameAction.dFlyChannel1,
        InGameAction.dFlyChannel2,
        InGameAction.dFlyChannel3,
        InGameAction.dFlyChannel4,
      ]);
    });

    test('isKeyDown on dFlyChannel2 emits a short-press bit on channel index 1', () async {
      final result = await emulator.sendAction(
        _channelPair(InGameAction.dFlyChannel2),
        isKeyDown: true,
        isKeyUp: false,
      );
      expect(result, isA<Success>());
      expect(transporter.sent, hasLength(1));
      // [header, ch0, ch1, ch2, ch3] — only channel 1 carries 0x10.
      expect(transporter.sent.single.data, [0x00, 0x00, 0x10, 0x00, 0x00]);
      expect(transporter.sent.single.uuid, Di2Definition.D_FLY_CHANNEL_UUID);
    });

    test('isKeyUp clears the channel back to released', () async {
      await emulator.sendAction(
        _channelPair(InGameAction.dFlyChannel2),
        isKeyDown: true,
        isKeyUp: false,
      );
      await emulator.sendAction(
        _channelPair(InGameAction.dFlyChannel2),
        isKeyDown: false,
        isKeyUp: true,
      );
      expect(transporter.sent, hasLength(2));
      expect(transporter.sent.last.data, [0x00, 0x00, 0x00, 0x00, 0x00]);
    });

    test('long-press keypair emits long-press bit (0x20) instead of short-press', () async {
      await emulator.sendAction(
        _channelPair(InGameAction.dFlyChannel4, longPress: true),
        isKeyDown: true,
        isKeyUp: false,
      );
      expect(transporter.sent.single.data, [0x00, 0x00, 0x00, 0x00, 0x20]);
    });

    test('multiple channels held simultaneously combine in one packet', () async {
      await emulator.sendAction(
        _channelPair(InGameAction.dFlyChannel1),
        isKeyDown: true,
        isKeyUp: false,
      );
      await emulator.sendAction(
        _channelPair(InGameAction.dFlyChannel3),
        isKeyDown: true,
        isKeyUp: false,
      );
      expect(transporter.sent.last.data, [0x00, 0x10, 0x00, 0x10, 0x00]);
    });

    test('non-D-Fly action returns NotHandled and emits nothing', () async {
      final result = await emulator.sendAction(
        _channelPair(InGameAction.shiftUp),
        isKeyDown: true,
        isKeyUp: false,
      );
      expect(result, isA<NotHandled>());
      expect(transporter.sent, isEmpty);
    });
  });
}
