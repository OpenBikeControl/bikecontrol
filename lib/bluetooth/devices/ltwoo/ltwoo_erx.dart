import 'dart:async';

import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:prop/prop.dart' show LogLevel, Logger, bytesToHex;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../bluetooth_device.dart';
import 'ltwoo_protocol.dart';

/// L-TWOO eRX/eR9 electronic shifting.
///
/// The shift levers talk to the REAR DERAILLEUR over a proprietary radio; the
/// derailleur is the only BLE endpoint. BikeControl connects to it, tracks
/// gear-position changes, and translates them into controller button clicks
/// that the keymap turns into virtual shifting.
///
/// Protocol source: https://github.com/eternal-flame-AD/ltwooShifting
/// (Apache-2.0) — see [LtwooProtocol] for the frame codec.
class LtwooErx extends BluetoothDevice {
  // supportsLongPress: false — we only see gear DELTAS, never press/release
  // edges, so a hold can't be told from a tap.
  LtwooErx(super.scanResult) : super(availableButtons: [], isBeta: true, supportsLongPress: false);

  static const String shiftUpButtonName = 'LTWOO Shift Up';
  static const String shiftDownButtonName = 'LTWOO Shift Down';
  static const String frontShiftButtonName = 'LTWOO Front Shift';

  /// A multi-cog sweep emits one click per step, capped here — beyond that the
  /// rider is dumping the cassette, not asking for N virtual shifts.
  static const int maxClicksPerChange = 3;

  /// One scheduler tick; the rear gear is polled at this cadence.
  static const Duration pollTickInterval = Duration(milliseconds: 500);

  /// Front gear is polled every Nth idle tick (2 s).
  static const int frontPollTickInterval = 4;

  /// Battery is polled every Nth idle tick (60 s), plus once on connect.
  static const int batteryPollTickInterval = 120;

  /// Idle ticks skipped after a failed write before polling resumes (~5 s).
  static const int failureBackoffTicks = 10;

  /// Guard slightly above the platform's own GATT write timeout (10 s on
  /// Android) so a write whose Future never completes cannot wedge the
  /// in-flight guard forever.
  static const Duration writeGuardTimeout = Duration(seconds: 12);

  /// Minimum spacing between consecutive anchor counter-shift commands (the
  /// vendor app spaces its writes 200 ms apart).
  static const Duration counterShiftSpacing = Duration(milliseconds: 200);

  /// A correction that hasn't reached the anchor after this long gives up and
  /// re-anchors at the current gear — never loop forever.
  static const Duration anchorGiveUpTimeout = Duration(seconds: 5);

  /// Extra commands allowed beyond the number of steps a correction needs
  /// before the give-up guard trips.
  static const int anchorExtraCommandBudget = 2;

  /// The single poll scheduler. All requests go out strictly serialized: a
  /// tick that lands while a write is still in flight is skipped, never
  /// queued — the derailleur drops the connection when writes pile up faster
  /// than it answers them (e.g. under heavy concurrent GATT traffic).
  /// Same discipline as https://github.com/eternal-flame-AD/ltwooShifting
  /// (`writeInProgress`).
  Timer? _pollTimer;

  /// Count of poll requests actually sent (skipped ticks don't advance it);
  /// selects which opcode is due next.
  int _pollTick = 0;

  /// Non-null while a write is outstanding; completes when it finishes
  /// (successfully or not). Poll ticks skip while set; explicit sends (hello,
  /// connect-time battery, PIN change) wait on it instead.
  Completer<void>? _writeCompleter;

  /// Idle ticks still to skip after a failed write.
  int _backoffTicksRemaining = 0;

  /// Whether a write failure was already recorded this connection.
  bool _recordedWriteError = false;

  /// Bumped by [resetConnectionState]; aborts sends queued behind an
  /// outstanding write once the connection they belonged to is gone.
  int _connectionGeneration = 0;

  /// Total number of rear gears, learned from the hello response.
  int? _numSpeeds;

