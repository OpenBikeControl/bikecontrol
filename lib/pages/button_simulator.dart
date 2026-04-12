import 'dart:math';

import 'package:bike_control/bluetooth/devices/trainer_connection.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/pages/touch_area.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/widgets/ui/gradient_text.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:bike_control/widgets/ui/warning.dart';
import 'package:dartx/dartx.dart';
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
  Map<InGameAction, List<int>> _recentValues = {};

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
  InGameAction? _editingHotkeyAction;

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
    _loadRecentValues();
    final savedHotkeys = core.settings.getButtonSimulatorHotkeys();

    // If no saved hotkeys, initialize with defaults
    if (savedHotkeys.isEmpty) {
      final connectedTrainers = core.logic.enabledTrainerConnections;
      final mapping = core.settings.getTrainerApp()?.inGameActionsMapping ?? const {};
      final allActions = <InGameAction>[];

      for (final connection in connectedTrainers) {
        allActions.addAll(connection.supportedActions.map((a) => mapping[a] ?? a));
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

  void _loadRecentValues() {
    final map = <InGameAction, List<int>>{};
    for (final action in InGameAction.values) {
      if (action.possibleValues != null) {
        map[action] = action.possibleValues!.take(2).toList();
      }
    }
    setState(() {
      _recentValues = map;
    });
  }

  Future<void> _sendQuickValue(InGameAction action, int value, TrainerConnection connection) async {
    if (!connection.isConnected.value) {
      buildToast(title: 'No connected trainer.');
      return;
    }
    await connection.sendAction(
      KeyPair(
        buttons: [],
        physicalKey: null,
        logicalKey: null,
        inGameAction: action,
        inGameActionValue: value,
      ),
      isKeyDown: true,
      isKeyUp: true,
    );
    _updateRecentValue(action, value);
  }

  void _updateRecentValue(InGameAction action, int value) {
    final list = List<int>.from(_recentValues[action] ?? []);
    list.remove(value);
    list.insert(0, value);
    setState(() {
      _recentValues[action] = list.take(2).toList();
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey.keyLabel.toLowerCase();

    // Handle inline hotkey editing
    if (_editingHotkeyAction != null) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        setState(() => _editingHotkeyAction = null);
        return KeyEventResult.handled;
      }
      if (key.length == 1) {
        setState(() {
          _hotkeys[_editingHotkeyAction!] = key;
          _editingHotkeyAction = null;
        });
        core.settings.setButtonSimulatorHotkeys(_hotkeys);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // Find the action associated with this key
    final action = _hotkeys.entries.firstOrNullWhere((entry) => entry.value == key)?.key;

    if (action == null) return KeyEventResult.ignored;

    _pressedAction = action;
    setState(() {});

    // Find the connection that supports this action (check both original and mapped actions)
    final connectedTrainers = core.logic.connectedTrainerConnections;
    final mapping = core.settings.getTrainerApp()?.inGameActionsMapping ?? const {};
    final connection = connectedTrainers.firstOrNullWhere(
      (c) => c.supportedActions.map((a) => mapping[a] ?? a).contains(action),
    );

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
      buildToast(title: context.i18n.notConnected);
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final connectedTrainers = core.logic.enabledNonLocalTrainerConnections;

    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        headers: [
          AppBar(
            leading: [
              IconButton.ghost(
                icon: Icon(LucideIcons.arrowLeft, size: 24),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
            title: Text(context.i18n.simulateButtons),
            trailing: [
              IconButton.ghost(
                icon: Icon(LucideIcons.x, size: 22, color: Theme.of(context).colorScheme.mutedForeground),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
            backgroundColor: Theme.of(context).colorScheme.background,
          ),
        ],
        child: Scrollbar(
          controller: _scrollController,
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 16,
                  children: [
                    if (connectedTrainers.isEmpty)
                      Warning(
                        children: [
                          Text(
                            'No suitable connection method activated. Connect a trainer to simulate button presses.',
                          ),
                        ],
                      ),
                    for (final connectedTrainer in connectedTrainers)
                      if (!screenshotMode) connectedTrainer.getTile(),
                    ...connectedTrainers.map(
                      (connection) {
                        final mapping = core.settings.getTrainerApp()?.inGameActionsMapping ?? const {};
                        final supportedActions =
                            (connection.supportedActions == InGameAction.values
                                    ? core.settings
                                          .getTrainerApp()!
                                          .keymap
                                          .keyPairs
                                          .mapNotNull((k) => k.inGameAction)
                                          .distinct()
                                          .toList()
                                    : connection.supportedActions)
                                .map((a) => mapping[a] ?? a)
                                .toList();

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
                          for (final group in actionGroups.entries) _buildGroupCard(group, connection, isMobile),
                        ];
                      },
                    ).flatten(),
                    _buildHotkeySection(connectedTrainers),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupCard(
    MapEntry<String, List<InGameAction>> group,
    TrainerConnection connection,
    bool isMobile,
  ) {
    return Card(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
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
                          height: isMobile ? 120 : 80,
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
            _buildActionGrid(group, connection, isMobile),
        ],
      ),
    );
  }

  Widget _buildHotkeySection(List<TrainerConnection> connections) {
    final mapping = core.settings.getTrainerApp()?.inGameActionsMapping ?? const {};
    final allActions = <InGameAction>[];
    for (final connection in connections) {
      final actions = connection.supportedActions == InGameAction.values
          ? core.settings.getTrainerApp()!.keymap.keyPairs.mapNotNull((k) => k.inGameAction).toList()
          : connection.supportedActions;
      allActions.addAll(actions.map((a) => mapping[a] ?? a));
    }
    final uniqueActions = allActions.distinct().toList();
    if (uniqueActions.isEmpty) return const SizedBox.shrink();

    return Card(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Text('KEYBOARD SHORTCUTS').bold.muted,
          Text('Assign keyboard shortcuts to simulator buttons').small.muted,
          for (final action in uniqueActions) _buildHotkeyRow(action),
        ],
      ),
    );
  }

  Widget _buildHotkeyRow(InGameAction action) {
    final hotkey = _hotkeys[action];
    final isEditing = _editingHotkeyAction == action;

    return Row(
      children: [
        Expanded(child: Text(action.title).small),
        if (isEditing)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('Press a key...', style: TextStyle(color: Colors.blue)).small,
          )
        else if (hotkey != null)
          KeyWidget(label: hotkey.toUpperCase())
        else
          Text('—').small.muted,
        Gap(8),
        Button.ghost(
          onPressed: () {
            setState(() {
              _editingHotkeyAction = isEditing ? null : action;
            });
          },
          child: Text(isEditing ? 'Cancel' : 'Set').xSmall,
        ),
        if (hotkey != null && !isEditing) ...[
          Gap(4),
          Button.ghost(
            onPressed: () {
              setState(() {
                _hotkeys.remove(action);
              });
              core.settings.setButtonSimulatorHotkeys(_hotkeys);
            },
            child: Text('Clear').xSmall,
          ),
        ],
      ],
    );
  }

  Widget _buildActionGrid(
    MapEntry<String, List<InGameAction>> group,
    TrainerConnection connection,
    bool isMobile,
  ) {
    final hasQuickAccess = group.value.any((a) => a.possibleValues != null);

    final crossAxisCount = min(group.value.length, 3);
    final buttonHeight = isMobile ? 120.0 : 80.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: group.value.map((action) {
            final hotkey = _hotkeys[action];
            return SizedBox(
              width: crossAxisCount == 1
                  ? availableWidth
                  : (availableWidth - 8 * (crossAxisCount - 1)) / crossAxisCount,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    children: [
                      SizedBox(
                        height: buttonHeight,
                        width: double.infinity,
                        child: _buildButton(action, group, connection, isMobile),
                      ),
                      if (hotkey != null)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: KeyWidget(label: hotkey.toUpperCase()),
                        ),
                    ],
                  ),
                  if (action.possibleValues != null) _buildQuickAccessButtons(action, connection),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildQuickAccessButtons(InGameAction action, TrainerConnection connection) {
    final recent = _recentValues[action] ?? action.possibleValues!.take(2).toList();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        spacing: 4,
        children: [
          for (int i = 0; i < 2; i++)
            Expanded(
              child: SizedBox(
                height: 42,
                child: i < recent.length
                    ? OutlineButton(
                        size: ButtonSize.small,
                        density: ButtonDensity.compact,
                        onPressed: () => _sendQuickValue(action, recent[i], connection),
                        child: Center(child: Text(recent[i].toString())),
                      )
                    : SizedBox.shrink(),
              ),
            ),
        ],
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
        buildToast(title: 'No connected trainer.');
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
                      isKeyDown: true,
                      isKeyUp: true,
                    );
                    _updateRecentValue(action, e);
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
      if (result is! Success && result is! Ignored) {
        buildToast(title: result.message);
      }
    }
  }
}
