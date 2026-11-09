import 'dart:async';

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/bluetooth/devices/controller_input_interceptor.dart';
import 'package:bike_control/utils/actions/base_actions.dart' show ActionResult, Success;
import 'package:bike_control/utils/actions/desktop.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/utils/keymap/manager.dart';
import 'package:bike_control/widgets/controller/controller_layout.dart';
import 'package:bike_control/widgets/status_icon.dart';
import 'package:bike_control/widgets/ui/beta_pill.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:prop/prop.dart' show LogLevel;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../utils/keymap/buttons.dart';
import '../messages/notification.dart';

/// Something the rider has to do on a controller before its buttons do
/// anything — see [BaseDevice.setupNeed].
enum DeviceSetupNeed {
  /// A one-time setup: the Zwift Click V2's unlock-mode choice, the SRAM AXS
  /// guided "disable on-device shifting" setup. Offered once, right away, when
  /// such a controller turns up.
  setup,

  /// A recurring unlock: a controller Zwift locks to its own app, until it has
  /// been unlocked again. A chore every day, so it is shown, never pushed.
  unlock,
}

abstract class BaseDevice {
  final String? _name;
  final bool isBeta;
  bool supportsLongPress;
  final String uniqueId;
  final IconData icon;
  final List<ControllerButton> availableButtons;

  /// Optional visual layout for the [DevicePage] controller footer. When
  /// null, the footer falls back to a plain [Wrap] of buttons. Subclasses
  /// for known hardware override this with a [ControllerLayout] positioning
  /// each button on a rough silhouette of the physical controller.
  ControllerLayout? get controllerLayout => null;

  BaseDevice(
    this._name, {
    required this.uniqueId,
    required this.availableButtons,
    required this.icon,
    this.isBeta = false,
    this.supportsLongPress = true,
    String? buttonPrefix,
  }) {
    if (availableButtons.isEmpty && core.actionHandler.supportedApp is CustomApp) {
      final allButtons = core.actionHandler.supportedApp!.keymap.keyPairs
          .expand((e) => e.buttons)
          .filter(
            (e) =>
                e.sourceDeviceId == uniqueId ||
                (e.sourceDeviceId == null && buttonPrefix != null && e.name.startsWith(buttonPrefix)),
          )
          .toSet();
      availableButtons.addAll(allButtons);
    }
  }

  bool isConnected = false;

  /// True while the device is rebooting because of an automatic reset (e.g.
  /// ClickLogic's periodic reset) and is expected to reconnect on its own
  /// shortly: keep its entry in the device list (greyed out) and suppress
  /// connect/disconnect notifications for the cycle.
  bool get isResetting => false;

  /// While set, every controller press is offered to it first (see
  /// [ControllerInputInterceptor]); the shifting calibrator installs one for
  /// the length of a run and removes it on every way out.
  static ControllerInputInterceptor? inputInterceptor;

  static const Duration _longPressTriggerDelay = Duration(milliseconds: 550);
  static const Duration _doubleClickDelay = Duration(milliseconds: 320);
  static const Duration _repeatInterval = Duration(milliseconds: 250);

  Timer? _longPressTimer;
  Timer? _singleClickTimer;
  Timer? _repeatTimer;
  bool _repeatInFlight = false;
  Set<ControllerButton> _previouslyPressedButtons = <ControllerButton>{};
  // A multi-button press already fired; until every button is up, what is
  // left held is that press being let go, not a new one.
  bool _releasingChord = false;
  Set<ControllerButton> _activeLongPressButtons = <ControllerButton>{};
  ControllerButton? _pendingSingleClickButton;

  String get name => _name ?? runtimeType.toString();

  String get buttonExplanation => isConnected ? 'Connecting...' : 'Click a button on this device to configure them.';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BaseDevice && runtimeType == other.runtimeType && toString() == other.toString();

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => name;

