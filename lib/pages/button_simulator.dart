import 'dart:math';

import 'package:bike_control/bluetooth/devices/mywhoosh/link.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/obc_ble_emulator.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/obc_mdns_emulator.dart';
import 'package:bike_control/bluetooth/devices/trainer_connection.dart';
import 'package:bike_control/bluetooth/devices/zwift/ftms_mdns_emulator.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_emulator.dart';
import 'package:bike_control/bluetooth/remote_keyboard_pairing.dart';
import 'package:bike_control/bluetooth/remote_pairing.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/pages/touch_area.dart';
import 'package:bike_control/utils/actions/android.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/actions/desktop.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/widgets/apps/mywhoosh_link_tile.dart';
import 'package:bike_control/widgets/apps/openbikecontrol_ble_tile.dart';
import 'package:bike_control/widgets/apps/openbikecontrol_mdns_tile.dart';
import 'package:bike_control/widgets/apps/zwift_mdns_tile.dart';
import 'package:bike_control/widgets/apps/zwift_tile.dart';
import 'package:bike_control/widgets/keyboard_pair_widget.dart';
import 'package:bike_control/widgets/mouse_pair_widget.dart';
import 'package:bike_control/widgets/ui/gradient_text.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:bike_control/widgets/ui/warning.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart' show BackButton;
import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class ButtonSimulator extends StatefulWidget {
  const ButtonSimulator({super.key});

  @override
  State<ButtonSimulator> createState() => _ButtonSimulatorState();
}

class _ButtonSimulatorState extends State<ButtonSimulator> {
  late final FocusNode _focusNode;
  Map<InGameAction, String> _hotkeys = {};

  // Default hotkeys for actions
  static const List<String> _defaultHotkeyOrder = [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    'q',
    'w',
    'e',
    'r',
    't',
    'y',
    'u',
    'i',
    'o',
    'p',
    'a',
    's',
    'd',
    'f',
    'g',
    'h',
    'j',
    'k',
    'l',
    'z',
    'x',
    'c',
    'v',
    'b',
    'n',
    'm',
  ];

  static const Duration _keyPressDuration = Duration(milliseconds: 200);

  InGameAction? _pressedAction;

