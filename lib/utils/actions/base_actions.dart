import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:accessibility/accessibility.dart';
import 'package:bike_control/bluetooth/devices/gyroscope/gyroscope_steering.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/services/workout/workout_recorder.dart';
import 'package:bike_control/utils/actions/android.dart';
import 'package:bike_control/utils/actions/desktop.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/widgets/keymap_explanation.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';

import '../keymap/apps/supported_app.dart';

enum SupportedMode { keyboard, touch, media }

sealed class ActionResult {
  final String message;
  final ControllerButton? button;
  const ActionResult(this.message, {required this.button});
}

class Success extends ActionResult {
  /// Saved file path for results that produced a file (e.g. a screen
  /// recording). Lets the UI offer an "open folder" action.
  final String? filePath;
  const Success(super.message, {required super.button, this.filePath});
}

class NotHandled extends ActionResult {
  const NotHandled(super.message, {required super.button});
}

class Ignored extends ActionResult {
  const Ignored(super.message, {required super.button});
}

enum ErrorType {
  noKeymapSet,
  noActionAssigned,
  noConnectionMethod,
  trainerNotConnected,
  proRequired,
  deviceRegistrationNeeded,
  headwindNotConnected,
  other,
}

class Error extends ActionResult {
  final ErrorType type;
  const Error(super.message, {this.type = ErrorType.other, required super.button});
}

abstract class BaseActions {
  final List<SupportedMode> supportedModes;

  SupportedApp? supportedApp;

  BaseActions({required this.supportedModes});

  void cleanup();

  void init(SupportedApp? supportedApp) {
    this.supportedApp = supportedApp;
    debugPrint('Supported app: ${supportedApp?.name ?? "None"}');

    if (supportedApp != null) {
      final allButtons = core.connection.devices.map((e) => e.availableButtons).flatten().distinct().toList();
      supportedApp.keymap.addNewButtons(allButtons);
    }
  }

  Future<Offset> resolveTouchPosition({required KeyPair keyPair, required WindowEvent? windowInfo}) async {
    if (keyPair.touchPosition != Offset.zero) {
      // convert relative position to absolute position based on window info

      // TODO support multiple screens
      final Size displaySize;
      final double devicePixelRatio;
      if (Platform.isWindows) {
        // TODO remove once https://github.com/flutter/flutter/pull/164460 is available in stable
        final display = await screenRetriever.getPrimaryDisplay();
        displaySize = display.size;
        devicePixelRatio = 1.0;
      } else {
        final display = WidgetsBinding.instance.platformDispatcher.views.first.display;
        displaySize = display.size;
        devicePixelRatio = display.devicePixelRatio;
      }

      late final Size physicalSize;
      if (this is AndroidActions) {
        if (windowInfo != null && windowInfo.packageName != 'de.jonasbark.swiftcontrol') {
          // a trainer app is in foreground, so use the always assume landscape
          physicalSize = Size(max(displaySize.width, displaySize.height), min(displaySize.width, displaySize.height));
        } else {
          // display size is already in physical pixels
          physicalSize = displaySize;
        }
      } else if (this is DesktopActions) {
        // display size is in logical pixels, convert to physical pixels
        // TODO on macOS the notch is included here, but it's not part of the usable screen area, so we should exclude it
        physicalSize = displaySize / devicePixelRatio;
      } else {
        physicalSize = displaySize;
      }

      final x = (keyPair.touchPosition.dx / 100.0) * physicalSize.width;
      final y = (keyPair.touchPosition.dy / 100.0) * physicalSize.height;

      if (kDebugMode) {
        print("Screen size: $physicalSize vs $displaySize => Touch at: $x, $y");
      }
      return Offset(x, y);
    }
    return Offset.zero;
  }

  /// True when the active trainer (the connected proxy device) has the
  /// both-shifters front-shift combo enabled in its [ShiftingConfig].
  bool get frontShiftComboEnabled {
    final proxy = core.connection.proxyDevices.where((d) => d.isConnected).firstOrNull;
    if (proxy == null) return false;
    return core.shiftingConfigs.activeFor(proxy.trainerKey).frontShiftEnabled;
  }

  // --- Both-shifters combo (coincidence-window detector) ---------------------
  // Two-device controllers (e.g. Zwift Play) deliver their two rear shifts as
  // separate performAction calls; pressing both shifters together is the SRAM
  // gesture for a front (chainring) shift. We detect the opposite shift landing
  // within a short window and additively emit a frontShift alongside the
  // (mutually cancelling) rear shifts.

  @visibleForTesting
  DateTime Function() nowFn = DateTime.now;
  static const Duration _frontShiftWindow = Duration(milliseconds: 120);
  DateTime? _lastShiftUpAt;
  DateTime? _lastShiftDownAt;

