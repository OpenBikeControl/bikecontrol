import 'dart:async';

import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
// The prop package exports a `SramAxs` constants class with the same name as
// this file's `SramAxs` device class. Hide it from the wildcard import and
// pull it back in under a prefix so both symbols stay unambiguous.
import 'package:prop/prop.dart' hide SramAxs;
import 'package:prop/prop.dart' as sram_proto show SramAxs;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../bluetooth_device.dart';
import 'sram_ble_transport.dart';
import 'sram_setup_sheet.dart';

class SramAxs extends BluetoothDevice {
  // supportsLongPress: false — a held SRAM lever emits one 0xFF edge and no
  // release (no multishift burst with shifting disabled), so a hold can't be
  // told from a tap; long-press isn't reconstructable. Single/double click and
  // the both-levers combo are (see _onPress).
  SramAxs(super.scanResult) : super(availableButtons: [], isBeta: false, supportsLongPress: false);

  SramBleTransport? _transport;
  SramAxsLogic? _logic;
  Timer? _keepAliveTimer;

  /// Logged once per connection when a press can't be decoded, so it's clear
  /// from the logs whether the session key is active this session.
  bool _loggedDegradedPress = false;

  /// User-facing setup nudge, shown at most once per connection (see
  /// _loggedDegradedPress for the log-side counterpart).
  bool _warnedSetupNeeded = false;

  /// Gesture reconstruction (protocol §7). A SRAM press is a single 0xFF EDGE on
  /// d9050054 — no release event, and (with shifting disabled) no multishift
  /// burst — so a hold is indistinguishable from a tap and long-press can't be
  /// reconstructed. Every press is therefore a discrete CLICK. The one thing the
  /// base device needs that the raw edge stream doesn't give us is "both levers
  /// at once", so a press is buffered for a short window: if the other lever's
  /// press lands inside it, both buttons are emitted together and the base device
  /// runs the front-shift combo ({shiftUp, shiftDown} → frontShift); otherwise
  /// the single button clicks. Single vs double click is left to the base device
  /// (two discrete taps within its double-click window). A SAME-name press inside
  /// the window is a duplicate of the pending one, not a new tap — a finger can't
  /// re-press a lever within 90ms, but on iOS a colliding read response of the
  /// 0xFF edge is re-delivered through the notify callback (§6.1) and decodes to
  /// the same button — so it coalesces instead of actuating twice.
  static const Duration _comboWindow = Duration(milliseconds: 90);
  final Map<String, ControllerButton> _pendingPresses = {}; // buffered during the combo window, by name
  Timer? _comboTimer;

  /// Multishift/hold guard (protocol §7), active ONLY while shifting is still
  /// enabled (pre-setup, or after a restore): there a held paddle makes the
  /// derailleur emit a rapid burst of triggers, so we forward the first two of
  /// a burst chain (a genuine double-click still works) and drop the rest until
  /// the stream goes quiet for [_multishiftWindow]. Once setup has disabled
  /// shifting — the normal bonded state — a held lever emits exactly ONE edge
  /// (verified by an --observe capture, see 16fad263), so no guard applies and
  /// every edge is a genuine tap. Timer-driven rather than wall-clock so it is
  /// deterministic under fakeAsync and reset by [_resetGesture] on (re)connect.
  static const Duration _multishiftWindow = Duration(milliseconds: 350);
  int _rapidTriggerCount = 0;
  Timer? _burstResetTimer;

  /// Stable "Shifter A/B/..." labels assigned to controller serials in the
  /// order they are first seen.
  final List<int> _serialOrder = [];

  String get _serialKey => device.deviceId;

  String _shifterLabel(int? serial) {
    if (serial == null) return '';
    var idx = _serialOrder.indexOf(serial);
    if (idx == -1) {
      _serialOrder.add(serial);
      idx = _serialOrder.length - 1;
    }
    return String.fromCharCode('A'.codeUnitAt(0) + idx);
  }

  /// Look up a pressing shifter's advertised type/model by serial. Prefers a
  /// live scan advert (which it also persists for future sessions); falls back
  /// to the persisted (deviceType, model) so a button's §6.4 name stays stable
  /// once the shifter's advert has been seen at least once.
  SramDeviceInfo? _shifterInfo(int? serial) {
    if (serial == null) return null;
    for (final info in core.connection.sramShifterAdverts) {
      if (info.serial == serial) {
        core.settings.setSramShifter(_serialKey, serial, info.deviceType, info.model); // remember for later sessions
        return info;
      }
    }
    final stored = core.settings.getSramShifter(_serialKey, serial);
    if (stored != null) {
      return SramDeviceInfo(serial: serial, deviceType: stored.deviceType, model: stored.model);
    }
    return null;
  }

