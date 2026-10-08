import 'package:bike_control/utils/window_size.dart';
import 'package:bike_control/widgets/ui/connection_method.dart' show ConnectionMethodWithoutSwitch;
import 'package:bike_control/widgets/ui/bk_page_header.dart';
import 'package:bike_control/widgets/ui/bk_word_safe_text.dart';

import 'package:bike_control/bluetooth/devices/trainer_connection.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:bike_control/widgets/ui/bk_status_dot.dart';
import 'package:bike_control/widgets/ui/bk_tappable.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:bike_control/widgets/ui/bk_page_column.dart';

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
      buildToast(title: context.i18n.notConnected);
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
    final connectedTrainers = core.logic.connectedNonLocalTrainerConnections;
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

  /// The actions [connection] can send, under the trainer app's own names.
  List<InGameAction> _actionsOf(TrainerConnection connection) {
    final mapping = core.settings.getTrainerApp()?.inGameActionsMapping ?? const {};
    return (connection.supportedActions == InGameAction.values
            ? core.settings.getTrainerApp()!.keymap.keyPairs.mapNotNull((k) => k.inGameAction).distinct().toList()
            : connection.supportedActions)
        .map((a) => mapping[a] ?? a)
        .distinct()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final connectedTrainers = core.logic.enabledNonLocalTrainerConnections;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        headers: [
          BkPageHeader(title: context.i18n.simulateButtons, showDivider: false),
        ],
        child: Scrollbar(
          controller: _scrollController,
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: BkPageColumn(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (connectedTrainers.isEmpty)
                    BkGroupedSection(
                      children: [
                        BkGroupedRow(
                          icon: LucideIcons.unplug,
                          quietIcon: true,
                          title: context.i18n.trainerControlsNoConnection,
                        ),
                      ],
                    ),
                  for (final connection in connectedTrainers) ...[
                    _buildConnection(connection),
                    const Gap(24),
                  ],
                  _buildHotkeySection(connectedTrainers),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// One connection's remote: its name and state, then shifting (the biggest
  /// targets, − left and + right as on Ride) with steering under it, the
  /// actions that take a value as rows with their recent values, and the
  /// rest as an even grid.
  Widget _buildConnection(TrainerConnection connection) {
    final actions = _actionsOf(connection);
    final hasShift = actions.contains(InGameAction.shiftUp) && actions.contains(InGameAction.shiftDown);
    final hasSteer = actions.contains(InGameAction.steerLeft) && actions.contains(InGameAction.steerRight);
    final rest = actions.where(
      (a) =>
          !(hasShift && (a == InGameAction.shiftUp || a == InGameAction.shiftDown)) &&
          !(hasSteer && (a == InGameAction.steerLeft || a == InGameAction.steerRight)),
    );
    final valued = rest.where((a) => a.possibleValues != null).toList();
    final plain = rest.where((a) => a.possibleValues == null).toList();
    final cs = Theme.of(context).colorScheme;

    return ValueListenableBuilder<bool>(
      valueListenable: connection.isConnected,
      builder: (context, connected, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(BkGroupedSection.inset, 0, BkGroupedSection.inset, 8),
              child: Row(
                spacing: 12,
                children: [
                  Expanded(child: BkGroupedHeader(connection.title)),
                  BkStatusDot(
                    label: connected ? context.i18n.connected : context.i18n.notConnected,
                    tone: connected ? BkStatusTone.success : BkStatusTone.neutral,
                  ),
                ],
              ),
            ),
            // Not connected yet: the method's own card, with its instructions
            // and network check, so the rider can fix it right here. No
            // switch: this page is for using the method, not turning it off.
            if (!connected && !screenshotMode) ...[
              ConnectionMethodWithoutSwitch(child: connection.getTile()),
              const Gap(16),
            ],
            if (hasShift || hasSteer)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.card,
                  borderRadius: BorderRadius.circular(BkComponentThemes.cardRadius),
                  boxShadow: bkCardShadow(context),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 12,
                    children: [
                      if (hasShift)
                        _padRow(
                          [
                            (InGameAction.shiftDown, _PadTone.fill, LucideIcons.minus),
                            (InGameAction.shiftUp, _PadTone.primary, LucideIcons.plus),
                          ],
                          _PadSize.hero,
                          connection,
                        ),
                      if (hasSteer)
                        _padRow(
                          [
                            (InGameAction.steerLeft, _PadTone.fill, null),
                            (InGameAction.steerRight, _PadTone.fill, null),
                          ],
                          _PadSize.medium,
                          connection,
                        ),
                    ],
                  ),
                ),
              ),
            if (valued.isNotEmpty || plain.isNotEmpty) ...[
              const Gap(24),
              if (hasShift || hasSteer)
                Padding(
                  padding: const EdgeInsets.fromLTRB(BkGroupedSection.inset, 0, BkGroupedSection.inset, 6),
                  child: BkGroupedHeader(AppLocalizations.of(context).actionCategoryOther),
                ),
              if (valued.isNotEmpty)
                BkGroupedSection(
                  dividerIndent: BkGroupedSection.inset + BkIconTile.size + BkGroupedRow.gap,
                  children: [for (final action in valued) _buildValueRow(action, connection)],
                ),
              if (valued.isNotEmpty && plain.isNotEmpty) const Gap(12),
              if (plain.isNotEmpty) _buildGrid(plain, connection),
            ],
          ],
        );
      },
    );
  }

  Widget _padRow(
    List<(InGameAction, _PadTone, IconData?)> pads,
    _PadSize size,
    TrainerConnection connection,
  ) {
    final scaling = Theme.of(context).scaling;
    final compact = isCompactWindow(context);
    final height =
        switch (size) {
          _PadSize.hero => compact ? 124.0 : 104.0,
          _PadSize.medium => compact ? 64.0 : 56.0,
          _PadSize.tile => 84.0,
        } *
        scaling;
    return Row(
      spacing: 12,
      children: [
        for (final (action, tone, icon) in pads)
          Expanded(
            child: SizedBox(
              height: height,
              child: _buildPad(action, tone, size, connection, icon: icon),
            ),
          ),
      ],
    );
  }

  /// The other actions: an even grid of card tiles, as many to a row as fit.
  Widget _buildGrid(List<InGameAction> actions, TrainerConnection connection) {
    final scaling = Theme.of(context).scaling;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const gap = 12.0;
        final columns = width >= 560 * scaling
            ? 4
            : width >= 300 * scaling
            ? 3
            : 2;
        final tileWidth = (width - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final action in actions)
              SizedBox(
                width: tileWidth,
                height: 84 * scaling,
                child: _buildPad(action, _PadTone.card, _PadSize.tile, connection),
              ),
          ],
        );
      },
    );
  }

  /// An action that takes a value (camera angle, emote): its name opens the
  /// full list, and the two values used last sit beside it, one tap each.
  Widget _buildValueRow(InGameAction action, TrainerConnection connection) {
    final cs = Theme.of(context).colorScheme;
    final scaling = Theme.of(context).scaling;
    final recent = _recentValues[action] ?? action.possibleValues!.take(2).toList();
    final hotkey = _hotkeys[action];
    final showKeycap = hotkey != null && !isCompactWindow(context);
    return Row(
      key: ValueKey('quick-values-${action.name}'),
      children: [
        Expanded(
          child: Builder(
            builder: (context) => BkTappable(
              wash: true,
              onPressed: () => _openValueMenu(context, action, connection),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: 60 * scaling),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(BkGroupedSection.inset, 8, 8, 8),
                  child: Row(
                    children: [
                      BkIconTile(icon: action.icon ?? LucideIcons.listOrdered),
                      const Gap(BkGroupedRow.gap),
                      Flexible(
                        // Beside two chips on a small phone: shrink rather
                        // than break "Kamerawinkel" mid-word.
                        child: BkWordSafeText(
                          action.title,
                          style: context.typography.small.copyWith(fontWeight: FontWeight.w600, color: cs.foreground),
                        ),
                      ),
                      const Gap(4),
                      Icon(LucideIcons.chevronDown, size: 16, color: cs.mutedForeground),
                      if (showKeycap) ...[const Gap(8), _Keycap(hotkey, color: cs.mutedForeground)],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
          child: Row(
            spacing: 8,
            children: [
              for (final value in recent)
                SizedBox(
                  width: 52 * scaling,
                  height: 44 * scaling,
                  child: Button(
                    style: ButtonStyle.secondary()
                        .withBorderRadius(borderRadius: BorderRadius.circular(999))
                        .withPadding(padding: EdgeInsets.zero),
                    onPressed: () => _sendQuickValue(action, value, connection),
                    child: Center(
                      child: Text(
                        '$value',
                        style: context.typography.small.copyWith(
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHotkeySection(List<TrainerConnection> connections) {
    final uniqueActions = [for (final c in connections) ..._actionsOf(c)].distinct().toList();
    if (uniqueActions.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);

    return BkGroupedSection(
      header: l10n.keyboardShortcuts,
      footer: l10n.keyboardShortcutsSimulatorHint,
      children: [for (final action in uniqueActions) _buildHotkeyRow(action)],
    );
  }

  Widget _buildHotkeyRow(InGameAction action) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final accent = bkAccentText(context);
    final hotkey = _hotkeys[action];
    final isEditing = _editingHotkeyAction == action;
    final compact = isCompactWindow(context);
    final actionStyle = context.typography.small.copyWith(color: accent, fontWeight: FontWeight.w600);
    final actionButtonStyle = ButtonStyle.ghost().withPadding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    );

    return BkGroupedRow(
      icon: action.icon ?? LucideIcons.keyboard,
      quietIcon: true,
      title: action.title,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isEditing)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: cs.primary, width: 1.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(l10n.pressAKey, style: context.typography.xSmall.copyWith(color: accent)),
            )
          else if (hotkey != null)
            _Keycap(hotkey, color: cs.foreground)
          else
            Text('—', style: context.typography.small.copyWith(color: cs.mutedForeground)),
          const Gap(4),
          Button(
            style: actionButtonStyle,
            onPressed: () {
              setState(() {
                _editingHotkeyAction = isEditing ? null : action;
              });
            },
            child: Text(isEditing ? l10n.cancel : l10n.setShortcut, style: actionStyle),
          ),
          // A phone row has no room for both; there Clear joins Cancel
          // while the shortcut is being changed.
          if (hotkey != null && (compact ? isEditing : !isEditing))
            Button(
              style: actionButtonStyle,
              onPressed: () {
                setState(() {
                  _hotkeys.remove(action);
                  _editingHotkeyAction = null;
                });
                core.settings.setButtonSimulatorHotkeys(_hotkeys);
              },
              child: Text(l10n.clear, style: actionStyle),
            ),
        ],
      ),
    );
  }

  /// One on-screen button. It sends key-down on touch and key-up on release,
  /// so long-press actions hold as long as the finger does.
  Widget _buildPad(
    InGameAction action,
    _PadTone tone,
    _PadSize size,
    TrainerConnection connection, {
    IconData? icon,
  }) {
    final cs = Theme.of(context).colorScheme;
    final brand = BkBrandColors.of(context);
    final (Color base, Color ink, Color subInk) = switch (tone) {
      _PadTone.primary => (cs.primary, cs.primaryForeground, cs.primaryForeground.withValues(alpha: 0.78)),
      _PadTone.fill => (cs.muted, cs.foreground, cs.mutedForeground),
      _PadTone.card => (cs.card, cs.foreground, cs.mutedForeground),
    };
    final hover = tone == _PadTone.card ? bkCardHover(context) : Color.alphaBlend(ink.withValues(alpha: 0.08), base);
    final pressed = tone == _PadTone.card
        ? bkCardPressed(context)
        : Color.alphaBlend(ink.withValues(alpha: 0.16), base);
    final radius = BorderRadius.circular(switch (size) {
      _PadSize.hero => 24,
      _PadSize.medium => 18,
      _PadSize.tile => BkComponentThemes.cardRadius,
    });
    final keyboardPressed = _pressedAction == action;
    final hotkey = _hotkeys[action];
    final showKeycap = hotkey != null && !isCompactWindow(context);
    final glyph = icon ?? action.icon;
    final typography = context.typography;

    final labelStyle = switch (size) {
      _PadSize.hero => typography.large.copyWith(fontWeight: FontWeight.w600, color: ink, height: 1.15),
      _PadSize.medium => typography.base.copyWith(fontWeight: FontWeight.w600, color: ink, height: 1.15),
      _PadSize.tile => typography.small.copyWith(fontWeight: FontWeight.w600, color: ink, height: 1.15),
    };
    final iconSize = switch (size) {
      _PadSize.hero => 34.0,
      _PadSize.medium => 20.0,
      _PadSize.tile => 22.0,
    };
    final iconColor = tone == _PadTone.card ? brand.tileInk : ink;

    final label = BkWordSafeText(
      action.title,
      textAlign: size == _PadSize.medium ? TextAlign.start : TextAlign.center,
      style: labelStyle,
      maxLines: 2,
    );
    final caption = action.alternativeTitle == null
        ? null
        : Text(
            action.alternativeTitle!.toUpperCase(),
            style: typography.caption.copyWith(color: subInk, fontWeight: FontWeight.w600, letterSpacing: 0.6),
          );

    final Widget content = switch (size) {
      // Steering: icon and words side by side, a low wide pad.
      _PadSize.medium => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 10,
        children: [
          if (glyph != null) Icon(glyph, size: iconSize, color: iconColor),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [label, ?caption],
            ),
          ),
        ],
      ),
      _ => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (glyph != null) ...[
            Icon(glyph, size: iconSize, color: iconColor),
            Gap(size == _PadSize.hero ? 6 : 8),
          ],
          label,
          ?caption,
        ],
      ),
    };

    return Button(
      style: ButtonStyle.ghost()
          .withPadding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8))
          .copyWith(
            decoration: (context, states, _) => BoxDecoration(
              color: keyboardPressed || states.contains(WidgetState.pressed)
                  ? pressed
                  : states.contains(WidgetState.hovered)
                  ? hover
                  : base,
              borderRadius: radius,
              boxShadow: tone == _PadTone.card ? bkCardShadow(context) : null,
            ),
          ),
      onPressed: () {},
      onTapDown: (_) => _sendKey(context, down: true, action: action, connection: connection),
      onTapUp: (_) => _sendKey(context, down: false, action: action, connection: connection),
      child: Stack(
        alignment: Alignment.center,
        children: [
          content,
          if (showKeycap)
            PositionedDirectional(
              top: 0,
              end: 0,
              child: _Keycap(hotkey, color: tone == _PadTone.card ? cs.mutedForeground : subInk),
            ),
        ],
      ),
    );
  }

  void _openValueMenu(BuildContext context, InGameAction action, TrainerConnection connection) {
    if (!connection.isConnected.value) {
      buildToast(title: context.i18n.notConnected);
      return;
    }
    showDropdown(
      context: context,
      builder: (context) => DropdownMenu(
        children: action.possibleValues!
            .map(
              (e) => MenuButton(
                child: Text(e.toString()),
                onPressed: (c) => _sendQuickValue(action, e, connection),
              ),
            )
            .toList(),
      ),
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
        buildToast(title: context.i18n.notConnected);
      }

      return;
    }
    if (action.possibleValues != null) {
      if (down) return;
      _openValueMenu(context, action, connection);
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

enum _PadTone { primary, fill, card }

enum _PadSize { hero, medium, tile }

/// The keyboard key that presses an action, drawn as a quiet keycap in the
/// tone of whatever it sits on. Decorative: the shortcuts list says it in
/// words.
class _Keycap extends StatelessWidget {
  const _Keycap(this.label, {required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        constraints: const BoxConstraints(minWidth: 22),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.45)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label.toUpperCase(),
          textAlign: TextAlign.center,
          style: context.typography.caption.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
