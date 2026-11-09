import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/ftms_mdns_emulator.dart';
import 'package:bike_control/bluetooth/devices/zwift/ride_controller_press.dart';
import 'package:bike_control/bluetooth/devices/zwift/rouvy_mdns_emulator.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart' show ftmsEmulator;
import 'package:bike_control/bluetooth/devices/zwift/zwift_emulator.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart' show RideButtonMask;
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/biketerra.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/transporter/transporter.dart';
import 'package:prop/prop.dart' hide RideButtonMask;
import 'package:prop/protocol/zp_support.dart' show ZpPacket;
import 'package:shared_preferences/shared_preferences.dart';

/// Captures the raw controller frames the Rouvy emulator writes.
class _RecordingClickEmulator extends ClickEmulator {
  final List<List<int>> notifications = [];

  @override
  void writeNotification(List<int> bytes) => notifications.add(List.of(bytes));
}

/// Captures the frames the shared DirCon composite would push to a client, so
/// [FtmsMdnsEmulator] can be exercised without a live transport.
class _RecordingTransporter extends Transporter {
  _RecordingTransporter({required super.definition});

  final List<List<int>> notifications = [];

  @override
  void sendCharacteristicNotification(String characteristicUUID, List<int> data, {int responseCode = 0}) {
    notifications.add(List.of(data));
  }
}

/// Stands in for the platform side of universal_ble's peripheral channel, so
/// [ZwiftEmulator]'s notify path can be exercised off-device.
class _RecordingPeripheralChannel {
  static const _channel = 'dev.flutter.pigeon.universal_ble.UniversalBlePeripheralChannel.updateCharacteristic';
  static const _codec = StandardMessageCodec();

  final List<List<int>> notifications = [];

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(_channel, (message) async {
      final args = _codec.decodeMessage(message)! as List<Object?>;
      notifications.add(List<int>.from(args[1]! as Uint8List));
      return _codec.encodeMessage(<Object?>[null]);
    });
  }

  void remove() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(_channel, null);
  }
}

KeyPair _pair(InGameAction action) => KeyPair(
  buttons: [ControllerButton('Test', action: action)],
  physicalKey: null,
  logicalKey: null,
  inGameAction: action,
);

/// The Rouvy emulator writes the bare protobuf; the Zwift/FTMS ones prefix the
/// controller-notification opcode.
int _buttonMapOf(List<int> frame, {bool hasOpcode = false}) =>
    RideKeyPadStatus.fromBuffer(hasOpcode ? frame.sublist(1) : frame).buttonMap;