  /// Pure naming from an (optional) advert + serial + mask. Exposed for tests.
  String buttonNameFor(SramDeviceInfo? info, int? serial, int? mask) {
    if (serial == null && mask == null) return 'SRAM Button';
    final side = _sideLabel(info, serial); // 'Left'/'Right' (type 0/1), else 'Shifter A/B', else ''
    if (mask == null) return side.isEmpty ? 'SRAM Button' : 'SRAM $side';
    final role = SramShifterButtons.nameFor(info?.deviceType, info?.model, mask);
    // Some roles already encode the side (drop-bar "Left/Right Shifter", "Vuka L/R
    // Shifter") — don't prefix a redundant side.
    if (role.startsWith('Left ') || role.startsWith('Right ') || role.startsWith('Vuka ')) return 'SRAM $role';
    return side.isEmpty ? 'SRAM $role' : 'SRAM $side – $role';
  }

  /// Stable name for one physical (shifter, button). [deviceType] is the value
  /// decoded from the button event (field 2) when available — it's the
  /// authoritative pressing side and, crucially, tells the left and right
  /// paddles apart (both report mask 1) even when no d9050003 serial was seen.
  /// Single vs double click is handled by the base device from the keymap, not
  /// encoded in the name.
  String logicalButtonName(int? serial, int? mask, {int? deviceType}) =>
      buttonNameFor(_infoFor(serial, deviceType), serial, mask);

  /// Advert/persisted info for [serial], augmented with a decoded press
  /// [deviceType] when the advert supplied none (or there's no serial at all).
  /// The button event's device_type is authoritative for the pressing side, so
  /// it fills in the side even before any advert/serial has been observed.
  SramDeviceInfo? _infoFor(int? serial, int? deviceType) {
    final info = _shifterInfo(serial);
    if (deviceType == null || (info != null && info.deviceType != null)) return info;
    // buttonNameFor only reads deviceType/model, never serial — a placeholder
    // serial here is harmless and keeps SramDeviceInfo's required field happy.
    return SramDeviceInfo(serial: serial ?? info?.serial ?? 0, deviceType: deviceType, model: info?.model);
  }

  /// Default in-game action for a freshly discovered button. So the two shifters
  /// aren't identical out of the box (and "one lever changes down" works without
  /// hunting through the keymap), the LEFT shifter's paddle defaults to shift
  /// DOWN and everything else to shift UP. Any button remains freely remappable.
  /// Exposed for tests.
  InGameAction defaultAction(int? deviceType, int? mask) =>
      (mask == sram_proto.SramAxs.paddleMask && deviceType == 0) ? InGameAction.shiftDown : InGameAction.shiftUp;

  String _sideLabel(SramDeviceInfo? info, int? serial) {
    if (info?.deviceType == 0) return 'Left';
    if (info?.deviceType == 1) return 'Right';
    if (serial != null) return 'Shifter ${_shifterLabel(serial)}';
    return '';
  }

  // -1 is the persisted sentinel for "null" (see Settings.addSramButton).
  static int? _fromStored(int v) => v == -1 ? null : v;

  /// Names a persisted (stored) button, mapping the `-1` sentinel back to null
  /// so re-registration never yields `"Button 0x-1"` or a phantom shifter slot.
  /// [storedDeviceType] (null for pre-side records) keeps a serial-less press's
  /// name stable across restarts. Exposed for tests.
  String storedButtonName(int storedSerial, int storedMask, {int? storedDeviceType}) =>
      logicalButtonName(_fromStored(storedSerial), _fromStored(storedMask), deviceType: storedDeviceType);