  /// Record a rear shift; return true if the OPPOSITE shift occurred within the
  /// front-shift window (→ treat as a both-shifters combo). Resets on a hit.
  @visibleForTesting
  bool noteShiftAndCheckCoincidence(InGameAction action) {
    final now = nowFn();
    if (action == InGameAction.shiftUp) {
      _lastShiftUpAt = now;
      final down = _lastShiftDownAt;
      if (down != null && now.difference(down) <= _frontShiftWindow) {
        _lastShiftUpAt = null;
        _lastShiftDownAt = null;
        return true;
      }
    } else if (action == InGameAction.shiftDown) {
      _lastShiftDownAt = now;
      final up = _lastShiftUpAt;
      if (up != null && now.difference(up) <= _frontShiftWindow) {
        _lastShiftUpAt = null;
        _lastShiftDownAt = null;
        return true;
      }
    }
    return false;
  }

  /// Dispatch [action] as if a mapped button fired it, with no physical button.
  /// Used by the both-shifters combo (this file's coincidence detector and the
  /// same-frame detector in base_device.dart) to emit a frontShift.
  Future<ActionResult> performInGameAction(InGameAction action) async {
    final synthButton = ControllerButton('frontShiftCombo', action: action);
    final keyPair = KeyPair(
      buttons: [synthButton],
      physicalKey: null,
      logicalKey: null,
      inGameAction: action,
    );
    // Direct path: a connected proxy trainer handles it (frontShift toggle).
    if (trainerActions.contains(action)) {
      final proxy = core.connection.proxyDevices.where((d) => d.isConnected).firstOrNull;
      if (proxy != null) {
        await IAPManager.instance.incrementCommandCount();
        final result = proxy.handleTrainerAction(synthButton, action);
        if (result is Ignored || result is Success) return result;
      }
    }
    // Otherwise forward to the connected app (e.g. Zwift native SRAM combo).
    return _handleDirectConnect(keyPair, synthButton, isKeyDown: true, isKeyUp: true);
  }