  /// Last RAW rear gear (counts from the LARGEST cog); null until the first
  /// successful reading, which initializes state without emitting anything.
  int? _lastRawRearGear;

  /// Last raw front gear; null until first observed. Front shifting is
  /// optional — the button is only registered once a front frame arrives.
  int? _lastRawFrontGear;

  /// Wrong-PIN alert shown at most once per connection (SramAxs
  /// `_warnedSetupNeeded` pattern).
  bool _warnedWrongPin = false;

  /// Kinds of anomalous frames (malformed, unrecognized opcode) already
  /// reported to the app-level support log this connection. The first
  /// occurrence logs with hex; repeats are suppressed so a framing mismatch on
  /// real hardware can't flood the 500-entry buffer at the 2 Hz poll rate.
  final Set<String> _loggedFrameKinds = {};

  /// The NUS service uuid as discovered, captured in [handleServices].
  String? _serviceUuid;

  // --- Anchor-gear mode (rear derailleur only; front shifts are untouched) ---
  //
  // With the mode on, every rider shift still emits its virtual clicks, then
  // counter-shift commands walk the derailleur back to the anchor so the chain
  // stays on one cog. State machine: `idle` → rider delta emits clicks →
  // `countering` → echoes moving toward the anchor are swallowed → anchor
  // reached → `idle`.

  /// idle: gear deltas are rider shifts. countering: a correction toward
  /// [_anchorRawGear] is in progress and its echoes must not emit clicks.
  _AnchorPhase _anchorPhase = _AnchorPhase.idle;

  /// The raw gear the correction returns to: the gear current when the mode
  /// was switched on, or the first gear observed if it was already on.
  int? _anchorRawGear;

  /// Counter commands sent whose gear effect hasn't been observed yet. Kept at
  /// 0 or 1: the next command only goes out once the previous one's outcome is
  /// visible, so every echo can be attributed unambiguously.
  int _pendingCounterSteps = 0;

  /// Commands sent in the current correction episode; capped by
  /// [_episodeStepBudget].
  int _counterCommandsSent = 0;

  /// steps + [anchorExtraCommandBudget], grown when rider presses (or a
  /// misdirected command) fold more distance into the episode.
  int _episodeStepBudget = 0;

  /// True once a counter-shift echo confirmed (or flipped) the direction
  /// mapping this connection; until then the first AWAY-moving echo is treated
  /// as an inverted mapping, not a rider press.
  bool _orientationVerified = false;

  /// Non-null while the [counterShiftSpacing] cooldown after a command runs.
  Timer? _counterCooldownTimer;

  /// Non-null while a correction episode runs; fires the give-up guard.
  Timer? _anchorGiveUpTimer;

  @visibleForTesting
  int? get debugNumSpeeds => _numSpeeds;

  @visibleForTesting
  int? get debugAnchorRawGear => _anchorRawGear;

  String get _pin => core.settings.getLtwooPin(device.deviceId);

  bool get _anchorModeEnabled => core.settings.getLtwooAnchorGearEnabled(device.deviceId);

  bool get _orientationInverted => core.settings.getLtwooShiftOrientationInverted(device.deviceId);

  @override
  Future<void> handleServices(List<BleService> services) async {
    resetConnectionState();
    final service = services.firstOrNullWhere(
      (s) => s.uuid.toLowerCase() == LtwooErxConstants.SERVICE_UUID.toLowerCase(),
    );
    if (service == null) {
      throw Exception('Service not found: ${LtwooErxConstants.SERVICE_UUID}');
    }
    _serviceUuid = service.uuid;

    await UniversalBle.subscribeNotifications(
      device.deviceId,
      service.uuid,
      LtwooErxConstants.TX_CHARACTERISTIC_UUID,
    );

    // Pre-register both shift buttons so they appear in the keymap without
    // needing a shift first (SramAxs advert pre-registration pattern).
    registerShiftButtons();

    startPolling();
  }

