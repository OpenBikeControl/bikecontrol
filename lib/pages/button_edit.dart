import 'package:dartx/dartx.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/bluetooth/devices/mywhoosh/link.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_emulator.dart';
import 'package:swift_control/gen/l10n.dart';
import 'package:swift_control/pages/touch_area.dart';
import 'package:swift_control/utils/actions/base_actions.dart';
import 'package:swift_control/utils/core.dart';
import 'package:swift_control/utils/i18n_extension.dart';
import 'package:swift_control/utils/keymap/apps/custom_app.dart';
import 'package:swift_control/utils/keymap/keymap.dart';
import 'package:swift_control/widgets/custom_keymap_selector.dart';
import 'package:swift_control/widgets/ui/button_widget.dart';
import 'package:swift_control/widgets/ui/colored_title.dart';
import 'package:swift_control/widgets/ui/colors.dart';
import 'package:swift_control/widgets/ui/warning.dart';

class ButtonEditPage extends StatefulWidget {
  final KeyPair keyPair;
  final VoidCallback onUpdate;
  const ButtonEditPage({super.key, required this.keyPair, required this.onUpdate});

  @override
  State<ButtonEditPage> createState() => _ButtonEditPageState();
}

class _ButtonEditPageState extends State<ButtonEditPage> {
  late final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyPair = widget.keyPair;
    final trainerApp = core.settings.getTrainerApp();