  DateTime? _lastDown;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'ButtonSimulatorFocus', canRequestFocus: true);
    _loadHotkeys();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHotkeys() async {
    final savedHotkeys = core.settings.getButtonSimulatorHotkeys();

    // If no saved hotkeys, initialize with defaults
    if (savedHotkeys.isEmpty) {
      final connectedTrainers = core.logic.enabledTrainerConnections;
      final allActions = <InGameAction>[];

      for (final connection in connectedTrainers) {
        allActions.addAll(connection.supportedActions);
      }

      // Assign default hotkeys to actions
      final Map<InGameAction, String> defaultHotkeys = {};
      int hotkeyIndex = 0;
      for (final action in allActions.distinct()) {
        if (hotkeyIndex < _defaultHotkeyOrder.length) {
          defaultHotkeys[action] = _defaultHotkeyOrder[hotkeyIndex];
          hotkeyIndex++;
        }
      }

      await core.settings.setButtonSimulatorHotkeys(defaultHotkeys);
      if (mounted) {
        setState(() {
          _hotkeys = defaultHotkeys;
        });
      }
    } else {
      setState(() {
        _hotkeys = savedHotkeys;
      });
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey.keyLabel.toLowerCase();

    // Find the action associated with this key
    final action = _hotkeys.entries.firstOrNullWhere((entry) => entry.value == key)?.key;

    if (action == null) return KeyEventResult.ignored;

    _pressedAction = action;
    setState(() {});

    // Find the connection that supports this action
    final connectedTrainers = core.logic.connectedTrainerConnections;
    final connection = connectedTrainers.firstOrNullWhere((c) => c.supportedActions.contains(action));

    if (connection != null) {
      _sendKey(context, down: true, action: action, connection: connection);
      // Schedule key up event
      Future.delayed(
        _keyPressDuration,
        () {
          if (mounted) {
            _pressedAction = null;
            setState(() {});
            _sendKey(context, down: false, action: action, connection: connection);
          }
        },
      );
      return KeyEventResult.handled;
    } else {
      _pressedAction = null;
      setState(() {});
      buildToast(context, title: 'No connected trainer.');
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final connectedTrainers = core.logic.enabledTrainerConnections;

    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        headers: [
          AppBar(
            leading: [BackButton()],
            title: Text(context.i18n.simulateButtons),
            trailing: [
              PrimaryButton(
                child: Icon(Icons.settings),
                onPressed: () => _showHotkeySettings(context, connectedTrainers),
              ),
            ],
          ),
        ],
        child: Scrollbar(
          controller: _scrollController,
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 16,
              children: [
                if (connectedTrainers.isEmpty)
                  Warning(
                    children: [
                      Text('No suitable connection method activated. Connect a trainer to simulate button presses.'),
                    ],
                  ),
                for (final connectedTrainer in connectedTrainers)
                  if (!screenshotMode)
                    switch (connectedTrainer.title) {
                      WhooshLink.connectionTitle => MyWhooshLinkTile(),
                      ZwiftEmulator.connectionTitle => ZwiftTile(
                        onUpdate: () {
                          if (mounted) setState(() {});
                        },
                      ),
                      FtmsMdnsEmulator.connectionTitle => ZwiftMdnsTile(
                        onUpdate: () {
                          setState(() {});
                        },
                      ),
                      OpenBikeControlMdnsEmulator.connectionTitle => OpenBikeControlMdnsTile(),
                      OpenBikeControlBluetoothEmulator.connectionTitle => OpenBikeControlBluetoothTile(),
                      RemotePairing.connectionTitle => RemoteMousePairingWidget(),
                      RemoteKeyboardPairing.connectionTitle => RemoteKeyboardPairingWidget(),
                      _ => SizedBox.shrink(),
                    },
                ...connectedTrainers.map(
                  (connection) {
                    final supportedActions = connection.supportedActions == InGameAction.values
                        ? core.settings
                              .getTrainerApp()!
                              .keymap
                              .keyPairs
                              .mapNotNull((k) => k.inGameAction)
                              .distinct()
                              .toList()
                        : connection.supportedActions;

                    final actionGroups = {
                      if (supportedActions.contains(InGameAction.shiftUp) &&
                          supportedActions.contains(InGameAction.shiftDown))
                        'Shifting': [InGameAction.shiftDown, InGameAction.shiftUp],
                      'Other': supportedActions
                          .where(
                            (action) =>
                                action != InGameAction.shiftUp &&
                                action != InGameAction.shiftDown &&
                                action != InGameAction.steerLeft &&
                                action != InGameAction.steerRight,
                          )
                          .toList(),
                      if (supportedActions.contains(InGameAction.steerLeft) &&
                          supportedActions.contains(InGameAction.steerRight))
                        'Steering': [InGameAction.steerLeft, InGameAction.steerRight],
                    };

                    return [
                      GradientText(connection.title).bold.large,
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 800),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 12,
                          children: [
                            for (final group in actionGroups.entries) ...[
                              Text(group.key.toUpperCase()).bold.muted,
                              if (group.value.length == 2)
                                Row(
                                  spacing: 8,
                                  children: group.value.map(
                                    (action) {
                                      final hotkey = _hotkeys[action];
                                      return Expanded(
                                        child: Stack(
                                          children: [
                                            SizedBox(
                                              height: 150,
                                              width: double.infinity,
                                              child: _buildButton(action, group, connection, isMobile),
                                            ),
                                            if (hotkey != null)
                                              Positioned(
                                                top: -4,
                                                right: -4,
                                                child: KeyWidget(
                                                  label: hotkey.toUpperCase(),
                                                  invert: true,
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    },
                                  ).toList(),
                                )
                              else
                                GridView.count(
                                  shrinkWrap: true,
                                  physics: NeverScrollableScrollPhysics(),
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                  crossAxisCount: min(group.value.length, 3),
                                  childAspectRatio: isMobile ? 1 : 2.4,
                                  children: group.value.map(
                                    (action) {
                                      final hotkey = _hotkeys[action];
                                      return Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          _buildButton(action, group, connection, isMobile),

                                          if (hotkey != null)
                                            Positioned(
                                              top: -4,
                                              right: -4,
                                              child: KeyWidget(
                                                label: hotkey.toUpperCase(),
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ).toList(),
                                ),
                              SizedBox(height: 12),
                            ],
                          ],
                        ),
                      ),
                    ];
                  },
                ).flatten(),
                // local control doesn't make much sense - it would send the key events to BikeControl itself
                if (false &&
                    core.logic.showLocalControl &&
                    core.settings.getLocalEnabled() &&
                    core.actionHandler.supportedApp != null) ...[
                  GradientText('Local Control'),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: core.actionHandler.supportedApp!.keymap.keyPairs
                        .map(
                          (keyPair) => PrimaryButton(
                            child: Text(keyPair.toString()),
                            onPressed: () async {
                              if (core.actionHandler is AndroidActions) {
                                await (core.actionHandler as AndroidActions).performAction(
                                  keyPair.buttons.first,
                                  isKeyDown: true,
                                  isKeyUp: false,
                                );
                                await (core.actionHandler as AndroidActions).performAction(
                                  keyPair.buttons.first,
                                  isKeyDown: false,
                                  isKeyUp: true,
                                );
                              } else {
                                await (core.actionHandler as DesktopActions).performAction(
                                  keyPair.buttons.first,
                                  isKeyDown: true,
                                  isKeyUp: false,
                                );
                                await (core.actionHandler as DesktopActions).performAction(
                                  keyPair.buttons.first,
                                  isKeyDown: false,
                                  isKeyUp: true,
                                );
                              }
                            },
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton(
    InGameAction action,
    MapEntry<String, List<InGameAction>> group,
    TrainerConnection connection,
    bool isMobile,
  ) {
    return Builder(
      builder: (context) {
        return Button(
          style: _pressedAction == action
              ? ButtonStyle.outline()
              : group.key == 'Other'
              ? ButtonStyle.outline()
              : ButtonStyle.primary(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (action.icon != null) ...[
                Icon(action.icon),
                SizedBox(height: 8),
              ],
              Text(
                action.title,
                textAlign: TextAlign.center,
                style: TextStyle(height: 1),
                maxLines: 2,
              ).bold,
              if (action.alternativeTitle != null)
                Text(
                  action.alternativeTitle!.toUpperCase(),
                  style: TextStyle(fontSize: 10, color: Colors.gray),
                ),
            ],
          ),
          onPressed: () {},
          onTapDown: (c) async {
            _sendKey(context, down: true, action: action, connection: connection);
            /*final device = HidDevice('Simulator');
            final button = ControllerButton('action', action: InGameAction.openActionBar);
            device.getOrAddButton(button.name, () => button);
            device.handleButtonsClickedWithoutLongPressSupport([button]);*/
          },
          onTapUp: (c) async {
            _sendKey(context, down: false, action: action, connection: connection);
          },
        );
      },
    );
  }

  Future<void> _sendKey(
    BuildContext context, {
    required bool down,
    required InGameAction action,
    required TrainerConnection connection,
  }) async {
    if (!connection.isConnected.value) {
      if (down) {
        buildToast(context, title: 'No connected trainer.');
      }

      return;
    }
    if (action.possibleValues != null) {
      if (down) return;
      showDropdown(
        context: context,
        builder: (context) => DropdownMenu(
          children: action.possibleValues!
              .map(
                (e) => MenuButton(
                  child: Text(e.toString()),
                  onPressed: (c) async {
                    await connection.sendAction(
                      KeyPair(
                        buttons: [],
                        physicalKey: null,
                        logicalKey: null,
                        inGameAction: action,
                        inGameActionValue: e,
                      ),
                      isKeyDown: false,
                      isKeyUp: true,
                    );
                  },
                ),
              )
              .toList(),
        ),
      );
      return;
    } else {
      if (!down && _lastDown != null && action.isLongPress) {
        final timeSinceLastDown = DateTime.now().difference(_lastDown!);
        if (timeSinceLastDown < Duration(milliseconds: 400)) {
          // wait a bit so actions actually get applied correctly for some trainer apps
          await Future.delayed(Duration(milliseconds: 800) - timeSinceLastDown);
        }
      } else if (down) {
        _lastDown = DateTime.now();
      }

      final result = await connection.sendAction(
        KeyPair(
          buttons: [],
          physicalKey: null,
          logicalKey: null,
          inGameAction: action,
        ),
        isKeyDown: down,
        isKeyUp: !down,
      );
      await IAPManager.instance.incrementCommandCount();
      if (result is! Success) {
        buildToast(context, title: result.message);
      }
    }
  }

  void _showHotkeySettings(BuildContext context, List<TrainerConnection> connections) {
    showDialog(
      context: context,
      builder: (context) => _HotkeySettingsDialog(
        connections: connections,
        currentHotkeys: _hotkeys,
        onSave: (newHotkeys) {
          setState(() {
            _hotkeys = newHotkeys;
          });
        },
      ),
    );
  }
}

class _HotkeySettingsDialog extends StatefulWidget {
  final List<TrainerConnection> connections;
  final Map<InGameAction, String> currentHotkeys;
  final Function(Map<InGameAction, String>) onSave;

  const _HotkeySettingsDialog({
    required this.connections,
    required this.currentHotkeys,
    required this.onSave,
  });

  @override
  State<_HotkeySettingsDialog> createState() => _HotkeySettingsDialogState();
}

class _HotkeySettingsDialogState extends State<_HotkeySettingsDialog> {
  late Map<InGameAction, String> _editableHotkeys;
  InGameAction? _editingAction;
  late FocusNode _focusNode;

  static final _validHotkeyPattern = RegExp(r'[0-9a-z]');

  @override
  void initState() {
    super.initState();
    _editableHotkeys = Map.from(widget.currentHotkeys);
    _focusNode = FocusNode(debugLabel: 'HotkeySettingsFocus', canRequestFocus: true);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (_editingAction == null || event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey.keyLabel.toLowerCase();

    // Only allow single character 1-9 and a-z
    if (key.length == 1 && _validHotkeyPattern.hasMatch(key)) {
      setState(() {
        _editableHotkeys[_editingAction!] = key;
        _editingAction = null;
      });
      return KeyEventResult.handled;
    }

    // Escape to cancel
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      setState(() {
        _editingAction = null;
      });
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final allActions = <InGameAction>[];
    for (final connection in widget.connections) {
      allActions.addAll(connection.supportedActions);
    }
    final uniqueActions = allActions.distinct().toList();

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: AlertDialog(
        title: Text('Configure Keyboard Hotkeys'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Text('Assign keyboard shortcuts to simulator buttons').muted,
              SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    spacing: 8,
                    children: uniqueActions.map((action) {
                      final hotkey = _editableHotkeys[action];
                      final isEditing = _editingAction == action;

                      return Card(
                        child: Container(
                          padding: EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(action.title),
                              ),
                              if (isEditing)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.blue),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('Press a key...', style: TextStyle(color: Colors.blue)),
                                )
                              else if (hotkey != null)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.gray.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(hotkey.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold)),
                                )
                              else
                                Text('No hotkey', style: TextStyle(color: Colors.gray)),
                              SizedBox(width: 8),
                              OutlineButton(
                                size: ButtonSize.small,
                                child: Text(isEditing ? 'Cancel' : 'Set'),
                                onPressed: () {
                                  setState(() {
                                    _editingAction = isEditing ? null : action;
                                  });
                                },
                              ),
                              if (hotkey != null && !isEditing) ...[
                                SizedBox(width: 4),
                                OutlineButton(
                                  size: ButtonSize.small,
                                  child: Text('Clear'),
                                  onPressed: () {
                                    setState(() {
                                      _editableHotkeys.remove(action);
                                    });
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          SecondaryButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          PrimaryButton(
            child: Text('Save'),
            onPressed: () async {
              await core.settings.setButtonSimulatorHotkeys(_editableHotkeys);
              widget.onSave(_editableHotkeys);
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
    );
  }
}