  final StreamController<BaseNotification> actionStreamInternal = StreamController<BaseNotification>.broadcast();

  Stream<BaseNotification> get actionStream => actionStreamInternal.stream;

  Future<void> connect();

  Future<void> handleButtonsClicked(List<ControllerButton>? buttonsClicked, {bool longPress = false}) async {
    try {
      if (buttonsClicked == null) {
        return;
      }

      if (longPress) {
        await _handleExplicitLongPress(buttonsClicked);
        return;
      }

      if (buttonsClicked.isEmpty) {
        await _handleButtonsReleased();
        return;
      }

      // Devices that report every change of the held set (Stages, Di2) send a
      // chord let go finger by finger as [A, B] → [A] → []: the [A] is the
      // tail of the chord, and acting on it would fire A once more on release.
      final held = buttonsClicked.toSet();
      if (_previouslyPressedButtons.length > 1 &&
          held.length < _previouslyPressedButtons.length &&
          _previouslyPressedButtons.containsAll(held)) {
        _previouslyPressedButtons = held;
        _releasingChord = true;
        return;
      }
      _releasingChord = false;

      actionStreamInternal.add(ButtonNotification(buttonsClicked: buttonsClicked, device: this));

      if (buttonsClicked.length != 1) {
        _cancelPendingClickTimers();
        if (_activeLongPressButtons.isNotEmpty) {
          await performRelease(_activeLongPressButtons.toList(), trigger: ButtonTrigger.longPress);
          _activeLongPressButtons.clear();
        }
        _previouslyPressedButtons = buttonsClicked.toSet();
        // Before the front-shift combo: while a screen owns the chord (the
        // calibrator's "both shifters"), it must not also change the ring.
        final chord = inputInterceptor?.interceptChord(buttonsClicked, buttonsClicked.map(_mappedAction).toList());
        if (chord != null) {
          _reportIntercepted(chord);
          return;
        }
        if (await _maybeHandleFrontShiftCombo(buttonsClicked)) return;
        await performClick(buttonsClicked, trigger: ButtonTrigger.singleClick);
        return;
      }

      final button = buttonsClicked.single;
      final wasAlreadyPressed =
          supportsLongPress &&
          _previouslyPressedButtons.length == 1 &&
          _previouslyPressedButtons.singleOrNull == button;
      _previouslyPressedButtons = {button};
      if (wasAlreadyPressed) {
        return;
      }

      final hasSingleAction = _hasTriggerAction(button, ButtonTrigger.singleClick);
      final hasDoubleAction = _hasTriggerAction(button, ButtonTrigger.doubleClick);
      final hasLongPressAction = _hasTriggerAction(button, ButtonTrigger.longPress);
      final isLongPressOnly = hasLongPressAction && !hasSingleAction && !hasDoubleAction;
      if (supportsLongPress && isLongPressOnly && !_isLongPressSuppressed(button)) {
        _cancelPendingClickTimers();
        _longPressTimer?.cancel();
        _activeLongPressButtons = {button};
        await performDown([button], trigger: ButtonTrigger.longPress);
        return;
      }

      if (!hasLongPressAction && !hasDoubleAction && !hasSingleAction) {
        // make sure we see this as an error
        await performClick([button]);
        return;
      }

      _scheduleLongPress(button);
    } catch (e, st) {
      recordError(e, st, context: 'handleButtonsClicked');
      actionStreamInternal.add(
        LogNotification('Error handling button clicks: $e\n$st'),
      );
    }
  }

  Future<void> _handleButtonsReleased() async {
    actionStreamInternal.add(LogNotification('Buttons released'));

    _longPressTimer?.cancel();
    _stopRepeatingSingleClick();
    final releasedButtons = _previouslyPressedButtons.toList();
    _previouslyPressedButtons.clear();
    if (_releasingChord) {
      _releasingChord = false;
      return;
    }

    if (releasedButtons.isEmpty) {
      return;
    }

    if (_activeLongPressButtons.isNotEmpty && supportsLongPress) {
      await performRelease(_activeLongPressButtons.toList(), trigger: ButtonTrigger.longPress);
      _activeLongPressButtons.clear();
      return;
    }

    if (releasedButtons.length != 1) {
      return;
    }

    await _handleSingleButtonTap(releasedButtons.single);
  }

