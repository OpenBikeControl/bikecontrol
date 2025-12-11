import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart' show BackButton;
import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/bluetooth/devices/trainer_connection.dart';
import 'package:swift_control/utils/actions/android.dart';
import 'package:swift_control/utils/actions/desktop.dart';
import 'package:swift_control/utils/core.dart';
import 'package:swift_control/utils/i18n_extension.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:swift_control/utils/keymap/keymap.dart';
import 'package:swift_control/widgets/ui/gradient_text.dart';
import 'package:swift_control/widgets/ui/warning.dart';

class ButtonSimulator extends StatefulWidget {
  const ButtonSimulator({super.key});

  @override
  State<ButtonSimulator> createState() => _ButtonSimulatorState();
}

class _ButtonSimulatorState extends State<ButtonSimulator> {
  late final FocusNode _focusNode;
  Map<String, String> _hotkeys = {};
  
  // Default hotkeys for actions
  static const List<String> _defaultHotkeyOrder = [
    '1', '2', '3', '4', '5', '6', '7', '8', '9',
    'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p',
    'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l',
    'z', 'x', 'c', 'v', 'b', 'n', 'm',
  ];

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'ButtonSimulatorFocus', canRequestFocus: true);
    _loadHotkeys();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _loadHotkeys() {
    final savedHotkeys = core.settings.getButtonSimulatorHotkeys();
    
    // If no saved hotkeys, initialize with defaults
    if (savedHotkeys.isEmpty) {
      final connectedTrainers = core.logic.connectedTrainerConnections;
      final allActions = <InGameAction>[];
      
      for (final connection in connectedTrainers) {
        allActions.addAll(connection.supportedActions);
      }
      
      // Assign default hotkeys to actions
      final Map<String, String> defaultHotkeys = {};
      int hotkeyIndex = 0;
      for (final action in allActions.distinct()) {
        if (hotkeyIndex < _defaultHotkeyOrder.length) {
          defaultHotkeys[action.name] = _defaultHotkeyOrder[hotkeyIndex];
          hotkeyIndex++;
        }
      }
      
      core.settings.setButtonSimulatorHotkeys(defaultHotkeys);
      setState(() {
        _hotkeys = defaultHotkeys;
      });
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
    final actionName = _hotkeys.entries
        .firstOrNullWhere((entry) => entry.value == key)
        ?.key;
    
    if (actionName == null) return KeyEventResult.ignored;
    
    final action = InGameAction.values.firstOrNullWhere((a) => a.name == actionName);
    if (action == null) return KeyEventResult.ignored;
    
    // Find the connection that supports this action
    final connectedTrainers = core.logic.connectedTrainerConnections;
    final connection = connectedTrainers.firstOrNullWhere(
      (c) => c.supportedActions.contains(action)
    );
    
    if (connection != null) {
      _sendKey(context, down: true, action: action, connection: connection);
      // Schedule key up event
      Future.delayed(
        Duration(milliseconds: 100),
        () {
          _sendKey(context, down: false, action: action, connection: connection);
        },
      );
      return KeyEventResult.handled;
    }
    
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final connectedTrainers = core.logic.connectedTrainerConnections;

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
              IconButton(
                icon: Icon(Icons.settings),
                onPressed: () => _showHotkeySettings(context, connectedTrainers),
              ),
            ],
          ),
        ],
        child: Scrollbar(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 16,
              children: [
                if (connectedTrainers.isEmpty)
                  Warning(
                    children: [
                      Text('No connected trainers found. Connect a trainer to simulate button presses.'),
                    ],
                  ),
                ...connectedTrainers.map(
                  (connection) {
                    final supportedActions = connection.supportedActions;

                    final actionGroups = {
                      if (supportedActions.contains(InGameAction.shiftUp) &&
                          supportedActions.contains(InGameAction.shiftDown))
                        'Shifting': [InGameAction.shiftUp, InGameAction.shiftDown],
                      'Other': supportedActions
                          .where((action) => action != InGameAction.shiftUp && action != InGameAction.shiftDown)
                          .toList(),
                    };

                    return [
                      GradientText(connection.title).bold.large,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 12,
                        children: [
                          for (final group in actionGroups.entries) ...[
                            Text(group.key).bold,
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: group.value
                                  .map(
                                    (action) {
                                      final hotkey = _hotkeys[action.name];
                                      return PrimaryButton(
                                        size: ButtonSize(1.6),
                                        leading: hotkey != null
                                            ? Container(
                                                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.withOpacity(0.3),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  hotkey.toUpperCase(),
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              )
                                            : null,
                                        child: Text(action.title),
                                        onTapDown: (c) async {
                                          _sendKey(context, down: true, action: action, connection: connection);
                                        },
                                        onTapUp: (c) async {
                                          _sendKey(context, down: false, action: action, connection: connection);
                                        },
                                      );
                                    },
                                  )
                                  .toList(),
                            ),
                            SizedBox(height: 12),
                          ],
                        ],
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

  Future<void> _sendKey(
    BuildContext context, {
    required bool down,
    required InGameAction action,
    required TrainerConnection connection,
  }) async {
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
      await connection.sendAction(
        KeyPair(
          buttons: [],
          physicalKey: null,
          logicalKey: null,
          inGameAction: action,
        ),
        isKeyDown: down,
        isKeyUp: !down,
      );
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
  final Map<String, String> currentHotkeys;
  final Function(Map<String, String>) onSave;

  const _HotkeySettingsDialog({
    required this.connections,
    required this.currentHotkeys,
    required this.onSave,
  });

  @override
  State<_HotkeySettingsDialog> createState() => _HotkeySettingsDialogState();
}

class _HotkeySettingsDialogState extends State<_HotkeySettingsDialog> {
  late Map<String, String> _editableHotkeys;
  String? _editingAction;
  late FocusNode _focusNode;

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
    
    // Only allow 1-9 and a-z
    if (key.length == 1 && (RegExp(r'[0-9a-z]').hasMatch(key))) {
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
      child: Dialog(
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
                      final hotkey = _editableHotkeys[action.name];
                      final isEditing = _editingAction == action.name;
                      
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
                                    color: Colors.grey.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(hotkey.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold)),
                                )
                              else
                                Text('No hotkey', style: TextStyle(color: Colors.grey)),
                              SizedBox(width: 8),
                              OutlineButton(
                                size: ButtonSize.small,
                                child: Text(isEditing ? 'Cancel' : 'Set'),
                                onPressed: () {
                                  setState(() {
                                    _editingAction = isEditing ? null : action.name;
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
                                      _editableHotkeys.remove(action.name);
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
            onPressed: () {
              core.settings.setButtonSimulatorHotkeys(_editableHotkeys);
              widget.onSave(_editableHotkeys);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
