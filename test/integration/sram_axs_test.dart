import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/sram/sram_axs.dart' show SramAxs;
import 'package:bike_control/bluetooth/emulation/emulated_ble_platform.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:flutter_test/flutter_test.dart';
// prop.dart exports a `SramAxs` *constants* class that collides with the app's
// `SramAxs` *device* class (imported above) — bring it in under a prefix.
import 'package:prop/prop.dart' as prop;
// The SRAM device side (bond handshake, reaction-config bookkeeping, press
// framing) lives in the private prop package — see prop/lib/testing/.
import 'package:prop/testing.dart';

import 'harness/test_env.dart';

/// Binds prop's [FakeSramDerailleur] to the app's fake BLE platform: the
/// peripheral model, the write routing and the notification delivery. Wiring
/// only — the device's behaviour is prop's.
class SramDerailleurHost {
  SramDerailleurHost(this.env)
      : peripheral = FakePeripheral(
          deviceId: 'fake-sram-axs',
          name: 'SRAM Rival AXS',
          advertisedServices: FakeSramDerailleur.advertisedServices,
          services: FakeSramDerailleur.buildServices(),
        ) {
    fake = FakeSramDerailleur(
      notify: (characteristic, value) => env.ble.notify(peripheral.deviceId, characteristic, value),
      onReadValue: (characteristic, value) => peripheral.readValues[characteristic] = value,
    );
    peripheral.onWrite = fake.handleWrite;
  }

  final IntegrationEnv env;
  final FakePeripheral peripheral;
  late final FakeSramDerailleur fake;

  String get deviceId => peripheral.deviceId;
  bool get derailleurUnassigned => fake.derailleurUnassigned;
  void pressPaddle(int serial) => fake.pressPaddle(serial);
}