  Future<void> _handleExplicitLongPress(List<ControllerButton> buttonsClicked) async {
    if (buttonsClicked.isEmpty) {
      if (_activeLongPressButtons.isNotEmpty) {
        await performRelease(_activeLongPressButtons.toList(), trigger: ButtonTrigger.longPress);
        _activeLongPressButtons.clear();
      }
      _previouslyPressedButtons.clear();
      return;
    }

    actionStreamInternal.add(ButtonNotification(buttonsClicked: buttonsClicked, device: this));
    _cancelPendingClickTimers();
    _activeLongPressButtons = buttonsClicked.toSet();
    _previouslyPressedButtons = buttonsClicked.toSet();
    await performDown(buttonsClicked, trigger: ButtonTrigger.longPress);
  }

  void _scheduleLongPress(ControllerButton button) {
    _longPressTimer?.cancel();
    if (!supportsLongPress || !_hasTriggerAction(button, ButtonTrigger.longPress)) {
      return;
    }
    if (_isLongPressSuppressed(button)) {
      return;
    }

    _longPressTimer = Timer(_longPressTriggerDelay, () {
      final stillPressed = _previouslyPressedButtons.length == 1 && _previouslyPressedButtons.singleOrNull == button;
      if (!stillPressed) {
        return;
      }
      _activeLongPressButtons = {button};
      unawaited(performDown([button], trigger: ButtonTrigger.longPress));
    });
  }

  bool _isLongPressSuppressed(ControllerButton button) {
    return button == ZwiftButtons.onOffLeft || button == ZwiftButtons.onOffRight;
  }

  Future<void> _handleSingleButtonTap(ControllerButton button) async {
    final hasSingleAction = _hasTriggerAction(button, ButtonTrigger.singleClick);
    final hasDoubleAction = _hasTriggerAction(button, ButtonTrigger.doubleClick);
    final hasLongPressAction = _hasTriggerAction(button, ButtonTrigger.longPress);

    if (!supportsLongPress && hasLongPressAction) {
      _cancelPendingClickTimers();
      final isLongPressAlreadyHeld = _activeLongPressButtons.contains(button);
      if (isLongPressAlreadyHeld) {
        await performRelease([button], trigger: ButtonTrigger.longPress);
        _activeLongPressButtons.remove(button);
      } else {
        await performDown([button], trigger: ButtonTrigger.longPress);
        _activeLongPressButtons.add(button);
      }
      return;
    }

    if (hasDoubleAction) {
      final isSecondTap =
          _pendingSingleClickButton == button &&
          (_singleClickTimer?.isActive ?? false) &&
          _activeLongPressButtons.isEmpty;

      if (isSecondTap) {
        _singleClickTimer?.cancel();
        _singleClickTimer = null;
        _pendingSingleClickButton = null;
        await performClick([button], trigger: ButtonTrigger.doubleClick);
        return;
      }

      _singleClickTimer?.cancel();
      _singleClickTimer = Timer(_doubleClickDelay, () {
        final pendingButton = _pendingSingleClickButton;
        _pendingSingleClickButton = null;
        _singleClickTimer = null;
        if (pendingButton != null && hasSingleAction) {
          unawaited(performClick([pendingButton], trigger: ButtonTrigger.singleClick));
        }
      });
      _pendingSingleClickButton = button;
      return;
    }

    if (hasSingleAction) {
      await performClick([button], trigger: ButtonTrigger.singleClick);
    }
  }

