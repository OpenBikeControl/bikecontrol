import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/bluetooth/emulation/emulated_ble_platform.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/prop.dart' show FtmsMdnsConstants, propPrefs;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

/// Records every BLE write, whatever device it targets.
class _RecordingBlePlatform extends FakeUniversalBlePlatform {
  final List<({String deviceId, String characteristic, Uint8List value})> writes = [];

  @override
  Future<void> writeValue(
    String deviceId,
    String service,
    String characteristic,
    Uint8List value,
    BleOutputProperty bleOutputProperty,
  ) async {
    writes.add((deviceId: deviceId, characteristic: characteristic, value: value));
  }
}

const _deviceId = 'click-v2';

/// The challenge a locked Click V2 sends on its async characteristic.
final _challenge = Uint8List.fromList([0xFF, 0x03, 0x00, 0x0A, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16]);

/// The long-form answer that unlocks it (≥ 10 bytes after the opcode).
final _longReply = Uint8List.fromList([
  0xFF, 0x04, 0x00, 0x0A, 0x15, 0x5B, 0x9A, 0x50, 0xAF, 0xDF, 0x47, 0x41, 0xCA, 0x11, //
]);

/// The short form — not an unlock on its own.
final _shortReply = Uint8List.fromList([0xFF, 0x04, 0x00]);

ZwiftClickV2 _connectedClick() {
  final click = ZwiftClickV2(BleDevice(deviceId: _deviceId, name: 'Zwift Click'));
  final syncRx = BleCharacteristic(ZwiftConstants.ZWIFT_SYNC_RX_CHARACTERISTIC_UUID.toLowerCase(), [], []);
  click.customService = BleService(ZwiftConstants.ZWIFT_RIDE_CUSTOM_SERVICE_UUID.toLowerCase(), [syncRx]);
  click.syncRxCharacteristic = syncRx;
  return click;
}

Future<void> _receiveChallenge(ZwiftClickV2 click) =>
    click.processCharacteristic(FtmsMdnsConstants.ZWIFT_ASYNC_CHARACTERISTIC_UUID, _challenge);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingBlePlatform ble;

  setUpAll(() async {
    await AppLocalizations.load(const Locale('en'));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    propPrefs.initialize(core.settings.prefs);
    core.actionHandler = StubActions();
    ble = _RecordingBlePlatform();
    UniversalBle.setInstance(ble);
    core.rouvyMdnsEmulator.clickEmulator.clearChallenge();
  });

  List<Uint8List> writesToClick() => [
    for (final w in ble.writes)
      if (w.deviceId == _deviceId &&
          w.characteristic.toUpperCase() == FtmsMdnsConstants.ZWIFT_SYNC_RX_CHARACTERISTIC_UUID)
        w.value,
  ];

  group('with Rouvy selected', () {
    setUp(() => core.settings.setTrainerApp(Rouvy()));

    test("the Click's challenge reaches the Rouvy endpoint", () async {
      final click = _connectedClick();

      await _receiveChallenge(click);

      expect(core.rouvyMdnsEmulator.clickEmulator.pendingChallenge, _challenge);
    });

    test("Rouvy's long reply is written to the Click and unlocks it", () async {
      final click = _connectedClick();
      await _receiveChallenge(click);

      core.rouvyMdnsEmulator.clickEmulator.onAuthResponse!(_longReply);
      await Future<void>.delayed(Duration.zero);

      expect(writesToClick().first, _longReply);
      expect(click.isUnlocked.value, isTrue);
      expect(click.isPersistedUnlocked, isTrue);
      // Unlocked: nothing left for a later Rouvy connection to answer.
      expect(core.rouvyMdnsEmulator.clickEmulator.pendingChallenge, isNull);
      // And the Click is started, as on a connect while unlocked.
      expect(writesToClick().skip(1), anyElement(equals(ZwiftConstants.RIDE_ON)));
    });

    test("a short reply is forwarded but doesn't count as unlocked", () async {
      final click = _connectedClick();
      await _receiveChallenge(click);

      core.rouvyMdnsEmulator.clickEmulator.onAuthResponse!(_shortReply);
      await Future<void>.delayed(Duration.zero);

      expect(writesToClick(), [_shortReply]);
      expect(click.isUnlocked.value, isFalse);
      expect(core.rouvyMdnsEmulator.clickEmulator.pendingChallenge, _challenge);
    });

    test('an already unlocked Click sends nothing to Rouvy', () async {
      final click = _connectedClick();
      click.isUnlocked.value = true;

      await _receiveChallenge(click);

      expect(core.rouvyMdnsEmulator.clickEmulator.pendingChallenge, isNull);
    });

    test('disconnecting the Click withdraws its challenge', () async {
      final click = _connectedClick();
      await _receiveChallenge(click);

      await click.disconnect();

      expect(core.rouvyMdnsEmulator.clickEmulator.pendingChallenge, isNull);
    });

    test('switching to Rouvy after the challenge came in still relays it', () async {
      core.settings.setTrainerApp(Zwift());
      final click = _connectedClick();
      await _receiveChallenge(click);
      expect(core.rouvyMdnsEmulator.clickEmulator.pendingChallenge, isNull);

      core.settings.setTrainerApp(Rouvy());
      click.onTrainerAppChanged();

      expect(core.rouvyMdnsEmulator.clickEmulator.pendingChallenge, _challenge);
    });
  });

  test('with Zwift selected the Rouvy endpoint is left alone', () async {
    core.settings.setTrainerApp(Zwift());
    final click = _connectedClick();

    await _receiveChallenge(click);

    expect(core.rouvyMdnsEmulator.clickEmulator.pendingChallenge, isNull);
    expect(writesToClick(), isEmpty);
  });
}