/// End-to-end SRAM AXS shifter chain: fake-BLE bond handshake -> guided
/// setup (bond + backup + disable on-device shifting) -> encrypted button
/// press -> decoded logical button -> keymap/action dispatch. Everything real
/// except the BLE platform and the final action executor (StubActions records
/// instead of pressing keys).
Future<void> main() async {
  final env = await IntegrationEnv.setUp();
  late StubActions stubActions;

  core.connection.initialize();

  setUp(() async {
    await env.resetState();
    stubActions = StubActions();
    stubActions.supportedApp = Zwift();
    core.actionHandler = stubActions;
  });

  tearDown(() async {
    await env.resetConnection();
  });

  Future<(SramDerailleurHost, SramAxs)> connectSram() async {
    final derailleur = SramDerailleurHost(env);
    env.ble.addPeripheral(derailleur.peripheral);
    await core.connection.performScanning();
    await IntegrationEnv.waitFor(
      () => core.connection.devices.whereType<SramAxs>().isNotEmpty,
      description: 'SRAM AXS derailleur in device list',
    );
    final device = core.connection.devices.whereType<SramAxs>().first;
    // handleServices() (which wires up SramAxsLogic/SramBleTransport and
    // subscribes to the control-trigger/component-event/bond characteristics)
    // runs as the tail of BluetoothDevice.connect() — the device is already
    // in core.connection.devices before that finishes. Wait for the
    // subscribe side effect so setupControl() doesn't race a still-null
    // internal logic instance (mirrors waiting on the Zwift RideOn write in
    // controller_button_chain_test.dart).
    await IntegrationEnv.waitFor(
      () => derailleur.peripheral.subscriptions.isNotEmpty,
      description: 'SRAM AXS handleServices subscriptions',
    );
    return (derailleur, device);
  }

  test('bonds, disables on-device shifting, and decodes a paddle press', () async {
    final (derailleur, device) = await connectSram();

    await device.setupControl();

    expect(device.isBonded, isTrue, reason: 'the bond handshake should have produced a session key');
    expect(device.isShiftingDisabled, isTrue);
    expect(derailleur.derailleurUnassigned, isTrue, reason: 'disableShifting() should have cleared a reaction slot');

    derailleur.pressPaddle(0x12345678);

    await IntegrationEnv.waitFor(
      () => stubActions.performedActions.isNotEmpty,
      description: 'performed action for the decoded paddle press',
    );

    expect(device.availableButtons.any((b) => b.name.contains('Shifter A')), isTrue);
    final action = stubActions.performedActions.single;
    expect(action.button.name, contains('Shifter A'));
    expect(action.trigger, ButtonTrigger.singleClick);
  });

  test('Disconnect & forget drops learned buttons, so stale entries do not come back', () async {
    final (derailleur, device) = await connectSram();
    await device.setupControl();
    derailleur.pressPaddle(0x12345678);
    await IntegrationEnv.waitFor(
      () => core.settings.getSramButtons(derailleur.deviceId).isNotEmpty,
      description: 'the press to be learned',
    );
    final key = core.settings.getSramKey(derailleur.deviceId);
    expect(key, isNotNull);

    await core.connection.disconnect(device, persistForget: true, forget: true);

    expect(core.settings.getSramButtons(derailleur.deviceId), isEmpty);
    // The bond survives: re-adding the derailleur must not force a new setup.
    expect(core.settings.getSramKey(derailleur.deviceId), key);
  });

  test('re-running setup does not wipe the saved backup', () async {
    final (derailleur, device) = await connectSram();

    await device.setupControl();
    expect(device.isShiftingDisabled, isTrue);

    final backupAfterFirstRun = core.settings.getSramBackup(derailleur.deviceId);
    expect(backupAfterFirstRun, isNotNull);
    expect(backupAfterFirstRun, isNotEmpty, reason: 'the original (still-assigned) config should have been captured');

    // "Re-run SRAM setup": shifting is already disabled, so the derailleur's
    // reaction slots are already cleared — backupConfig() would read an EMPTY
    // config here if setupControl() blindly re-captured it.
    await device.setupControl();
    expect(device.isShiftingDisabled, isTrue);

    final backupAfterSecondRun = core.settings.getSramBackup(derailleur.deviceId);
    expect(backupAfterSecondRun, isNotNull);
    expect(
      jsonEncode(backupAfterSecondRun!.map((k, v) => MapEntry(k, v.toJson()))),
      jsonEncode(backupAfterFirstRun!.map((k, v) => MapEntry(k, v.toJson()))),
      reason: 'the stored backup must survive a re-run of setup unchanged',
    );

    // And the surviving backup is real: restoring re-writes the reaction char.
    await device.restoreShifting();
    expect(device.isShiftingDisabled, isFalse);
    expect(core.settings.getSramBackup(derailleur.deviceId), isNull, reason: 'restore clears the backup for a fresh future capture');
  });

  test('a GATT timeout while clearing the shifting config resets the link so a retry runs on a fresh one', () async {
    final (derailleur, device) = await connectSram();
    final reactionChars = {prop.SramAxs.reactionChar1.toLowerCase(), prop.SramAxs.reactionChar2.toLowerCase()};
    // The derailleur stops answering config writes, exactly like a wedged
    // link: universal_ble's queue gives up after 10 s with a TimeoutException.
    var wedged = true;
    derailleur.peripheral.onWrite = (service, characteristic, value) {
      if (wedged && reactionChars.contains(characteristic.toLowerCase())) {
        throw TimeoutException('Future not completed', const Duration(seconds: 10));
      }
      derailleur.fake.handleWrite(service, characteristic, value);
    };

    await expectLater(
      device.setupControl(),
      throwsA(isA<TimeoutException>().having((e) => e.toString(), 'message', contains('(write '))),
    );
    expect(device.isShiftingDisabled, isFalse);
    final backup = core.settings.getSramBackup(derailleur.deviceId);
    expect(backup, isNotNull, reason: 'the original config captured before the hang must survive');

    // The wedged link is torn down; the same device entry stays listed and is
    // reconnected by the regular rediscovery path.
    expect(device.isResetting, isTrue);
    await IntegrationEnv.waitFor(() => !derailleur.peripheral.isConnected, description: 'wedged link torn down');
    expect(core.connection.devices, contains(device));

    wedged = false;
    // The still-running scan sees the derailleur advertising again.
    env.ble.updateScanResult(derailleur.peripheral.scanResult);
    await IntegrationEnv.waitFor(
      () => device.isConnected && !device.isResetting,
      description: 'same device reconnected on a fresh link',
    );

    await device.setupControl();
    expect(device.isShiftingDisabled, isTrue);
    expect(derailleur.derailleurUnassigned, isTrue);
    expect(
      jsonEncode(core.settings.getSramBackup(derailleur.deviceId)!.map((k, v) => MapEntry(k, v.toJson()))),
      jsonEncode(backup!.map((k, v) => MapEntry(k, v.toJson()))),
      reason: 'the retry must not overwrite the saved backup',
    );
  });

  test('a refused authorization (create-bond decrypt failed) keeps the connection up', () async {
    final (derailleur, device) = await connectSram();
    final bondChar = prop.SramAxs.bondChar.toLowerCase();
    bool isInit(List<int> v) => v.length == 16 && [for (var i = 0; i < 16; i++) v[i] == i].every((b) => b);
    // AXS button not held: the derailleur answers the app's public key with a
    // create-bond frame that doesn't decrypt.
    derailleur.peripheral.onWrite = (service, characteristic, value) {
      if (characteristic.toLowerCase() == bondChar && value.length == 16 && !isInit(value)) {
        env.ble.notify(derailleur.deviceId, prop.SramAxs.bondChar, Uint8List(48));
        return;
      }
      derailleur.fake.handleWrite(service, characteristic, value);
    };

    await expectLater(
      device.setupControl(),
      throwsA(isA<prop.SramBondException>().having((e) => e.message, 'message', contains('decrypt failed'))),
    );

    // Give a (wrongly) triggered disconnect time to land (the fake platform
    // delivers it 400 ms later).
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(device.isResetting, isFalse);
    expect(derailleur.peripheral.isConnected, isTrue);
    expect(device.isConnected, isTrue);
  });

  // NOTE on trigger semantics: SramAxs no longer resolves its own tap-count
  // gesture. It emits ONE physical button press (down + release) per 0xFF
  // trigger, identified by (serial, mask), and lets BaseDevice's shared
  // single-vs-double-click machinery (`_handleSingleButtonTap`, a 320ms
  // window) decide the trigger. The integration harness's Zwift keymap has
  // no double-click mapping for a freshly-discovered SRAM button, so
  // `_hasTriggerAction(button, ButtonTrigger.doubleClick)` is false and every
  // press resolves to its own immediate `ButtonTrigger.singleClick` (see
  // base_device.dart:277-279). Same-name edges inside the 90ms combo window
  // coalesce as duplicates (the iOS read-response echo of one tap), so the two
  // taps here are spaced beyond it — as any two real presses of one lever are.
  test('two presses on the same identity each resolve to an immediate single click', () async {
    final (derailleur, device) = await connectSram();
    await device.setupControl();

    // Two taps on the SAME controller serial, spaced past the combo window.
    derailleur.pressPaddle(0x11111111);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    derailleur.pressPaddle(0x11111111);

    await IntegrationEnv.waitFor(
      () => stubActions.performedActions.length >= 2,
      description: 'two single-click actions',
    );

    expect(stubActions.performedActions.length, 2);
    expect(stubActions.performedActions.every((a) => a.trigger == ButtonTrigger.singleClick), isTrue);
    expect(stubActions.performedActions.every((a) => a.button.name.contains('Shifter A')), isTrue);
    // Only one physical button was ever discovered for this identity.
    expect(device.availableButtons.where((b) => b.name.contains('Shifter A')).length, 1);
  });

  test('presses from two different identities discover two distinct shifter buttons', () async {
    final (derailleur, device) = await connectSram();
    await device.setupControl();

    derailleur.pressPaddle(0x11111111);
    derailleur.pressPaddle(0x22222222);

    await IntegrationEnv.waitFor(
      () => stubActions.performedActions.length >= 2,
      description: 'two independent single-click actions',
    );

    expect(stubActions.performedActions.length, 2);
    expect(stubActions.performedActions.every((a) => a.trigger == ButtonTrigger.singleClick), isTrue);
    // Different serials => different "Shifter" labels, assigned in first-seen order.
    expect(stubActions.performedActions[0].button.name, contains('Shifter A'));
    expect(stubActions.performedActions[1].button.name, contains('Shifter B'));
    expect(device.availableButtons.any((b) => b.name.contains('Shifter A')), isTrue);
    expect(device.availableButtons.any((b) => b.name.contains('Shifter B')), isTrue);
  });

  test('a rapid multishift burst is suppressed to at most two presses while shifting is enabled (§7)', () async {
    final (derailleur, device) = await connectSram();
    // Deliberately NO setupControl: with shifting still enabled the derailleur
    // multishifts while held and bursts triggers — the one state the §7 guard
    // protects. (Post-setup a held lever emits exactly ONE edge — 16fad263's
    // --observe capture — so the guard doesn't run there; see the test below.)
    // Edges are spaced past the 90ms combo window so they can't just coalesce:
    // without the guard this burst would dispatch four presses.
    for (var i = 0; i < 4; i++) {
      derailleur.pressPaddle(0x33333333);
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }

    await IntegrationEnv.waitFor(
      () => stubActions.performedActions.isNotEmpty,
      description: 'at least one press from the burst',
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // The 3rd+ trigger of a rapid chain is dropped, so a hold can't spam
    // presses in a loop.
    expect(stubActions.performedActions.length, lessThanOrEqualTo(2));
  });

  test('once shifting is disabled, rapid deliberate taps are all delivered (no §7 guard)', () async {
    final (derailleur, device) = await connectSram();
    await device.setupControl();

    // Three quick same-lever taps (~150ms cadence — a rider dumping gears).
    // Post-setup every edge is a genuine tap and none may be swallowed.
    for (var i = 0; i < 3; i++) {
      derailleur.pressPaddle(0x44444444);
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }

    await IntegrationEnv.waitFor(
      () => stubActions.performedActions.length >= 3,
      description: 'all three rapid taps dispatched',
    );
    expect(stubActions.performedActions.length, 3);
    expect(stubActions.performedActions.every((a) => a.trigger == ButtonTrigger.singleClick), isTrue);
  });

  test('a read-response echoed on the trigger characteristic is not a press (§6.1)', () async {
    final (derailleur, device) = await connectSram();
    await device.setupControl();

    derailleur.pressPaddle(0x44444444);
    await IntegrationEnv.waitFor(
      () => stubActions.performedActions.isNotEmpty,
      description: 'the real 0xFF-edge press',
    );
    final countAfterPress = stubActions.performedActions.length;

    // Simulate iOS/CoreBluetooth delivering the READ response of d9050054
    // through the notify callback — a multi-byte encrypted value, not the 0xFF
    // edge. Treating it as a press would spin an infinite read loop.
    final echoed = derailleur.peripheral.readValues[prop.SramAxs.controlTriggerChar.toLowerCase()]!;
    env.ble.notify(derailleur.peripheral.deviceId, prop.SramAxs.controlTriggerChar, echoed);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(stubActions.performedActions.length, countAfterPress, reason: 'the multi-byte echo must be ignored');
  });

  // The real crash report: SRAM AXS + trainer app selected, but the keymap
  // pref ('app') never resolved, so `supportedApp` was null. Every press threw
  // "Null check operator used on a null value" (swallowed into a log line) and
  // the device surfaced zero buttons, so the edit screen was empty too.
  test('a paddle press with no keymap set still registers the button and does not error', () async {
    stubActions.supportedApp = null;
    core.actionHandler.supportedApp = null;

    final (derailleur, device) = await connectSram();
    await device.setupControl();

    final logs = <String>[];
    final sub = device.actionStream.listen((n) {
      if (n is LogNotification) logs.add(n.message);
    });

    derailleur.pressPaddle(0x12345678);

    await IntegrationEnv.waitFor(
      () => device.availableButtons.isNotEmpty,
      description: 'the decoded paddle button registered on the device',
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await sub.cancel();

    expect(
      logs.where((m) => m.contains('Error handling button clicks')),
      isEmpty,
      reason: 'a missing keymap must not throw out of handleButtonsClicked',
    );
    expect(
      device.availableButtons.any((b) => b.name.contains('Shifter A')),
      isTrue,
      reason: 'without a keymap the button must still be exposed for editing',
    );
  });

  // Only button-bearing SRAM controllers surface in `sramShifterAdverts`. A
  // front derailleur advertises the same service but must NOT leak in and mint
  // a phantom button.
  test('sramShifterAdverts includes button-bearing shifters but excludes FD/POST', () async {
    env.ble.addPeripheral(FakePeripheral(
      deviceId: 'fake-sram-shifter',
      name: 'SRAM Shifter',
      advertisedServices: FakeSramDerailleur.advertisedServices,
      serviceData: {
        prop.SramAdvertisement.serviceUuid128: SramAdvertFixtures.shifter(serial: 170),
      },
    ));
    env.ble.addPeripheral(FakePeripheral(
      deviceId: 'fake-sram-fd',
      name: 'SRAM FD',
      advertisedServices: FakeSramDerailleur.advertisedServices,
      serviceData: {
        prop.SramAdvertisement.serviceUuid128: SramAdvertFixtures.frontDerailleur(serial: 187),
      },
    ));

    await core.connection.performScanning();
    await IntegrationEnv.waitFor(
      () => core.connection.sramShifterAdverts.any((i) => i.serial == 170),
      description: 'shifter advert retained in sramShifterAdverts',
    );

    final serials = core.connection.sramShifterAdverts.map((i) => i.serial).toSet();
    expect(serials, contains(170), reason: 'the type-0 drop-bar shifter has buttons and must surface');
    expect(serials, isNot(contains(187)), reason: 'the front derailleur (type 128) has no buttons and must be excluded');

    // Neither is a rear derailleur, so neither becomes a connectable SramAxs.
    expect(core.connection.devices.whereType<SramAxs>(), isEmpty);
  });
}
