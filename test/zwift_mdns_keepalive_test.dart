import 'package:bike_control/bluetooth/devices/zwift/controller_keep_alive.dart';
import 'package:bike_control/bluetooth/devices/zwift/ftms_mdns_emulator.dart';
import 'package:bike_control/bluetooth/devices/zwift/rouvy_mdns_emulator.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart' show ftmsEmulator;
import 'package:bike_control/gen/l10n.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/ble_definition.dart';
import 'package:prop/emulators/transporter/transporter.dart';
import 'package:prop/prop.dart';

/// The Zwift Click/Ride controller characteristic both emulators notify on.
const _controllerCharacteristicUuid = '00000002-19CA-4651-86E5-FA29DCDD09D1';

/// Captures notifications pushed through the composite definition (FTMS path).
class _RecordingTransporter extends Transporter {
  _RecordingTransporter(BleDefinition def) : super(definition: def);

  final List<({String uuid, List<int> data})> sent = [];

  @override
  void sendCharacteristicNotification(String characteristicUUID, List<int> data, {int responseCode = 0}) {
    sent.add((uuid: characteristicUUID, data: List.of(data)));
  }
}

/// Captures the raw controller frames the Rouvy emulator writes.
class _RecordingClickEmulator extends ClickEmulator {
  final List<List<int>> notifications = [];

  @override
  void writeNotification(List<int> bytes) => notifications.add(List.of(bytes));
}

void main() {
  setUpAll(() async {
    await AppLocalizations.load(const Locale('en'));
  });

  group('FtmsMdnsEmulator keepalive', () {
    test('sendKeepAlive emits the released controller state on the controller characteristic', () {
      final emulator = FtmsMdnsEmulator();
      final recording = _RecordingTransporter(ftmsEmulator.composite);
      addTearDown(() => ftmsEmulator.composite.transporter = null);

      emulator.sendKeepAlive();

      expect(recording.sent, hasLength(1));
      expect(recording.sent.single.uuid, _controllerCharacteristicUuid);
      expect(
        recording.sent.single.data,
        [Opcode.CONTROLLER_NOTIFICATION.value, ...kZwiftControllerReleasedState],
      );
    });

    test('keepalive runs only while connected', () {
      final emulator = FtmsMdnsEmulator();
      addTearDown(emulator.keepAlive.stop);

      emulator.updateKeepAlive(true);
      expect(emulator.keepAlive.isRunning, isTrue);

      emulator.updateKeepAlive(false);
      expect(emulator.keepAlive.isRunning, isFalse);
    });
  });

  group('RouvyMdnsEmulator keepalive', () {
    test('sendKeepAlive writes the released controller state', () {
      final recording = _RecordingClickEmulator();
      final emulator = RouvyMdnsEmulator(clickEmulator: recording);

      emulator.sendKeepAlive();

      expect(recording.notifications, [kZwiftControllerReleasedState]);
    });

    test('keepalive runs only while connected', () {
      final emulator = RouvyMdnsEmulator(clickEmulator: _RecordingClickEmulator());
      addTearDown(emulator.keepAlive.stop);

      emulator.updateKeepAlive(true);
      expect(emulator.keepAlive.isRunning, isTrue);

      emulator.updateKeepAlive(false);
      expect(emulator.keepAlive.isRunning, isFalse);
    });
  });
}
