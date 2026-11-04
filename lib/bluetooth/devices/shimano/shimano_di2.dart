import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/device_setup_prompt.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/widgets/controller/controller_layout.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:prop/prop.dart' hide Set;
import 'package:shadcn_flutter/shadcn_flutter.dart' show LucideIcons;
import 'package:universal_ble/universal_ble.dart';

import '../base_device.dart' show DeviceSetupNeed;
import '../bluetooth_device.dart';
import 'shimano_ble_transport.dart';
import 'shimano_setup_sheet.dart';

class ShimanoDi2 extends BluetoothDevice {
  ShimanoDi2(super.scanResult) : super(availableButtons: [], buttonPrefix: 'D-Fly Channel ');

  /// Config seam (18FF E-TUBE service), present on wireless units such as the
  /// RD-R7150. Null when the unit only exposes the 18EF runtime D-FLY service.
  ShimanoBleTransport? _configTransport;

  String get _serialKey => device.deviceId;

  bool get hasConfigService => _configTransport != null;

  /// The wireless unit of a wired 11-speed Di2 (e.g. Ultegra 8000, Dura-Ace
  /// 9150) has the config service too, but in button mode it relays no paddle
  /// press while the derailleurs stop shifting. Its firmware is 4.7.x; the
  /// 12-speed wireless RDs run 4.0.x / 4.1.x. Such a unit keeps the D-Fly
  /// channels set in E-TUBE.
  static bool isWiredSystemUnit(String? firmware) => firmware?.startsWith('4.7.') ?? false;

  @visibleForTesting
  void debugUseConfigTransport(ShimanoBleTransport transport) => _configTransport = transport;

  /// Set while the link drops as expected: on purpose after channel setup or
  /// restore, or by the Di2 itself after a wrong passkey in the setup sheet.
  /// The entry stays listed and reconnects without connection toasts.
  bool _linkResetting = false;
  Timer? _linkResetTimeout;

  @override
  bool get isResetting => _linkResetting && !isConnected;

  @override
  Future<void> handleServices(List<BleService> services) async {
    _endLinkReset();
    final service = services.firstWhere(
      (e) => e.uuid.toLowerCase() == ShimanoDi2Constants.SERVICE_UUID.toLowerCase(),
      orElse: () => throw Exception('Service not found: ${ShimanoDi2Constants.SERVICE_UUID}'),
    );
    final characteristic = service.characteristics.firstWhere(
      (e) => e.uuid.toLowerCase() == ShimanoDi2Constants.D_FLY_CHANNEL_UUID.toLowerCase(),
      orElse: () => throw Exception('Characteristic not found: ${ShimanoDi2Constants.D_FLY_CHANNEL_UUID}'),
    );

    // A fresh link reports its channels from scratch (see [processCharacteristic]).
    _isInitialized = false;
    _lastButtons.clear();
    await UniversalBle.subscribeIndications(device.deviceId, service.uuid, characteristic.uuid);

    // The Di2 reports its D-Fly channels only once one is pressed. With E-TUBE
    // channels chosen they are BikeControl's buttons: list them right away,
    // and where the state can be read, start from it so the first press counts.
    if (isDflyChosen) {
      _addChannelButtons(_dflyChannelCount);
      if (characteristic.properties.contains(CharacteristicProperty.read)) {
        try {
          final state = await UniversalBle.read(device.deviceId, service.uuid, characteristic.uuid);
          if (state.length > 1) _initChannels(state.sublist(1));
        } catch (e) {
          actionStreamInternal.add(LogNotification('ShimanoDi2 D-Fly state not readable: $e'));
        }
      }
    }

    // The 18FF E-TUBE config service (SERVICE_UUID_ALTERNATIVE) unlocks button
    // mode: the paddles become BikeControl buttons without changing any Di2
    // setting. Its GATT dance runs through [ShimanoConfig] over this transport;
    // notifications are routed back from [processCharacteristic].
    final hasConfig = !isWiredSystemUnit(firmwareVersion) &&
        services.any(
          (e) => e.uuid.toLowerCase() == ShimanoDi2Constants.SERVICE_UUID_ALTERNATIVE.toLowerCase(),
        );
    _configTransport = hasConfig ? ShimanoBleTransport(device.deviceId, services) : null;

    // Once the rider has opted in, re-enter button mode on every (re)connect.
    // This also releases a derailleur left in PC-connect mode by an earlier,
    // interrupted session.
    if (hasConfig && isButtonModeEnabled) {
      unawaited(reenterButtonMode());
    }
  }

  final _lastButtons = <int, ({int value, _Di2State type})>{};
  bool _isInitialized = false;

  /// D-Fly Ch1–Ch4.
  static const _dflyChannelCount = 4;
  static const _dflyFirstReport = 0x20;
  static const _dflyUnpressed = 0xf0;

  void _addChannelButtons(int count) {
    for (var readableIndex = 1; readableIndex <= count; readableIndex++) {
      getOrAddButton(
        'D-Fly Channel $readableIndex',
        () => ControllerButton(
          'D-Fly Channel $readableIndex',
          sourceDeviceId: device.deviceId,
          action: isDflyChosen ? ShimanoDi2Buttons.channelActions[readableIndex] : null,
        ),
      );
    }
  }

  void _initChannels(List<int> channels) {
    channels.forEachIndexed((int value, int index) => _lastButtons[index] = (value: value, type: _Di2State.released));
    _addChannelButtons(channels.length);
    _isInitialized = true;
  }