    final actionsWithInGameAction = trainerApp?.keymap.keyPairs
        .where((kp) => kp.inGameAction != null)
        .distinctBy((kp) => kp.inGameAction)
        .toList();

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
              spacing: 16,
              children: [
                SizedBox(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  spacing: 8,
                  children: [
                    Text('Editing').h3,
                    ButtonWidget(button: widget.keyPair.buttons.first),
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
                  Builder(
                    builder: (context) => SelectableCard(
                      icon: Icons.link,
                      title: Text(
                        core.logic.obpConnectedApp == null
                            ? 'Please connect to ${core.settings.getTrainerApp()?.name}, first.'
                            : context.i18n.appIdActions(core.logic.obpConnectedApp!.appId),
                      ),
                      isActive: core.logic.obpConnectedApp != null && keyPair.inGameAction != null,
                      onPressed: core.logic.obpConnectedApp == null
                          ? null
                          : () {
                              showDropdown(
                                builder: (c) => DropdownMenu(
                                  children: core.logic.obpConnectedApp!.supportedButtons
                                      .map(
                                        (button) => MenuButton(
                                          child: Text(button.name),
                                          onPressed: (_) {
                                            keyPair.touchPosition = Offset.zero;
                                            keyPair.physicalKey = null;
                                            keyPair.logicalKey = null;
                                            keyPair.inGameAction = button.action!;
                                            keyPair.inGameActionValue = null;
                                            widget.onUpdate();
                                            setState(() {});
                                          },
                                        ),
                                      )
                                      .toList(),
                                ),
                                context: context,
                              );
                            },
                    ),
                  ),
                ],

                if (core.settings.getMyWhooshLinkEnabled() && core.logic.showMyWhooshLink) ...[
                  SizedBox(height: 8),
                  ColoredTitle(text: context.i18n.myWhooshDirectConnectAction),
                  Builder(
                    builder: (context) => SelectableCard(
                      icon: Icons.link,
                      title: Text(context.i18n.myWhooshDirectConnectAction),
                      isActive: keyPair.inGameAction != null,
                      value: [keyPair.inGameAction.toString(), ?keyPair.inGameActionValue?.toString()].join(' '),
                      onPressed: () {
                        showDropdown(
                          context: context,
                          builder: (c) => DropdownMenu(
                            children: WhooshLink.supportedActions.map(
                              (ingame) {
                                return MenuButton(
                                  subMenu: ingame.possibleValues
                                      ?.map(
                                        (value) => MenuButton(
                                          child: Text(value.toString()),
                                          onPressed: (_) {
                                            keyPair.inGameAction = ingame;
                                            keyPair.inGameActionValue = value;
                                            widget.onUpdate();
                                            setState(() {});
                                          },
                                        ),
                                      )
                                      .toList(),
                                  child: Text(ingame.toString()),
                                  onPressed: (_) {
                                    keyPair.inGameAction = ingame;
                                    keyPair.inGameActionValue = null;
                                    widget.onUpdate();
                                    setState(() {});
                                  },
                                );
                              },
                            ).toList(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                if (core.logic.isZwiftBleEnabled || core.logic.isZwiftMdnsEnabled) ...[
                  SizedBox(height: 8),
                  ColoredTitle(text: context.i18n.zwiftControllerAction),
                  Builder(
                    builder: (context) => SelectableCard(
                      icon: Icons.link,
                      title: Text(context.i18n.zwiftControllerAction),
                      isActive: keyPair.inGameAction != null,
                      value: [keyPair.inGameAction.toString(), ?keyPair.inGameActionValue?.toString()].join(' '),
                      onPressed: () {
                        showDropdown(
                          context: context,
                          builder: (c) => DropdownMenu(
                            children: ZwiftEmulator.supportedActions.map(
                              (ingame) {
                                return MenuButton(
                                  subMenu: ingame.possibleValues
                                      ?.map(
                                        (value) => MenuButton(
                                          child: Text(value.toString()),
                                          onPressed: (_) {
                                            keyPair.inGameAction = ingame;
                                            keyPair.inGameActionValue = value;
                                            widget.onUpdate();
                                            setState(() {});
                                          },
                                        ),
                                      )
                                      .toList(),
                                  child: Text(ingame.toString()),
                                  onPressed: (_) {
                                    keyPair.inGameAction = ingame;
                                    keyPair.inGameActionValue = null;
                                    widget.onUpdate();
                                    setState(() {});
                                  },
                                );
                              },
                            ).toList(),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                if (core.logic.showLocalRemoteOptions) ...[
                  SizedBox(height: 8),
                  ColoredTitle(text: 'Local / Remote Setting'),
                  if (trainerApp != null && trainerApp is! CustomApp && actionsWithInGameAction?.isEmpty != true) ...[
                    Builder(
                      builder: (context) => SelectableCard(
                        icon: null,
                        title: Text(context.i18n.predefinedAction(trainerApp.name)),
                        isActive: false,
                        onPressed: () {
                          showDropdown(
                            context: context,
                            builder: (c) => DropdownMenu(
                              children: actionsWithInGameAction!.map((keyPairAction) {
                                return MenuButton(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      Text(_formatActionDescription(keyPairAction).split(' = ').first),
                                      Text(
                                        _formatActionDescription(keyPairAction).split(' = ').last,
                                        style: TextStyle(fontSize: 12, color: Colors.gray),
                                      ),
                                    ],
                                  ),
                                  onPressed: (_) {
                                    // Copy all properties from the selected predefined action
                                    if (core.actionHandler.supportedModes.contains(SupportedMode.keyboard)) {
                                      keyPair.physicalKey = keyPairAction.physicalKey;
                                      keyPair.logicalKey = keyPairAction.logicalKey;
                                      keyPair.modifiers = List.of(keyPairAction.modifiers);
                                    } else {
                                      keyPair.physicalKey = null;
                                      keyPair.logicalKey = null;
                                      keyPair.modifiers = [];
                                    }
                                    if (core.actionHandler.supportedModes.contains(SupportedMode.touch)) {
                                      keyPair.touchPosition = keyPairAction.touchPosition;
                                    } else {
                                      keyPair.touchPosition = Offset.zero;
                                    }
                                    keyPair.isLongPress = keyPairAction.isLongPress;
                                    keyPair.inGameAction = keyPairAction.inGameAction;
                                    keyPair.inGameActionValue = keyPairAction.inGameActionValue;
                                    setState(() {});
                                  },
                                );
                              }).toList(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  if (core.actionHandler.supportedModes.contains(SupportedMode.keyboard))
                    SelectableCard(
                      icon: Icons.keyboard_alt_outlined,
                      title: Text(context.i18n.simulateKeyboardShortcut),
                      isActive: keyPair.physicalKey != null && !keyPair.isSpecialKey,
                      value: 'Key: $keyPair',
                      onPressed: () async {
                        await showDialog<void>(
                          context: context,
                          barrierDismissible: false, // enable Escape key
                          builder: (c) => HotKeyListenerDialog(
                            customApp: core.actionHandler.supportedApp! as CustomApp,
                            keyPair: keyPair,
                          ),
                        );
                        setState(() {});
                        widget.onUpdate();
                      },
                    ),
                  if (core.actionHandler.supportedModes.contains(SupportedMode.touch))
                    SelectableCard(
                      title: Text(context.i18n.simulateTouch),
                      icon: Icons.touch_app_outlined,
                      isActive: keyPair.physicalKey == null && keyPair.touchPosition != Offset.zero,
                      value:
                          'Coordinates: X: ${keyPair.touchPosition.dx.toInt()}, Y: ${keyPair.touchPosition.dy.toInt()}',
                      onPressed: () async {
                        if (keyPair.touchPosition == Offset.zero) {
                          keyPair.touchPosition = Offset(50, 50);
                        }
                        keyPair.physicalKey = null;
                        keyPair.logicalKey = null;
                        await Navigator.of(context).push<bool?>(
                          MaterialPageRoute(
                            builder: (c) => TouchAreaSetupPage(
                              keyPair: keyPair,
                            ),
                          ),
                        );
                        setState(() {});
                        widget.onUpdate();
                      },
                    ),

                  if (core.actionHandler.supportedModes.contains(SupportedMode.media))
                    Builder(
                      builder: (context) => SelectableCard(
                        icon: Icons.music_note_outlined,
                        isActive: keyPair.isSpecialKey,
                        title: Text(context.i18n.simulateMediaKey),
                        value: keyPair.toString(),
                        onPressed: () {
                          showDropdown(
                            context: context,
                            builder: (c) => DropdownMenu(
                              children: [
                                MenuButton(
                                  child: Text(context.i18n.playPause),
                                  onPressed: (c) {
                                    keyPair.physicalKey = PhysicalKeyboardKey.mediaPlayPause;
                                    keyPair.logicalKey = null;

                                    setState(() {});
                                    widget.onUpdate();
                                  },
                                ),
                                MenuButton(
                                  child: Text(context.i18n.stop),
                                  onPressed: (c) {
                                    keyPair.physicalKey = PhysicalKeyboardKey.mediaStop;
                                    keyPair.logicalKey = null;

                                    setState(() {});
                                    widget.onUpdate();
                                  },
                                ),
                                MenuButton(
                                  child: Text(context.i18n.previous),

                                  onPressed: (c) {
                                    keyPair.physicalKey = PhysicalKeyboardKey.mediaTrackPrevious;
                                    keyPair.logicalKey = null;

                                    setState(() {});
                                    widget.onUpdate();
                                  },
                                ),
                                MenuButton(
                                  child: Text(context.i18n.next),
                                  onPressed: (c) {
                                    keyPair.physicalKey = PhysicalKeyboardKey.mediaTrackNext;
                                    keyPair.logicalKey = null;

                                    setState(() {});
                                    widget.onUpdate();
                                  },
                                ),
                                MenuButton(
                                  onPressed: (c) {
                                    keyPair.physicalKey = PhysicalKeyboardKey.audioVolumeUp;
                                    keyPair.logicalKey = null;

                                    setState(() {});
                                    widget.onUpdate();
                                  },
                                  child: Text(context.i18n.volumeUp),
                                ),
                                MenuButton(
                                  child: Text(context.i18n.volumeDown),
                                  onPressed: (c) {
                                    keyPair.physicalKey = PhysicalKeyboardKey.audioVolumeDown;
                                    keyPair.logicalKey = null;

                                    setState(() {});
                                    widget.onUpdate();
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
                  icon: keyPair.isLongPress ? Icons.check_box : Icons.check_box_outline_blank,
                  title: Text(context.i18n.longPressMode),
                  isActive: keyPair.isLongPress,
                  onPressed: () {
                    keyPair.isLongPress = !keyPair.isLongPress;
                    widget.onUpdate();
                    setState(() {});
                  },
                ),
                SizedBox(height: 8),
                DestructiveButton(
                  onPressed: () {
                    keyPair.isLongPress = false;
                    keyPair.physicalKey = null;
                    keyPair.logicalKey = null;
                    keyPair.modifiers = [];
                    keyPair.touchPosition = Offset.zero;
                    keyPair.inGameAction = null;
                    keyPair.inGameActionValue = null;
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

  String _formatActionDescription(KeyPair keyPairAction) {
    final parts = <String>[];

    if (keyPairAction.inGameAction != null) {
      parts.add(keyPairAction.inGameAction!.toString());
      if (keyPairAction.inGameActionValue != null) {
        parts.add('(${keyPairAction.inGameActionValue})');
      }
    }

    // Use KeyPair's toString() which formats the key with modifiers (e.g., "Ctrl+Alt+R")
    final keyLabel = keyPairAction.toString();
    if (keyLabel != 'Not assigned') {
      parts.add('Key: $keyLabel');
    }

    if (keyPairAction.touchPosition != Offset.zero) {
      parts.add(
        'Touch: ${keyPairAction.touchPosition.dx.toInt()}, ${keyPairAction.touchPosition.dy.toInt()}',
      );
    }

    if (keyPairAction.isLongPress) {
      parts.add('[Long Press]');
    }

    return parts.isNotEmpty ? [parts.first, ' = ', parts.skip(1).join(' • ')].join() : 'Action';
  }
}

class SelectableCard extends StatelessWidget {
  final Widget title;
  final Widget? subtitle;
  final IconData? icon;
  final bool isActive;
  final String? value;
  final VoidCallback? onPressed;

  const SelectableCard({
    super.key,
    required this.title,
    this.icon,
    this.subtitle,
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
      alignment: Alignment.centerLeft,
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
        ),
      ),
    );
  }
}
