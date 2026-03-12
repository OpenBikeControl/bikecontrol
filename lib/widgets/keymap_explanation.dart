import 'dart:async';

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
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
  final BaseDevice? filterDevice;
  const KeymapExplanation({super.key, required this.keymap, required this.onUpdate, this.filterDevice});

  @override
  State<KeymapExplanation> createState() => _KeymapExplanationState();
}

class _KeymapExplanationState extends State<KeymapExplanation> {
  late StreamSubscription<void> _updateStreamListener;

  late StreamSubscription<BaseNotification> _actionSubscription;

  bool _isDrawerOpen = false;
  bool _isMobile = false;

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
  void didChangeDependencies() {
    super.didChangeDependencies();

    _isMobile = MediaQuery.sizeOf(context).width < 860;
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
    final devices = widget.filterDevice != null
        ? core.connection.controllerDevices.where((d) => d == widget.filterDevice).toList()
        : core.connection.controllerDevices;
    final keyButtonMap = devices.associateWith((device) {
      return device.availableButtons.distinct().sortedBy(
        (button) => button.color != null ? '0${(button.icon?.codePoint ?? 0)}' : '1${(button.icon?.codePoint ?? 0)}',
      );
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        for (final devicePair in keyButtonMap.entries) ...[
          if (widget.filterDevice == null) ColoredTitle(text: devicePair.key.toString()),
          if (devicePair.value.isEmpty)
            Text(
              devicePair.key.buttonExplanation,
              style: TextStyle(height: 1),
            ).muted,
          for (final button in devicePair.value) ...[
            Card(
              fillColor: Theme.of(context).colorScheme.background,
              filled: true,
              borderColor: ComponentTheme.maybeOf<DividerTheme>(context)?.color ?? Theme.of(context).colorScheme.border,
              padding: _isMobile ? EdgeInsets.zero : null,
              clipBehavior: Clip.antiAlias,
              child: _isMobile
                  ? Column(
                      children: [
                        Container(
                          color: Theme.of(context).colorScheme.card.withAlpha(70),
                          height: 52,
                          child: Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: ButtonWidget(
                                  button: button,
                                ),
                              ),
                              Expanded(
                                child: Text(button.name.splitByUpperCase()).medium.small,
                              ),
                            ],
                          ),
                        ),
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
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Basic(
                            leading: SizedBox(
                              width: 58,
                              child: Center(
                                child: IntrinsicHeight(
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
    KeyPair? keyPair = widget.keymap.getKeyPair(deviceButton, trigger: trigger);
    final longPressKeyPair = widget.keymap.getKeyPair(deviceButton, trigger: ButtonTrigger.longPress);
    if (screenshotMode &&
        keyPair == null &&
        deviceButton.name == ZwiftButtons.a.name &&
        trigger == ButtonTrigger.longPress) {
      // TODO fix it in the screenshot_test.dart instead
      keyPair = KeyPair(
        physicalKey: null,
        logicalKey: null,
        modifiers: [],
        touchPosition: Offset.zero,
        inGameAction: InGameAction.steerRight,
        inGameActionValue: null,
        androidAction: null,
        command: null,
        screenshotPath: null,
        buttons: [ZwiftButtons.a],
      );
    }
    final showProBanner = _shouldShowProBanner(button: deviceButton, trigger: trigger);
    final hasAction = keyPair != null && !keyPair.hasNoAction;
    final hasLongPressAction = longPressKeyPair != null && !longPressKeyPair.hasNoAction;
    final usesLongPressToggleMode = !supportsLongPress && hasLongPressAction;
    final isDisabled = usesLongPressToggleMode && trigger != ButtonTrigger.longPress;
    final actionText = hasAction ? keyPair.toString() : context.i18n.noActionAssigned;
    final hintText = switch (trigger) {
      ButtonTrigger.singleClick ||
      ButtonTrigger.doubleClick when isDisabled => context.i18n.removeOnePressAction(device.name),
      _ => null,
    };

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      mainAxisSize: MainAxisSize.min,
      spacing: _isMobile ? 4 : 0,
      children: [
        Align(
          alignment: _isMobile ? Alignment.centerLeft : Alignment.centerRight,
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
              if (hasAction || _isMobile)
                Flexible(
                  child: Text(
                    actionText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _isMobile && !hasAction
                        ? TextStyle(
                            color: Theme.of(context).colorScheme.secondaryForeground.withAlpha(60),
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.normal,
                          )
                        : null,
                  ).small,
                ),
            ],
          ),

        if (trigger == ButtonTrigger.longPress && !supportsLongPress && hasAction)
          Text(context.i18n.longTapExplanation).xSmall.muted,
      ],
    );

    return LoadingWidget(
      futureCallback: () async {
        await _onTriggerPressed(
          device: device,
          button: deviceButton,
          trigger: trigger,
          hasAction: hasAction,
          forceConflictDialog: showProBanner,
          hintText: hintText,
        );
      },
      renderChild: (isLoading, tap) => Stack(
        children: [
          if (_isMobile) ...[
            Divider(),
            Button.ghost(
              onPressed: tap,
              child: Container(
                width: _isMobile ? null : 120,
                constraints: BoxConstraints(minHeight: 52),
                child: Row(
                  children: [
                    Expanded(child: column),
                    if (isLoading) SmallProgressIndicator() else if (hasAction) Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ] else
            Button.outline(
              style: ButtonStyle.outline().withBorder(
                border: hasAction
                    ? Border.all(color: BKColor.main, width: 2)
                    : Border.all(color: Theme.of(context).colorScheme.border, width: 1),
              ),
              onPressed: tap,
              child: Container(
                width: _isMobile ? null : 140,
                constraints: BoxConstraints(minHeight: 52),
                child: isLoading ? SmallProgressIndicator() : column,
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
    required String? hintText,
  }) async {
    final isPro = IAPManager.instance.hasActiveSubscription;
    final hasOtherAssignedTrigger = _hasActiveTriggerOtherThan(button, trigger);

    final shouldShowConflictDialog = hintText != null || forceConflictDialog || (!hasAction && hasOtherAssignedTrigger);

    if ((!isPro || hintText != null) && shouldShowConflictDialog) {
      final resolution = await _showTriggerConflictDialog(trigger, hintText: hintText);
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

  Future<_TriggerConflictResolution?> _showTriggerConflictDialog(ButtonTrigger trigger, {required String? hintText}) {
    return showDialog<_TriggerConflictResolution>(
      context: context,
      builder: (c) => Container(
        constraints: BoxConstraints(maxWidth: 420),
        child: AlertDialog(
          title: Row(
            children: [
              if (!IAPManager.instance.hasActiveSubscription) ...[
                Icon(Icons.workspace_premium, color: Colors.orange),
                const SizedBox(width: 8),
              ],
              Text(AppLocalizations.of(context).additionalTriggerAssignment),
            ],
          ),
          content: Text(
            hintText ?? AppLocalizations.of(context).anotherTriggerIsAlreadyAssignedForThisButton(trigger.title),
          ),
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              spacing: 8,
              children: [
                Button.secondary(
                  onPressed: () => Navigator.of(c).pop(),
                  child: Text(AppLocalizations.of(context).cancel),
                ),

                Button.secondary(
                  onPressed: () => Navigator.of(c).pop(_TriggerConflictResolution.replaceOtherTriggers),
                  child: Text(AppLocalizations.of(context).replaceExisting),
                ),
                if (!IAPManager.instance.hasActiveSubscription)
                  PrimaryButton(
                    onPressed: () => Navigator.of(c).pop(_TriggerConflictResolution.goPro),
                    child: Text(AppLocalizations.of(context).goPro),
                  ),
              ],
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
      keyPair.screenshotPath = null;
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

          if (core.actionHandler.supportedApp is CustomApp) {
            core.settings.setKeyMap(core.actionHandler.supportedApp!);
          }
          widget.onUpdate();
        },
      ),
      position: OverlayPosition.end,
    );
    if (core.actionHandler.supportedApp is CustomApp) {
      core.settings.setKeyMap(core.actionHandler.supportedApp!);
    }
    widget.onUpdate();
    _isDrawerOpen = false;
  }
}

extension SplitByUppercase on String {
  String splitByUpperCase() {
    return replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (match) => '${match.group(1)} ${match.group(2)}').capitalize();
  }
}