int _released(RideButtonMask button) => (~button.mask) & 0xFFFFFFFF;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppLocalizations.load(const Locale('en'));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
  });

  // Rouvy renames two Zwift Click V2 actions for its own UI — the Y button is
  // Kudos and the Z button is Pause. Buttons are stored and delivered under the
  // renamed action, so every emulator has to resolve it back to the controller
  // action before looking up the physical button. Getting that reverse lookup
  // wrong made exactly Pause and Kudos report "No connection method active"
  // while every unmapped action (shifting, steering, A/B) kept working.
  group('RouvyMdnsEmulator resolves app-specific actions', () {
    setUp(() => core.settings.setTrainerApp(Rouvy()));

    test('pause presses the Z button', () async {
      final click = _RecordingClickEmulator();
      final emulator = RouvyMdnsEmulator(clickEmulator: click);

      final result = await emulator.sendAction(_pair(InGameAction.pause), isKeyDown: true, isKeyUp: false);

      expect(result, isA<Success>());
      expect(_buttonMapOf(click.notifications.single), _released(RideButtonMask.Z_BTN));
    });

    test('kudos presses the Y button', () async {
      final click = _RecordingClickEmulator();
      final emulator = RouvyMdnsEmulator(clickEmulator: click);

      final result = await emulator.sendAction(_pair(InGameAction.kudos), isKeyDown: true, isKeyUp: false);

      expect(result, isA<Success>());
      expect(_buttonMapOf(click.notifications.single), _released(RideButtonMask.Y_BTN));
    });

    test('an unmapped action still reaches its button', () async {
      final click = _RecordingClickEmulator();
      final emulator = RouvyMdnsEmulator(clickEmulator: click);

      final result = await emulator.sendAction(_pair(InGameAction.shiftUp), isKeyDown: true, isKeyUp: false);

      expect(result, isA<Success>());
      expect(_buttonMapOf(click.notifications.single), _released(RideButtonMask.SHFT_UP_R_BTN));
    });

    test('the raw controller actions behind the mapping keep working', () async {
      final click = _RecordingClickEmulator();
      final emulator = RouvyMdnsEmulator(clickEmulator: click);

      final bomb = await emulator.sendAction(_pair(InGameAction.rideOnBomb), isKeyDown: true, isKeyUp: false);
      expect(bomb, isA<Success>());
      expect(_buttonMapOf(click.notifications.single), _released(RideButtonMask.Z_BTN));

      final powerUp = await emulator.sendAction(_pair(InGameAction.usePowerUp), isKeyDown: true, isKeyUp: false);
      expect(powerUp, isA<Success>());
      expect(_buttonMapOf(click.notifications.last), _released(RideButtonMask.Y_BTN));
    });

    test('an action the emulator has no button for is still reported unhandled', () async {
      final click = _RecordingClickEmulator();
      final emulator = RouvyMdnsEmulator(clickEmulator: click);

      final result = await emulator.sendAction(_pair(InGameAction.frontShift), isKeyDown: true, isKeyUp: false);

      expect(result, isA<NotHandled>());
      expect(click.notifications, isEmpty);
    });
  });

  group('FtmsMdnsEmulator resolves app-specific actions', () {
    late _RecordingTransporter transporter;

    setUp(() {
      core.settings.setTrainerApp(Rouvy());
      transporter = _RecordingTransporter(definition: ftmsEmulator.composite);
      addTearDown(transporter.dispose);
    });

    test('pause presses the Z button', () async {
      final result = await FtmsMdnsEmulator().sendAction(
        _pair(InGameAction.pause),
        isKeyDown: true,
        isKeyUp: false,
      );

      expect(result, isA<Success>());
      expect(_buttonMapOf(transporter.notifications.single, hasOpcode: true), _released(RideButtonMask.Z_BTN));
    });

    test('kudos presses the Y button', () async {
      final result = await FtmsMdnsEmulator().sendAction(
        _pair(InGameAction.kudos),
        isKeyDown: true,
        isKeyUp: false,
      );

      expect(result, isA<Success>());
      expect(_buttonMapOf(transporter.notifications.single, hasOpcode: true), _released(RideButtonMask.Y_BTN));
    });

    test('an unmapped action still reaches its button', () async {
      final result = await FtmsMdnsEmulator().sendAction(
        _pair(InGameAction.shiftUp),
        isKeyDown: true,
        isKeyUp: false,
      );

      expect(result, isA<Success>());
      expect(
        _buttonMapOf(transporter.notifications.single, hasOpcode: true),
        _released(RideButtonMask.SHFT_UP_R_BTN),
      );
    });

    test('the raw controller actions behind the mapping keep working', () async {
      final emulator = FtmsMdnsEmulator();

      final bomb = await emulator.sendAction(_pair(InGameAction.rideOnBomb), isKeyDown: true, isKeyUp: false);
      expect(bomb, isA<Success>());
      expect(_buttonMapOf(transporter.notifications.single, hasOpcode: true), _released(RideButtonMask.Z_BTN));

      final powerUp = await emulator.sendAction(_pair(InGameAction.usePowerUp), isKeyDown: true, isKeyUp: false);
      expect(powerUp, isA<Success>());
      expect(_buttonMapOf(transporter.notifications.last, hasOpcode: true), _released(RideButtonMask.Y_BTN));
    });
  });

  group('ZwiftEmulator resolves app-specific actions', () {
    late _RecordingPeripheralChannel channel;

    setUp(() {
      core.settings.setTrainerApp(Rouvy());
      channel = _RecordingPeripheralChannel()..install();
      addTearDown(channel.remove);
    });

    test('pause presses the Z button', () async {
      final result = await ZwiftEmulator().sendAction(_pair(InGameAction.pause), isKeyDown: true, isKeyUp: false);

      expect(result, isA<Success>());
      expect(_buttonMapOf(channel.notifications.single, hasOpcode: true), _released(RideButtonMask.Z_BTN));
    });

    test('kudos presses the Y button', () async {
      final result = await ZwiftEmulator().sendAction(_pair(InGameAction.kudos), isKeyDown: true, isKeyUp: false);

      expect(result, isA<Success>());
      expect(_buttonMapOf(channel.notifications.single, hasOpcode: true), _released(RideButtonMask.Y_BTN));
    });

    test('an unmapped action still reaches its button', () async {
      final result = await ZwiftEmulator().sendAction(_pair(InGameAction.shiftUp), isKeyDown: true, isKeyUp: false);

      expect(result, isA<Success>());
      expect(
        _buttonMapOf(channel.notifications.single, hasOpcode: true),
        _released(RideButtonMask.SHFT_UP_R_BTN),
      );
    });

    test('the raw controller actions behind the mapping keep working', () async {
      final emulator = ZwiftEmulator();

      final bomb = await emulator.sendAction(_pair(InGameAction.rideOnBomb), isKeyDown: true, isKeyUp: false);
      expect(bomb, isA<Success>());
      expect(_buttonMapOf(channel.notifications.single, hasOpcode: true), _released(RideButtonMask.Z_BTN));

      final powerUp = await emulator.sendAction(_pair(InGameAction.usePowerUp), isKeyDown: true, isKeyUp: false);
      expect(powerUp, isA<Success>());
      expect(_buttonMapOf(channel.notifications.last, hasOpcode: true), _released(RideButtonMask.Y_BTN));
    });

    test('front shift still takes its own combo path', () async {
      final result = await ZwiftEmulator().sendAction(
        _pair(InGameAction.frontShift),
        isKeyDown: true,
        isKeyUp: false,
      );

      expect(result, isA<Success>());
      expect(
        _buttonMapOf(channel.notifications.first, hasOpcode: true),
        (~(RideButtonMask.SHFT_UP_R_BTN.mask | RideButtonMask.SHFT_UP_L_BTN.mask)) & 0xFFFFFFFF,
      );
    });
  });

  group('Ride controls', () {
    const buttons = {
      InGameAction.leftDropButton: RideButtonMask.POWERUP_L_BTN,
      InGameAction.rightDropButton: RideButtonMask.POWERUP_R_BTN,
      InGameAction.leftShiftButton2: RideButtonMask.SHFT_DN_L_BTN,
      InGameAction.rightShiftButton2: RideButtonMask.SHFT_DN_R_BTN,
    };

    setUp(() => core.settings.setTrainerApp(Zwift()));

    for (final MapEntry(key: action, value: button) in buttons.entries) {
      test('${action.name} presses ${button.name} over Bluetooth', () async {
        final channel = _RecordingPeripheralChannel()..install();
        addTearDown(channel.remove);

        final result = await ZwiftEmulator().sendAction(_pair(action), isKeyDown: true, isKeyUp: false);

        expect(result, isA<Success>());
        expect(_buttonMapOf(channel.notifications.single, hasOpcode: true), _released(button));
      });

      test('${action.name} presses ${button.name} over the network', () async {
        final transporter = _RecordingTransporter(definition: ftmsEmulator.composite);
        addTearDown(transporter.dispose);

        final result = await FtmsMdnsEmulator().sendAction(_pair(action), isKeyDown: true, isKeyUp: false);

        expect(result, isA<Success>());
        expect(_buttonMapOf(transporter.notifications.single, hasOpcode: true), _released(button));
      });
    }

    Map<RideAnalogLocation, int> paddlesOf(List<int> frame) => {
      for (final p in RideKeyPadStatus.fromBuffer(frame.sublist(1)).analogPaddles) p.location: p.analogValue,
    };

    test('steering pulls a paddle while held and lets go on release', () async {
      final channel = _RecordingPeripheralChannel()..install();
      addTearDown(channel.remove);

      final result = await ZwiftEmulator().sendAction(_pair(InGameAction.steerLeft), isKeyDown: true, isKeyUp: true);

      expect(result, isA<Success>());
      final [down, up] = channel.notifications;
      expect(_buttonMapOf(down, hasOpcode: true), 0xFFFFFFFF);
      expect(paddlesOf(down), {RideAnalogLocation.LEFT: -100});
      expect(paddlesOf(up), {RideAnalogLocation.LEFT: 0});
    });

    test('steering right pulls the right paddle over the network', () async {
      final transporter = _RecordingTransporter(definition: ftmsEmulator.composite);
      addTearDown(transporter.dispose);

      await FtmsMdnsEmulator().sendAction(_pair(InGameAction.steerRight), isKeyDown: true, isKeyUp: false);

      final frame = transporter.notifications.single;
      expect(_buttonMapOf(frame, hasOpcode: true), 0xFFFFFFFF);
      expect(paddlesOf(frame), {RideAnalogLocation.RIGHT: 100});
    });

    test('apps without a Ride keep steering on the D-pad', () async {
      core.settings.setTrainerApp(Biketerra());
      final channel = _RecordingPeripheralChannel()..install();
      addTearDown(channel.remove);

      await ZwiftEmulator().sendAction(_pair(InGameAction.steerLeft), isKeyDown: true, isKeyUp: false);

      final frame = channel.notifications.single;
      expect(_buttonMapOf(frame, hasOpcode: true), _released(RideButtonMask.LEFT_BTN));
      expect(paddlesOf(frame), isEmpty);
    });

    test('brake tilts both paddles inward over the network', () async {
      final transporter = _RecordingTransporter(definition: ftmsEmulator.composite);
      addTearDown(transporter.dispose);

      await FtmsMdnsEmulator().sendAction(_pair(InGameAction.brake), isKeyDown: true, isKeyUp: true);

      final [down, up] = transporter.notifications;
      expect(paddlesOf(down), {RideAnalogLocation.LEFT: 100, RideAnalogLocation.RIGHT: -100});
      expect(paddlesOf(up), {RideAnalogLocation.LEFT: 0, RideAnalogLocation.RIGHT: 0});
    });

    test('navigating presses the D-pad', () async {
      final channel = _RecordingPeripheralChannel()..install();
      addTearDown(channel.remove);

      await ZwiftEmulator().sendAction(_pair(InGameAction.navigateLeft), isKeyDown: true, isKeyUp: false);

      expect(_buttonMapOf(channel.notifications.single, hasOpcode: true), _released(RideButtonMask.LEFT_BTN));
    });

    test('Navigate is a Zwift action', () {
      expect(appControllerActions(core.zwiftEmulator.supportedActions), contains(InGameAction.navigateLeft));
    });
  });

  group('device info', () {
    DevInfoPage devInfo({required bool asRide}) {
      final request = Uint8List.fromList([
        Opcode.GET.value,
        ...Get(dataObjectId: DO.PAGE_DEV_INFO.value).writeToBuffer(),
      ]);
      final response = SharedLogic.handleWriteRequest(
        ZwiftConstants.ZWIFT_SYNC_RX_CHARACTERISTIC_UUID,
        request,
        asRide: asRide,
      )!;
      return DevInfoPage.fromBuffer(
        ZpPacket.unwrapObjectData(GetResponse.fromBuffer(response.sublist(1)).dataObjectData),
      );
    }

    test('answers as a Ride for Zwift and as a Click otherwise', () {
      expect(devInfo(asRide: true).productId, 8);
      expect(devInfo(asRide: false).productId, 11);
    });

    test('only Zwift gets the Ride', () {
      core.settings.setTrainerApp(Zwift());
      expect(RideControllerPress.emulatesRide, isTrue);
      core.settings.setTrainerApp(CustomApp());
      expect(RideControllerPress.emulatesRide, isFalse);
    });
  });

  group('Ride controls are only offered for Zwift', () {
    setUp(() async {
      await core.settings.setZwiftMdnsEmulatorEnabled(true);
      await core.settings.setZwiftBleEmulatorEnabled(true);
    });

    test('Zwift offers them', () {
      core.settings.setTrainerApp(Zwift());

      expect(appControllerActions(core.zwiftEmulator.supportedActions), containsAll(rideOnlyActions));
      expect(_pair(InGameAction.brake).hasActiveAction, isTrue);
    });

    test('a custom app does not', () {
      core.settings.setTrainerApp(CustomApp());

      expect(appControllerActions(core.zwiftEmulator.supportedActions).toSet().intersection(rideOnlyActions), isEmpty);
    });

    test('Rouvy does not', () {
      core.settings.setTrainerApp(Rouvy());

      final actions = appControllerActions(core.zwiftEmulator.supportedActions);
      expect(actions.toSet().intersection(rideOnlyActions), isEmpty);
      expect(actions, containsAll([InGameAction.kudos, InGameAction.pause]));
      expect(_pair(InGameAction.rightDropButton).hasActiveAction, isFalse);
    });

    test('Biketerra does not', () {
      core.settings.setTrainerApp(Biketerra());

      expect(appControllerActions(core.zwiftEmulator.supportedActions).toSet().intersection(rideOnlyActions), isEmpty);
    });
  });

  // The button editor offers the app-facing names (Kudos / Pause), so a button
  // assigned from that list carries the mapped action. hasActiveAction has to
  // resolve it the same way the emulators do, or the editor lists an action it
  // then reports as doing nothing.
  group('KeyPair.hasActiveAction accounts for the app mapping', () {
    setUp(() async {
      core.settings.setTrainerApp(Rouvy());
      await core.settings.setZwiftMdnsEmulatorEnabled(true);
      await core.settings.setZwiftBleEmulatorEnabled(true);
    });

    test('a mapped network action counts as active', () {
      expect(_pair(InGameAction.pause).hasActiveAction, isTrue);
      expect(_pair(InGameAction.kudos).hasActiveAction, isTrue);
    });

    test('the raw controller actions behind the mapping stay active', () {
      expect(_pair(InGameAction.rideOnBomb).hasActiveAction, isTrue);
      expect(_pair(InGameAction.usePowerUp).hasActiveAction, isTrue);
    });

    test('an action no emulator handles stays inactive', () {
      expect(_pair(InGameAction.tuck).hasActiveAction, isFalse);
    });

    test('the mapping does not leak into apps that do not define one', () {
      core.settings.setTrainerApp(Zwift());

      expect(_pair(InGameAction.pause).hasActiveAction, isFalse);
      expect(_pair(InGameAction.rideOnBomb).hasActiveAction, isTrue);
    });
  });
}