  /// What the rider's keymap does with [button] on a single click.
  InGameAction? _mappedAction(ControllerButton button) =>
      core.actionHandler.supportedApp?.keymap.getKeyPair(button, trigger: ButtonTrigger.singleClick)?.inGameAction;

  bool _longPressClaimed(ControllerButton button) =>
      supportsLongPress && (inputInterceptor?.claimsLongPress(_mappedAction(button)) ?? false);

  /// Offers a press to [inputInterceptor]; non-null means it was consumed.
  ActionResult? _intercept(ControllerButton button, ButtonTrigger trigger, {required bool isKeyDown}) {
    final interceptor = inputInterceptor;
    if (interceptor == null) return null;
    final result = interceptor.intercept(button, _mappedAction(button), trigger, isKeyDown: isKeyDown);
    if (result != null) _reportIntercepted(result);
    return result;
  }

  void _reportIntercepted(ActionResult result) {
    if (result.message.isNotEmpty) actionStreamInternal.add(ActionNotification(result));
  }

  bool _hasTriggerAction(ControllerButton button, ButtonTrigger trigger) {
    if (trigger == ButtonTrigger.longPress && _longPressClaimed(button)) return true;
    final keyPair = core.actionHandler.supportedApp?.keymap.getKeyPair(button, trigger: trigger);
    if (keyPair == null && core.actionHandler.supportedApp == null) {
      return trigger == ButtonTrigger.singleClick;
    }
    if (keyPair != null && !keyPair.hasNoAction) {
      return true;
    }
    // Implicit repeat: long press repeats single click for Pro users by default.
    if (trigger == ButtonTrigger.longPress) {
      return _shouldRepeatSingleClick(button);
    }
    return false;
  }

  /// Whether the current device has Pro features enabled.
  /// Extracted for testability — can be overridden in test subclasses.
  @visibleForTesting
  bool get isProEnabledForRepeat {
    try {
      return IAPManager.instance.isProEnabledForCurrentDeviceOrDidPurchaseOld;
    } catch (_) {
      return false;
    }
  }

  /// Whether a long press should implicitly repeat the single click action.
  /// Active by default for Pro users when no explicit long press action is set.
  bool _shouldRepeatSingleClick(ControllerButton button) {
    if (!supportsLongPress) return false;
    // A claimed hold is an answer, not a stream of repeated clicks.
    if (_longPressClaimed(button)) return false;
    if (!isProEnabledForRepeat) return false;
    final longPressPair = core.actionHandler.supportedApp?.keymap.getKeyPair(
      button,
      trigger: ButtonTrigger.longPress,
    );
    if (longPressPair != null && !longPressPair.hasNoAction) return false;
    final singleClickPair = core.actionHandler.supportedApp?.keymap.getKeyPair(
      button,
      trigger: ButtonTrigger.singleClick,
    );
    return singleClickPair != null && !singleClickPair.hasNoAction;
  }

  void _cancelPendingClickTimers() {
    _singleClickTimer?.cancel();
    _singleClickTimer = null;
    _pendingSingleClickButton = null;
  }

  String _getCommandLimitMessage() {
    return AppLocalizations.current.dailyCommandLimitReachedNotification;
  }

  String _getCommandLimitTitle() {
    return AppLocalizations.current
        .dailyLimitReached(IAPManager.dailyCommandLimit, IAPManager.dailyCommandLimit)
        .replaceAll(
          '${IAPManager.dailyCommandLimit}/${IAPManager.dailyCommandLimit}',
          IAPManager.dailyCommandLimit.toString(),
        )
        .replaceAll(
          '${IAPManager.dailyCommandLimit} / ${IAPManager.dailyCommandLimit}',
          IAPManager.dailyCommandLimit.toString(),
        );
  }

