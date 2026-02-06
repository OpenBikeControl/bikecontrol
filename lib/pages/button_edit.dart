import 'dart:async';

import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/pages/touch_area.dart';
import 'package:bike_control/utils/actions/android.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/widgets/custom_keymap_selector.dart';
import 'package:bike_control/widgets/ui/button_widget.dart';
import 'package:bike_control/widgets/ui/colored_title.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:bike_control/widgets/ui/warning.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

class ButtonEditPage extends StatefulWidget {
  final Keymap keymap;
  final KeyPair keyPair;
  final VoidCallback onUpdate;
  const ButtonEditPage({super.key, required this.keyPair, required this.onUpdate, required this.keymap});

  @override
  State<ButtonEditPage> createState() => _ButtonEditPageState();
}

class _ButtonEditPageState extends State<ButtonEditPage> {
  late KeyPair _keyPair;
  late final ScrollController _scrollController = ScrollController();
  final double baseHeight = 46;
  bool _bumped = false;

  void _triggerBump() async {
    setState(() {
      _bumped = true;
    });

    await Future.delayed(const Duration(milliseconds: 150));

    if (mounted) {
      setState(() {
        _bumped = false;
      });
    }
  }

  late StreamSubscription<BaseNotification> _actionSubscription;

  @override
  void initState() {
    super.initState();
    _keyPair = widget.keyPair;
    _actionSubscription = core.connection.actionStream.listen((data) async {
      if (!mounted) {
        return;
      }
      if (data is ButtonNotification && data.buttonsClicked.length == 1) {
        final clickedButton = data.buttonsClicked.first;
        final keyPair = widget.keymap.keyPairs.firstOrNullWhere(
          (kp) => kp.buttons.contains(clickedButton),
        );
        if (keyPair != null) {
          setState(() {
            _keyPair = keyPair;
          });
          _triggerBump();
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _actionSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IntrinsicWidth(
      child: Scrollbar(
        controller: _scrollController,
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Container(
            constraints: BoxConstraints(maxWidth: 300),
            padding: const EdgeInsets.only(right: 26.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                SizedBox(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  spacing: 8,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOut,
                      width: _keyPair.buttons.first.color != null ? baseHeight : null,
                      height: _keyPair.buttons.first.color != null ? baseHeight : null,
                      padding: EdgeInsets.all(_bumped ? 0 : 6.0),
                      constraints: BoxConstraints(maxWidth: 120),
                      child: ButtonWidget(button: _keyPair.buttons.first),
                    ),
                    Expanded(child: SizedBox()),
                    IconButton(
                      icon: Icon(Icons.close),
                      variance: ButtonVariance.ghost,
                      onPressed: () {
                        closeDrawer(context);
                      },
                    ),
                  ],
                ),
                if (core.logic.hasNoConnectionMethod)
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 300),
                    child: Warning(
                      children: [
                        Text(AppLocalizations.of(context).pleaseSelectAConnectionMethodFirst),
                      ],
                    ),
                  ),
                if (core.logic.showObpActions) ...[
                  ColoredTitle(text: context.i18n.openBikeControlActions),
                  if (core.logic.obpConnectedApp == null)
                    Warning(
                      children: [
                        Text(
                          core.logic.obpConnectedApp == null
                              ? 'Please connect to ${core.settings.getTrainerApp()?.name}, first.'
                              : context.i18n.appIdActions(core.logic.obpConnectedApp!.appId),
                        ),
                      ],
                    )
                  else
                    ..._buildTrainerConnectionActions(core.logic.obpConnectedApp!.supportedActions),
                ],

                if (core.logic.showMyWhooshLink) ...[
                  SizedBox(height: 8),
                  ColoredTitle(text: context.i18n.myWhooshDirectConnectAction),
                  if (!core.settings.getMyWhooshLinkEnabled())
                    Warning(
                      important: false,
                      children: [
                        Text(AppLocalizations.of(context).enableMywhooshLinkInTheConnectionSettingsFirst),
                      ],
                    )
                  else
                    ..._buildTrainerConnectionActions(core.whooshLink.supportedActions),
                ],
                if (core.logic.showZwiftBleEmulator || core.logic.showZwiftMsdnEmulator) ...[
                  SizedBox(height: 8),
                  ColoredTitle(text: context.i18n.zwiftControllerAction),
                  if (!core.settings.getZwiftBleEmulatorEnabled() && !core.settings.getZwiftMdnsEmulatorEnabled())
                    Warning(
                      important: false,
                      children: [
                        Text(AppLocalizations.of(context).enableItInTheConnectionSettingsFirst),
                      ],
                    )
                  else
                    ..._buildTrainerConnectionActions(core.zwiftEmulator.supportedActions),
                ],

                if (core.logic.showLocalRemoteOptions) ...[
                  SizedBox(height: 8),
                  ColoredTitle(text: 'Local / Remote Setting'),

                  if (core.actionHandler.supportedModes.contains(SupportedMode.keyboard) &&
                      (core.settings.getLocalEnabled() || core.settings.getRemoteKeyboardControlEnabled()))
                    Builder(
                      builder: (context) {
                        return SelectableCard(
                          icon: RadixIcons.keyboard,
                          title: Text(context.i18n.simulateKeyboardShortcut),
                          isActive:
                              _keyPair.physicalKey != null &&
                              !_keyPair.isSpecialKey &&
                              (core.settings.getLocalEnabled() || core.settings.getRemoteKeyboardControlEnabled()),
                          value: _keyPair.toString(),
                          onPressed: () async {
                            await _showModeDropdown(context, SupportedMode.keyboard);
                          },
                        );
                      },
                    ),
                  if (core.actionHandler.supportedModes.contains(SupportedMode.touch) &&
                      (core.settings.getLocalEnabled() || core.settings.getRemoteControlEnabled()))
                    Builder(
                      builder: (context) {
                        return SelectableCard(
                          title: Text(context.i18n.simulateTouch),
                          icon: core.actionHandler is AndroidActions ? Icons.touch_app_outlined : BootstrapIcons.mouse,
                          isActive:
                              ((core.actionHandler is AndroidActions || _keyPair.physicalKey == null) &&
                                  _keyPair.touchPosition != Offset.zero) &&
                              (core.settings.getLocalEnabled() || core.settings.getRemoteControlEnabled()),
                          value: _keyPair.toString(),
                          trailing: IconButton.secondary(
                            icon: Icon(Icons.ondemand_video),
                            onPressed: () {
                              launchUrlString('https://youtube.com/shorts/SvLOQqu2Dqg?feature=share');
                            },
                          ),
                          onPressed: () async {
                            await _showModeDropdown(context, SupportedMode.touch);
                          },
                        );
                      },
                    ),

                  if (core.actionHandler.supportedModes.contains(SupportedMode.media))
                    Builder(
                      builder: (context) => SelectableCard(
                        icon: Icons.music_note_outlined,
                        isActive: _keyPair.isSpecialKey && core.settings.getLocalEnabled(),
                        title: Text(context.i18n.simulateMediaKey),
                        value: _keyPair.toString(),
                        trailing: IconButton.secondary(
                          icon: Icon(Icons.ondemand_video),
                          onPressed: () {
                            launchUrlString('https://youtube.com/shorts/ClY1eTnmAv0?feature=share');
                          },
                        ),
                        onPressed: () {
                          if (!core.settings.getLocalEnabled()) {
                            buildToast(
                              navigatorKey.currentContext!,
                              title: AppLocalizations.of(context).enableLocalConnectionMethodFirst,
                            );
                          } else {
                            showDropdown(
                              context: context,
                              builder: (c) => DropdownMenu(
                                children: [
                                  MenuButton(
                                    leading: Icon(Icons.play_arrow_outlined),
                                    onPressed: (c) {
                                      _keyPair.physicalKey = PhysicalKeyboardKey.mediaPlayPause;
                                      _keyPair.touchPosition = Offset.zero;
                                      _keyPair.logicalKey = null;
                                      _keyPair.androidAction = null;

                                      setState(() {});
                                      widget.onUpdate();
                                    },
                                    child: Text(context.i18n.playPause),
                                  ),
                                  MenuButton(
                                    leading: Icon(Icons.stop_outlined),
                                    onPressed: (c) {
                                      _keyPair.physicalKey = PhysicalKeyboardKey.mediaStop;
                                      _keyPair.touchPosition = Offset.zero;
                                      _keyPair.logicalKey = null;
                                      _keyPair.androidAction = null;

                                      setState(() {});
                                      widget.onUpdate();
                                    },
                                    child: Text(context.i18n.stop),
                                  ),
                                  MenuButton(
                                    leading: Icon(Icons.skip_previous_outlined),
                                    onPressed: (c) {
                                      _keyPair.physicalKey = PhysicalKeyboardKey.mediaTrackPrevious;
                                      _keyPair.touchPosition = Offset.zero;
                                      _keyPair.logicalKey = null;
                                      _keyPair.androidAction = null;

                                      setState(() {});
                                      widget.onUpdate();
                                    },
                                    child: Text(context.i18n.previous),
                                  ),
                                  MenuButton(
                                    leading: Icon(Icons.skip_next_outlined),
                                    onPressed: (c) {
                                      _keyPair.physicalKey = PhysicalKeyboardKey.mediaTrackNext;
                                      _keyPair.touchPosition = Offset.zero;
                                      _keyPair.logicalKey = null;
                                      _keyPair.androidAction = null;

                                      setState(() {});
                                      widget.onUpdate();
                                    },
                                    child: Text(context.i18n.next),
                                  ),
                                  MenuButton(
                                    leading: Icon(Icons.volume_up_outlined),
                                    onPressed: (c) {
                                      _keyPair.physicalKey = PhysicalKeyboardKey.audioVolumeUp;
                                      _keyPair.touchPosition = Offset.zero;
                                      _keyPair.logicalKey = null;
                                      _keyPair.androidAction = null;

                                      setState(() {});
                                      widget.onUpdate();
                                    },
                                    child: Text(context.i18n.volumeUp),
                                  ),
                                  MenuButton(
                                    leading: Icon(Icons.volume_down_outlined),
                                    child: Text(context.i18n.volumeDown),
                                    onPressed: (c) {
                                      _keyPair.physicalKey = PhysicalKeyboardKey.audioVolumeDown;
                                      _keyPair.touchPosition = Offset.zero;
                                      _keyPair.logicalKey = null;
                                      _keyPair.androidAction = null;

                                      setState(() {});
                                      widget.onUpdate();
                                    },
                                  ),
                                ],
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  if (core.logic.showLocalControl && core.actionHandler is AndroidActions)
                    Builder(
                      builder: (context) => SelectableCard(
                        icon: Icons.settings_remote_outlined,
                        isActive: _keyPair.androidAction != null && core.settings.getLocalEnabled(),
                        title: Text(AppLocalizations.of(context).androidSystemAction),
                        value: _keyPair.androidAction?.title,
                        trailing: IconButton.secondary(
                          icon: Icon(Icons.ondemand_video),
                          onPressed: () {
                            launchUrlString('https://youtube.com/shorts/zqD5ARGIVmE?feature=share');
                          },
                        ),
                        onPressed: () {
                          if (!core.settings.getLocalEnabled()) {
                            buildToast(navigatorKey.currentContext!, title: 'Enable Local Connection method, first.');
                          } else {
                            showDropdown(
                              context: context,
                              builder: (c) => DropdownMenu(
                                children: AndroidSystemAction.values
                                    .map(
                                      (action) => MenuButton(
                                        leading: Icon(action.icon),
                                        onPressed: (_) {
                                          _keyPair.androidAction = action;
                                          _keyPair.physicalKey = null;
                                          _keyPair.logicalKey = null;
                                          _keyPair.modifiers = [];
                                          _keyPair.touchPosition = Offset.zero;
                                          _keyPair.inGameAction = null;
                                          _keyPair.inGameActionValue = null;
                                          setState(() {});
                                          widget.onUpdate();
                                        },
                                        child: Text(action.title),
                                      ),
                                    )
                                    .toList(),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                ],

                if (core.connection.accessories.isNotEmpty) ...[
                  SizedBox(height: 8),
                  ColoredTitle(text: 'Accessory Actions'),
                  Builder(
                    builder: (context) => SelectableCard(
                      icon: Icons.air,
                      title: Text('KICKR Headwind'),
                      isActive:
                          _keyPair.inGameAction != null &&
                          (_keyPair.inGameAction == InGameAction.headwindSpeed ||
                              _keyPair.inGameAction == InGameAction.headwindHeartRateMode),
                      value: _keyPair.inGameAction != null
                          ? '${_keyPair.inGameAction} ${_keyPair.inGameActionValue ?? ""}'.trim()
                          : null,
                      onPressed: () {
                        showDropdown(
                          context: context,
                          builder: (c) => DropdownMenu(
                            children: [
                              MenuButton(
                                subMenu: [0, 25, 50, 75, 100]
                                    .map(
                                      (value) => MenuButton(
                                        child: Text('Set Speed to $value%'),
                                        onPressed: (_) {
                                          _keyPair.inGameAction = InGameAction.headwindSpeed;
                                          _keyPair.inGameActionValue = value;
                                          _keyPair.androidAction = null;
                                          widget.onUpdate();
                                          setState(() {});
                                        },
                                      ),
                                    )
                                    .toList(),
                                child: Text('Set Speed'),
                              ),
                              MenuButton(
                                child: Text('Set to Heart Rate Mode'),
                                onPressed: (_) {
                                  _keyPair.inGameAction = InGameAction.headwindHeartRateMode;
                                  _keyPair.inGameActionValue = null;
                                  _keyPair.androidAction = null;
                                  widget.onUpdate();
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],

                SizedBox(height: 8),
                ColoredTitle(text: context.i18n.setting),
                SelectableCard(
                  icon: _keyPair.isLongPress ? Icons.check_box : Icons.check_box_outline_blank,
                  title: Text(context.i18n.longPressMode),
                  isActive: _keyPair.isLongPress,
                  onPressed: () {
                    _keyPair.isLongPress = !_keyPair.isLongPress;
                    widget.onUpdate();
                    setState(() {});
                  },
                ),
                SizedBox(height: 8),
                DestructiveButton(
                  onPressed: () {
                    _keyPair.isLongPress = false;
                    _keyPair.physicalKey = null;
                    _keyPair.logicalKey = null;
                    _keyPair.modifiers = [];
                    _keyPair.touchPosition = Offset.zero;
                    _keyPair.inGameAction = null;
                    _keyPair.inGameActionValue = null;
                    _keyPair.androidAction = null;
                    widget.onUpdate();
                    setState(() {});
                  },
                  child: Text(context.i18n.unassignAction),
                ),
                SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTrainerConnectionActions(List<InGameAction> supportedActions) {
    return supportedActions.map((action) {
      return Builder(
        builder: (context) {
          return SelectableCard(
            icon: action.icon,
            title: Text(action.title),
            subtitle: (action.possibleValues != null && action == _keyPair.inGameAction)
                ? Text(_keyPair.inGameActionValue!.toString())
                : action.alternativeTitle != null
                ? Text(action.alternativeTitle!)
                : null,
            isActive: _keyPair.inGameAction == action && supportedActions.contains(_keyPair.inGameAction),
            onPressed: () {
              if (action.possibleValues?.isNotEmpty == true) {
                showDropdown(
                  context: context,
                  builder: (c) => DropdownMenu(
                    children: action.possibleValues!.map(
                      (ingame) {
                        return MenuButton(
                          child: Text(ingame.toString()),
                          onPressed: (_) {
                            _keyPair.touchPosition = Offset.zero;
                            _keyPair.physicalKey = null;
                            _keyPair.logicalKey = null;
                            _keyPair.androidAction = null;
                            _keyPair.inGameAction = action;
                            _keyPair.inGameActionValue = ingame;
                            _keyPair.isLongPress = _keyPair.isLongPress ? true : action.isLongPress;
                            widget.onUpdate();
                            setState(() {});
                          },
                        );
                      },
                    ).toList(),
                  ),
                );
              } else {
                _keyPair.touchPosition = Offset.zero;
                _keyPair.physicalKey = null;
                _keyPair.logicalKey = null;
                _keyPair.androidAction = null;
                _keyPair.inGameAction = action;
                _keyPair.inGameActionValue = null;
                _keyPair.isLongPress = _keyPair.isLongPress ? true : action.isLongPress;
                widget.onUpdate();
                setState(() {});
              }
            },
          );
        },
      );
    }).toList();
  }

  Future<void> _showModeDropdown(BuildContext context, SupportedMode supportedMode) async {
    final trainerApp = core.settings.getTrainerApp();

    final actionsWithInGameAction = trainerApp?.keymap.keyPairs
        .where(
          (kp) =>
              kp.inGameAction != null &&
              switch (supportedMode) {
                SupportedMode.keyboard => kp.physicalKey != null,
                SupportedMode.touch => kp.touchPosition != Offset.zero,
                SupportedMode.media => kp.isSpecialKey,
              },
        )
        .distinctBy((kp) => kp.inGameAction)
        .toList();

    final isEnabled =
        supportedMode == SupportedMode.keyboard &&
            (core.settings.getLocalEnabled() || core.settings.getRemoteKeyboardControlEnabled()) ||
        supportedMode == SupportedMode.touch &&
            (core.settings.getLocalEnabled() || core.settings.getRemoteControlEnabled()) ||
        supportedMode == SupportedMode.media && core.settings.getLocalEnabled();

    if (!isEnabled) {
      return buildToast(
        navigatorKey.currentContext!,
        title: AppLocalizations.of(context).enableLocalConnectionMethodFirst,
      );
    } else if (actionsWithInGameAction != null && actionsWithInGameAction.isNotEmpty) {
      showDropdown(
        context: context,
        builder: (c) => DropdownMenu(
          children: [
            MenuLabel(child: Text(context.i18n.predefinedAction(trainerApp?.name ?? 'App'))),
            ...actionsWithInGameAction.map((keyPairAction) {
              return MenuButton(
                leading: keyPairAction.inGameAction?.icon != null ? Icon(keyPairAction.inGameAction!.icon) : null,
                onPressed: (_) {
                  // Copy all properties from the selected predefined action
                  if (core.actionHandler.supportedModes.contains(SupportedMode.keyboard)) {
                    _keyPair.physicalKey = keyPairAction.physicalKey;
                    _keyPair.logicalKey = keyPairAction.logicalKey;
                    _keyPair.modifiers = List.of(keyPairAction.modifiers);
                  } else {
                    _keyPair.physicalKey = null;
                    _keyPair.logicalKey = null;
                    _keyPair.modifiers = [];
                  }
                  if (core.actionHandler.supportedModes.contains(SupportedMode.touch)) {
                    _keyPair.touchPosition = keyPairAction.touchPosition;
                  } else {
                    _keyPair.touchPosition = Offset.zero;
                  }
                  _keyPair.isLongPress = keyPairAction.isLongPress;
                  _keyPair.inGameAction = keyPairAction.inGameAction;
                  _keyPair.inGameActionValue = keyPairAction.inGameActionValue;
                  _keyPair.androidAction = null;
                  setState(() {});
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(keyPairAction.inGameAction?.title ?? ''),
                    Text(switch (supportedMode) {
                      SupportedMode.keyboard => keyPairAction.logicalKey?.keyLabel ?? 'Not assigned',
                      SupportedMode.touch =>
                        'X:${keyPairAction.touchPosition.dx.toInt()}, Y:${keyPairAction.touchPosition.dy.toInt()}',
                      SupportedMode.media => throw UnimplementedError(),
                    }).muted.small,
                  ],
                ),
              );
            }),
            MenuDivider(),
            MenuLabel(child: Text('Custom ${supportedMode.name.capitalize()} action')),
            MenuButton(
              leading: Icon(Icons.edit_outlined),
              onPressed: (_) {
                _editAction(supportedMode);
              },
              child: Text('Custom'),
            ),
          ],
        ),
      );
    } else {
      _editAction(supportedMode);
    }
  }

  Future<void> _editAction(SupportedMode supportedMode) async {
    if (supportedMode == SupportedMode.keyboard) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false, // enable Escape key
        builder: (c) => HotKeyListenerDialog(
          customApp: core.actionHandler.supportedApp! as CustomApp,
          keyPair: _keyPair,
        ),
      );
      _keyPair.androidAction = null;
      setState(() {});
      widget.onUpdate();
    } else if (supportedMode == SupportedMode.touch) {
      if (_keyPair.touchPosition == Offset.zero) {
        _keyPair.touchPosition = Offset(50, 50);
      }
      _keyPair.physicalKey = null;
      _keyPair.logicalKey = null;
      _keyPair.androidAction = null;
      await Navigator.of(context).push<bool?>(
        MaterialPageRoute(
          builder: (c) => TouchAreaSetupPage(
            keyPair: _keyPair,
          ),
        ),
      );
      setState(() {});
      widget.onUpdate();
    }
  }
}

class SelectableCard extends StatelessWidget {
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final IconData? icon;
  final bool isActive;
  final String? value;
  final VoidCallback? onPressed;

  const SelectableCard({
    super.key,
    required this.title,
    this.icon,
    this.subtitle,
    this.trailing,
    required this.isActive,
    this.value,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Button.outline(
      style:
          ButtonStyle(
                variance: ButtonVariance.outline,
              )
              .withBorder(
                border: isActive
                    ? Border.all(color: BKColor.main, width: 2)
                    : Border.all(color: Theme.of(context).colorScheme.border, width: 2),
                hoverBorder: Border.all(color: BKColor.mainEnd, width: 2),
                focusBorder: Border.all(color: BKColor.main, width: 2),
              )
              .withBackgroundColor(
                color: isActive
                    ? Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context).colorScheme.card
                          : Theme.of(context).colorScheme.card.withLuminance(0.9)
                    : Theme.of(context).colorScheme.background,
                hoverColor: Theme.of(context).colorScheme.card,
              ),
      onPressed: onPressed,
      alignment: Alignment.topLeft,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Basic(
          leading: icon != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 3.0),
                  child: Icon(
                    icon,
                    color: icon == Icons.delete_outline ? Theme.of(context).colorScheme.destructive : null,
                  ),
                )
              : null,
          title: title,
          subtitle: value != null && isActive ? Text(value!) : subtitle,
          trailing: trailing,
        ),
      ),
    );
  }
}
