import 'dart:async';

import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/utils/actions/desktop.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/utils/keymap/manager.dart';
import 'package:bike_control/widgets/controller/controller_layout.dart';
import 'package:bike_control/widgets/ui/beta_pill.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:prop/prop.dart' show LogLevel;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../utils/keymap/buttons.dart';
import '../messages/notification.dart';

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

  static const Duration _longPressTriggerDelay = Duration(milliseconds: 550);
  static const Duration _doubleClickDelay = Duration(milliseconds: 320);
  static const Duration _repeatInterval = Duration(milliseconds: 250);

  Timer? _longPressTimer;
  Timer? _singleClickTimer;
  Timer? _repeatTimer;
  bool _repeatInFlight = false;
  Set<ControllerButton> _previouslyPressedButtons = <ControllerButton>{};
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

      actionStreamInternal.add(ButtonNotification(buttonsClicked: buttonsClicked, device: this));

      if (buttonsClicked.length != 1) {
        _cancelPendingClickTimers();
        if (_activeLongPressButtons.isNotEmpty) {
          await performRelease(_activeLongPressButtons.toList(), trigger: ButtonTrigger.longPress);
          _activeLongPressButtons.clear();
        }
        _previouslyPressedButtons = buttonsClicked.toSet();
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

  bool _hasTriggerAction(ControllerButton button, ButtonTrigger trigger) {
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

  bool _canExecuteCommand() {
    try {
      return IAPManager.instance.canExecuteCommand;
    } catch (_) {
      return true;
    }
  }

  Future<void> performDown(
    List<ControllerButton> buttonsClicked, {
    ButtonTrigger trigger = ButtonTrigger.longPress,
  }) async {
    for (final action in buttonsClicked) {
      // Check IAP status before executing command
      if (!_canExecuteCommand()) {
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

      actionStreamInternal.add(
        ActionNotification(result, button: action.copyWith(sourceDeviceId: action.sourceDeviceId ?? uniqueId)),
      );
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
    if (!_canExecuteCommand()) {
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
      // Check IAP status before executing command
      if (!_canExecuteCommand()) {
        _showCommandLimitAlert();
        continue;
      }

      final result = await core.actionHandler.performAction(
        action,
        isKeyDown: true,
        isKeyUp: true,
        trigger: trigger,
      );
      actionStreamInternal.add(
        ActionNotification(result, button: action.copyWith(sourceDeviceId: action.sourceDeviceId ?? uniqueId)),
      );
    }
  }

  Future<void> performRelease(
    List<ControllerButton> buttonsReleased, {
    ButtonTrigger trigger = ButtonTrigger.longPress,
  }) async {
    _stopRepeatingSingleClick();
    for (final action in buttonsReleased) {
      // Skip normal release handling for repeat-on-long-press buttons
      if (_shouldRepeatSingleClick(action)) {
        continue;
      }

      // Check IAP status before executing command
      if (!_canExecuteCommand()) {
        _showCommandLimitAlert();
        continue;
      }

      final result = await core.actionHandler.performAction(
        action,
        isKeyDown: false,
        isKeyUp: true,
        trigger: trigger,
      );
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

  List<Widget> showMetaInformation(BuildContext context, {required bool showFull}) {
    return [];
  }

  List<Widget> showAdditionalInformation(BuildContext context) {
    return [];
  }

  Widget showInformation(BuildContext context, {required bool showFull}) {
    return Row(
      spacing: 12,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.muted,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 24),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 4,
            children: [
              Row(
                spacing: 6,
                children: [
                  Text(
                    toString(),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.2),
                  ),
                  if (isBeta) BetaPill(),
                ],
              ),
              Wrap(
                runSpacing: 6,
                spacing: 6,
                alignment: WrapAlignment.start,
                crossAxisAlignment: WrapCrossAlignment.center,
                runAlignment: WrapAlignment.start,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isConnected ? const Color(0xFF22C55E) : Theme.of(context).colorScheme.mutedForeground,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Text(
                    isConnected ? AppLocalizations.of(context).connected : AppLocalizations.of(context).disconnected,
                    style: TextStyle(
                      fontSize: 11,
                      color: isConnected
                          ? Theme.of(context).colorScheme.mutedForeground
                          : Theme.of(context).colorScheme.destructive,
                    ),
                  ),
                  ...showMetaInformation(context, showFull: showFull),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget? buildPreferences(BuildContext context) => null;

  ControllerButton getOrAddButton(String key, ControllerButton Function() creator) {
    if (core.actionHandler.supportedApp == null) {
      return creator();
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
      1337,
      _getCommandLimitTitle(),
      _getCommandLimitMessage(),
      NotificationDetails(
        android: AndroidNotificationDetails('Limit', 'Limit reached'),
        iOS: DarwinNotificationDetails(presentAlert: true),
      ),
    );
  }
}
