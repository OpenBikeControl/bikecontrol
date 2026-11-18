import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:bike_control/bluetooth/incline/incline_manual_state.dart';
import 'package:bike_control/bluetooth/incline/incline_sink.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';

/// Shared manual-incline behavior for incline devices (KICKR Climb, Elite Rizer).
/// Holds the auto/manual state and maps the incline in-game actions to it, then
/// writes via the device-specific [writeInclineToDevice]. `auto` follows the
/// bridge grade (the InclineController pushes it); `manual` holds a user-set
/// incline.
mixin ManualInclineDevice on BluetoothDevice implements InclineSink {
  final InclineManualState inclineState = InclineManualState();

  /// The incline last written to the device (0.01% signed), null before the
  /// first write. What the device was told, not what it reports back.
  final ValueNotifier<int?> inclineApplied = ValueNotifier(null);

  @override
  bool get followsGrade => inclineState.mode == InclineMode.auto;

  /// Device-specific BLE write of the incline (0.01% signed). Returns true if issued.
  @protected
  Future<bool> writeInclineToDevice(int grade001Pct);

  @override
  Future<bool> writeInclineRaw(int grade001Pct) async {
    final ok = await writeInclineToDevice(grade001Pct);
    if (ok) inclineApplied.value = grade001Pct;
    return ok;
  }

  @override
  List<InGameAction> get assignableActions => const [
    InGameAction.inclineIncrease,
    InGameAction.inclineDecrease,
    InGameAction.inclineZero,
    InGameAction.inclineAutoMode,
  ];

  /// Applies one of the incline actions (from a controller button or the
  /// incline UI). Returns false for an action that is not an incline action.
  /// Leaving auto starts from the incline the grade had set, so the first
  /// step moves 1% from where the device is.
  Future<bool> applyInclineAction(InGameAction action) async {
    final applied = inclineApplied.value;
    if (followsGrade &&
        applied != null &&
        (action == InGameAction.inclineIncrease || action == InGameAction.inclineDecrease)) {
      inclineState.holdAt(applied);
    }
    switch (action) {
      case InGameAction.inclineIncrease:
        inclineState.increase();
      case InGameAction.inclineDecrease:
        inclineState.decrease();
      case InGameAction.inclineZero:
        inclineState.zero();
      case InGameAction.inclineAutoMode:
        // The InclineController re-asserts the grade on its next tick.
        inclineState.setAuto();
        return true;
      default:
        return false;
    }
    await writeInclineRaw(inclineState.grade001);
    return true;
  }

  Future<ActionResult> handleKeypair(KeyPair keyPair, {required bool isKeyDown}) async {
    if (!isKeyDown) return NotHandled('', button: keyPair.buttons.firstOrNull);
    try {
      final action = keyPair.inGameAction;
      if (action == null || !await applyInclineAction(action)) {
        return NotHandled('', button: keyPair.buttons.firstOrNull);
      }
      if (action == InGameAction.inclineAutoMode) {
        return Success('Incline: follow grade', button: keyPair.buttons.firstOrNull);
      }
      return Success(
        'Incline ${(inclineState.grade001 / 100).toStringAsFixed(1)}%',
        button: keyPair.buttons.firstOrNull,
      );
    } catch (e, s) {
      recordError(e, s, context: 'ManualInclineDevice: handleKeypair failed');
      return Error('Failed to control incline: $e', button: keyPair.buttons.firstOrNull);
    }
  }
}