  Future<ActionResult> performAction(
    ControllerButton button, {
    required bool isKeyDown,
    required bool isKeyUp,
    ButtonTrigger trigger = ButtonTrigger.singleClick,
  }) async {
    if (supportedApp == null) {
      return Error(
        AppLocalizations.current.couldNotPerformButtonnamesplitbyuppercaseNoKeymapSet(button.name.splitByUpperCase()),
        type: ErrorType.noKeymapSet,
        button: button,
      );
    }

    final keyPair = supportedApp!.keymap.getKeyPair(button, trigger: trigger);
    if (keyPair == null || keyPair.hasNoAction) {
      return Error(
        AppLocalizations.current.noActionAssignedForButton(button.name.splitByUpperCase()),
        type: ErrorType.noActionAssigned,
        button: keyPair?.buttons.firstOrNull ?? button,
      );
    }

    // Both-shifters combo (coincidence window): two-device controllers (Play)
    // deliver each rear shift as its own performAction call. When the opposite
    // shift lands within the window, additively fire a frontShift — this does
    // NOT suppress the normal shift; the two opposite rear shifts cancel while
    // the front toggles. The same-frame case (Ride/Click) is handled at the
    // device layer (Task 8), so those never reach this detector.
    if (frontShiftComboEnabled &&
        isKeyDown &&
        (keyPair.inGameAction == InGameAction.shiftUp || keyPair.inGameAction == InGameAction.shiftDown)) {
      if (noteShiftAndCheckCoincidence(keyPair.inGameAction!)) {
        unawaited(() async {
          try {
            await performInGameAction(InGameAction.frontShift);
          } catch (e, s) {
            recordError(e, s, context: 'frontShiftCombo');
          }
        }());
      }
    }

    final guard = proGuard(button: button, trigger: trigger, keyPair: keyPair);
    if (guard is! NotHandled) {
      return guard;
    }

    // Handle Headwind actions
    if (keyPair.inGameAction == InGameAction.headwindSpeed ||
        keyPair.inGameAction == InGameAction.headwindSpeedInc ||
        keyPair.inGameAction == InGameAction.headwindSpeedDec ||
        keyPair.inGameAction == InGameAction.headwindSpeedCyclicInc ||
        keyPair.inGameAction == InGameAction.headwindSpeedCyclicDec ||
        keyPair.inGameAction == InGameAction.headwindHeartRateMode) {
      final headwind = core.connection.accessories.where((h) => h.isConnected).firstOrNull;
      if (headwind == null) {
        return Error(
          'No Headwind connected',
          type: ErrorType.headwindNotConnected,
          button: keyPair.buttons.firstOrNull ?? button,
        );
      }

      // Increment command count after successful execution
      await IAPManager.instance.incrementCommandCount();
      return await headwind.handleKeypair(keyPair, isKeyDown: isKeyDown);
    }

    // Handle workout pause/resume — local recorder, no trainer required.
    if (keyPair.inGameAction == InGameAction.workoutPauseResume) {
      if (!isKeyDown) {
        return Ignored(
          '',
          button: keyPair.buttons.firstOrNull ?? button,
        );
      }
      final recorder = core.workoutRecorder;
      if (recorder.state.value == WorkoutState.recording) {
        recorder.pause();
        await IAPManager.instance.incrementCommandCount();
        return Success(
          AppLocalizations.current.workoutPaused,
          button: keyPair.buttons.firstOrNull ?? button,
        );
      } else if (recorder.state.value == WorkoutState.paused) {
        recorder.resume();
        await IAPManager.instance.incrementCommandCount();
        return Success(
          AppLocalizations.current.workoutResumed,
          button: keyPair.buttons.firstOrNull ?? button,
        );
      }
      return Ignored(
        AppLocalizations.current.noActiveWorkout,
        button: keyPair.buttons.firstOrNull ?? button,
      );
    }

    // Handle screen recording — device-level toggle, works with no trainer.
    if (keyPair.inGameAction == InGameAction.screenRecording) {
      if (!isKeyDown) {
        return Ignored('', button: keyPair.buttons.firstOrNull ?? button);
      }
      final svc = core.screenRecording;
      if (!await svc.isAvailable) {
        return Ignored(
          AppLocalizations.current.screenRecordingNotSupported,
          button: keyPair.buttons.firstOrNull ?? button,
        );
      }
      final result = await svc.toggle();
      if (result.ok) {
        await IAPManager.instance.incrementCommandCount();
        final stopped = !result.startedRecording;
        return Success(
          stopped ? AppLocalizations.current.screenRecordingStopped : AppLocalizations.current.screenRecordingStarted,
          button: keyPair.buttons.firstOrNull ?? button,
          // Carries the saved path so the activity log can offer "open folder".
          filePath: stopped ? result.savedPath : null,
        );
      }
      return Error(
        AppLocalizations.current.screenRecordingFailed,
        button: keyPair.buttons.firstOrNull ?? button,
      );
    }

    // Handle trainer-control actions
    if (trainerActions.contains(keyPair.inGameAction)) {
      final proxy = core.connection.proxyDevices.where((d) => d.isConnected).firstOrNull;
      if (proxy == null) {
        if (trainerOnlyActions.contains(keyPair.inGameAction)) {
          return Error(
            AppLocalizations.current.noProxyTrainerConnected,
            button: keyPair.buttons.firstOrNull ?? button,
          );
        }
      } else {
        if (!isKeyDown) {
          return Ignored(
            '',
            button: keyPair.buttons.firstOrNull ?? button,
          );
        }
        await IAPManager.instance.incrementCommandCount();
        final result = proxy.handleTrainerAction(keyPair.buttons.firstOrNull ?? button, keyPair.inGameAction!);
        // Ignored e.g. when already in highest gear
        // Success when action was executed and the action should not be sent to connected trainer
        // NotHandled means the e.g. gear changes should still be sent to the trainer, so we continue with the regular flow
        if (result is Ignored || result is Success) {
          return result;
        }
      }
    }

    if (core.logic.hasNoConnectionMethod) {
      if (GyroscopeSteeringButtons.values.contains(button)) {
        return Ignored(
          'Too many messages from gyroscope steering',
          button: keyPair.buttons.firstOrNull ?? button,
        );
      } else {
        return Error(
          AppLocalizations.current.pleaseSelectAConnectionMethodFirst,
          type: ErrorType.noConnectionMethod,
          button: keyPair.buttons.firstOrNull ?? button,
        );
      }
    } else if (!(await core.logic.isTrainerConnected()) &&
        !keyPair.doesNotNeedTrainerConnection &&
        // A pure trainer-app action (e.g. a virtual-shifting gear change) flows
        // on to the delivery attempt below, which produces a message naming the
        // trainer app instead of this generic one.
        !keyPair.isTrainerAppActionOnly) {
      return Error(
        AppLocalizations.current.noConnectionMethodIsConnectedOrActive,
        type: ErrorType.trainerNotConnected,
        button: keyPair.buttons.firstOrNull ?? button,
      );
    }

    final directConnectHandled = await _handleDirectConnect(keyPair, button, isKeyUp: isKeyUp, isKeyDown: isKeyDown);
    if (directConnectHandled is NotHandled) {
      // A pure trainer-app action reached here unhandled: no connected trainer
      // app accepted it (the trainer app was closed or disconnected) and it has
      // no keyboard/touch fallback. Without this it would fall through to the
      // platform keyboard path and be misreported as "no action assigned"
      // whenever local control is enabled — note `local` is itself a
      // "connected" connection that never handles in-game actions (issue #367).
      if (keyPair.isTrainerAppActionOnly) {
        return Error(
          AppLocalizations.current.trainerAppNotConnectedForButton(
            button.name.splitByUpperCase(),
            core.settings.getTrainerApp()?.name ?? supportedApp!.name,
          ),
          type: ErrorType.trainerNotConnected,
          button: keyPair.buttons.firstOrNull ?? button,
        );
      }
      if (directConnectHandled.message.isNotEmpty) {
        core.connection.signalNotification(LogNotification(directConnectHandled.message));
      }
    } else {
      // Increment command count after successful execution
      await IAPManager.instance.incrementCommandCount();
    }
    return directConnectHandled;
  }