  bool _canExecuteCommand(ControllerButton button, ButtonTrigger trigger) {
    final bool withinLimit;
    try {
      withinLimit = IAPManager.instance.canExecuteCommand;
    } catch (_) {
      return true;
    }
    if (withinLimit) return true;
    // Gear changes during the daily virtual shifting trial run on its budget,
    // not the command limit.
    return core.actionHandler.passesCommandLimitFor(button, trigger: trigger);
  }

  Future<void> performDown(
    List<ControllerButton> buttonsClicked, {
    ButtonTrigger trigger = ButtonTrigger.longPress,
  }) async {
    for (final action in buttonsClicked) {
      actionStreamInternal.add(GestureNotification(device: this, button: action, trigger: trigger));
      if (_intercept(action, trigger, isKeyDown: true) != null) continue;
      // Check IAP status before executing command
      if (!_canExecuteCommand(action, trigger)) {
        //actionStreamInternal.add(AlertNotification(LogLevel.LOGLEVEL_ERROR, _getCommandLimitMessage()));
        continue;
      }

      // Check for implicit repeat single click mode (single-button only)
      if (buttonsClicked.length == 1 && _shouldRepeatSingleClick(action)) {
        _startRepeatingSingleClick(action);
        continue;
      }

      // For repeated actions, don't trigger key down/up events (useful for long press)
      final result = await core.actionHandler.performAction(
        action,
        isKeyDown: true,
        isKeyUp: false,
        trigger: trigger,
      );
      if (result is Success) core.feedbackPromptService.recordCommandDelivered();

      actionStreamInternal.add(ActionNotification(result));
    }
  }

  void _startRepeatingSingleClick(ControllerButton button) {
    _repeatTimer?.cancel();
    _repeatInFlight = false;
    // Fire immediately, then repeat periodically with in-flight guard
    unawaited(_fireRepeatClick(button));
    _repeatTimer = Timer.periodic(_repeatInterval, (_) {
      if (_repeatInFlight) return;
      unawaited(_fireRepeatClick(button));
    });
  }

  Future<void> _fireRepeatClick(ControllerButton button) async {
    if (!_canExecuteCommand(button, ButtonTrigger.singleClick)) {
      _stopRepeatingSingleClick();
      _showCommandLimitAlert();
      return;
    }
    _repeatInFlight = true;
    try {
      await performClick([button], trigger: ButtonTrigger.singleClick);
    } finally {
      _repeatInFlight = false;
    }
  }