  /// Sends the hello (to learn numSpeeds) and the connect-time battery
  /// request, then starts the poll scheduler. The derailleur also pushes
  /// unsolicited event frames, which are parsed by the same path — the rear
  /// poll is the fallback that keeps state fresh.
  @visibleForTesting
  void startPolling() {
    unawaited(_send(LtwooProtocol.opcodeHello));
    unawaited(_send(LtwooProtocol.opcodeGetBattery));
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(pollTickInterval, (_) => _onPollTick());
  }

  /// One scheduler tick. A tick while a write is in flight is skipped, never
  /// queued; after a failed write, [failureBackoffTicks] idle ticks are
  /// consumed before polling resumes. Only [resetConnectionState] (via
  /// [disconnect] / reconnect) stops the scheduler for good.
  void _onPollTick() {
    if (_writeCompleter != null) return;
    if (_backoffTicksRemaining > 0) {
      _backoffTicksRemaining--;
      return;
    }
    _pollTick++;
    final List<int> opcode;
    if (_pollTick % batteryPollTickInterval == 0) {
      opcode = LtwooProtocol.opcodeGetBattery;
    } else if (_pollTick % frontPollTickInterval == 0) {
      opcode = LtwooProtocol.opcodeGetFrontGear;
    } else {
      opcode = LtwooProtocol.opcodeGetRearGear;
    }
    unawaited(_send(opcode));
  }

  Future<void> _send(List<int> opcode) async {
    // Serialize behind any outstanding write (poll ticks never get here while
    // one is in flight — they skip; this wait only orders the few explicit
    // sends: hello, connect-time battery, PIN change).
    final generation = _connectionGeneration;
    while (_writeCompleter != null) {
      await _writeCompleter!.future;
    }
    // The connection this send was queued for is gone — don't write into the
    // next one.
    if (generation != _connectionGeneration) return;

    final completer = _writeCompleter = Completer<void>();
    try {
      final request = LtwooProtocol.buildRequest(_pin, opcode);
      Logger.trace(() => 'ltwoo> ${_maskedHex(request)}');
      await writeRequest(request).timeout(writeGuardTimeout);
    } catch (e, s) {
      _backoffTicksRemaining = failureBackoffTicks;
      // Deliberate dedup, not a swallow: polling retries at 2 Hz against a
      // link that can stay broken for minutes, and every retry funnels through
      // here — so only the FIRST failure per connection goes to [recordError]
      // (support bundles need the failure, not thousands of copies of it).
      // Every failure still triggers the backoff above.
      if (!_recordedWriteError) {
        _recordedWriteError = true;
        await recordError(e, s, context: 'LtwooErx: write ${opcode.map((b) => b.toRadixString(16)).join()}');
      }
    } finally {
      if (identical(_writeCompleter, completer)) {
        _writeCompleter = null;
      }
      completer.complete();
    }
  }

  /// Raw write to the NUS RX characteristic. Overridable seam for tests.
  @protected
  @visibleForTesting
  Future<void> writeRequest(Uint8List data) => UniversalBle.write(
    device.deviceId,
    _serviceUuid ?? LtwooErxConstants.SERVICE_UUID,
    LtwooErxConstants.RX_CHARACTERISTIC_UUID,
    data,
    withoutResponse: false,
  );

  /// Registers the two rear-shift buttons (idempotent).
  @visibleForTesting
  void registerShiftButtons() {
    getOrAddButton(
      shiftUpButtonName,
      () => ControllerButton(shiftUpButtonName, action: InGameAction.shiftUp, sourceDeviceId: device.deviceId),
    );
    getOrAddButton(
      shiftDownButtonName,
      () => ControllerButton(shiftDownButtonName, action: InGameAction.shiftDown, sourceDeviceId: device.deviceId),
    );
  }

