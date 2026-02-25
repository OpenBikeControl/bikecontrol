import 'dart:async';

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/button_edit.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/utils/keymap/manager.dart';
import 'package:bike_control/widgets/ui/button_widget.dart';
import 'package:bike_control/widgets/ui/colored_title.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/loading_widget.dart';
import 'package:bike_control/widgets/ui/pro_badge.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:dartx/dartx.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../bluetooth/messages/notification.dart';
import '../utils/iap/iap_manager.dart';

enum _TriggerConflictResolution {
  goPro,
  replaceOtherTriggers,
}

class KeymapExplanation extends StatefulWidget {
  final Keymap keymap;
  final VoidCallback onUpdate;
  const KeymapExplanation({super.key, required this.keymap, required this.onUpdate});

  @override
  State<KeymapExplanation> createState() => _KeymapExplanationState();
}

class _KeymapExplanationState extends State<KeymapExplanation> {
  late StreamSubscription<void> _updateStreamListener;

  late StreamSubscription<BaseNotification> _actionSubscription;

  bool _isDrawerOpen = false;

  @override
  void initState() {
    super.initState();
    _updateStreamListener = widget.keymap.updateStream.listen((_) {
      setState(() {});
    });
    _actionSubscription = core.connection.actionStream.listen((data) async {
      if (!mounted) {
        return;
      }
      if (data is ButtonNotification && data.buttonsClicked.length == 1) {
        final clickedButton = data.buttonsClicked.first;
        if (!_isDrawerOpen) {
          final hasFallbackLongPress =
              data.device.supportsLongPress == false &&
              widget.keymap.getKeyPair(clickedButton, trigger: ButtonTrigger.longPress)?.hasNoAction == false;
          _openButtonEditor(
            data.device,
            clickedButton,
            hasFallbackLongPress ? ButtonTrigger.longPress : ButtonTrigger.singleClick,
          );
        }
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    _updateStreamListener.cancel();
    _actionSubscription.cancel();
  }

  @override
  void didUpdateWidget(KeymapExplanation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.keymap != widget.keymap) {
      _updateStreamListener.cancel();
      _updateStreamListener = widget.keymap.updateStream.listen((_) {
        setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyButtonMap = core.connection.controllerDevices.associateWith((device) {
      return device.availableButtons.distinct().sortedBy(
        (button) => button.color != null ? '0${(button.icon?.codePoint ?? 0)}' : '1${(button.icon?.codePoint ?? 0)}',
      );
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        if (core.connection.controllerDevices.isNotEmpty)
          Text(
            AppLocalizations.of(context).clickAButtonOnYourController,
            style: TextStyle(fontSize: 12),
          ).muted,

        for (final devicePair in keyButtonMap.entries) ...[
          SizedBox(height: 12),
          ColoredTitle(text: devicePair.key.toString()),
          if (devicePair.value.isEmpty)
            Text(
              devicePair.key.buttonExplanation,
              style: TextStyle(height: 1),
            ).muted,
          for (final button in devicePair.value) ...[
            Card(
              fillColor: Theme.of(context).colorScheme.background,
              filled: true,
              child: Row(
                children: [
                  Expanded(
                    child: Basic(
                      leading: SizedBox(
                        width: 58,
                        child: Center(
                          child: IntrinsicWidth(
                            child: ButtonWidget(
                              button: button,
                              big: true,
                            ),
                          ),
                        ),
                      ),
                      content: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildTriggerButton(
                            context,
                            device: devicePair.key,
                            deviceButton: button,
                            trigger: ButtonTrigger.singleClick,
                            supportsLongPress: devicePair.key.supportsLongPress,
                          ),
                          _buildTriggerButton(
                            context,
                            device: devicePair.key,
                            deviceButton: button,
                            trigger: ButtonTrigger.doubleClick,
                            supportsLongPress: devicePair.key.supportsLongPress,
                          ),
                          _buildTriggerButton(
                            context,
                            device: devicePair.key,
                            deviceButton: button,
                            trigger: ButtonTrigger.longPress,
                            supportsLongPress: devicePair.key.supportsLongPress,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildTriggerButton(
    BuildContext context, {
    required ControllerButton deviceButton,
    required BaseDevice device,
    required ButtonTrigger trigger,
    required bool supportsLongPress,
  }) {
    final keyPair = widget.keymap.getKeyPair(deviceButton, trigger: trigger);
    final longPressKeyPair = widget.keymap.getKeyPair(deviceButton, trigger: ButtonTrigger.longPress);
    final showProBanner = _shouldShowProBanner(button: deviceButton, trigger: trigger);
    final hasAction = keyPair != null && !keyPair.hasNoAction;
    final hasLongPressAction = longPressKeyPair != null && !longPressKeyPair.hasNoAction;
    final usesLongPressToggleMode = !supportsLongPress && hasLongPressAction;
    final isDisabled = usesLongPressToggleMode && trigger != ButtonTrigger.longPress;
    final actionText = hasAction ? keyPair.toString() : context.i18n.noActionAssigned;
    final hintText = switch (trigger) {
      ButtonTrigger.longPress when !supportsLongPress => 'tap 1: key down\ntap 2: key up',
      ButtonTrigger.singleClick || ButtonTrigger.doubleClick when isDisabled => 'Remove long press action to re-enable',
      _ => null,
    };

    return LoadingWidget(
      futureCallback: () async {
        await _onTriggerPressed(
          device: device,
          button: deviceButton,
          trigger: trigger,
          hasAction: hasAction,
          forceConflictDialog: showProBanner,
        );
      },
      renderChild: (isLoading, tap) => Stack(
        children: [
          Button.outline(
            style: ButtonStyle.outline().withBorder(
              border: hasAction
                  ? Border.all(color: BKColor.main, width: 2)
                  : Border.all(color: Theme.of(context).colorScheme.border, width: 1),
            ),
            onPressed: isDisabled ? null : tap,
            child: Container(
              width: 120,
              constraints: BoxConstraints(minHeight: 52),
              child: isLoading
                  ? SmallProgressIndicator()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: EdgeInsets.only(right: showProBanner ? 26 : 0),
                            child: Text(trigger.title).xSmall.muted,
                          ),
                        ),
                        if (!isDisabled)
                          Row(
                            spacing: 6,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (hasAction) Icon(keyPair.icon ?? Icons.check_circle_outline, size: 14),
                              if (hasAction)
                                Flexible(
                                  child: Text(actionText).small,
                                ),
                            ],
                          ),
                        if (hintText != null)
                          Text(
                            hintText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ).xSmall.muted,
                      ],
                    ),
            ),
          ),
          if (showProBanner)
            Positioned(
              top: 0,
              right: 0,
              child: ProBadge(
                borderRadius: BorderRadius.only(topRight: Radius.circular(6), bottomLeft: Radius.circular(6)),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _onTriggerPressed({
    required BaseDevice device,
    required ControllerButton button,
    required ButtonTrigger trigger,
    required bool hasAction,
    bool forceConflictDialog = false,
  }) async {
    final isPro = IAPManager.instance.hasActiveSubscription;
    final hasOtherAssignedTrigger = _hasActiveTriggerOtherThan(button, trigger);

    final shouldShowConflictDialog = forceConflictDialog || (!hasAction && hasOtherAssignedTrigger);

    if (!isPro && shouldShowConflictDialog) {
      final resolution = await _showTriggerConflictDialog(trigger);
      if (!mounted || resolution == null) {
        return;
      }

      if (resolution == _TriggerConflictResolution.goPro) {
        await IAPManager.instance.purchaseSubscription(context);
        if (!mounted || !IAPManager.instance.hasActiveSubscription) {
          return;
        }
        await _openButtonEditor(device, button, trigger);
        return;
      }

      await _openButtonEditor(device, button, trigger, clearOtherTriggers: true);
      return;
    }

    await _openButtonEditor(device, button, trigger);
  }

  bool _shouldShowProBanner({required ControllerButton button, required ButtonTrigger trigger}) {
    if (IAPManager.instance.hasActiveSubscription) {
      return false;
    }
    final activeTriggers = _activeTriggers(button);
    return activeTriggers.length > 1 && activeTriggers.skip(1).contains(trigger);
  }

  List<ButtonTrigger> _activeTriggers(ControllerButton button) {
    return ButtonTrigger.values.where((trigger) {
      final keyPair = widget.keymap.getKeyPair(button, trigger: trigger);
      return keyPair != null && !keyPair.hasNoAction;
    }).toList();
  }

  bool _hasActiveTriggerOtherThan(ControllerButton button, ButtonTrigger trigger) {
    return _activeTriggers(button).any((candidate) => candidate != trigger);
  }

  Future<_TriggerConflictResolution?> _showTriggerConflictDialog(ButtonTrigger trigger) {
    return showDialog<_TriggerConflictResolution>(
      context: context,
      builder: (c) => Container(
        constraints: BoxConstraints(maxWidth: 420),
        child: AlertDialog(
          title: Row(
            children: [
              Icon(Icons.workspace_premium, color: Colors.orange),
              const SizedBox(width: 8),
              Text('Additional trigger assignment'),
            ],
          ),
          content: Text(
            'Another trigger is already assigned for this button. Go Pro to keep multiple trigger types, or replace the existing trigger assignment and continue with ${trigger.title}.',
          ),
          actions: [
            Button.secondary(onPressed: () => Navigator.of(c).pop(), child: Text('Cancel')),
            Button.secondary(
              onPressed: () => Navigator.of(c).pop(_TriggerConflictResolution.replaceOtherTriggers),
              child: Text('Replace Existing'),
            ),
            PrimaryButton(
              onPressed: () => Navigator.of(c).pop(_TriggerConflictResolution.goPro),
              child: Text('Go Pro'),
            ),
          ],
        ),
      ),
    );
  }

  void _clearOtherTriggerAssignments(Keymap keymap, ControllerButton button, ButtonTrigger keepTrigger) {
    for (final trigger in ButtonTrigger.values) {
      if (trigger == keepTrigger) {
        continue;
      }
      final existing = keymap.getKeyPair(button, trigger: trigger);
      if (existing == null || existing.hasNoAction) {
        continue;
      }

      final keyPair = keymap.getOrCreateKeyPair(button, trigger: trigger);
      keyPair.physicalKey = null;
      keyPair.logicalKey = null;
      keyPair.modifiers = [];
      keyPair.touchPosition = Offset.zero;
      keyPair.inGameAction = null;
      keyPair.inGameActionValue = null;
      keyPair.androidAction = null;
      keyPair.command = null;
    }
  }

  Future<void> _openButtonEditor(
    BaseDevice device,
    ControllerButton button,
    ButtonTrigger trigger, {
    bool clearOtherTriggers = false,
  }) async {
    Keymap selectedKeymap = widget.keymap;
    if (core.actionHandler.supportedApp is! CustomApp) {
      final currentProfile = core.actionHandler.supportedApp!.name;
      final newName = await KeymapManager().duplicate(
        context,
        currentProfile,
        skipName: '$currentProfile (Copy)',
      );
      if (!mounted) {
        return;
      }
      if (newName != null) {
        buildToast(title: context.i18n.createdNewCustomProfile(newName));
        selectedKeymap = core.actionHandler.supportedApp!.keymap;
      }
    }

    if (clearOtherTriggers) {
      _clearOtherTriggerAssignments(selectedKeymap, button, trigger);
      selectedKeymap.signalUpdate();
    }

    final selectedKeyPair = selectedKeymap.getOrCreateKeyPair(button, trigger: trigger);

    _isDrawerOpen = true;
    await openDrawer(
      context: context,
      builder: (c) => ButtonEditPage(
        device: device,
        keyPair: selectedKeyPair,
        keymap: selectedKeymap,
        trigger: trigger,
        onUpdate: () {
          selectedKeymap.signalUpdate();
          widget.onUpdate();
        },
      ),
      position: OverlayPosition.end,
    );
    widget.onUpdate();
    _isDrawerOpen = false;
  }
}

extension SplitByUppercase on String {
  String splitByUpperCase() {
    return replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (match) => '${match.group(1)} ${match.group(2)}').capitalize();
  }
}
