import 'dart:async';
import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/base_device.dart' show DeviceSetupNeed;
import 'package:bike_control/bluetooth/devices/shimano/shimano_ble_transport.dart';
import 'package:bike_control/bluetooth/devices/shimano/shimano_di2.dart';
import 'package:bike_control/bluetooth/devices/shimano/shimano_setup_sheet.dart' show ShimanoSetupCancelled, ShimanoShifterAsk;
import 'package:bike_control/bluetooth/emulation/emulated_ble_platform.dart' show FakePeripheral, FakeUniversalBlePlatform;
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/openbikecontrol.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/prop.dart' hide Set;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

Future<void> main() async {
  final stubActions = StubActions();
  stubActions.supportedApp = OpenBikeControl();

  SharedPreferences.setMockInitialValues({});
  await core.settings.init();
  core.actionHandler = stubActions;

  group('Shimano Di2 button mode', () {
    const rightLeverDown = ShimanoPaddleEvent(ShimanoShifter.right, ShimanoPaddle.big, ShimanoPaddleState.down);
    const rightLeverHeld = ShimanoPaddleEvent(ShimanoShifter.right, ShimanoPaddle.big, ShimanoPaddleState.held);
    const rightLeverUp = ShimanoPaddleEvent(ShimanoShifter.right, ShimanoPaddle.big, ShimanoPaddleState.released);

    test('a paddle press is one click of its button; held repeats are ignored', () async {
      stubActions.cleanup();
      final instance = ShimanoDi2(BleDevice(name: 'RDR7150', deviceId: 'di2'))..registerPaddleButtons();

      instance.onPaddle(rightLeverDown);
      instance.onPaddle(rightLeverHeld);
      instance.onPaddle(rightLeverHeld);
      instance.onPaddle(rightLeverUp);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(stubActions.performedActions, [
        PerformedAction(ShimanoDi2Buttons.rightLever, isDown: true, isUp: true),
      ]);
    });

    test('a hood button press is a click of its own button, which only shows up once pressed', () async {
      stubActions.cleanup();
      final instance = ShimanoDi2(BleDevice(name: 'RDR9250', deviceId: 'di2-hood'))..registerPaddleButtons();
      expect(instance.availableButtons.map((b) => b.name), isNot(contains(ShimanoDi2Buttons.rightHood.name)));

      instance.onPaddle(const ShimanoPaddleEvent(ShimanoShifter.right, ShimanoPaddle.hood, ShimanoPaddleState.down));
      instance.onPaddle(const ShimanoPaddleEvent(ShimanoShifter.right, ShimanoPaddle.hood, ShimanoPaddleState.released));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(instance.availableButtons.map((b) => b.name), contains(ShimanoDi2Buttons.rightHood.name));
      expect(stubActions.performedActions, [
        PerformedAction(ShimanoDi2Buttons.rightHood, isDown: true, isUp: true),
      ]);
    });

    test('button telemetry it cannot decode is logged with its raw bytes, repeats only once', () async {
      final instance = ShimanoDi2(BleDevice(name: 'RDR9250', deviceId: 'di2-unknown'));
      final logs = <String>[];
      final sub = instance.actionStream.listen((n) {
        if (n is LogNotification) logs.add(n.message);
      });

      instance.onUnknownFrame(ShimanoPce.fromHex('33411802e5e4e0e001ff'));
      instance.onUnknownFrame(ShimanoPce.fromHex('33411802e5e4e0e001ff'));
      instance.onUnknownFrame(ShimanoPce.fromHex('33411802e5e420e001ff'));
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(logs, [
        'ShimanoDi2 unknown button frame: 33411802e5e4e0e001ff',
        'ShimanoDi2 unknown button frame: 33411802e5e420e001ff',
      ]);
    });

    test('every Di2 button has a spot on the contour', () {
      for (final button in ShimanoDi2Buttons.values) {
        expect(ShimanoDi2Buttons.layout.positions.keys, contains(button), reason: button.name);
      }
    });

    test('the paddle buttons are known buttons, so a saved keymap keeps their labels', () {
      for (final button in ShimanoDi2Buttons.values) {
        final known = ControllerButton.values.firstWhere((b) => b.name == button.name);
        expect(known.label, button.label);
        expect(known.action, button.action);
      }
    });

    test('each paddle maps to its own button', () {
      ControllerButton of(ShimanoShifter s, ShimanoPaddle p) =>
          ShimanoDi2Buttons.of(ShimanoPaddleEvent(s, p, ShimanoPaddleState.down));
      expect(of(ShimanoShifter.left, ShimanoPaddle.big), ShimanoDi2Buttons.leftLever);
      expect(of(ShimanoShifter.left, ShimanoPaddle.small), ShimanoDi2Buttons.leftButton);
      expect(of(ShimanoShifter.right, ShimanoPaddle.big), ShimanoDi2Buttons.rightLever);
      expect(of(ShimanoShifter.right, ShimanoPaddle.small), ShimanoDi2Buttons.rightButton);
      expect(of(ShimanoShifter.left, ShimanoPaddle.hood), ShimanoDi2Buttons.leftHood);
      expect(of(ShimanoShifter.right, ShimanoPaddle.hood), ShimanoDi2Buttons.rightHood);
      expect(of(ShimanoShifter.left, ShimanoPaddle.satellite), ShimanoDi2Buttons.leftSatellite);
      expect(of(ShimanoShifter.right, ShimanoPaddle.satellite), ShimanoDi2Buttons.rightSatellite);
    });
  });

  group('Shimano Di2 button mode setup', () {
    test('a stored passkey the Di2 rejects on connect switches button mode off, so setup asks again', () async {
      final instance = ShimanoDi2(BleDevice(name: 'RDR7150', deviceId: 'di2-passkey'));
      await core.settings.setShimanoButtonMode('di2-passkey', true);

      await instance.autoEnterButtonMode(() async => throw ShimanoPasskeyRejectedException(0x01));

      expect(core.settings.getShimanoButtonMode('di2-passkey'), isFalse);
    });

    test('a Di2 that does not answer on connect keeps button mode on for the next connect', () async {
      final instance = ShimanoDi2(BleDevice(name: 'RDR7150', deviceId: 'di2-asleep'));
      await core.settings.setShimanoButtonMode('di2-asleep', true);

      await instance.autoEnterButtonMode(() async => throw TimeoutException('asleep'));

      expect(core.settings.getShimanoButtonMode('di2-asleep'), isTrue);
    });

    test('button mode fails as unresponsive when the Di2 answers none of its steps', () async {
      final instance = ShimanoDi2(BleDevice(name: 'RDR7150', deviceId: 'di2-silent'));

      await expectLater(instance.startButtonSession(_FakeShimanoTransport(fail: true)), throwsA(isA<TimeoutException>()));
      expect(instance.availableButtons, isEmpty);
    });

    test('button mode registers the paddles when the Di2 answers', () async {
      final instance = ShimanoDi2(BleDevice(name: 'RDR7150', deviceId: 'di2-awake'));

      await instance.startButtonSession(_FakeShimanoTransport(fail: false));

      expect(instance.availableButtons.map((b) => b.name), containsAll(ShimanoDi2Buttons.paddles.map((b) => b.name)));
    });

    // A rider's log must tell a 2AF9 subscription that never delivers (no
    // presses although the Di2 stopped shifting) from presses lost later.
    test('the log shows failed button mode steps and how many replies arrived', () async {
      final instance = ShimanoDi2(BleDevice(name: 'RDR7150', deviceId: 'di2-diag'));
      final logs = <String>[];
      final sub = instance.actionStream.listen((n) {
        if (n is LogNotification) logs.add(n.message);
      });

      await instance.startButtonSession(
        _FakeShimanoTransport(fail: false, failSubscribe: true, replies: [Uint8List.fromList([0x25, 0x00])]),
      );
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(logs, contains(startsWith('ShimanoDi2 button mode step ')));
      expect(logs.where((l) => l.contains('button mode step')), everyElement(contains('subscribe refused')));
      expect(logs.firstWhere((l) => l.contains('button mode active')), matches(RegExp(r'^ShimanoDi2 button mode active: \d+ steps answered, [1-9]\d* failed, 1 replies on 2af9$')));
    });

    // Wired Di2 shifters may report presses in a shape the decoder doesn't
    // know: the log shows every frame that arrives once button mode is on.
    test('the log shows the frames the Di2 sends once button mode is active', () async {
      final live = StreamController<Uint8List>.broadcast();
      final instance = ShimanoDi2(BleDevice(name: 'RDR7150', deviceId: 'di2-frames'));
      final logs = <String>[];
      final sub = instance.actionStream.listen((n) {
        if (n is LogNotification) logs.add(n.message);
      });

      await instance.startButtonSession(_FakeShimanoTransport(fail: false, live: live));
      live.add(Uint8List.fromList([0x33, 0x42, 0x01, 0x02]));
      live.add(Uint8List.fromList([0x33, 0x42, 0x01, 0x02]));
      live.add(Uint8List.fromList([0x25, 0x0c]));
      for (var i = 0; i < 60; i++) {
        live.add(Uint8List.fromList([0x40, i]));
      }
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      await live.close();

      final frames = logs.where((l) => l.startsWith('ShimanoDi2 frame after button mode: ')).toList();
      expect(frames.take(2), ['ShimanoDi2 frame after button mode: 33420102', 'ShimanoDi2 frame after button mode: 250c']);
      expect(frames, hasLength(50));
    });

    // Wired 11-speed shifters report their switches on 2AFD instead of 2AF9.
    test('the log shows the 2AFD frames the Di2 sends once button mode is active', () async {
      final aux = StreamController<Uint8List>.broadcast();
      final instance = ShimanoDi2(BleDevice(name: 'RDR8050', deviceId: 'di2-aux-frames'));
      final logs = <String>[];
      final sub = instance.actionStream.listen((n) {
        if (n is LogNotification) logs.add(n.message);
      });

      await instance.startButtonSession(_FakeShimanoTransport(fail: false, aux: aux));
      aux.add(Uint8List.fromList([0x03, 0x04, 0x00, 0x02]));
      aux.add(Uint8List.fromList([0x03, 0x04, 0x00, 0x02]));
      aux.add(Uint8List.fromList([0x03, 0x04, 0x00, 0x12]));
      for (var i = 0; i < 60; i++) {
        aux.add(Uint8List.fromList([0x40, i]));
      }
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      await aux.close();

      final frames = logs.where((l) => l.startsWith('ShimanoDi2 2afd frame after button mode: ')).toList();
      expect(frames.take(2), [
        'ShimanoDi2 2afd frame after button mode: 03040002',
        'ShimanoDi2 2afd frame after button mode: 03040012',
      ]);
      expect(frames, hasLength(50));
    });

    // Some Di2 RDs relay nothing on 2AF9 or 2AFD in button mode; 2AFB is the
    // last characteristic the sequence subscribes to.
    test('the log shows the 2AFB frames the Di2 sends once button mode is active', () async {
      final aux1 = StreamController<Uint8List>.broadcast();
      final instance = ShimanoDi2(BleDevice(name: 'RDR9250', deviceId: 'di2-aux1-frames'));
      final logs = <String>[];
      final sub = instance.actionStream.listen((n) {
        if (n is LogNotification) logs.add(n.message);
      });

      await instance.startButtonSession(_FakeShimanoTransport(fail: false, aux1: aux1));
      aux1.add(Uint8List.fromList([0x33, 0x41, 0x18, 0x00]));
      aux1.add(Uint8List.fromList([0x33, 0x41, 0x18, 0x00]));
      aux1.add(Uint8List.fromList([0x33, 0x41, 0x18, 0x01]));
      for (var i = 0; i < 60; i++) {
        aux1.add(Uint8List.fromList([0x40, i]));
      }
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      await aux1.close();

      final frames = logs.where((l) => l.startsWith('ShimanoDi2 2afb frame after button mode: ')).toList();
      expect(frames.take(2), [
        'ShimanoDi2 2afb frame after button mode: 33411800',
        'ShimanoDi2 2afb frame after button mode: 33411801',
      ]);
      expect(frames, hasLength(50));
    });

    // The hood and satellite byte positions are not confirmed on hardware yet:
    // every hood or satellite press is logged raw, even after the general frame
    // log has stopped.
    test('the log shows the raw frame of every hood or satellite press', () async {
      final live = StreamController<Uint8List>.broadcast();
      final instance = ShimanoDi2(BleDevice(name: 'RDR9250', deviceId: 'di2-hood-frames'));
      final logs = <String>[];
      final sub = instance.actionStream.listen((n) {
        if (n is LogNotification) logs.add(n.message);
      });

      await instance.startButtonSession(_FakeShimanoTransport(fail: false, live: live));
      for (var i = 0; i < 60; i++) {
        live.add(Uint8List.fromList([0x40, i]));
      }
      live.add(_hex('33411801e5e4e00001ff')); // right hood down
      live.add(_hex('33411801e5e4e00001ff'));
      live.add(_hex('33411801e5e4e02001ff')); // right hood released
      live.add(_hex('33411801e5e4e0e001ff')); // no hood or satellite press
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      await live.close();

      expect(logs.where((l) => l.startsWith('ShimanoDi2 hood/satellite frame: ')), [
        'ShimanoDi2 hood/satellite frame: 33411801e5e4e00001ff',
        'ShimanoDi2 hood/satellite frame: 33411801e5e4e02001ff',
      ]);
    });
  });

  group('Shimano Di2 E-TUBE channels', () {
    // Button frames as a 105 Di2 sends them: the right shifter on its factory
    // setting, the left one with Front Up / Front Down.
    final rightFactory = _hex('33411801e5e4e0e001ff');
    final leftFactory = _hex('33411800e2e3e0e001ff');
    final rightOnDfly = _hex('33411801f6f7e0e001ff');
    final leftOnDfly = _hex('33411800f4f5e0e001ff');

    setUp(() => ShimanoDi2.debugSwitchWriteQuiet = Duration.zero);
    tearDown(() {
      ShimanoDi2.debugEnterButtonMode = null;
      ShimanoDi2.debugSwitchWriteQuiet = null;
      ShimanoDi2.debugSwitchReadyDelay = null;
    });

    ({ShimanoDi2 di2, _SwitchingShimanoTransport t}) connected(String id) {
      final t = _SwitchingShimanoTransport();
      final di2 = ShimanoDi2(BleDevice(name: 'RDR7150', deviceId: id))
        ..debugUseConfigTransport(t)
        ..isConnected = true;
      ShimanoDi2.debugEnterButtonMode = (d, passkey) async {};
      return (di2: di2, t: t);
    }

    Future<void> untilWaitingForShifters(ShimanoDi2 di2) async {
      while (di2.shifterAsk.value == null) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test('setup saves what the paddles did and puts them on D-Fly channels', () async {
      final (:di2, :t) = connected('di2-channels');
      final asks = <ShimanoShifterAsk?>[];
      di2.shifterAsk.addListener(() => asks.add(di2.shifterAsk.value));

      final setup = di2.setupChannels(passkey: '000000');
      await untilWaitingForShifters(di2);
      t.press(leftFactory);
      t.press(rightFactory);
      await setup;

      expect(t.switchWrites, ['00134120000111abff0000', '00134120010111cdff0000']);
      expect(di2.switchBackup, [
        ShimanoShifterSwitches.fromTelemetry(leftFactory),
        ShimanoShifterSwitches.fromTelemetry(rightFactory),
      ]);
      expect(di2.isDflyChosen, isTrue);
      expect(di2.isButtonModeEnabled, isFalse);
      expect(asks, [
        const ShimanoShifterAsk({}),
        const ShimanoShifterAsk({ShimanoShifter.left}),
        const ShimanoShifterAsk({ShimanoShifter.left, ShimanoShifter.right}),
        const ShimanoShifterAsk({}, saving: true),
        const ShimanoShifterAsk({ShimanoShifter.left}, saving: true),
        const ShimanoShifterAsk({ShimanoShifter.left, ShimanoShifter.right}, saving: true),
        null,
      ]);
    });

    // Hardware: a press within half a second of the write didn't save it, one
    // a second and more later did.
    test('the shifter to press is shown only once its write had time to reach the Di2', () async {
      final t = _SwitchingShimanoTransport(confirms: false);
      final di2 = ShimanoDi2(BleDevice(name: 'RDR7150', deviceId: 'di2-channels-ready'))
        ..debugUseConfigTransport(t)
        ..isConnected = true;
      ShimanoDi2.debugEnterButtonMode = (d, passkey) async {};
      ShimanoDi2.debugSwitchReadyDelay = const Duration(milliseconds: 20);

      final setup = di2.setupChannels(passkey: '000000');
      await untilWaitingForShifters(di2);
      t.press(leftFactory);
      t.press(rightFactory);
      while (t.switchWrites.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(di2.shifterAsk.value, const ShimanoShifterAsk({}, saving: true));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(di2.shifterAsk.value, const ShimanoShifterAsk({}, saving: true, next: ShimanoShifter.left));

      di2.cancelShifterWait();
      await expectLater(setup, throwsA(isA<ShimanoSetupCancelled>()));
    });

    test('the left shifter is written first, whichever was pressed first', () async {
      final (:di2, :t) = connected('di2-channels-order');

      final setup = di2.setupChannels(passkey: '000000');
      await untilWaitingForShifters(di2);
      t.press(rightFactory);
      t.press(leftFactory);
      await setup;

      expect(t.switchWrites, ['00134120000111abff0000', '00134120010111cdff0000']);
    });

    test('a shifter that needs no change counts as saved', () async {
      final (:di2, :t) = connected('di2-channels-one');
      final asks = <ShimanoShifterAsk?>[];
      di2.shifterAsk.addListener(() => asks.add(di2.shifterAsk.value));

      final setup = di2.setupChannels(passkey: '000000');
      await untilWaitingForShifters(di2);
      t.press(leftOnDfly);
      t.press(rightFactory);
      await setup;

      expect(asks.where((a) => a?.saving ?? false), [
        const ShimanoShifterAsk({ShimanoShifter.left}, saving: true),
        const ShimanoShifterAsk({ShimanoShifter.left, ShimanoShifter.right}, saving: true),
      ]);
    });

    // Rider log (XT Di2, right shifter only): the one shifter reports slot 0.
    // The save step asked for it and ticked a right shifter never seen.
    test('a Di2 with one shifter is saved with that one, nothing else ticked', () async {
      ShimanoDi2.debugOneShifterGrace = Duration.zero;
      addTearDown(() => ShimanoDi2.debugOneShifterGrace = null);
      final (:di2, :t) = connected('di2-channels-single');
      final asks = <ShimanoShifterAsk?>[];
      di2.shifterAsk.addListener(() => asks.add(di2.shifterAsk.value));

      final setup = di2.setupChannels(passkey: '000000');
      await untilWaitingForShifters(di2);
      t.press(leftFactory);
      await setup;

      expect(t.switchWrites, ['00134120000111abff0000']);
      expect(di2.isDflyChosen, isTrue);
      expect(asks.where((a) => a?.saving ?? false), [
        const ShimanoShifterAsk({}, saving: true, single: true),
        const ShimanoShifterAsk({ShimanoShifter.left}, saving: true, single: true),
      ]);
    });

    test('restoring a single shifter asks for that one only', () async {
      final (:di2, :t) = connected('di2-channels-restore-single');
      await core.settings.setShimanoDfly('di2-channels-restore-single', true);
      await core.settings.setShimanoSwitchBackup('di2-channels-restore-single', [
        ShimanoShifterSwitches.fromTelemetry(leftFactory)!,
      ]);
      final asks = <ShimanoShifterAsk?>[];
      di2.shifterAsk.addListener(() => asks.add(di2.shifterAsk.value));

      final restore = di2.restoreSwitches(passkey: '000000');
      await untilWaitingForShifters(di2);
      t.press(leftOnDfly);
      await restore;

      expect(t.switchWrites, ['0013412000011101ff0000']);
      expect(asks.whereType<ShimanoShifterAsk>().every((a) => a.single), isTrue);
    });

    test('a setup cancelled while it waits for the shifters writes nothing', () async {
      final (:di2, :t) = connected('di2-channels-cancel');

      final setup = di2.setupChannels(passkey: '000000');
      await untilWaitingForShifters(di2);
      t.press(leftFactory);
      di2.cancelShifterWait();

      await expectLater(setup, throwsA(isA<ShimanoSetupCancelled>()));
      expect(t.switchWrites, isEmpty);
      expect(di2.isDflyChosen, isFalse);
      expect(di2.shifterAsk.value, isNull);
    });

    test('a rejected passkey: BikeControl keeps the link, the Di2 drops it, reconnecting quietly', () async {
      final (:di2, :t) = connected('di2-channels-wrong-passkey');
      ShimanoDi2.debugEnterButtonMode = (d, passkey) async => throw ShimanoPasskeyRejectedException(0x02);

      await expectLater(di2.setupChannels(passkey: '000000'), throwsA(isA<ShimanoPasskeyRejectedException>()));

      expect(di2.isConnected, isTrue);
      expect(di2.isResetting, isFalse);
      expect(t.switchWrites, isEmpty);

      // The Di2 then drops the link itself: BikeControl expects it and
      // reconnects without connection toasts.
      di2.isConnected = false;
      expect(di2.isResetting, isTrue);
    });

    test('a finished setup drops the link, which ends the configuration mode', () async {
      final (:di2, :t) = connected('di2-channels-drop');

      final setup = di2.setupChannels(passkey: '000000');
      await untilWaitingForShifters(di2);
      t.press(leftOnDfly);
      t.press(rightOnDfly);
      await setup;

      expect(di2.isConnected, isFalse);
      // A planned drop: reconnect quietly, without connection toasts.
      expect(di2.isResetting, isTrue);
    });

    test('the passkey is kept once the Di2 accepted it, even if the setup stops there', () async {
      final (:di2, t: _) = connected('di2-channels-passkey');

      final setup = di2.setupChannels(passkey: '123456');
      await untilWaitingForShifters(di2);
      di2.cancelShifterWait();
      await expectLater(setup, throwsA(isA<ShimanoSetupCancelled>()));

      expect(core.settings.getShimanoPasskey('di2-channels-passkey'), '123456');
    });

    test('paddles already on their D-Fly channels are left alone', () async {
      final (:di2, :t) = connected('di2-channels-already');

      final setup = di2.setupChannels(passkey: '000000');
      await untilWaitingForShifters(di2);
      t.press(leftOnDfly);
      t.press(rightOnDfly);
      await setup;

      expect(t.switchWrites, isEmpty);
      expect(di2.switchBackup, isEmpty);
      expect(di2.isDflyChosen, isTrue);
    });

    test('a second setup keeps the first backup', () async {
      final (:di2, :t) = connected('di2-channels-twice');
      await core.settings.setShimanoSwitchBackup('di2-channels-twice', [
        ShimanoShifterSwitches.fromTelemetry(rightFactory)!,
      ]);

      final setup = di2.setupChannels(passkey: '000000');
      await untilWaitingForShifters(di2);
      t.press(leftFactory);
      t.press(_hex('33411801f6e4e0e001ff')); // right half on D-Fly
      await setup;

      expect(di2.switchBackup, [ShimanoShifterSwitches.fromTelemetry(rightFactory)]);
    });

    test('presses while the shifters are read trigger no action', () async {
      stubActions.cleanup();
      final (:di2, :t) = connected('di2-channels-quiet');

      final setup = di2.setupChannels(passkey: '000000');
      await untilWaitingForShifters(di2);
      di2.onPaddle(const ShimanoPaddleEvent(ShimanoShifter.right, ShimanoPaddle.big, ShimanoPaddleState.down));
      t.press(leftFactory);
      t.press(rightFactory);
      await setup;

      expect(stubActions.performedActions, isEmpty);
    });

    test('restore writes the saved setting back and forgets it', () async {
      final (:di2, :t) = connected('di2-channels-restore');
      await core.settings.setShimanoDfly('di2-channels-restore', true);
      await core.settings.setShimanoSwitchBackup('di2-channels-restore', [
        ShimanoShifterSwitches.fromTelemetry(leftFactory)!,
        ShimanoShifterSwitches.fromTelemetry(rightFactory)!,
      ]);

      final restore = di2.restoreSwitches(passkey: '000000');
      await untilWaitingForShifters(di2);
      t.press(rightOnDfly);
      t.press(leftOnDfly);
      await restore;

      expect(t.switchWrites, ['0013412000011101ff0000', '0013412001011132ff0000']);
      expect(di2.switchBackup, isEmpty);
      expect(di2.isDflyChosen, isFalse);
    });

    test('channel buttons BikeControl assigned get the actions of their paddles', () async {
      final (:di2, t: _) = connected('di2-channels-actions');
      await core.settings.setShimanoDfly('di2-channels-actions', true);
      // Without a keymap the buttons stay on the device instead of being
      // registered in the shared one the other tests read.
      final app = core.actionHandler.supportedApp;
      core.actionHandler.supportedApp = null;
      addTearDown(() => core.actionHandler.supportedApp = app);

      await di2.processCharacteristic(ShimanoDi2Constants.D_FLY_CHANNEL_UUID, Uint8List.fromList([0, 0, 0, 0, 0]));

      expect(
        [for (var ch = 1; ch <= 4; ch++) di2.availableButtons.firstWhere((b) => b.name == 'D-Fly Channel $ch').action],
        [
          ShimanoDi2Buttons.leftButton.action,
          ShimanoDi2Buttons.leftLever.action,
          ShimanoDi2Buttons.rightButton.action,
          ShimanoDi2Buttons.rightLever.action,
        ],
      );
    });

    test('with E-TUBE channels chosen the channel buttons are there before the first press', () async {
      const id = 'di2-channels-listed';
      await core.settings.setShimanoDfly(id, true);
      final services = [
        BleService(ShimanoDi2Constants.SERVICE_UUID, [
          BleCharacteristic(ShimanoDi2Constants.D_FLY_CHANNEL_UUID, [CharacteristicProperty.indicate], []),
        ]),
      ];
      final ble = FakeUniversalBlePlatform()..addPeripheral(FakePeripheral(deviceId: id, name: 'Di2', services: services));
      UniversalBle.setInstance(ble);
      await ble.connect(id);
      final app = core.actionHandler.supportedApp;
      core.actionHandler.supportedApp = null;
      addTearDown(() => core.actionHandler.supportedApp = app);
      final di2 = ShimanoDi2(BleDevice(name: 'Di2', deviceId: id))..firmwareVersion = '4.1.0.0';

      await di2.handleServices(services);

      expect([for (final b in di2.availableButtons) b.name], [
        'D-Fly Channel 1',
        'D-Fly Channel 2',
        'D-Fly Channel 3',
        'D-Fly Channel 4',
      ]);
    });

    group('D-Fly reports', () {
      // Captured on an RD-R7150: a fresh link numbers its reports from 0x20
      // and starts every channel at f0; each press counts the channel up
      // (11, 12, …).
      Uint8List report(String hex) => _hex(hex);

      Future<_PressRecordingDi2> fresh(String id) async {
        final services = [
          BleService(ShimanoDi2Constants.SERVICE_UUID, [
            BleCharacteristic(ShimanoDi2Constants.D_FLY_CHANNEL_UUID, [CharacteristicProperty.indicate], []),
          ]),
        ];
        final ble = FakeUniversalBlePlatform()
          ..addPeripheral(FakePeripheral(deviceId: id, name: 'Di2', services: services));
        UniversalBle.setInstance(ble);
        await ble.connect(id);
        final di2 = _PressRecordingDi2(BleDevice(name: 'Di2', deviceId: id))..firmwareVersion = '4.1.0.0';
        await di2.handleServices(services);
        return di2;
      }

      setUp(() {
        final app = core.actionHandler.supportedApp;
        core.actionHandler.supportedApp = null;
        addTearDown(() => core.actionHandler.supportedApp = app);
      });

      test('the first report of a link already carries a press', () async {
        final di2 = await fresh('di2-dfly-first');

        await di2.processCharacteristic(ShimanoDi2Constants.D_FLY_CHANNEL_UUID, report('20f011f0f0'));
        await di2.processCharacteristic(ShimanoDi2Constants.D_FLY_CHANNEL_UUID, report('21f011f011'));
        await di2.processCharacteristic(ShimanoDi2Constants.D_FLY_CHANNEL_UUID, report('22f011f012'));

        expect(di2.pressed, ['D-Fly Channel 2', 'D-Fly Channel 4', 'D-Fly Channel 4']);
      });

      test('a report from the middle of a link only sets where the channels are', () async {
        final di2 = await fresh('di2-dfly-midway');

        await di2.processCharacteristic(ShimanoDi2Constants.D_FLY_CHANNEL_UUID, report('2511121112'));
        await di2.processCharacteristic(ShimanoDi2Constants.D_FLY_CHANNEL_UUID, report('2611121113'));

        expect(di2.pressed, ['D-Fly Channel 4']);
      });

      // Captured when the restore put the RD into its configuration mode.
      test('channels reset to f0 are no press', () async {
        final di2 = await fresh('di2-dfly-reset');
        await di2.processCharacteristic(ShimanoDi2Constants.D_FLY_CHANNEL_UUID, report('20f011f0f0'));
        await di2.processCharacteristic(ShimanoDi2Constants.D_FLY_CHANNEL_UUID, report('21f011f011'));

        await di2.processCharacteristic(ShimanoDi2Constants.D_FLY_CHANNEL_UUID, report('22f0f0f0f0'));

        expect(di2.pressed, ['D-Fly Channel 2', 'D-Fly Channel 4']);
      });

      test('reports while a setup reads the shifters are no press', () async {
        final t = _SwitchingShimanoTransport();
        final di2 = _PressRecordingDi2(BleDevice(name: 'RDR7150', deviceId: 'di2-dfly-reading'))
          ..debugUseConfigTransport(t)
          ..isConnected = true;
        ShimanoDi2.debugEnterButtonMode = (d, passkey) async {};
        await di2.processCharacteristic(ShimanoDi2Constants.D_FLY_CHANNEL_UUID, report('2511121112'));

        final setup = di2.setupChannels(passkey: '000000');
        while (di2.shifterAsk.value == null) {
          await Future<void>.delayed(Duration.zero);
        }
        await di2.processCharacteristic(ShimanoDi2Constants.D_FLY_CHANNEL_UUID, report('2611121113'));
        t.press(rightFactory);
        t.press(leftFactory);
        await setup;

        expect(di2.pressed, isEmpty);
      });

      test('after a reconnect the channels start over', () async {
        final di2 = await fresh('di2-dfly-reconnect');
        await di2.processCharacteristic(ShimanoDi2Constants.D_FLY_CHANNEL_UUID, report('20f011f0f0'));

        await di2.handleServices([
          BleService(ShimanoDi2Constants.SERVICE_UUID, [
            BleCharacteristic(ShimanoDi2Constants.D_FLY_CHANNEL_UUID, [CharacteristicProperty.indicate], []),
          ]),
        ]);
        await di2.processCharacteristic(ShimanoDi2Constants.D_FLY_CHANNEL_UUID, report('20f011f0f0'));

        expect(di2.pressed, ['D-Fly Channel 2', 'D-Fly Channel 2']);
      });
    });

    test('button mode warns once that a disconnect shifts for real', () async {
      final (:di2, t: _) = connected('di2-warning');
      await core.settings.setShimanoButtonMode('di2-warning', true);
      expect(di2.showButtonModeWarning, isTrue);

      await di2.dismissButtonModeWarning();

      expect(di2.showButtonModeWarning, isFalse);
    });
  });

  group('Shimano Di2 bond on Windows', () {
    // What WinRT throws when the 18FF CCCD is written over an unbonded link
    // (E_BLUETOOTH_ATT_INSUFFICIENT_AUTHENTICATION), as seen on an RD-R7150.
    final insufficientAuthentication = ShimanoTransportException(
      'subscribe',
      ShimanoDi2Config.authControlChar,
      UniversalBleException(
        code: UniversalBleErrorCode.failed,
        message: 'SetNotifiable exception: Das Attribut muss vor dem Lesen oder Schreiben zunächst '
            'authentifiziert werden.',
        details: 'hr=-2140864507',
      ),
    );

    late List<String> calls;
    setUp(() => calls = []);
    tearDown(() => ShimanoDi2.bond = const ShimanoDi2Bond());

    ShimanoDi2 di2(String id, {Object? subscribeError}) => ShimanoDi2(BleDevice(name: 'RDR7150', deviceId: id))
      ..debugUseConfigTransport(_RecordingShimanoTransport(calls, subscribeError: subscribeError));

    test('an unpaired Di2 is paired before the first config step', () async {
      ShimanoDi2.bond = _FakeBond(calls, paired: false);
      final instance = di2('di2-unpaired', subscribeError: TimeoutException('stop after the first step'));

      await expectLater(instance.enterButtonMode(passkey: '000000'), throwsA(isA<TimeoutException>()));

      expect(calls, ['isPaired', 'pair', 'subscribe ${ShimanoDi2Config.authControlChar}']);
    });

    test('a paired Di2 is not paired again', () async {
      ShimanoDi2.bond = _FakeBond(calls, paired: true);
      final instance = di2('di2-paired', subscribeError: TimeoutException('stop after the first step'));

      await expectLater(instance.enterButtonMode(passkey: '000000'), throwsA(isA<TimeoutException>()));

      expect(calls, ['isPaired', 'subscribe ${ShimanoDi2Config.authControlChar}']);
    });

    test('a refused pairing fails as pairing required, before touching the config service', () async {
      ShimanoDi2.bond = _FakeBond(calls, paired: false, pairError: PairingException('Failed'));
      final instance = di2('di2-refused');

      await expectLater(
        instance.enterButtonMode(passkey: '000000'),
        throwsA(isA<ShimanoDi2PairingRequiredException>().having((e) => e.cause, 'cause', isA<PairingException>())),
      );
      expect(calls, ['isPaired', 'pair']);
    });

    test('insufficient authentication despite a bond (lost on the Di2) fails as pairing required', () async {
      ShimanoDi2.bond = _FakeBond(calls, paired: true);
      final instance = di2('di2-stale', subscribeError: insufficientAuthentication);

      await expectLater(
        instance.enterButtonMode(passkey: '000000'),
        throwsA(isA<ShimanoDi2PairingRequiredException>().having((e) => e.cause, 'cause', insufficientAuthentication)),
      );
    });

    test('off Windows nothing is paired and errors pass through unchanged', () async {
      ShimanoDi2.bond = _FakeBond(calls, paired: false, isRequired: false);
      final instance = di2('di2-android', subscribeError: insufficientAuthentication);

      await expectLater(instance.enterButtonMode(passkey: '000000'), throwsA(same(insufficientAuthentication)));
      expect(calls, ['subscribe ${ShimanoDi2Config.authControlChar}']);
    });

    test('re-entry on reconnect never starts pairing, and a missing bond keeps button mode on', () async {
      ShimanoDi2.bond = _FakeBond(calls, paired: false);
      final instance = di2('di2-reconnect');
      await core.settings.setShimanoButtonMode('di2-reconnect', true);

      await instance.reenterButtonMode();

      expect(calls, ['isPaired']);
      expect(core.settings.getShimanoButtonMode('di2-reconnect'), isTrue);
    });

    test('a lost bond found on reconnect keeps button mode on', () async {
      ShimanoDi2.bond = _FakeBond(calls, paired: true);
      final instance = di2('di2-reconnect-stale', subscribeError: insufficientAuthentication);
      await core.settings.setShimanoButtonMode('di2-reconnect-stale', true);

      await instance.reenterButtonMode();

      expect(core.settings.getShimanoButtonMode('di2-reconnect-stale'), isTrue);
    });
  });

  group('Shimano Di2 D-Fly fallback', () {
    ShimanoDi2 connectedDi2(String id) => ShimanoDi2(BleDevice(name: 'RDR7150', deviceId: id))
      ..debugUseConfigTransport(ShimanoBleTransport(id, const []))
      ..isConnected = true;

    test('a Di2 with the config service asks for button mode setup until the rider decides', () {
      final instance = connectedDi2('di2-undecided');

      expect(instance.setupNeed, DeviceSetupNeed.setup);
    });

    test('choosing D-Fly channels ends the setup request and points at the D-Fly buttons', () async {
      final l = await AppLocalizations.load(const Locale('en'));
      final instance = connectedDi2('di2-dfly-choice');

      await instance.useDflyChannels();

      expect(instance.isDflyChosen, isTrue);
      expect(instance.setupNeed, isNull);
      expect(instance.buttonExplanation, l.shimanoDflyExplanation);
      expect(instance.isButtonModeEnabled, isFalse);
    });

    test('the home chain lists the button mode step until the rider decides, and drops it for D-Fly', () async {
      final instance = connectedDi2('di2-chain');
      expect(instance.buttonModeSetupDone, isFalse);

      await instance.useDflyChannels();

      expect(instance.buttonModeSetupDone, isNull);
    });

    test('a Di2 without the config service has no button mode step', () {
      final instance = ShimanoDi2(BleDevice(name: 'Di2', deviceId: 'di2-no-config'));

      expect(instance.buttonModeSetupDone, isNull);
    });
  });

  group('Shimano Di2 wireless unit of a wired 11-speed system', () {
    // Both a 12-speed RD and the wireless unit of a wired 11-speed Di2 expose
    // the 18FF config service, but the 11-speed unit relays no paddle press
    // in button mode while the derailleurs stop shifting.
    final services = [
      BleService(ShimanoDi2Constants.SERVICE_UUID, [
        BleCharacteristic(ShimanoDi2Constants.D_FLY_CHANNEL_UUID, [CharacteristicProperty.indicate], []),
      ]),
      BleService(ShimanoDi2Constants.SERVICE_UUID_ALTERNATIVE, []),
    ];

    Future<ShimanoDi2> connect(String id, String firmware) async {
      final ble = FakeUniversalBlePlatform()
        ..addPeripheral(FakePeripheral(deviceId: id, name: 'Di2', services: services));
      UniversalBle.setInstance(ble);
      await ble.connect(id);
      final instance = ShimanoDi2(BleDevice(name: 'Di2', deviceId: id))..firmwareVersion = firmware;
      await instance.handleServices(services);
      return instance;
    }

    test('a 12-speed RD offers button mode', () async {
      final instance = await connect('di2-12s', '4.1.0.0');

      expect(instance.hasConfigService, isTrue);
      expect(instance.buttonModeSetupDone, isFalse);
    });

    test('the 11-speed wireless unit keeps the D-Fly channels and offers no button mode', () async {
      final l = await AppLocalizations.load(const Locale('en'));
      final instance = await connect('di2-11s', '4.7.1.0');

      expect(instance.hasConfigService, isFalse);
      expect(instance.buttonModeSetupDone, isNull);
      expect(instance.buttonExplanation, l.shimanoDflyExplanation);
    });

    test('a rider who already turned button mode on gets the D-Fly channels back', () async {
      await core.settings.setShimanoButtonMode('di2-11s-on', true);
      final instance = await connect('di2-11s-on', '4.7.1.0');

      expect(instance.hasConfigService, isFalse);
      expect(instance.controllerLayout, isNull);
    });
  });

  group('Shimano Di2 settings hint before any button is known', () {
    test('a Di2 with button mode asks for the one-time setup, not a D-Fly button', () async {
      final l = await AppLocalizations.load(const Locale('en'));
      final instance = ShimanoDi2(BleDevice(name: 'RDR7150', deviceId: 'di2-hint'))
        ..debugUseConfigTransport(ShimanoBleTransport('di2-hint', const []));

      expect(instance.buttonExplanation, l.chainStepShimanoSetupHint);
    });

    test('a Di2 without the config service still points at its D-Fly buttons', () async {
      final l = await AppLocalizations.load(const Locale('en'));
      final instance = ShimanoDi2(BleDevice(name: 'Di2', deviceId: 'di2-dfly'));

      expect(instance.buttonExplanation, l.shimanoDflyExplanation);
    });
  });

  group('Shimano DI2 Tests', () {
    test('Should parse Di2 values correctly', () async {
      stubActions.cleanup();
      final instance = ShimanoDi2(BleDevice(name: 'Di2', deviceId: ''));
      await instance.processCharacteristic(
        ShimanoDi2Constants.D_FLY_CHANNEL_UUID,
        Uint8List.fromList([0x21, 0x13, 0xF0, 0xF0]),
      );

      expect(stubActions.performedActions.isEmpty, true);

      await instance.processCharacteristic(
        ShimanoDi2Constants.D_FLY_CHANNEL_UUID,
        Uint8List.fromList([0x21, 0x13, 0xF0, 0xF0]),
      );
      expect(stubActions.performedActions.isEmpty, true);

      await instance.processCharacteristic(
        ShimanoDi2Constants.D_FLY_CHANNEL_UUID,
        Uint8List.fromList([0x21, 0x14, 0xF0, 0xF0]),
      );
      expect(stubActions.performedActions.isEmpty, false);
    });

    test('should transmit all events', () async {
      stubActions.cleanup();
      final instance = ShimanoDi2(BleDevice(name: 'Di2', deviceId: ''));
      await instance.processCharacteristic(
        ShimanoDi2Constants.D_FLY_CHANNEL_UUID,
        Uint8List.fromList([0x21, 0x13, 0xF0, 0xF0]),
      );

      expect(stubActions.performedActions.isEmpty, true);

      await instance.processCharacteristic(
        ShimanoDi2Constants.D_FLY_CHANNEL_UUID,
        Uint8List.fromList([0x21, 0x13, 0xF0, 0xF0]),
      );
      expect(stubActions.performedActions.isEmpty, true);

      await instance.processCharacteristic(
        ShimanoDi2Constants.D_FLY_CHANNEL_UUID,
        Uint8List.fromList([0x21, 0x14, 0xF0, 0xF0]),
      );
      final button = ControllerButton('D-Fly Channel 1');
      expect(
        stubActions.performedActions,
        equals([
          PerformedAction(button, isDown: true, isUp: true),
        ]),
      );

      await instance.processCharacteristic(
        ShimanoDi2Constants.D_FLY_CHANNEL_UUID,
        Uint8List.fromList([0x21, 0x15, 0xF0, 0xF0]),
      );
      expect(
        stubActions.performedActions,
        equals([
          PerformedAction(button, isDown: true, isUp: true),
          PerformedAction(button, isDown: true, isUp: true),
        ]),
      );
    });
  });
}

class _FakeBond implements ShimanoDi2Bond {
  _FakeBond(this.calls, {required this.paired, this.pairError, this.isRequired = true});
  final List<String> calls;
  bool paired;
  final Object? pairError;

  @override
  final bool isRequired;

  @override
  Future<bool> isPaired(String deviceId) async {
    calls.add('isPaired');
    return paired;
  }

  @override
  Future<void> pair(String deviceId) async {
    calls.add('pair');
    if (pairError != null) throw pairError!;
    paired = true;
  }
}

/// Records every GATT step into the shared [calls] log; the first subscribe
/// throws [subscribeError] when set.
/// Answers every switch write with the shifter's confirm, as a Di2 does.
class _PressRecordingDi2 extends ShimanoDi2 {
  _PressRecordingDi2(super.scanResult);
  final pressed = <String>[];

  @override
  Future<void> handleButtonsClicked(List<ControllerButton>? buttonsClicked, {bool longPress = false}) async {
    pressed.addAll([...?buttonsClicked?.map((b) => b.name)]);
  }
}

class _SwitchingShimanoTransport extends ShimanoBleTransport {
  _SwitchingShimanoTransport({this.confirms = true}) : super('di2', const []);

  /// Whether the shifter confirms each write right away.
  final bool confirms;
  final _frames = StreamController<Uint8List>.broadcast(sync: true);
  final switchWrites = <String>[];

  void press(Uint8List frame) => _frames.add(frame);

  @override
  Future<void> subscribe(String characteristic) async {}

  @override
  Future<void> write(String characteristic, Uint8List data, {bool withoutResponse = false}) async {
    final hex = data.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    if (!hex.startsWith('00134120')) return;
    switchWrites.add(hex);
    if (!confirms) return;
    scheduleMicrotask(() => _frames.add(Uint8List.fromList([0x33, 0x41, 0x22, data[4], 0x03, 0x11, ...data.sublist(7, 10), 0xff])));
  }

  @override
  Future<Uint8List> read(String characteristic) async => Uint8List(0);

  @override
  Stream<Uint8List> notifications(String characteristic) =>
      characteristic == ShimanoDi2Config.pceResponseChar ? _frames.stream : const Stream.empty();
}

class _RecordingShimanoTransport extends ShimanoBleTransport {
  _RecordingShimanoTransport(this.calls, {this.subscribeError}) : super('di2', const []);
  final List<String> calls;
  final Object? subscribeError;

  @override
  Future<void> subscribe(String characteristic) async {
    calls.add('subscribe $characteristic');
    if (subscribeError != null) throw subscribeError!;
  }

  @override
  Future<void> write(String characteristic, Uint8List data, {bool withoutResponse = false}) async =>
      calls.add('write $characteristic');

  @override
  Future<Uint8List> read(String characteristic) async {
    calls.add('read $characteristic');
    return Uint8List(0);
  }

  @override
  Stream<Uint8List> notifications(String characteristic) => const Stream.empty();
}

class _FakeShimanoTransport implements ShimanoTransport {
  _FakeShimanoTransport({required this.fail, this.failSubscribe = false, this.replies = const [], this.live, this.aux, this.aux1});
  final bool fail;
  final bool failSubscribe;

  /// Frames the Di2 sends on 2AF9 at any time, pushed by the test.
  final StreamController<Uint8List>? live;

  /// Frames the Di2 sends on 2AFD, pushed by the test.
  final StreamController<Uint8List>? aux;

  /// Frames the Di2 sends on 2AFB, pushed by the test.
  final StreamController<Uint8List>? aux1;

  /// Frames the Di2 sends on 2AF9 while the sequence runs.
  final List<Uint8List> replies;

  Future<T> _answer<T>(T value) async {
    if (fail) throw TimeoutException('no answer');
    return value;
  }

  @override
  Future<void> subscribe(String characteristic) async {
    if (failSubscribe) throw StateError('subscribe refused');
    return _answer(null);
  }

  @override
  Future<void> write(String characteristic, Uint8List data, {bool withoutResponse = false}) => _answer(null);

  @override
  Future<Uint8List> read(String characteristic) => _answer(Uint8List(0));

  @override
  Stream<Uint8List> notifications(String characteristic) => switch (characteristic.toLowerCase()) {
        ShimanoDi2Config.pceResponseChar => live?.stream ?? Stream.fromIterable(replies),
        ShimanoDi2Config.pceAuxNotify2 => aux?.stream ?? const Stream.empty(),
        ShimanoDi2Config.pceAuxNotify1 => aux1?.stream ?? const Stream.empty(),
        _ => const Stream.empty(),
      };
}

Uint8List _hex(String hex) =>
    Uint8List.fromList([for (var i = 0; i < hex.length; i += 2) int.parse(hex.substring(i, i + 2), radix: 16)]);