  void _stopRepeatingSingleClick() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
    _repeatInFlight = false;
  }

  Future<void> performClick(
    List<ControllerButton> buttonsClicked, {
    ButtonTrigger trigger = ButtonTrigger.singleClick,
  }) async {
    for (final action in buttonsClicked) {
      actionStreamInternal.add(GestureNotification(device: this, button: action, trigger: trigger));
      if (_intercept(action, trigger, isKeyDown: true) != null) continue;
      // Check IAP status before executing command
      if (!_canExecuteCommand(action, trigger)) {
        _showCommandLimitAlert();
        continue;
      }

      final result = await core.actionHandler.performAction(
        action,
        isKeyDown: true,
        isKeyUp: true,
        trigger: trigger,
      );
      if (result is Success) core.feedbackPromptService.recordCommandDelivered();
      actionStreamInternal.add(ActionNotification(result));
    }
  }

  Future<void> performRelease(
    List<ControllerButton> buttonsReleased, {
    ButtonTrigger trigger = ButtonTrigger.longPress,
  }) async {
    _stopRepeatingSingleClick();
    for (final action in buttonsReleased) {
      if (_intercept(action, trigger, isKeyDown: false) != null) continue;
      // Skip normal release handling for repeat-on-long-press buttons
      if (_shouldRepeatSingleClick(action)) {
        continue;
      }

      // Check IAP status before executing command
      if (!_canExecuteCommand(action, trigger)) {
        _showCommandLimitAlert();
        continue;
      }

      final result = await core.actionHandler.performAction(
        action,
        isKeyDown: false,
        isKeyUp: true,
        trigger: trigger,
      );
      if (result is Success) core.feedbackPromptService.recordCommandDelivered();
      actionStreamInternal.add(LogNotification(result.message));
    }
  }

  Future<void> disconnect() async {
    _longPressTimer?.cancel();
    _singleClickTimer?.cancel();
    _singleClickTimer = null;
    _repeatTimer?.cancel();
    _repeatTimer = null;
    _pendingSingleClickButton = null;
    // Release any held keys in long press mode
    if (core.actionHandler is DesktopActions) {
      await (core.actionHandler as DesktopActions).releaseAllHeldKeys(_activeLongPressButtons.toList());
    }
    _activeLongPressButtons.clear();
    _previouslyPressedButtons.clear();
    isConnected = false;
  }

  /// Whether the connect queue may open this device on its own when it is
  /// discovered or the app launches. Devices that need explicit rider intent
  /// first — a proxied trainer awaiting consent, a Zwift Click V2 awaiting
  /// unlock-mode onboarding — return false and stay listed but unconnected.
  ///
  /// A device returning false must also return early from [connect] so no
  /// transport is opened; the queue still runs its listener wiring.
  bool get shouldAutoConnect => true;

  /// What the rider still has to do on this controller before its buttons
  /// work, or null when nothing — see [DeviceSetupNeed].
  ///
  /// Only needs the rider can act on right now are reported: a setup that
  /// talks to the device over its link is not one while it is out of reach.
  /// Ride's warning and the one-time setup prompt read this, never the device
  /// class, so a new kind of controller with a setup of its own only overrides
  /// this and [openSetup].
  DeviceSetupNeed? get setupNeed => null;

  /// Identifies the setup behind [setupNeed], so it is offered once rather than
  /// once per device: a decision that covers several devices (the Zwift Click
  /// V2's two pucks share one unlock-mode choice) shares one key.
  String get setupPromptKey => uniqueId;

  /// Runs the flow that clears [setupNeed] — the same sheet or page the
  /// device's own screens and the onboarding open. Completes once the rider
  /// has left it, done or not.
  Future<void> openSetup(BuildContext context) async {}

  List<Widget> showMetaInformation(BuildContext context, {required bool showFull}) {
    return [];
  }

  List<Widget> showAdditionalInformation(BuildContext context) {
    return [];
  }

  /// An optional small badge rendered immediately to the left of the Beta pill
  /// in the device header. Smart trainers use it to show a transport icon when
  /// the same trainer is discovered over both WiFi and Bluetooth, so the two
  /// identically-named entries can be told apart. Returns null by default.
  Widget? nameBadge(BuildContext context) => null;

  /// The device name as shown to the rider. Defaults to [toString], which stays
  /// English on purpose so logs, crash reports and notifications keep a stable
  /// identity; only overrides that carry a translatable part (the Click V2
  /// left/right suffix) differ from it.
  String displayName(BuildContext context) => toString();

  /// In-game actions this device *receives* rather than sends — the fan speeds
  /// a Headwind reacts to, the incline steps a Climb takes.
  ///
  /// They are assigned to a controller's buttons, never to this device's own
  /// (an accessory has none), so its settings page can only name them and send
  /// the rider to a controller.
  List<InGameAction> get assignableActions => const [];

  Widget showInformation(
    BuildContext context, {
    required bool showFull,
    Widget? footer,
    bool showSettingsIcon = true,
    bool showAdditionalInfo = true,
  }) {
    final meta = showMetaInformation(context, showFull: showFull);
    final badge = nameBadge(context);
    // Hero the entire header Row so the icon, title and meta fly together
    // when navigating between the overview's compact card and the
    // ControllerSettingsPage's expanded card — the same Row shape is rendered
    // on both sides, just at a different width and with/without the trailing
    // settings gear (which lands at destination).
    return Column(
      spacing: 12,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Hero(
          tag: 'device-header-$uniqueId',
          child: Row(
            spacing: 12,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusIcon(
                icon: icon,
                status: isConnected,
                started: !isConnected && (this is! ProxyDevice || (this as ProxyDevice).isStarting.value),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  spacing: 4,
                  children: [
                    Row(
                      spacing: 6,
                      children: [
                        Text(
                          displayName(context),
                          style: context.typography.base.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.2),
                        ),
                        if (badge != null) badge,
                        if (isBeta) BetaPill(),
                        Expanded(child: SizedBox()),
                        if (!showFull && showSettingsIcon)
                          Icon(
                            LucideIcons.settings,
                            size: 16,
                            color: Theme.of(context).colorScheme.mutedForeground,
                          ),
                      ],
                    ),
                    if (meta.isNotEmpty)
                      Wrap(
                        runSpacing: 6,
                        spacing: 6,
                        alignment: WrapAlignment.start,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        runAlignment: WrapAlignment.start,
                        children: meta,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (footer != null) footer,
        if (showAdditionalInfo) ...showAdditionalInformation(context),
      ],
    );
  }

  Widget? buildPreferences(BuildContext context) => null;

  ControllerButton getOrAddButton(String key, ControllerButton Function() creator) {
    if (core.actionHandler.supportedApp == null) {
      // No keymap resolved (e.g. the 'app' pref is missing). We can't register
      // the button with a keymap, but the device must still expose it — dropping
      // it here is what makes the device render without any buttons at all.
      final createdButton = creator();
      if (availableButtons.none((e) => e.name == createdButton.name)) {
        availableButtons.add(createdButton);
      }
      return createdButton;
    }
    if (core.actionHandler.supportedApp is! CustomApp) {
      final currentProfile = core.actionHandler.supportedApp!.name;
      // should we display this to the user?
      KeymapManager().duplicateSync(currentProfile, '$currentProfile (Copy)');
    }
    var createdButton = creator();
    if (createdButton.sourceDeviceId == null) {
      createdButton = createdButton.copyWith(sourceDeviceId: uniqueId);
    }
    final button = core.actionHandler.supportedApp!.keymap.getOrAddButton(key, createdButton);

    if (availableButtons.none((e) => e.name == button.name)) {
      availableButtons.add(button);
      core.settings.setKeyMap(core.actionHandler.supportedApp!);
    }
    return button;
  }

  /// If [buttons] resolve to exactly {shiftUp, shiftDown} and the front-shift
  /// combo is enabled, emit a single frontShift and suppress the rear shifts.
  Future<bool> _maybeHandleFrontShiftCombo(List<ControllerButton> buttons) async {
    if (!core.actionHandler.frontShiftComboEnabled) return false;
    if (buttons.length < 2) return false;
    final actions = buttons
        .map(
          (b) =>
              core.actionHandler.supportedApp?.keymap.getKeyPair(b, trigger: ButtonTrigger.singleClick)?.inGameAction,
        )
        .toSet();
    if (actions.contains(InGameAction.shiftUp) && actions.contains(InGameAction.shiftDown)) {
      final result = await core.actionHandler.performInGameAction(InGameAction.frontShift);
      actionStreamInternal.add(ActionNotification(result));
      return true;
    }
    return false;
  }

  void _showCommandLimitAlert() {
    actionStreamInternal.add(
      AlertNotification(
        LogLevel.LOGLEVEL_ERROR,
        _getCommandLimitMessage(),
        buttonTitle: AppLocalizations.current.purchase,
        onTap: () {
          IAPManager.instance.purchaseFullVersion(navigatorKey.currentContext!);
        },
      ),
    );
    core.flutterLocalNotificationsPlugin.show(
      id: 1337,
      title: _getCommandLimitTitle(),
      body: _getCommandLimitMessage(),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails('Limit', 'Limit reached'),
        iOS: DarwinNotificationDetails(presentAlert: true),
      ),
    );
  }
}