  @override
  Future<void> handleServices(List<BleService> services) async {
    _resetGesture(); // clear any gesture timers/state left over from a prior connection
    final transport = SramBleTransport(device.deviceId, services);
    final logic = SramAxsLogic(transport);
    _transport = transport;
    _logic = logic;

    // The SRAM rear derailleur drops idle BLE connections after ~3 minutes.
    // Requesting high-performance connection parameters keeps link-layer PDU
    // exchange frequent enough to prevent the supervision timeout from firing.
    try {
      await UniversalBle.requestConnectionPriority(device.deviceId, BleConnectionPriority.highPerformance);
    } catch (_) {}

    // Seed a previously-persisted session key so we start bonded when possible.
    final storedKey = core.settings.getSramKey(_serialKey);
    if (storedKey != null) {
      logic.seedKey(_hexToBytes(storedKey));
    }

    // Subscribe: press trigger, component event (plaintext), bond channel,
    // and gear state. The gear char generates periodic notifications that
    // double as application-level keepalive traffic.
    for (final char in [
      sram_proto.SramAxs.controlTriggerChar,
      sram_proto.SramAxs.componentEventChar,
      sram_proto.SramAxs.bondChar,
      sram_proto.SramAxs.gearChar,
    ]) {
      final service = services.firstOrNullWhere((s) => s.characteristics.any((c) => c.uuid == char.toLowerCase()));
      if (service != null) {
        await UniversalBle.subscribeNotifications(device.deviceId, service.uuid, char.toLowerCase());
      } else if (char == sram_proto.SramAxs.controlTriggerChar) {
        // The trigger char is essential; without it the device can't report
        // presses. Log it so a non-functional connect is diagnosable from logs.
        actionStreamInternal.add(LogNotification('SramAxs: control-trigger characteristic $char not found'));
      }
    }

    // Re-register any previously-discovered buttons so they persist in the keymap.
    // The `-1` sentinel is mapped back to null so it never yields "Button 0x-1".
    // The stored device_type reproduces the same left/right name (and default)
    // as the live press did, so a restart doesn't spawn a duplicate entry.
    for (final b in core.settings.getSramButtons(_serialKey)) {
      _registerButton(_fromStored(b.serial), _fromStored(b.mask), deviceType: b.deviceType);
    }

    // Pre-register buttons for nearby SRAM shifters (§6.4) so they show up in the
    // keymap without needing a press. Persist each advert (serial → type/model)
    // so its buttons keep the same §6.4 name in future sessions even when the
    // shifter isn't advertising.
    for (final info in core.connection.sramShifterAdverts) {
      core.settings.setSramShifter(_serialKey, info.serial, info.deviceType, info.model);
      for (final mask in SramShifterButtons.masksFor(info.deviceType, info.model)) {
        final name = buttonNameFor(info, info.serial, mask);
        getOrAddButton(
          name,
          () => ControllerButton(name, action: defaultAction(info.deviceType, mask), sourceDeviceId: device.deviceId),
        );
      }
    }

    _startKeepAlive(services);
  }