  Future<ActionResult> _handleDirectConnect(
    KeyPair keyPair,
    ControllerButton button, {
    required bool isKeyDown,
    required bool isKeyUp,
  }) async {
    if (keyPair.inGameAction != null) {
      final actions = <ActionResult>[];
      for (final connectedTrainer in core.logic.connectedTrainerConnections) {
        final result = await connectedTrainer.sendAction(
          keyPair,
          isKeyDown: isKeyDown,
          isKeyUp: isKeyUp,
        );
        actions.add(result);
      }
      if (actions.isNotEmpty) {
        return actions.firstOrNullWhere((e) => e is! NotHandled) ?? actions.first;
      }
    }
    return NotHandled(
      '',
      button: keyPair.buttons.firstOrNull ?? button,
    );
  }

  ActionResult proGuard({
    required ControllerButton button,
    required ButtonTrigger trigger,
    required KeyPair keyPair,
  }) {
    if (keyPair.isProAction && !IAPManager.instance.isProEnabledForCurrentDevice) {
      if (keyPair.isSpecialKey && IAPManager.instance.hasPurchasedBefore50RVC) {
        // it's okay to allow special keys for users who purchased before the subscription model, even without an active subscription, since they already paid for the pro features
      } else if (IAPManager.instance.isProEnabled) {
        return Error(
          AppLocalizations.current.currentDeviceIsNotRegistered,
          type: ErrorType.deviceRegistrationNeeded,
          button: keyPair.buttons.firstOrNull ?? button,
        );
      } else {
        return Error(
          AppLocalizations.current.proSubscriptionRequiredForAction,
          type: ErrorType.proRequired,
          button: keyPair.buttons.firstOrNull ?? button,
        );
      }
    }

    if (!IAPManager.instance.hasActiveSubscription && supportedApp != null) {
      final activeTriggers = ButtonTrigger.values.where((candidate) {
        final candidatePair = supportedApp!.keymap.getKeyPair(button, trigger: candidate);
        return candidatePair != null && !candidatePair.hasNoAction;
      }).toList();

      if (activeTriggers.length > 1 && trigger != activeTriggers.first) {
        return Error(
          AppLocalizations.current.proSubscriptionRequiredForAdditionalTriggers,
          type: ErrorType.proRequired,
          button: keyPair.buttons.firstOrNull ?? button,
        );
      }
    }

    return NotHandled(
      '',
      button: keyPair.buttons.firstOrNull ?? button,
    );
  }
}

class StubActions extends BaseActions {
  StubActions({super.supportedModes = const []});

  final List<PerformedAction> performedActions = [];

  @override
  Future<ActionResult> performAction(
    ControllerButton button, {
    bool isKeyDown = true,
    bool isKeyUp = false,
    ButtonTrigger trigger = ButtonTrigger.singleClick,
  }) async {
    performedActions.add(PerformedAction(button, isDown: isKeyDown, isUp: isKeyUp, trigger: trigger));
    return Future.value(
      Error(
        AppLocalizations.current.pleaseSelectAConnectionMethodFirst,
        type: ErrorType.noConnectionMethod,
        button: button,
      ),
    );
  }

  @override
  void cleanup() {
    performedActions.clear();
  }
}

class PerformedAction {
  final ControllerButton button;
  final bool isDown;
  final bool isUp;
  final ButtonTrigger trigger;

  PerformedAction(
    this.button, {
    required this.isDown,
    required this.isUp,
    this.trigger = ButtonTrigger.singleClick,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PerformedAction &&
          runtimeType == other.runtimeType &&
          button.copyWith(sourceDeviceId: null) == other.button.copyWith(sourceDeviceId: null) &&
          isDown == other.isDown &&
          isUp == other.isUp &&
          trigger == other.trigger;

  @override
  int get hashCode => Object.hash(button, isDown, isUp, trigger);

  @override
  String toString() {
    return '{button: $button, isDown: $isDown, isUp: $isUp, trigger: $trigger}';
  }
}
