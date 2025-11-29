import 'dart:async';

import 'package:dartx/dartx.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_emulator.dart';
import 'package:swift_control/pages/device.dart';
import 'package:swift_control/utils/actions/base_actions.dart';
import 'package:swift_control/utils/core.dart';
import 'package:swift_control/utils/keymap/apps/custom_app.dart';
import 'package:swift_control/utils/keymap/keymap.dart';
import 'package:swift_control/utils/keymap/manager.dart';
import 'package:swift_control/widgets/custom_keymap_selector.dart';
import 'package:swift_control/widgets/ui/button_widget.dart';
import 'package:swift_control/widgets/ui/toast.dart';

import '../bluetooth/devices/link/link.dart';
import '../pages/touch_area.dart';

class KeymapExplanation extends StatefulWidget {
  final Keymap keymap;
  final VoidCallback onUpdate;
  const KeymapExplanation({super.key, required this.keymap, required this.onUpdate});

  @override
  State<KeymapExplanation> createState() => _KeymapExplanationState();
}

class _KeymapExplanationState extends State<KeymapExplanation> {
  late StreamSubscription<void> _updateStreamListener;

  @override
  void initState() {
    super.initState();
    _updateStreamListener = widget.keymap.updateStream.listen((_) {
      setState(() {});
    });
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
  void dispose() {
    super.dispose();
    _updateStreamListener.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final availableKeypairs = widget.keymap.keyPairs;
    final allAvailableButtons = IterableFlatMap(core.connection.devices).flatMap((d) => d.availableButtons);

    return Card(
      child: ValueListenableBuilder(
        valueListenable: core.whooshLink.isConnected,
        builder: (c, _, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            Table(
              columnWidths: {0: FlexTableSize(flex: 2), 1: FlexTableSize(flex: 3)},
              rows: [
                TableHeader(
                  cells: [
                    TableCell(
                      child: Text(
                        '${core.connection.devices.isEmpty ? 'Device' : core.connection.devices.joinToString(transform: (d) => d.name.screenshot)} button',
                      ).small,
                    ),
                    TableCell(
                      child: Text('Action').small,
                    ),
                  ],
                ),
                for (final keyPair in availableKeypairs) ...[
                  TableRow(
                    cells: [
                      TableCell(
                        child: Container(
                          constraints: BoxConstraints(minHeight: 52),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            runAlignment: WrapAlignment.center,
                            children: [
                              if (core.actionHandler.supportedApp is! CustomApp)
                                if (keyPair.buttons.filter((b) => allAvailableButtons.contains(b)).isEmpty)
                                  Text('No button assigned for your connected device')
                                else
                                  for (final button in keyPair.buttons.filter((b) => allAvailableButtons.contains(b)))
                                    IntrinsicWidth(child: ButtonWidget(button: button))
                              else
                                for (final button in keyPair.buttons)
                                  IntrinsicWidth(child: ButtonWidget(button: button)),
                            ],
                          ),
                        ),
                      ),
                      TableCell(
                        child: _ButtonEditor(keyPair: keyPair, onUpdate: widget.onUpdate),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ButtonEditor extends StatelessWidget {
  final KeyPair keyPair;
  final VoidCallback onUpdate;
  const _ButtonEditor({required this.onUpdate, super.key, required this.keyPair});

  @override
  Widget build(BuildContext context) {
    final trainerApp = core.settings.getTrainerApp();

    final actionsWithInGameAction = trainerApp?.keymap.keyPairs.where((kp) => kp.inGameAction != null).toList();

    final actions = <MenuItem>[
      if (core.settings.getMyWhooshLinkEnabled() && core.whooshLink.isCompatible(core.settings.getLastTarget()!))
        MenuButton(
          subMenu: WhooshLink.supportedActions.map(
            (ingame) {
              return MenuButton(
                subMenu: ingame.possibleValues
                    ?.map(
                      (value) => MenuButton(
                        child: Text(value.toString()),
                        onPressed: (_) {
                          keyPair.inGameAction = ingame;
                          keyPair.inGameActionValue = value;
                          onUpdate();
                        },
                      ),
                    )
                    .toList(),
                child: Text(ingame.toString()),
                onPressed: (_) {
                  keyPair.inGameAction = ingame;
                  keyPair.inGameActionValue = null;
                  onUpdate();
                },
              );
            },
          ).toList(),
          child: _Item(
            icon: Icons.link,
            title: 'MyWhoosh Direct Connect Action',
            isActive: keyPair.inGameAction != null,
          ),
        ),
      if (core.settings.getZwiftEmulatorEnabled() && core.settings.getTrainerApp()?.supportsZwiftEmulation == true)
        MenuButton(
          subMenu: ZwiftEmulator.supportedActions.map(
            (ingame) {
              return MenuButton(
                subMenu: ingame.possibleValues
                    ?.map(
                      (value) => MenuButton(
                        child: Text(value.toString()),
                        onPressed: (_) {
                          keyPair.inGameAction = ingame;
                          keyPair.inGameActionValue = value;
                          onUpdate();
                        },
                      ),
                    )
                    .toList(),
                child: Text(ingame.toString()),
                onPressed: (_) {
                  keyPair.inGameAction = ingame;
                  keyPair.inGameActionValue = null;
                  onUpdate();
                },
              );
            },
          ).toList(),
          child: _Item(
            icon: Icons.link,
            title: 'Zwift Controller Action',
            isActive: keyPair.inGameAction != null,
          ),
        ),
      if (trainerApp != null && trainerApp is! CustomApp)
        MenuButton(
          subMenu: (actionsWithInGameAction?.isEmpty == true)
              ? <MenuItem>[
                  MenuButton(
                    enabled: false,
                    child: Text('No predefined actions available'),
                  ),
                ]
              : actionsWithInGameAction?.map((keyPairAction) {
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
                      keyPair.physicalKey = keyPairAction.physicalKey;
                      keyPair.logicalKey = keyPairAction.logicalKey;
                      keyPair.modifiers = List.of(keyPairAction.modifiers);
                      keyPair.touchPosition = keyPairAction.touchPosition;
                      keyPair.isLongPress = keyPairAction.isLongPress;
                      keyPair.inGameAction = keyPairAction.inGameAction;
                      keyPair.inGameActionValue = keyPairAction.inGameActionValue;
                      onUpdate();
                    },
                  );
                }).toList(),
          child: _Item(
            icon: Icons.file_copy_outlined,
            title: '${trainerApp.name} action',
            isActive: false,
          ),
        ),
      if (core.actionHandler.supportedModes.contains(SupportedMode.keyboard))
        MenuButton(
          child: _Item(
            icon: Icons.keyboard_alt_outlined,
            title: 'Simulate Keyboard shortcut',
            isActive: keyPair.physicalKey != null,
          ),
          onPressed: (context) async {
            await showDialog<void>(
              context: context,
              barrierDismissible: false, // enable Escape key
              builder: (c) =>
                  HotKeyListenerDialog(customApp: core.actionHandler.supportedApp! as CustomApp, keyPair: keyPair),
            );
            onUpdate();
          },
        ),
      if (core.actionHandler.supportedModes.contains(SupportedMode.touch))
        MenuButton(
          child: _Item(
            title: 'Simulate Touch',
            icon: Icons.touch_app_outlined,
            isActive: keyPair.physicalKey == null && keyPair.touchPosition != Offset.zero,
          ),
          onPressed: (context) async {
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
            onUpdate();
          },
        ),

      if (core.actionHandler.supportedModes.contains(SupportedMode.media))
        MenuButton(
          subMenu: [
            MenuButton(
              child: const Text('Play/Pause'),
              onPressed: (c) {
                keyPair.physicalKey = PhysicalKeyboardKey.mediaPlayPause;
                keyPair.logicalKey = null;

                onUpdate();
              },
            ),
            MenuButton(
              child: const Text('Stop'),
              onPressed: (c) {
                keyPair.physicalKey = PhysicalKeyboardKey.mediaStop;
                keyPair.logicalKey = null;

                onUpdate();
              },
            ),
            MenuButton(
              child: const Text('Previous'),

              onPressed: (c) {
                keyPair.physicalKey = PhysicalKeyboardKey.mediaTrackPrevious;
                keyPair.logicalKey = null;

                onUpdate();
              },
            ),
            MenuButton(
              child: const Text('Next'),
              onPressed: (c) {
                keyPair.physicalKey = PhysicalKeyboardKey.mediaTrackNext;
                keyPair.logicalKey = null;

                onUpdate();
              },
            ),
            MenuButton(
              onPressed: (c) {
                keyPair.physicalKey = PhysicalKeyboardKey.audioVolumeUp;
                keyPair.logicalKey = null;

                onUpdate();
              },
              child: const Text('Volume Up'),
            ),
            MenuButton(
              child: const Text('Volume Down'),
              onPressed: (c) {
                keyPair.physicalKey = PhysicalKeyboardKey.audioVolumeDown;
                keyPair.logicalKey = null;

                onUpdate();
              },
            ),
          ],

          child: _Item(
            icon: Icons.music_note_outlined,
            isActive: keyPair.isSpecialKey,
            title: 'Simulate Media key',
          ),
        ),

      MenuDivider(),
      MenuButton(
        onPressed: (_) {
          keyPair.isLongPress = !keyPair.isLongPress;
          onUpdate();
        },
        child: _Item(
          icon: keyPair.isLongPress ? Icons.check_box : Icons.check_box_outline_blank,
          title: 'Long Press Mode (vs. repeating)',
          isActive: keyPair.isLongPress,
        ),
      ),
      MenuButton(
        onPressed: (_) {
          keyPair.isLongPress = false;
          keyPair.physicalKey = null;
          keyPair.logicalKey = null;
          keyPair.modifiers = [];
          keyPair.touchPosition = Offset.zero;
          keyPair.inGameAction = null;
          keyPair.inGameActionValue = null;
          onUpdate();
        },
        child: _Item(
          icon: Icons.delete_outline,
          title: 'Unassign action',
          isActive: false,
        ),
      ),
    ];

    return TextButton(
      onPressed: () async {
        if (core.actionHandler.supportedApp is! CustomApp) {
          final currentProfile = core.actionHandler.supportedApp!.name;
          final newName = await KeymapManager().duplicate(
            context,
            currentProfile,
            skipName: '$currentProfile (Copy)',
          );
          if (newName != null) {
            showToast(
              context: context,
              builder: (c, overlay) => buildToast(context, overlay, title: 'Created a new custom profile: $newName'),
            );
          }
          onUpdate();
        } else {
          showDropdown(
            context: context,

            builder: (c) => DropdownMenu(children: actions),
          );
        }
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        spacing: 6,
        children: [
          if (keyPair.buttons.isNotEmpty &&
              (keyPair.physicalKey != null || keyPair.touchPosition != Offset.zero || keyPair.inGameAction != null))
            Expanded(
              child: KeypairExplanation(
                keyPair: keyPair,
              ),
            )
          else
            Expanded(
              child: Text(
                'No action assigned',
              ).muted.xSmall,
            ),
          Icon(Icons.edit, size: 14),
        ],
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

extension SplitByUppercase on String {
  String splitByUpperCase() {
    return replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (match) => '${match.group(1)} ${match.group(2)}').capitalize();
  }
}

class _Item extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isActive;
  const _Item({super.key, required this.title, required this.icon, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: Basic(
        leading: Stack(
          children: [
            Icon(
              icon,
              color: icon == Icons.delete_outline ? Theme.of(context).colorScheme.destructive : null,
            ),
            if (isActive)
              Positioned(
                right: 0,
                bottom: 0,
                child: Icon(
                  Icons.check_circle,
                  size: 12,
                  color: Colors.green,
                ),
              ),
          ],
        ),
        title: Text(
          title,
          style: TextStyle(
            color: icon == Icons.delete_outline ? Theme.of(context).colorScheme.destructive : null,
          ),
        ),
      ),
    );
  }
}
