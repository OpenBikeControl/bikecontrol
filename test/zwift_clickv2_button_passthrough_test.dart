import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/ftms_mdns_emulator.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart' show ftmsEmulator;
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/ble_definition.dart';
import 'package:prop/emulators/definitions/zwift_click_definition.dart';
import 'package:prop/emulators/definitions/zwift_emulator_definition.dart';
import 'package:prop/emulators/transporter/transporter.dart';
import 'package:prop/prop.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

/// The Zwift Click/Ride controller characteristic. Both the physical Click's
/// own frames and the emulator's mapped actions travel on this one.
const _controllerCharacteristicUuid = '00000002-19CA-4651-86E5-FA29DCDD09D1';

/// Everything that reaches the trainer app.
class _RecordingTransporter extends Transporter {
  _RecordingTransporter(BleDefinition definition) : super(definition: definition);

  final List<({String uuid, List<int> data})> sent = [];

  @override
  void sendCharacteristicNotification(String characteristicUUID, List<int> data, {int responseCode = 0}) {
    sent.add((uuid: characteristicUUID, data: List.of(data)));
  }
}

ZwiftClickDefinition _clickDefinition() => ZwiftClickDefinition(
  services: const <BleService>[],
  device: BleDevice(deviceId: 'click-v2', name: 'Zwift Click'),
  data: ValueNotifier<String>(''),
  vendorMessage: null,
  isUnlocked: ValueNotifier<bool>(false),
  alreadyUnlocked: ValueNotifier<bool>(false),
  waiting: ValueNotifier<bool>(false),
  isStarted: ValueNotifier<bool>(true),
  connectionDate: DateTime(2026),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppLocalizations.load(const Locale('en'));
  });

  group('Zwift Click V2 press reaches the trainer app once', () {
    late _RecordingTransporter recording;
    late ZwiftClickDefinition clickDef;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      core.settings.prefs = await SharedPreferences.getInstance();
      recording = _RecordingTransporter(ftmsEmulator.composite);
      clickDef = _clickDefinition();
      ftmsEmulator.composite.attach(clickDef);
    });

    tearDown(() {
      ftmsEmulator.composite.detach(clickDef);
      ftmsEmulator.composite.transporter = null;
    });

    test('the raw frame from the physical Click is not relayed', () {
      // What ZwiftClickV2.processCharacteristic hands to the emulator on every
      // press. Relaying it lets Zwift act on the button natively — on top of
      // the mapped action below.
      ftmsEmulator.composite.onNotification(
        _controllerCharacteristicUuid,
        Uint8List.fromList([Opcode.CONTROLLER_NOTIFICATION.value, 0x08, 0xFF, 0xFF, 0xFE, 0xFF, 0x0F]),
      );

      expect(recording.sent, isEmpty);
    });

    test('the mapped action is still delivered, exactly once', () async {
      await FtmsMdnsEmulator().sendAction(
        KeyPair(
          buttons: [ZwiftButtons.navigationDown],
          physicalKey: null,
          logicalKey: null,
          inGameAction: InGameAction.rideOnBomb,
        ),
        isKeyDown: true,
        isKeyUp: false,
      );

      expect(recording.sent, hasLength(1));
      expect(recording.sent.single.uuid, _controllerCharacteristicUuid);
      expect(recording.sent.single.data.first, Opcode.CONTROLLER_NOTIFICATION.value);
    });
  });

  test('once off the bridge, a press is not relayed by what is left on it', () async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    propPrefs.initialize(core.settings.prefs);
    core.actionHandler = StubActions();
    // BikeControl's own controller, back on the bridge after the unlock.
    final ours = ZwiftEmulatorDefinition(device: BleDevice(deviceId: 'controller', name: 'BikeControl'));
    ftmsEmulator.debugSetActiveDefinition(ours);
    final recording = _RecordingTransporter(ftmsEmulator.composite);
    addTearDown(() {
      ftmsEmulator.composite.detach(ours);
      ftmsEmulator.composite.transporter = null;
    });
    final click = ZwiftClickV2(BleDevice(deviceId: 'click-v2', name: 'Zwift Click'));
    click.debugSetClickDef(_clickDefinition()); // not attached

    await click.processCharacteristic(
      _controllerCharacteristicUuid,
      Uint8List.fromList([Opcode.CONTROLLER_NOTIFICATION.value, 0x08, 0xFF, 0xFF, 0xFE, 0xFF, 0x0F]),
    );

    expect(recording.sent, isEmpty);
  });
}