  void _startKeepAlive(List<BleService> services) {
    _keepAliveTimer?.cancel();
    final gearService = services.firstOrNullWhere(
      (s) => s.characteristics.any((c) => c.uuid == sram_proto.SramAxs.gearChar.toLowerCase()),
    );
    if (gearService == null) return;
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      try {
        await UniversalBle.read(device.deviceId, gearService.uuid, sram_proto.SramAxs.gearChar.toLowerCase());
      } catch (_) {}
    });
  }

  ControllerButton _registerButton(int? serial, int? mask, {int? deviceType}) {
    final name = logicalButtonName(serial, mask, deviceType: deviceType);
    return getOrAddButton(
      name,
      () => ControllerButton(name, action: defaultAction(deviceType, mask), sourceDeviceId: device.deviceId),
    );
  }

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) async {
    final lc = characteristic.toLowerCase();
    _transport?.onNotification(characteristic, bytes);

    if (lc == sram_proto.SramAxs.componentEventChar.toLowerCase()) {
      _logic?.onComponentEvent(bytes);
      return;
    }

    if (lc == sram_proto.SramAxs.controlTriggerChar.toLowerCase()) {
      // Only the 1-byte 0xFF edge is a press (§6.1). handleTrigger() READS the
      // encrypted button event from this same characteristic; on iOS/CoreBluetooth
      // a read response is also delivered through the notify callback, so that
      // multi-byte value re-enters here — treating it as a new press would read
      // again and spin an infinite loop. Ignore anything that isn't the 0xFF edge.
      if (bytes.length != 1 || bytes[0] != SramAxsConstants.triggerEdge) return;

      // Multishift/hold guard (§7) — only while shifting is enabled (see the
      // _multishiftWindow field doc for the full policy).
      if (!isShiftingDisabled) {
        _burstResetTimer?.cancel();
        _burstResetTimer = Timer(_multishiftWindow, () => _rapidTriggerCount = 0);
        if (++_rapidTriggerCount > 2) return;
      }

      // 0xFF edge → resolve identity (may read+decrypt), then feed the press into
      // the gesture reconstruction (DOWN/RELEASE/combo timing lives in _onPress).
      final press = await _logic?.handleTrigger() ?? const SramPress();
      // Persist a re-bond if the key was just dropped.
      if (_logic != null && !_logic!.isBonded && core.settings.getSramKey(_serialKey) != null) {
        await core.settings.setSramKey(_serialKey, null);
      }
      final serial = press.controllerSerial;
      final mask = press.buttonMask;
      final deviceType = press.deviceType; // field 2: pressing side (0=left, 1=right)
      if (mask == null && !_loggedDegradedPress) {
        _loggedDegradedPress = true;
        actionStreamInternal.add(
          LogNotification(
            'SramAxs: press received but not decoded ${_bytesToHex(bytes)} — the bond session key is not active this '
            'session (using plaintext). Full per-button decoding and setup/restore need '
            're-authorizing (Set up SRAM control → press and hold the AXS button).',
          ),
        );
      }
      if (serial != null || mask != null) {
        await core.settings.addSramButton(_serialKey, serial ?? -1, mask ?? -1, deviceType);
      }
      // If this press revealed a shifter's side, remember it against its serial
      // (preserving any known model) so the shifter's other buttons — and future
      // sessions — resolve the same §6.4 name.
      if (serial != null && deviceType != null) {
        final known = core.settings.getSramShifter(_serialKey, serial);
        if (known?.deviceType == null) core.settings.setSramShifter(_serialKey, serial, deviceType, known?.model);
      }
      final button = _registerButton(serial, mask, deviceType: deviceType);
      // Once per connection, like _loggedDegradedPress — this fires on every
      // undecoded press otherwise, spamming a warning per shift for the whole ride.
      if (!_warnedSetupNeeded && button.name == "SRAM Button" && _logic?.isBonded == false) {
        _warnedSetupNeeded = true;
        core.connection.signalNotification(
          AlertNotification(
            LogLevel.LOGLEVEL_WARNING,
            'To properly detect the SRAM buttons, please set up SRAM control in the app. This will allow the app to bond with the SRAM device and enable full functionality.',
          ),
        );
      }
      _onPress(button);
    }
  }

  /// Feed one decoded physical press (a 0xFF edge) into the gesture engine.
  /// Exposed for tests.
  @visibleForTesting
  void onPress(ControllerButton button) => _onPress(button);

  void _onPress(ControllerButton button) {
    // Buffer for the combo window; a second, different lever landing inside it
    // is combined into one emit so the base device can run the front-shift
    // combo. A same-name press overwrites the pending one — it's the iOS
    // read-response echo of the same tap (see the _comboWindow field doc).
    _pendingPresses[button.name] = button;
    _comboTimer ??= Timer(_comboWindow, _flushPresses);
  }

  void _flushPresses() {
    _comboTimer = null;
    if (_pendingPresses.isEmpty) return;
    final buttons = _pendingPresses.values.toList();
    _pendingPresses.clear();
    // One button → single (or double) click; two → the base device's front-shift
    // combo. A discrete down+up: SRAM gives no separate release edge.
    unawaited(_emitClick(buttons));
  }

  Future<void> _emitClick(List<ControllerButton> buttons) async {
    await handleButtonsClicked(buttons);
    await handleButtonsClicked(const []);
  }

  /// Drop any in-flight gesture state (on (re)connect / teardown) so a timer from
  /// a previous session can't emit a stale press.
  void _resetGesture() {
    _comboTimer?.cancel();
    _comboTimer = null;
    _pendingPresses.clear();
    _burstResetTimer?.cancel();
    _burstResetTimer = null;
    _rapidTriggerCount = 0;
  }

  @override
  Future<void> disconnect() async {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    _resetGesture();
    await super.disconnect();
  }

  Uint8List _hexToBytes(String hex) => Uint8List.fromList([
    for (var i = 0; i < hex.length; i += 2) int.parse(hex.substring(i, i + 2), radix: 16),
  ]);

  String _bytesToHex(Uint8List b) => b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();

  // ── Guided setup / restore (called from the UI in Task 12) ────────────────

  Future<void> setupControl() async {
    final logic = _logic;
    if (logic == null) return;
    try {
      // Ensure a working bond (re-bonds if a persisted key went stale).
      await logic.ensureBonded();
      await core.settings.setSramKey(_serialKey, _bytesToHex(logic.sessionKey!));
      // Capture the ORIGINAL config exactly once. Never overwrite a saved backup:
      // a re-run (or a mid-unassign failure retry) reads the already-cleared
      // device and would otherwise wipe the only copy of the user's config.
      if (core.settings.getSramBackup(_serialKey) == null) {
        final backup = await logic.backupConfig();
        await core.settings.setSramBackup(_serialKey, backup);
      }
      await logic.disableShifting();
      await core.settings.setSramShiftingDisabled(_serialKey, true);
      core.connection.signalChange(this);
    } catch (e, st) {
      actionStreamInternal.add(LogNotification('SramAxs setup failed: $e\n$st'));
      rethrow;
    }
  }

  Future<void> restoreShifting() async {
    final logic = _logic;
    final backup = core.settings.getSramBackup(_serialKey);
    if (logic == null || backup == null) return;
    try {
      await logic.restoreConfig(backup);
      await core.settings.setSramKey(_serialKey, _bytesToHex(logic.sessionKey!)); // persist any re-bond
      await core.settings.setSramShiftingDisabled(_serialKey, false);
      await core.settings.clearSramBackup(_serialKey); // next setup captures fresh
      core.connection.signalChange(this);
    } catch (e, st) {
      actionStreamInternal.add(LogNotification('SramAxs restore failed: $e\n$st'));
      rethrow;
    }
  }

  bool get isBonded => _logic?.isBonded ?? false;
  bool get isShiftingDisabled => core.settings.getSramShiftingDisabled(_serialKey);

  /// Whether the guided "disable on-device shifting" setup hasn't run yet for
  /// this derailleur. Uses the same serial key as the setup itself.
  bool get needsGuidedSetup => !core.settings.getSramShiftingDisabled(_serialKey);

  /// Whether the rider can hand the derailleur's own shifting back: setup has
  /// already disabled it, and the original config is still backed up to put
  /// back. Keyed off persisted state, not the live bond, so the home card can
  /// offer restore even before the session key is re-established — the guided
  /// flow re-bonds ([restoreConfig] calls `ensureBonded`). Presence gating (the
  /// derailleur must be here for BLE to reach it) is the caller's job.
  bool get canRestoreShifting => isShiftingDisabled && core.settings.getSramBackup(_serialKey) != null;

  /// Opens the same guided setup sheet as the device card's
  /// "Set up SRAM control" button. Used by the onboarding wizard.
  Future<void> showGuidedSetup(BuildContext context) {
    final l = context.i18n;
    return _runGuidedOperation(
      context,
      title: l.sramSetup,
      intro: l.sramSetupIntro,
      successMessage: l.sramSetupSuccess,
      confirmIcon: LucideIcons.slidersHorizontal,
      runningTitle: l.sramSettingUp,
      successTitle: l.sramAllSet,
      checklistItems: [l.sramChecklistPairing, l.sramChecklistBackingUp, l.sramChecklistDisabling],
      operation: setupControl,
    );
  }

  /// Opens the same guided restore sheet as the device card's "Restore original
  /// shifting" button. Shared with the home card's optional restore offer so the
  /// two run the identical flow.
  Future<void> showGuidedRestore(BuildContext context) {
    final l = context.i18n;
    return _runGuidedOperation(
      context,
      title: l.sramRestore,
      intro: l.sramRestoreIntro,
      successMessage: l.sramRestoreSuccess,
      confirmIcon: LucideIcons.rotateCcw,
      runningTitle: l.sramRestoringShifting,
      successTitle: l.sramRestoredTitle,
      checklistItems: [l.sramChecklistPairing, l.sramChecklistRestoring],
      operation: restoreShifting,
    );
  }

  @override
  List<Widget> showAdditionalInformation(BuildContext context) => [_buildSetupPanel(context)];

  // The setup panel lives on the main device card (showAdditionalInformation),
  // so there's no separate preferences view.
  @override
  Widget? buildPreferences(BuildContext context) => null;

  Widget _buildSetupPanel(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = context.i18n;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hasBackup = core.settings.getSramBackup(_serialKey) != null;

    // This renders inside the device card, which already shows the device header
    // and the mappable-button list — so keep it to just the current status and
    // the setup/restore action. The rich flow lives in the guided sheet.
    if (!isShiftingDisabled || !isBonded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.sramPanelIntro,
            style: context.typography.small.copyWith(height: 1.4, color: scheme.mutedForeground),
          ),
          const Gap(12),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              leading: const Icon(LucideIcons.slidersHorizontal, size: 16),
              onPressed: () => unawaited(
                _runGuidedOperation(
                  context,
                  title: l.sramSetup,
                  intro: l.sramSetupIntro,
                  successMessage: l.sramSetupSuccess,
                  confirmIcon: LucideIcons.slidersHorizontal,
                  runningTitle: l.sramSettingUp,
                  successTitle: l.sramAllSet,
                  checklistItems: [l.sramChecklistPairing, l.sramChecklistBackingUp, l.sramChecklistDisabling],
                  operation: setupControl,
                ),
              ),
              child: Text(l.sramSetup),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: dark ? const Color(0x1A22C55E) : sramSuccessWash,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.circleCheck, size: 18, color: sramSuccess),
              const Gap(10),
              Expanded(
                child: Text(
                  l.sramShiftingOff,
                  style: context.typography.small.copyWith(fontWeight: FontWeight.w600, height: 1.35),
                ),
              ),
            ],
          ),
        ),
        if (hasBackup) ...[
          const Gap(12),
          SizedBox(
            width: double.infinity,
            child: SecondaryButton(
              leading: const Icon(LucideIcons.rotateCcw, size: 16),
              onPressed: () => unawaited(showGuidedRestore(context)),
              child: Text(l.sramRestore),
            ),
          ),
        ],
      ],
    );
  }

  /// Interactive, staged runner for setup/restore, presented as a bottom sheet:
  /// guide the AXS authorize gesture, show progress, and surface any error
  /// (notably the bond-authorization failure — which happens when the session
  /// key didn't survive a reconnect and a fresh bond is needed) with a Retry.
  Future<void> _runGuidedOperation(
    BuildContext context, {
    required String title,
    required String intro,
    required String successMessage,
    required IconData confirmIcon,
    required String runningTitle,
    required String successTitle,
    required List<String> checklistItems,
    required Future<void> Function() operation,
  }) async {
    await openSheet<void>(
      context: context,
      position: OverlayPosition.bottom,
      barrierDismissible: false,
      builder: (sheetContext) => SramGuidedSheet(
        title: title,
        intro: intro,
        successMessage: successMessage,
        confirmIcon: confirmIcon,
        runningTitle: runningTitle,
        successTitle: successTitle,
        checklistItems: checklistItems,
        operation: operation,
      ),
    );
    core.connection.signalChange(this);
  }

  // ── Test seams ────────────────────────────────────────────────────────────
  // The bottom sheet is an overlay route, which the widget-snapshot harness
  // can't capture. This exposes the same per-stage content as a plain widget
  // (test == production: both go through `sramGuidedBody`).

  // Stage handles for the snapshot harness — plain ints (indices into
  // `SramSetupStage.values`) so tests don't depend on the enum directly.
  @visibleForTesting
  static const int debugStageConfirm = 0;
  @visibleForTesting
  static const int debugStageRunning = 1;
  @visibleForTesting
  static const int debugStageAuthorize = 2;
  @visibleForTesting
  static const int debugStageSuccess = 3;
  @visibleForTesting
  static const int debugStageError = 4;

  /// The exact per-stage sheet body the guided operation renders, as a
  /// standalone widget (actions are inert). [runningStep] seeds the running
  /// checklist's current index (that item spins, earlier items are done).
  @visibleForTesting
  Widget debugGuidedSheetBody(
    BuildContext context, {
    required int stage,
    required IconData confirmIcon,
    required String title,
    required String intro,
    required String successMessage,
    required String runningTitle,
    required String successTitle,
    required List<String> checklistItems,
    int runningStep = 1,
  }) => sramGuidedBody(
    context,
    stage: SramSetupStage.values[stage],
    confirmIcon: confirmIcon,
    title: title,
    intro: intro,
    successMessage: successMessage,
    runningTitle: runningTitle,
    successTitle: successTitle,
    checklistItems: checklistItems,
    runningStep: runningStep,
    checklistAutoAdvance: false,
    onClose: () {},
    onProceed: () {},
  );
}

class SramAxsConstants {
  static const String SERVICE_UUID = "0000fe51-0000-1000-8000-00805f9b34fb";
  static const String SERVICE_UUID_RELEVANT = "d9050053-90aa-4c7c-b036-1e01fb8eb7ee";

  static const String TRIGGER_UUID = "d9050054-90aa-4c7c-b036-1e01fb8eb7ee";

  /// The §6.1 press edge: a 1-byte 0xFF notify on [TRIGGER_UUID]. Shared by the
  /// press filter, the emulated profile, and the integration harness so the
  /// encodings can't drift apart (the emulation once sent 0x01 and silently
  /// stopped matching the device filter).
  static const int triggerEdge = 0xFF;
}