  @override
  // Shown while no button is known yet. A Di2 with the config service sends
  // nothing until button mode is set up, so pressing a paddle would do
  // nothing — point at the setup instead, unless the rider chose D-Fly.
  String get buttonExplanation => hasConfigService && !isDflyChosen
      ? AppLocalizations.current.chainStepShimanoSetupHint
      : AppLocalizations.current.shimanoDflyExplanation;

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) async {
    Logger.info('Received data from $characteristic: ${bytesToReadableHex(bytes)}');

    // Route the config service's notifications/indications (incl. the paddle
    // presses in button mode) to the config transport.
    final lower = characteristic.toLowerCase();
    if (_configTransport != null &&
        (lower == ShimanoDi2Config.pceResponseChar ||
            lower == ShimanoDi2Config.authControlChar ||
            lower == ShimanoDi2Config.pceAuxNotify1 ||
            lower == ShimanoDi2Config.pceAuxNotify2)) {
      _configTransport!.onNotification(lower, bytes);
      return;
    }

    if (characteristic.toLowerCase() == ShimanoDi2Constants.D_FLY_CHANNEL_UUID) {
      final channels = bytes.sublist(1);

      // A link numbers its reports from 0x20 and starts every channel at
      // [_dflyUnpressed]: its first report already carries a press. A first
      // report from later on only says where the channels are.
      if (!_isInitialized) {
        final firstOfLink = bytes[0] == _dflyFirstReport;
        _initChannels(firstOfLink ? List.filled(channels.length, _dflyUnpressed) : channels);
        if (!firstOfLink) return Future.value();
      }

      var actualChange = false;
      channels.forEachIndexed((int value, int index) {
        final didChange = _lastButtons[index]?.value != value;

        final readableIndex = index + 1;

        if (didChange) {
          if (value >> 4 == _dflyUnpressed >> 4) {
            // Not pressed (a fresh link, or the RD entering its configuration
            // mode): although it has the 0x10 bit set, no press.
            _lastButtons[index] = (value: value, type: _Di2State.released);
            Logger.info('Button $readableIndex not pressed');
          } else if ((value & 0x10) != 0) {
            if (_lastButtons[index]?.type == _Di2State.longPress || _lastButtons[index]?.type == _Di2State.keep) {
              // short press is triggered after long press, until it's released later on
              _lastButtons[index] = (value: value, type: _Di2State.keep);
              Logger.info('Button $readableIndex still long pressed');
            } else {
              _lastButtons[index] = (value: value, type: _Di2State.shortPress);
              actualChange = true;
              Logger.info('Button $readableIndex short pressed');
            }
          } else if ((value & 0x20) != 0) {
            _lastButtons[index] = (value: value, type: _Di2State.longPress);
            actualChange = true;
            Logger.info('Button $readableIndex long pressed');
          } else if ((value & 0x40) != 0) {
            _lastButtons[index] = (value: value, type: _Di2State.doublePress);
            actualChange = true;
            Logger.info('Button $readableIndex double pressed');
          } else {
            _lastButtons[index] = (value: value, type: _Di2State.released);
            actualChange = true;
            Logger.info('Button $readableIndex released');
          }
        }
      });

      // While channel setup or restore reads the shifters, presses only wake
      // them and must not trigger actions.
      if (actualChange && !_readingSwitches) {
        final Map<_Di2State, List<ControllerButton>> mapped = _lastButtons.entries.groupBy((e) => e.value.type).map((
          key,
          value,
        ) {
          final buttons = value
              .map((entry) => availableButtons.firstWhere((button) => button.name == 'D-Fly Channel ${entry.key + 1}'))
              .toList();
          return MapEntry(key, buttons);
        });

        final shortPress = [...?mapped[_Di2State.shortPress], ...?mapped[_Di2State.doublePress]];
        if (shortPress.isNotEmpty) {
          Logger.debug('Short Press Buttons to trigger: ${shortPress.map((b) => b.name).join(', ')}');
          handleButtonsClicked(shortPress);
          handleButtonsClicked([]);
          _resetButtonsForState([_Di2State.shortPress]);
        }

        final longPress = mapped[_Di2State.longPress] ?? [];
        if (longPress.isNotEmpty) {
          Logger.debug('Long Press Buttons to trigger: ${longPress.map((b) => b.name).join(', ')}');
          handleButtonsClicked(longPress);
        }

        final released = mapped[_Di2State.released] ?? [];
        final keepPress = mapped[_Di2State.longPress] ?? [];

        if (released.isNotEmpty && keepPress.isEmpty) {
          Logger.debug('Releasing all Buttons');
          handleButtonsClicked([]);
        }

        final doublePress = mapped[_Di2State.doublePress] ?? [];
        if (doublePress.isNotEmpty) {
          Logger.debug('Buttons to still trigger: ${doublePress.map((b) => b.name).join(', ')}');
          handleButtonsClicked(doublePress);
          handleButtonsClicked([]);
          _resetButtonsForState([_Di2State.doublePress]);
        }
      }
    }
  }

  void _resetButtonsForState(List<_Di2State> list) {
    _lastButtons.forEach((key, value) {
      if (list.contains(value.type)) {
        _lastButtons[key] = (value: value.value, type: _Di2State.released);
      }
    });
  }

  // ── Button mode (18FF config service) ─────────────────────────────────────

  /// Whether the rider opted in to button mode for this Di2.
  bool get isButtonModeEnabled => core.settings.getShimanoButtonMode(_serialKey);

  /// Whether the rider chose to keep the D-Fly channel buttons instead of
  /// button mode. They need no pairing, so this is the way out where Windows
  /// can't pair the Di2.
  bool get isDflyChosen => core.settings.getShimanoDfly(_serialKey);

  /// The home chain's "Use Di2 buttons" step: whether button mode is on, or
  /// null when there is no such step — a Di2 without the config service, or
  /// one whose rider chose the D-Fly channel buttons.
  bool? get buttonModeSetupDone => hasConfigService && !isDflyChosen ? isButtonModeEnabled : null;

  /// Keep the D-Fly channel buttons: the Di2 keeps shifting by itself and
  /// button mode's setup is no longer requested. "Use Di2 buttons" stays
  /// available on the device panel.
  Future<void> useDflyChannels() async {
    await core.settings.setShimanoDfly(_serialKey, true);
    core.connection.signalChange(this);
  }

  ShimanoButtonSession? _buttonSession;
  final Set<ControllerButton> _pressed = {};

  /// How BikeControl gets the bond the config service needs; replaced in tests.
  @visibleForTesting
  static ShimanoDi2Bond bond = const ShimanoDi2Bond();

  /// A GATT/handshake timeout means the Di2 didn't answer (asleep / out of
  /// range) — the sheet then prompts the rider to wake it and retry.
  bool _isUnresponsive(Object error) {
    if (error is TimeoutException) return true;
    if (error is ShimanoPasskeyRejectedException) return false;
    if (error is ShimanoAuthException) return error.message.contains('TimeoutException');
    return false;
  }

  /// Authenticate with [passkey] and put the Di2 into button mode: while the
  /// link is up the derailleur stops shifting itself and every paddle press
  /// arrives here as a button. Nothing on the Di2 is changed — once the link
  /// drops it shifts normally again.
  ///
  /// Where the platform doesn't bond on its own (Windows), the bond is checked
  /// first and, with [pair], requested; a missing or refused bond fails as
  /// [ShimanoDi2PairingRequiredException].
  Future<void> enterButtonMode({required String passkey, bool pair = true}) async {
    final t = _configTransport;
    if (t == null) return;
    await _ensureBonded(pair: pair);
    try {
      await ShimanoConfig.authenticate(t, passkey: passkey);
    } catch (e, st) {
      // Windows still holds keys the Di2 has since forgotten: pairing again
      // from code is a no-op (Windows thinks it's paired), only the rider can
      // remove and re-add it.
      if (bond.isRequired && ShimanoDi2Bond.isInsufficientAuthentication(e)) {
        Error.throwWithStackTrace(ShimanoDi2PairingRequiredException(e), st);
      }
      rethrow;
    }
    await startButtonSession(t);
  }

  Future<void> _ensureBonded({required bool pair}) async {
    if (!bond.isRequired) return;
    if (await bond.isPaired(device.deviceId)) return;
    if (!pair) throw ShimanoDi2PairingRequiredException(null);
    try {
      await bond.pair(device.deviceId);
    } catch (e, st) {
      Error.throwWithStackTrace(ShimanoDi2PairingRequiredException(e), st);
    }
  }

  /// Replay the button-mode sequence on [t]. Every step runs even if one
  /// fails, so a single lost reply doesn't end it — but a Di2 that answered
  /// none of them never switched, and saying "you're all set" would leave the
  /// rider pressing paddles that do nothing. That fails as unresponsive, which
  /// the setup sheet turns into "wake your Di2".
  @visibleForTesting
  Future<void> startButtonSession(ShimanoTransport t) async {
    await _buttonSession?.close();
    _buttonSession = null;
    final counted = _CountingShimanoTransport(t);
    // The paddle presses arrive on 2AF9, the same characteristic the RD
    // answers the sequence on: no replies there means presses can't arrive
    // either, although the RD already stopped shifting.
    var replies = 0;
    final replyCounter = t.notifications(ShimanoDi2Config.pceResponseChar).listen((_) => replies++);
    final ShimanoButtonSession session;
    try {
      session = await ShimanoConfig.enterButtonMode(
        counted,
        onPaddle: onPaddle,
        onUnknownFrame: onUnknownFrame,
        onStepError: (step, e, st) {
          actionStreamInternal.add(LogNotification('ShimanoDi2 button mode step $step failed: $e'));
          unawaited(recordError(e, st, context: 'ShimanoDi2: button mode step $step'));
        },
      );
    } finally {
      await replyCounter.cancel();
    }
    if (counted.answered == 0 && counted.failed > 0) {
      await session.close();
      throw TimeoutException('Di2 answered none of the ${counted.failed} button mode steps');
    }
    actionStreamInternal.add(
      LogNotification(
        'ShimanoDi2 button mode active: ${counted.answered} steps answered, ${counted.failed} failed, '
        '$replies replies on 2af9',
      ),
    );
    _buttonSession = session;
    _logFramesAfterButtonMode(t);
    if (!_readingSwitches) registerPaddleButtons();
  }

  @visibleForTesting
  void registerPaddleButtons() {
    for (final button in ShimanoDi2Buttons.paddles) {
      getOrAddButton(button.name, () => button.copyWith(sourceDeviceId: device.deviceId));
    }
  }

  /// One-time opt-in from the setup sheet: enter button mode with [passkey]
  /// and remember both, so every later connect re-enters it automatically.
  Future<void> setupButtonMode({required String passkey}) async {
    try {
      // A wrong passkey makes the RD drop the link, and BikeControl reconnects
      // it as a new device object — a retry from the still-open sheet must run
      // on that one, not on this disconnected instance.
      final target = await _liveInstance();
      await target.enterButtonMode(passkey: passkey);
      await core.settings.setShimanoPasskey(_serialKey, passkey);
      await core.settings.setShimanoButtonMode(_serialKey, true);
      await core.settings.setShimanoDfly(_serialKey, false);
      core.connection.signalChange(target);
    } catch (e, st) {
      // The Di2 drops the link after a wrong passkey: reconnect quietly.
      if (e is ShimanoPasskeyRejectedException) _expectLinkDrop();
      actionStreamInternal.add(LogNotification('ShimanoDi2 button mode setup failed: $e'));
      await recordError(e, st, context: 'ShimanoDi2: button mode setup');
      rethrow;
    }
  }

  /// The connected [ShimanoDi2] for this Di2: this instance, or the one a
  /// reconnect replaced it with. Waits briefly for a reconnect to finish; a
  /// [TimeoutException] means the Di2 didn't come back (asleep / out of range).
  Future<ShimanoDi2> _liveInstance({Duration timeout = const Duration(seconds: 20)}) async {
    final deadline = DateTime.now().add(timeout);
    while (true) {
      final live = core.connection.controllerDevices
              .whereType<ShimanoDi2>()
              .firstOrNullWhere((d) => d.device.deviceId == device.deviceId) ??
          this;
      if (live.isConnected && live.hasConfigService) return live;
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException('Di2 did not reconnect', timeout);
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  /// Re-enter button mode on (re)connect. It never starts a pairing: a
  /// refused one drops the link at the 30 s security timeout, so pairing
  /// on every reconnect would cycle the connection. A missing bond is logged
  /// and retried next connect; pairing belongs to the setup sheet.
  @visibleForTesting
  Future<void> reenterButtonMode() => autoEnterButtonMode(
        () => enterButtonMode(passkey: core.settings.getShimanoPasskey(_serialKey), pair: false),
      );

  /// The automatic re-entry on connect. A stored passkey the Di2 now rejects
  /// (changed in E-TUBE since setup) can't start working on its own, and a
  /// rejection drops the link, so retrying it on every reconnect would only
  /// cycle the connection while the card claims the paddles are buttons.
  /// Switch button mode off instead: the setup step comes back and asks for
  /// the passkey. Anything else (asleep, out of range, no Windows bond) is
  /// retried next connect.
  @visibleForTesting
  Future<void> autoEnterButtonMode(Future<void> Function() enter) async {
    try {
      await enter();
      core.connection.signalChange(this);
    } catch (e, st) {
      actionStreamInternal.add(LogNotification('ShimanoDi2 could not enter button mode: $e'));
      await recordError(e, st, context: 'ShimanoDi2: enter button mode');
      if (e is ShimanoPasskeyRejectedException) {
        await core.settings.setShimanoButtonMode(_serialKey, false);
        core.connection.signalChange(this);
      }
    }
  }

  /// Opt out: forget the choice and drop the link, which is what returns the
  /// Di2 to normal shifting. The next connect leaves it shifting by itself.
  Future<void> turnOffButtonMode() async {
    await core.settings.setShimanoButtonMode(_serialKey, false);
    await _buttonSession?.close();
    _buttonSession = null;
    await _cancelFrameLogs();
    await disconnect();
    core.connection.signalChange(this);
  }

  // ── E-TUBE channels (D-Fly) ───────────────────────────────────────────────

  /// What the shifters did before BikeControl put their paddles on D-Fly
  /// channels; empty when BikeControl changed nothing.
  List<ShimanoShifterSwitches> get switchBackup => core.settings.getShimanoSwitchBackup(_serialKey);

  /// While channel setup or restore waits for the rider to press a button on
  /// each shifter: which press it waits for, and the shifters done so far.
  /// Null otherwise.
  final shifterAsk = ValueNotifier<ShimanoShifterAsk?>(null);

  /// Completes with [ShimanoSetupCancelled] when the rider cancels while
  /// [_writeShifters] waits for a press.
  Completer<void>? _shifterWaitCancel;

  /// The instance [_onLiveInstance] runs on, which [cancelShifterWait] stops.
  ShimanoDi2? _liveTarget;

  /// Stop a channel setup or restore that waits for a press on a shifter. It
  /// then fails with [ShimanoSetupCancelled] and disconnects, which returns
  /// the Di2 to normal operation.
  void cancelShifterWait() {
    final target = _liveTarget ?? this;
    final cancel = target._shifterWaitCancel;
    if (cancel != null && !cancel.isCompleted) cancel.completeError(const ShimanoSetupCancelled());
  }

  /// Set while a channel setup or restore reads the shifters: their presses
  /// carry the switch setting and must not trigger actions.
  bool _readingSwitches = false;

  /// One-time setup of the E-TUBE channel mode: put both shifters' paddles on
  /// D-Fly channels (left Ch1/Ch2, right Ch3/Ch4), after saving what they did
  /// before. The Di2 then never shifts with the paddles, whether BikeControl
  /// is connected or not, until [restoreSwitches].
  Future<void> setupChannels({required String passkey}) async {
    try {
      await _onLiveInstance((target) => target._writeShifters(passkey, (seen) async {
        final changed = [for (final s in seen) if (!s.paddlesOnDfly) s];
        if (changed.isEmpty) return const [];
        // Keep the first backup: a second setup would otherwise save the D-Fly
        // channels as the "original" setting.
        if (switchBackup.isEmpty) await core.settings.setShimanoSwitchBackup(_serialKey, changed);
        return [for (final s in changed) s.withDflyPaddles()];
      }));
      await core.settings.setShimanoPasskey(_serialKey, passkey);
      await core.settings.setShimanoButtonMode(_serialKey, false);
      await core.settings.setShimanoDfly(_serialKey, true);
      core.connection.signalChange(this);
    } on ShimanoSetupCancelled {
      rethrow;
    } catch (e, st) {
      actionStreamInternal.add(LogNotification('ShimanoDi2 channel setup failed: $e'));
      await recordError(e, st, context: 'ShimanoDi2: channel setup');
      rethrow;
    }
  }

  /// Put back what the shifters did before [setupChannels], so the Di2 shifts
  /// with its paddles again.
  Future<void> restoreSwitches({required String passkey}) async {
    final backup = switchBackup;
    try {
      await _onLiveInstance(
        (target) => target._writeShifters(
          passkey,
          (seen) async => [for (final s in backup) if (seen.any((e) => e.slot == s.slot)) s],
          slots: {for (final s in backup) s.slot},
        ),
      );
      await core.settings.clearShimanoSwitchBackup(_serialKey);
      await core.settings.setShimanoDfly(_serialKey, false);
      core.connection.signalChange(this);
    } on ShimanoSetupCancelled {
      rethrow;
    } catch (e, st) {
      actionStreamInternal.add(LogNotification('ShimanoDi2 restore failed: $e'));
      await recordError(e, st, context: 'ShimanoDi2: restore switches');
      rethrow;
    }
  }

  /// Run [body] on the connected instance for this Di2 (see [_liveInstance]),
  /// mirroring its [shifterAsk] here, where the setup sheet listens.
  Future<void> _onLiveInstance(Future<void> Function(ShimanoDi2 target) body) async {
    final target = await _liveInstance();
    if (identical(target, this)) return body(this);
    void mirror() => shifterAsk.value = target.shifterAsk.value;
    target.shifterAsk.addListener(mirror);
    _liveTarget = target;
    try {
      await body(target);
    } finally {
      _liveTarget = null;
      target.shifterAsk.removeListener(mirror);
      shifterAsk.value = null;
    }
  }

  /// Authenticate, enter the RD's PC-connect mode (the only mode in which it
  /// relays to the shifters), wait for a press on each shifter in [slots] —
  /// the press both wakes it and reports its current switch setting — and
  /// write what [plan] returns, left shifter first: each write is saved on
  /// that shifter's next press. Once the passkey was accepted it disconnects
  /// afterwards, which is what returns the Di2 to normal operation; it keeps
  /// that passkey even if the rest fails.
  Future<void> _writeShifters(
    String passkey,
    Future<List<ShimanoShifterSwitches>> Function(List<ShimanoShifterSwitches> seen) plan, {
    Set<int> slots = const {0, 1},
  }) async {
    final t = _configTransport;
    if (t == null) throw StateError('Di2 has no config service');
    final seen = <int, ShimanoShifterSwitches>{};
    final allSeen = Completer<void>();
    Timer? oneShifterGrace;
    final sub = t.notifications(ShimanoDi2Config.pceResponseChar).listen((frame) {
      final switches = ShimanoShifterSwitches.fromTelemetry(frame);
      if (switches == null || !slots.contains(switches.slot)) return;
      if (shifterAsk.value == null || shifterAsk.value!.saving) return;
      seen[switches.slot] = switches;
      shifterAsk.value = ShimanoShifterAsk({for (final slot in seen.keys) _shifterIn(slot)});
      if (seen.length == slots.length) {
        if (!allSeen.isCompleted) allSeen.complete();
      } else {
        // A Di2 with a single shifter (e.g. a TT setup) never reports the
        // other: go on with the one seen once the rider stopped pressing.
        oneShifterGrace?.cancel();
        oneShifterGrace = Timer(const Duration(seconds: 15), () {
          if (!allSeen.isCompleted) allSeen.complete();
        });
      }
    });
    _readingSwitches = true;
    // Until the passkey is accepted the Di2 is still in normal operation:
    // nothing to end by dropping the link, and a retry can use it.
    var configMode = false;
    try {
      try {
        await (debugEnterButtonMode?.call(this, passkey) ?? enterButtonMode(passkey: passkey));
      } on ShimanoAuthException catch (e) {
        if (e is ShimanoPasskeyRejectedException) _expectLinkDrop();
        rethrow;
      } on ShimanoDi2PairingRequiredException {
        rethrow;
      } catch (_) {
        configMode = true;
        rethrow;
      }
      configMode = true;
      await core.settings.setShimanoPasskey(_serialKey, passkey);
      final cancel = _shifterWaitCancel = Completer<void>();
      shifterAsk.value = const ShimanoShifterAsk({});
      await Future.any([allSeen.future.timeout(const Duration(minutes: 2)), cancel.future]);
      final writes = [...await plan(seen.values.toList())]..sort((a, b) => a.slot.compareTo(b.slot));
      if (writes.isNotEmpty) {
        final saved = {for (final slot in {...slots, ...seen.keys}) _shifterIn(slot)}
          ..removeAll(writes.map((w) => _shifterIn(w.slot)));
        for (final switches in writes) {
          final shifter = _shifterIn(switches.slot);
          void ask({ShimanoShifter? next}) => shifterAsk.value = ShimanoShifterAsk({...saved}, saving: true, next: next);
          Timer? ready;
          ask();
          try {
            await Future.any([
              ShimanoConfig.writeSwitches(
                t,
                switches,
                quiet: debugSwitchWriteQuiet ?? ShimanoConfig.switchWriteQuiet,
                onWrite: (command) {
                  final hex = command.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
                  Logger.info('ShimanoDi2 writing $switches: $hex');
                  actionStreamInternal.add(LogNotification('ShimanoDi2 writing $switches: $hex'));
                  // A press within half a second of the write doesn't save it:
                  // ask for it once the write has had time to reach the Di2.
                  ask();
                  ready?.cancel();
                  ready = Timer(debugSwitchReadyDelay ?? const Duration(seconds: 1), () => ask(next: shifter));
                },
              ),
              cancel.future,
            ]);
          } finally {
            ready?.cancel();
          }
          actionStreamInternal.add(LogNotification('ShimanoDi2 wrote $switches'));
          saved.add(shifter);
        }
        shifterAsk.value = ShimanoShifterAsk({...saved}, saving: true);
      }
    } finally {
      oneShifterGrace?.cancel();
      _shifterWaitCancel = null;
      shifterAsk.value = null;
      _readingSwitches = false;
      await sub.cancel();
      await _buttonSession?.close();
      _buttonSession = null;
      await _cancelFrameLogs();
      if (configMode) {
        _expectLinkDrop();
        await disconnect();
      }
    }
  }

  void _expectLinkDrop() {
    _linkResetTimeout?.cancel();
    _linkResetting = true;
    // A Di2 that doesn't come back is shown as gone again after a while.
    _linkResetTimeout = Timer(const Duration(seconds: 30), () {
      _endLinkReset();
      core.connection.signalChange(this);
    });
  }

  void _endLinkReset() {
    _linkResetTimeout?.cancel();
    _linkResetTimeout = null;
    _linkResetting = false;
  }

  static ShimanoShifter _shifterIn(int slot) => slot == 0 ? ShimanoShifter.left : ShimanoShifter.right;

  /// Shortens the time the save step waits before it asks for the press.
  @visibleForTesting
  static Duration? debugSwitchReadyDelay;

  /// Shortens the pause [ShimanoConfig.writeSwitches] waits for in tests.
  @visibleForTesting
  static Duration? debugSwitchWriteQuiet;

  /// Replaces the authenticated [enterButtonMode] in channel setup tests.
  @visibleForTesting
  static Future<void> Function(ShimanoDi2 di2, String passkey)? debugEnterButtonMode;

  /// Button mode shifts for real once BikeControl disconnects: the device
  /// panel says so once.
  bool get showButtonModeWarning =>
      isButtonModeEnabled && !core.settings.getShimanoButtonModeWarningSeen(_serialKey);

  Future<void> dismissButtonModeWarning() async {
    await core.settings.setShimanoButtonModeWarningSeen(_serialKey);
    core.connection.signalChange(this);
  }

  @visibleForTesting
  void onPaddle(ShimanoPaddleEvent event) {
    if (_readingSwitches) return;
    final template = ShimanoDi2Buttons.of(event);
    var button = availableButtons.firstOrNullWhere((b) => b.name == template.name);
    // Hood and satellite buttons only exist on some shifters: show them once
    // the rider presses one rather than as dead chips on every Di2.
    if (button == null && ShimanoDi2Buttons.extras.contains(template)) {
      button = getOrAddButton(template.name, () => template.copyWith(sourceDeviceId: device.deviceId));
      core.connection.signalChange(this);
    }
    if (button == null) return;
    switch (event.state) {
      case ShimanoPaddleState.down:
        if (!_pressed.add(button)) return;
      case ShimanoPaddleState.released:
        if (!_pressed.remove(button)) return;
      case ShimanoPaddleState.held:
        // Repeats while pressed; long-press timing is handled by BaseDevice.
        return;
    }
    unawaited(handleButtonsClicked(_pressed.toList()));
  }

  final List<StreamSubscription<Uint8List>> _frameLogs = [];

  /// Wired Di2 shifters may report presses in a shape the decoder doesn't
  /// know, which it drops without a trace, and wired 11-speed switches report
  /// on 2AFD instead of 2AF9. Log the first raw frames on both (each distinct
  /// frame once in a row) so a rider's log shows what arrives.
  void _logFramesAfterButtonMode(ShimanoTransport t) {
    unawaited(_cancelFrameLogs());
    _logFrames(t, ShimanoDi2Config.pceResponseChar, 'ShimanoDi2 frame after button mode');
    _logFrames(t, ShimanoDi2Config.pceAuxNotify2, 'ShimanoDi2 2afd frame after button mode');
    _logHoodAndSatelliteFrames(t);
  }

  /// Which bytes carry the hood button and the satellite switch is not
  /// confirmed on hardware yet: log the raw frame of every such press.
  void _logHoodAndSatelliteFrames(ShimanoTransport t) {
    String? last;
    var logged = 0;
    late final StreamSubscription<Uint8List> sub;
    sub = t.notifications(ShimanoDi2Config.pceResponseChar).listen((frame) {
      final events = ShimanoButtons.decode(frame);
      if (!events.any((e) => e.paddle == ShimanoPaddle.hood || e.paddle == ShimanoPaddle.satellite)) return;
      final hex = frame.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      if (hex == last) return;
      last = hex;
      actionStreamInternal.add(LogNotification('ShimanoDi2 hood/satellite frame: $hex'));
      if (++logged >= 50) unawaited(sub.cancel());
    });
    _frameLogs.add(sub);
  }

  void _logFrames(ShimanoTransport t, String characteristic, String label) {
    String? last;
    var logged = 0;
    late final StreamSubscription<Uint8List> sub;
    sub = t.notifications(characteristic).listen((frame) {
      final hex = frame.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      if (hex == last) return;
      last = hex;
      actionStreamInternal.add(LogNotification('$label: $hex'));
      if (++logged >= 50) unawaited(sub.cancel());
    });
    _frameLogs.add(sub);
  }

  Future<void> _cancelFrameLogs() async {
    final subs = [..._frameLogs];
    _frameLogs.clear();
    for (final sub in subs) {
      await sub.cancel();
    }
  }

  String? _lastUnknownFrame;

  /// Button telemetry the decoder found no press in, e.g. a switch it doesn't
  /// know yet. Logged raw (each distinct frame once in a row) so a rider's log
  /// shows which bytes that switch uses.
  @visibleForTesting
  void onUnknownFrame(Uint8List frame) {
    final hex = frame.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    if (hex == _lastUnknownFrame) return;
    _lastUnknownFrame = hex;
    actionStreamInternal.add(LogNotification('ShimanoDi2 unknown button frame: $hex'));
  }

  @override
  Future<void> disconnect() async {
    await _buttonSession?.close();
    _buttonSession = null;
    await _cancelFrameLogs();
    _pressed.clear();
    await super.disconnect();
  }

  /// Until button mode is on, the Di2 shifts itself and reports nothing — so
  /// the ride card has no buttons to show. Surface that as a required one-time
  /// setup (dimmed card + prompt) rather than a blank card — unless the rider
  /// chose the D-Fly channel buttons instead.
  @override
  DeviceSetupNeed? get setupNeed =>
      isConnected && hasConfigService && !isButtonModeEnabled && !isDflyChosen ? DeviceSetupNeed.setup : null;

  @override
  Future<void> openSetup(BuildContext context) async {
    if (setupNeed == DeviceSetupNeed.setup) await _showSetup(context);
  }

  /// The setup starts with the choice between E-TUBE channels and button mode.
  /// However it was opened (Di2 card, checklist, or by itself), it counts as
  /// offered: the Di2 drops the link after a wrong passkey, and its reconnect
  /// must not open a second setup on top.
  Future<void> _showSetup(BuildContext context) {
    DeviceSetupPrompt.markOffered(this);
    return showShimanoModeChooser(
        context,
        onChoose: (mode) {
          if (!context.mounted) return;
          unawaited(switch (mode) {
            ShimanoSetupMode.channels => _showChannelSetup(context, afterChooser: true),
            ShimanoSetupMode.buttons => _showButtonModeSetup(context, afterChooser: true),
          });
        },
      );
  }

  Future<void> _showButtonModeSetup(BuildContext context, {bool afterChooser = false}) {
    final l = context.i18n;
    return showShimanoSetup(
      context,
      title: l.shimanoSetup,
      intro: l.shimanoSetupIntro,
      successMessage: l.shimanoSetupSuccess,
      confirmIcon: LucideIcons.gamepad2,
      runningTitle: l.shimanoSettingUp,
      successTitle: l.shimanoAllSet,
      checklistItems: [l.shimanoChecklistAuthenticating, l.shimanoChecklistActivating],
      initialPasskey: core.settings.getShimanoPasskey(_serialKey),
      operation: (passkey) => setupButtonMode(passkey: passkey),
      isUnresponsive: _isUnresponsive,
      isPasskeyRejected: (e) => e is ShimanoPasskeyRejectedException,
      isPairingRequired: (e) => e is ShimanoDi2PairingRequiredException,
      afterChooser: afterChooser,
      onUseDfly: () => unawaited(useDflyChannels()),
    );
  }

  Future<void> _showChannelSetup(BuildContext context, {bool afterChooser = false}) {
    final l = context.i18n;
    return showShimanoSetup(
      context,
      title: l.shimanoChannelsTitle,
      intro: l.shimanoChannelsIntro,
      successMessage: l.shimanoChannelsSuccess,
      confirmIcon: LucideIcons.radio,
      runningTitle: l.shimanoSettingUp,
      successTitle: l.shimanoAllSet,
      checklistItems: [
        l.shimanoChecklistAuthenticating,
        l.shimanoChecklistReadingButtons,
        l.shimanoChecklistAssigning,
      ],
      initialPasskey: core.settings.getShimanoPasskey(_serialKey),
      operation: (passkey) => setupChannels(passkey: passkey),
      isUnresponsive: _isUnresponsive,
      isPasskeyRejected: (e) => e is ShimanoPasskeyRejectedException,
      isPairingRequired: (e) => e is ShimanoDi2PairingRequiredException,
      shifters: shifterAsk,
      onCancelShifters: cancelShifterWait,
      afterChooser: afterChooser,
    );
  }

  Future<void> _showRestore(BuildContext context) {
    final l = context.i18n;
    return showShimanoSetup(
      context,
      title: l.shimanoRestore,
      intro: l.shimanoRestoreIntro,
      successMessage: l.shimanoRestoreSuccess,
      confirmIcon: LucideIcons.rotateCcw,
      runningTitle: l.shimanoRestoring,
      successTitle: l.shimanoRestoredTitle,
      checklistItems: [l.shimanoChecklistAuthenticating, l.shimanoChecklistRestoring],
      initialPasskey: core.settings.getShimanoPasskey(_serialKey),
      operation: (passkey) => restoreSwitches(passkey: passkey),
      isUnresponsive: _isUnresponsive,
      isPasskeyRejected: (e) => e is ShimanoPasskeyRejectedException,
      isPairingRequired: (e) => e is ShimanoDi2PairingRequiredException,
      shifters: shifterAsk,
      onCancelShifters: cancelShifterWait,
    );
  }

  @override
  ControllerLayout? get controllerLayout =>
      hasConfigService && isButtonModeEnabled ? ShimanoDi2Buttons.layout : null;

  @override
  List<Widget> showAdditionalInformation(BuildContext context) {
    if (hasConfigService) {
      return [
        shimanoSetupPanel(
          context,
          buttonMode: isButtonModeEnabled,
          channels: isDflyChosen,
          canRestore: switchBackup.isNotEmpty,
          showButtonModeWarning: showButtonModeWarning,
          onSetup: () => unawaited(_showSetup(context)),
          onRestore: () => unawaited(_showRestore(context)),
          onTurnOff: () => unawaited(turnOffButtonMode()),
          onSwitchToChannels: () => unawaited(_showChannelSetup(context)),
          onDismissWarning: () => unawaited(dismissButtonModeWarning()),
        ),
      ];
    }
    return [
      Text(
        'Make sure to set your Di2 buttons to D-Fly channels in the Shimano E-TUBE app.',
        style: context.typography.xSmall.copyWith(color: Colors.grey),
      ),
    ];
  }
}

/// The two paddles of each wireless Di2 shifter in button mode, named with the
/// same L1/L2/R1/R2 code their chip shows on the contour, plus the hood button
/// (L3/R3) and satellite switch (L4/R4) some shifters have. Default
/// actions follow Di2's own shifting: right lever → larger cog (easier), right
/// button → smaller cog (harder); left lever → big ring (harder), left button
/// → small ring (easier).
class ShimanoDi2Buttons {
  ShimanoDi2Buttons._();

  static const leftLever = ControllerButton('Di2 L1 (Lever)', label: 'L1', action: InGameAction.shiftUp);
  static const leftButton = ControllerButton('Di2 L2 (Button)', label: 'L2', action: InGameAction.shiftDown);
  static const rightLever = ControllerButton('Di2 R1 (Lever)', label: 'R1', action: InGameAction.shiftDown);
  static const rightButton = ControllerButton('Di2 R2 (Button)', label: 'R2', action: InGameAction.shiftUp);

  static const leftHood = ControllerButton('Di2 L3 (Hood)', label: 'L3');
  static const leftSatellite = ControllerButton('Di2 L4 (Satellite)', label: 'L4');
  static const rightHood = ControllerButton('Di2 R3 (Hood)', label: 'R3');
  static const rightSatellite = ControllerButton('Di2 R4 (Satellite)', label: 'R4');

  static const paddles = [leftLever, leftButton, rightLever, rightButton];

  /// The actions of the D-Fly channels BikeControl puts on the paddles, the
  /// same as those paddles have in button mode: Ch1/Ch2 = left button/lever,
  /// Ch3/Ch4 = right button/lever.
  static final channelActions = {
    1: leftButton.action,
    2: leftLever.action,
    3: rightButton.action,
    4: rightLever.action,
  };
  static const extras = [leftHood, leftSatellite, rightHood, rightSatellite];
  static const values = [...paddles, ...extras];

  static ControllerButton of(ShimanoPaddleEvent e) => switch ((e.shifter, e.paddle)) {
        (ShimanoShifter.left, ShimanoPaddle.big) => leftLever,
        (ShimanoShifter.left, ShimanoPaddle.small) => leftButton,
        (ShimanoShifter.right, ShimanoPaddle.big) => rightLever,
        (ShimanoShifter.right, ShimanoPaddle.small) => rightButton,
        (ShimanoShifter.left, ShimanoPaddle.hood) => leftHood,
        (ShimanoShifter.right, ShimanoPaddle.hood) => rightHood,
        (ShimanoShifter.left, ShimanoPaddle.satellite) => leftSatellite,
        (ShimanoShifter.right, ShimanoPaddle.satellite) => rightSatellite,
      };

  /// The website's Di2 lever line art: the right lever as drawn, mirrored for
  /// the left. Chips sit on the shift lever (big paddle) and on the shift
  /// button (small paddle) behind each brake lever, and on top of each hood.
  /// The satellite switch isn't drawn; its chip sits beside the lever.
  static final layout = ControllerLayout(
    aspectRatio: 980 / 1054,
    shape: ContourShape.steeringPad,
    svgAsset: 'assets/contours/shimano_di2_shifters.svg',
    positions: {
      leftButton: const Offset(0.206, 0.350),
      leftLever: const Offset(0.277, 0.546),
      rightButton: const Offset(0.794, 0.350),
      rightLever: const Offset(0.723, 0.546),
      leftHood: const Offset(0.200, 0.100),
      rightHood: const Offset(0.800, 0.100),
      leftSatellite: const Offset(0.400, 0.880),
      rightSatellite: const Offset(0.600, 0.880),
    },
  );

}

/// The bond (encrypted link) the 18FF config service needs: unbonded, the RD
/// refuses every 18FF read, write and subscribe. Android and iOS pair on their
/// own when the RD answers "insufficient authentication"; WinRT only fails the
/// call, so on Windows BikeControl checks the bond and asks for it.
class ShimanoDi2Bond {
  const ShimanoDi2Bond();

  /// A pairing that works takes a few seconds; a refused one only ends with
  /// the 30 s security-manager timeout (and drops the link), which is too long
  /// to keep the rider waiting. Give up sooner: should Windows still finish
  /// the pairing, Retry finds the bond in place.
  static const _pairTimeout = Duration(seconds: 10);

  /// WinRT HRESULTs for ATT "insufficient authentication / encryption" — what
  /// an 18FF call over an unbonded (or no longer bonded) link fails with.
  static const _insufficientAuthenticationHr = 'hr=-2140864507'; // 0x80650005
  static const _insufficientEncryptionHr = 'hr=-2140864497'; // 0x8065000F

  bool get isRequired => !kIsWeb && Platform.isWindows;

  Future<bool> isPaired(String deviceId) async => await UniversalBle.isPaired(deviceId) ?? false;

  Future<void> pair(String deviceId) => UniversalBle.pair(deviceId, timeout: _pairTimeout);

  static bool isInsufficientAuthentication(Object error) {
    final text = error.toString();
    return text.contains(_insufficientAuthenticationHr) || text.contains(_insufficientEncryptionHr);
  }
}

/// Button mode needs a bond Windows doesn't have and couldn't (or, on
/// reconnect, didn't try to) set up. [cause] is the pairing or GATT failure,
/// null when the bond was only found missing.
class ShimanoDi2PairingRequiredException implements Exception {
  ShimanoDi2PairingRequiredException(this.cause);

  final Object? cause;

  @override
  String toString() => 'ShimanoDi2PairingRequiredException: ${cause ?? 'Di2 is not paired with Windows'}';
}

class ShimanoDi2Constants {
  static const String SERVICE_UUID = "000018ef-5348-494d-414e-4f5f424c4500";
  static const String SERVICE_UUID_ALTERNATIVE = "000018ff-5348-494d-414e-4f5f424c4500";

  static const String D_FLY_CHANNEL_UUID = "00002ac2-5348-494d-414e-4f5f424c4500";
}

enum _Di2State {
  shortPress,
  longPress,
  keep,
  doublePress,
  released,
}

/// Counts which button-mode steps the Di2 answered.
class _CountingShimanoTransport implements ShimanoTransport {
  _CountingShimanoTransport(this._inner);
  final ShimanoTransport _inner;
  int answered = 0;
  int failed = 0;

  Future<T> _count<T>(Future<T> step) async {
    try {
      final result = await step;
      answered++;
      return result;
    } catch (_) {
      failed++;
      rethrow;
    }
  }

  @override
  Future<void> subscribe(String characteristic) => _count(_inner.subscribe(characteristic));

  @override
  Future<void> write(String characteristic, Uint8List data, {bool withoutResponse = false}) =>
      _count(_inner.write(characteristic, data, withoutResponse: withoutResponse));

  @override
  Future<Uint8List> read(String characteristic) => _count(_inner.read(characteristic));

  @override
  Stream<Uint8List> notifications(String characteristic) => _inner.notifications(characteristic);
}