  ControllerButton _button(String name, InGameAction action) =>
      getOrAddButton(name, () => ControllerButton(name, action: action, sourceDeviceId: device.deviceId));

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) async {
    if (characteristic.toLowerCase() != LtwooErxConstants.TX_CHARACTERISTIC_UUID.toLowerCase()) return;

    Logger.trace(() => 'ltwoo< ${_maskedHex(bytes)}');

    final response = LtwooProtocol.parseResponse(bytes);
    if (response == null) {
      // Invalid frame — dropped, but a framing mismatch on real hardware must
      // be visible in a support bundle.
      _logFrameOnce('malformed', () => 'LtwooErx: malformed frame (bad XOR/framing): ${_maskedHex(bytes)}');
      return;
    }

    if (response.isWrongPin) {
      if (!_warnedWrongPin) {
        _warnedWrongPin = true;
        core.connection.signalNotification(
          AlertNotification(LogLevel.LOGLEVEL_WARNING, AppLocalizations.current.ltwooWrongPinAlert),
        );
      }
      return;
    }

    if (!response.isHello && !response.isRearGear && !response.isFrontGear && !response.isBattery) {
      final opcodeHex = response.opcode.toRadixString(16).padLeft(4, '0');
      _logFrameOnce('opcode-$opcodeHex', () => 'LtwooErx: unrecognized opcode 0x$opcodeHex: ${_maskedHex(bytes)}');
      return;
    }

    if (response.payload.isEmpty) return;
    final value = response.payload.first;

    if (response.isHello) {
      if (_numSpeeds != value) {
        actionStreamInternal.add(LogNotification('LtwooErx: derailleur reports $value speeds'));
      }
      _numSpeeds = value;
    } else if (response.isRearGear) {
      await _onRearGear(value);
    } else if (response.isFrontGear) {
      await _onFrontGear(value);
    } else if (response.isBattery) {
      if (batteryLevel != value) {
        actionStreamInternal.add(LogNotification('LtwooErx: battery $value%'));
      }
      batteryLevel = value;
      core.connection.signalChange(this);
    }
  }

  /// Adds an app-level support-log line for an anomalous frame [kind], at most
  /// once per connection ([_loggedFrameKinds] is cleared on reconnect). The
  /// wrong-PIN alert has its own once-per-connection flag and never routes
  /// through here, so this suppression cannot hide it.
  void _logFrameOnce(String kind, String Function() message) {
    if (!_loggedFrameKinds.add(kind)) return;
    actionStreamInternal.add(LogNotification(message()));
  }

  /// Hex dump with the 3 PIN/pwd bytes after the frame header masked as
  /// `??????` so support bundles never carry a user's derailleur PIN.
  static String _maskedHex(List<int> bytes) {
    if (bytes.length < 4 ||
        (bytes.first != LtwooProtocol.requestHeader && bytes.first != LtwooProtocol.responseHeader)) {
      return bytesToHex(bytes);
    }
    return '${bytesToHex([bytes.first])}??????${bytesToHex(bytes.sublist(4))}';
  }

  /// The display gear for [raw], or `?` while numSpeeds is still unknown.
  String _displayGear(int raw) {
    final numSpeeds = _numSpeeds;
    return numSpeeds == null ? '?' : '${LtwooProtocol.displayGear(numSpeeds: numSpeeds, rawGear: raw)}';
  }

  Future<void> _onRearGear(int raw) async {
    if (_anchorModeEnabled) return _onRearGearAnchored(raw);

    final last = _lastRawRearGear;
    _lastRawRearGear = raw;
    if (last == null) {
      // First reading initializes silently (no click) — but the starting gear
      // is a key diagnostic for a support bundle.
      actionStreamInternal.add(LogNotification('LtwooErx: first rear gear raw $raw (display ${_displayGear(raw)})'));
      return;
    }
    if (raw == last) return;
    await _emitRearShift(last, raw);
  }

  /// Emits the virtual clicks (and the descriptive support log) for a rear
  /// gear movement [from] → [to], capped at [maxClicksPerChange].
  ///
  /// RAW counts from the LARGEST cog: a raw DECREASE is a smaller cog =
  /// harder gear = "Shift Up"; a raw increase is "Shift Down".
  Future<void> _emitRearShift(int from, int to) async {
    final shiftUp = to < from;
    final button = shiftUp
        ? _button(shiftUpButtonName, InGameAction.shiftUp)
        : _button(shiftDownButtonName, InGameAction.shiftDown);
    final steps = (to - from).abs().coerceAtMost(maxClicksPerChange);
    actionStreamInternal.add(
      LogNotification(
        'LtwooErx: rear $from→$to (display ${_displayGear(from)}→${_displayGear(to)}), '
        '$steps× ${shiftUp ? 'Shift Up' : 'Shift Down'}',
      ),
    );
    for (var i = 0; i < steps; i++) {
      await _emitClick(button);
    }
  }

  /// Rear-gear handling with anchor mode on. Rider deltas emit clicks exactly
  /// like the plain path, then counter commands walk the derailleur back to
  /// [_anchorRawGear]; the movement those commands cause is swallowed.
  Future<void> _onRearGearAnchored(int raw) async {
    final last = _lastRawRearGear;
    _lastRawRearGear = raw;
    if (last == null) {
      // Mode enabled before/at connect: the first observed gear is the anchor.
      _anchorRawGear ??= raw;
      actionStreamInternal.add(
        LogNotification('LtwooErx: first rear gear raw $raw (display ${_displayGear(raw)}), anchor gear mode on'),
      );
      return;
    }
    // Toggled on outside [setAnchorGearEnabled] (e.g. settings written
    // directly): anchor at the last known gear, before this delta.
    _anchorRawGear ??= last;
    final anchor = _anchorRawGear!;

    if (raw == last) {
      // The derailleur answers strictly in order, so any reading that arrives
      // after a counter command reflects its outcome: unchanged means the
      // command had no effect (e.g. cassette end) — release it and let the
      // budget/give-up guards decide whether to try again.
      if (_anchorPhase == _AnchorPhase.countering && _pendingCounterSteps > 0) {
        _pendingCounterSteps = 0;
        _maybeSendCounterCommand();
      }
      return;
    }

    final delta = raw - last;
    var riderDelta = delta;

    if (_anchorPhase == _AnchorPhase.countering && _pendingCounterSteps > 0) {
      final towardSign = (anchor - last).sign;
      if (towardSign != 0 && delta.sign == towardSign) {
        // Movement toward the anchor: the first step(s), up to the outstanding
        // counter commands and never past the anchor, are our own — swallow
        // them. Anything beyond is the rider helping and still gets clicks.
        final ours = delta.abs().coerceAtMost(_pendingCounterSteps).coerceAtMost((anchor - last).abs());
        _pendingCounterSteps -= ours;
        _orientationVerified = true;
        riderDelta = delta - towardSign * ours;
      } else if (towardSign != 0 && !_orientationVerified) {
        // The first counter-shift echo of this connection moved AWAY from the
        // anchor: this derailleur maps the shift opcodes the other way around.
        // Flip the mapping for the rest of the connection (persisted per
        // device), swallow the misdirected step(s), and let the corrective
        // commands below converge on the anchor with the corrected mapping.
        _orientationVerified = true;
        unawaited(core.settings.setLtwooShiftOrientationInverted(device.deviceId, !_orientationInverted));
        actionStreamInternal.add(LogNotification('LtwooErx: shift command orientation inverted, corrected'));
        final ours = delta.abs().coerceAtMost(_pendingCounterSteps);
        _pendingCounterSteps -= ours;
        // The misdirected steps consumed budget AND grew the distance.
        _episodeStepBudget += ours;
        riderDelta = delta + towardSign * ours;
      }
      // Away movement with a verified orientation: the rider pressed again —
      // it stays in riderDelta and emits clicks below.
    }

    if (riderDelta != 0) {
      await _emitRearShift(raw - riderDelta, raw);
    }

    if (raw == anchor && _pendingCounterSteps == 0) {
      _endCounterEpisode();
      return;
    }
    if (_anchorPhase == _AnchorPhase.idle) {
      _startCounterEpisode();
    } else if (riderDelta != 0) {
      // A rider press mid-correction folds into the same episode (the target
      // stays the anchor); the budget grows so the guard stays proportional
      // to the total distance.
      _episodeStepBudget += riderDelta.abs();
    }
    _maybeSendCounterCommand();
  }

  void _startCounterEpisode() {
    _anchorPhase = _AnchorPhase.countering;
    _counterCommandsSent = 0;
    _episodeStepBudget = (_anchorRawGear! - _lastRawRearGear!).abs() + anchorExtraCommandBudget;
    _anchorGiveUpTimer?.cancel();
    _anchorGiveUpTimer = Timer(anchorGiveUpTimeout, _giveUpAnchorCorrection);
  }

  /// Stops commanding, re-anchors at the current gear, and returns to idle.
  /// Logs at most once per episode by construction: both triggers (command
  /// budget and timer) end the episode, which disarms them.
  void _giveUpAnchorCorrection() {
    final raw = _lastRawRearGear;
    actionStreamInternal.add(LogNotification('LtwooErx: could not return to anchor gear, re-anchoring at $raw'));
    _anchorRawGear = raw;
    _endCounterEpisode();
  }

  void _endCounterEpisode() {
    _anchorPhase = _AnchorPhase.idle;
    _pendingCounterSteps = 0;
    _counterCommandsSent = 0;
    _episodeStepBudget = 0;
    _anchorGiveUpTimer?.cancel();
    _anchorGiveUpTimer = null;
    _counterCooldownTimer?.cancel();
    _counterCooldownTimer = null;
  }

  /// Sends the next counter-shift command when one is due: countering, no
  /// command outstanding, and outside the [counterShiftSpacing] cooldown.
  /// Ends the episode at the anchor; trips the give-up guard at the budget.
  void _maybeSendCounterCommand() {
    if (_anchorPhase != _AnchorPhase.countering) return;
    if (_pendingCounterSteps > 0 || _counterCooldownTimer != null) return;
    final raw = _lastRawRearGear;
    final anchor = _anchorRawGear;
    if (raw == null || anchor == null || raw == anchor) {
      _endCounterEpisode();
      return;
    }
    if (_counterCommandsSent >= _episodeStepBudget) {
      _giveUpAnchorCorrection();
      return;
    }
    _pendingCounterSteps = 1;
    _counterCommandsSent++;
    _counterCooldownTimer = Timer(counterShiftSpacing, () {
      _counterCooldownTimer = null;
      _maybeSendCounterCommand();
    });
    unawaited(_send(_counterShiftOpcode(increaseRaw: anchor > raw)));
  }

  /// The opcode that moves the raw gear one step in the requested direction
  /// under the current (possibly runtime-flipped) mapping.
  List<int> _counterShiftOpcode({required bool increaseRaw}) => increaseRaw != _orientationInverted
      ? LtwooProtocol.opcodeShiftRearRawIncrease
      : LtwooProtocol.opcodeShiftRearRawDecrease;

  /// Persists the anchor-gear toggle. Turning it ON (re-)anchors at the
  /// current gear; turning it OFF clears the anchor and any correction in
  /// progress.
  Future<void> setAnchorGearEnabled(bool enabled) async {
    await core.settings.setLtwooAnchorGearEnabled(device.deviceId, enabled);
    _endCounterEpisode();
    _anchorRawGear = enabled ? _lastRawRearGear : null;
    if (enabled && _anchorRawGear != null) {
      actionStreamInternal.add(LogNotification('LtwooErx: anchor gear mode on, anchored at raw $_anchorRawGear'));
    }
  }

  Future<void> _onFrontGear(int raw) async {
    final last = _lastRawFrontGear;
    _lastRawFrontGear = raw;
    // Register the button on the first front-gear observation so only bikes
    // that actually have a front derailleur get the extra keymap entry.
    final button = _button(frontShiftButtonName, InGameAction.frontShift);
    if (last == null || raw == last) return;
    actionStreamInternal.add(LogNotification('LtwooErx: front $last→$raw, Front Shift'));
    await _emitClick(button);
  }

  Future<void> _emitClick(ControllerButton button) async {
    await handleButtonsClicked([button]);
    await handleButtonsClicked(const []);
  }

  /// Persists a new PIN and re-sends the hello so the derailleur re-validates
  /// it (and re-reports numSpeeds).
  Future<void> setPin(String pin) async {
    await core.settings.setLtwooPin(device.deviceId, pin);
    _warnedWrongPin = false; // a wrong new PIN should warn again
    await _send(LtwooProtocol.opcodeHello);
  }

  /// Stops the poll scheduler and clears per-connection state so a reconnect
  /// initializes silently again. Extracted from [disconnect] for tests that
  /// can't reach the BLE platform channel (WheeltopEds pattern).
  @visibleForTesting
  void resetConnectionState() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pollTick = 0;
    _connectionGeneration++;
    // A still-outstanding write belongs to the dead connection; its own guard
    // timeout completes it eventually — don't let it block the next one.
    _writeCompleter = null;
    _backoffTicksRemaining = 0;
    _recordedWriteError = false;
    _numSpeeds = null;
    _lastRawRearGear = null;
    _lastRawFrontGear = null;
    _warnedWrongPin = false;
    _loggedFrameKinds.clear();
    // Anchor state must not leak across connections: the anchor and the
    // learned-orientation check are per-connection (the persisted orientation
    // setting survives; only its verification is redone).
    _endCounterEpisode();
    _anchorRawGear = null;
    _orientationVerified = false;
  }

  @override
  Future<void> disconnect() async {
    resetConnectionState();
    await super.disconnect();
  }

  @override
  List<Widget> showAdditionalInformation(BuildContext context) => [
    Text(context.i18n.ltwooHintCloseApp).xSmall,
    Text(context.i18n.ltwooHintCassetteEnds).xSmall,
  ];

  @override
  Widget? buildPreferences(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(context.i18n.ltwooPinLabel).small),
            SizedBox(
              width: 80,
              child: TextField(
                initialValue: _pin,
                maxLength: 3,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (value) {
                  if (value.length == 3) unawaited(setPin(value));
                },
              ),
            ),
          ],
        ),
        const Gap(8),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.i18n.ltwooAnchorGearTitle).small,
                  Text(context.i18n.ltwooAnchorGearDescription).xSmall.muted,
                ],
              ),
            ),
            const Gap(8),
            StatefulBuilder(
              builder: (context, setState) => Switch(
                value: _anchorModeEnabled,
                onChanged: (value) {
                  unawaited(setAnchorGearEnabled(value));
                  setState(() {});
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Anchor-mode phases: see the state-machine comment on the anchor fields.
enum _AnchorPhase { idle, countering }

class LtwooErxConstants {
  /// Nordic UART Service (shared with other NUS devices — matching is
  /// name-gated, never by this UUID alone).
  static const String SERVICE_UUID = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';

  /// Requests are written here (write with response).
  static const String RX_CHARACTERISTIC_UUID = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';

  /// Responses/event frames are notified here.
  static const String TX_CHARACTERISTIC_UUID = '6e400003-b5a3-f393-e0a9-e50e24dcca9e';

  /// eRX/eR9 derailleurs advertise names like `LTOED2501…` (chars 5–9 encode
  /// the model). `LTOED00…` is a legacy model with different framing —
  /// excluded from matching.
  static const String NAME_PREFIX = 'LTOED';
  static const String LEGACY_NAME_PREFIX = 'LTOED00';

  static bool matchesName(String? name) {
    final upper = name?.toUpperCase();
    if (upper == null) return false;
    return upper.startsWith(NAME_PREFIX) && !upper.startsWith(LEGACY_NAME_PREFIX);
  }
}
