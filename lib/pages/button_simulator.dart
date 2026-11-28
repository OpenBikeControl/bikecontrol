import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/pages/companion/companion_canvas.dart';
import 'package:bike_control/pages/companion/companion_info_tile.dart';
import 'package:bike_control/pages/companion/companion_layout.dart';
import 'package:bike_control/widgets/ui/bk_icon_button.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:bike_control/bluetooth/devices/zwift/ride_controller_press.dart';
import 'package:bike_control/utils/window_size.dart';
import 'package:bike_control/widgets/ui/connection_method.dart' show ConnectionMethodWithoutSwitch;
import 'package:bike_control/widgets/ui/bk_page_header.dart';
import 'package:bike_control/widgets/ui/bk_word_safe_text.dart';

import 'package:bike_control/bluetooth/devices/trainer_connection.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/utils/actions/android.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/host_platform.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
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
  const ButtonSimulator({super.key, this.startFullScreen = false});

  /// Opens straight into the full-screen view — from Ride's virtual
  /// shifting card. Until the rider saves a layout of their own, that view
  /// starts from the ride mode one: big − and + with the readings between.
  final bool startFullScreen;

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

  /// Rows of the grid that one screen shows.
  static const int _screenRows = CompanionLayout.gridRows;

  InGameAction? _pressedAction;
  InGameAction? _editingHotkeyAction;

  DateTime? _lastDown;
  final ScrollController _scrollController = ScrollController();

  late bool _fullScreen = widget.startFullScreen;
  bool _editing = false;

  /// Holds the page in landscape on a phone, for a mount that only fits it
  /// sideways; the system's rotation lock doesn't keep it upright then.
  late bool _forceLandscape = _canLockOrientation && core.settings.getCompanionForceLandscape();

  static bool get _canLockOrientation => HostPlatform.isAndroid || HostPlatform.isIOS;

  /// The rider's own layout per orientation (key: landscape); absent while
  /// they haven't changed it.
  final Map<bool, CompanionLayout?> _saved = {};

  StreamSubscription<BaseDevice>? _connectionSub;
  static final ValueNotifier<FitnessBikeDefinition?> _noDefinition = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'ButtonSimulatorFocus', canRequestFocus: true);
    _loadHotkeys();
    _focusNode.requestFocus();
    for (final landscape in [false, true]) {
      final raw = core.settings.getCompanionLayout(landscape: landscape);
      _saved[landscape] = raw == null ? null : CompanionLayout.tryParse(raw, landscape: landscape);
    }
    // A trainer connecting or dropping changes which buttons and readings
    // the page can offer.
    _connectionSub = core.connection.connectionStream.listen((_) {
      if (mounted) setState(() {});
    });
    if (_fullScreen) _applySystemUi(true);
    if (_forceLandscape) _applyOrientation(true);
  }

  @override
  void dispose() {
    if (_fullScreen) _applySystemUi(false);
    if (_forceLandscape) _applyOrientation(false);
    _connectionSub?.cancel();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// On a phone, full screen hides the status and navigation bars too.
  void _applySystemUi(bool fullScreen) {
    if (screenshotMode || !(Platform.isAndroid || Platform.isIOS)) return;
    unawaited(
      (fullScreen
              ? SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky, overlays: [])
              : SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values))
          .catchError((Object e, StackTrace s) => recordError(e, s, context: 'companion full screen')),
    );
  }

  /// Landscape only while [landscape], else every orientation again.
  void _applyOrientation(bool landscape) {
    unawaited(
      SystemChrome.setPreferredOrientations(
        landscape
            ? const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
            : const [
                DeviceOrientation.portraitUp,
                DeviceOrientation.portraitDown,
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ],
      ).catchError((Object e, StackTrace s) => recordError(e, s, context: 'companion landscape lock')),
    );
  }

  void _toggleForceLandscape() {
    final value = !_forceLandscape;
    _applyOrientation(value);
    setState(() => _forceLandscape = value);
    unawaited(
      core.settings
          .setCompanionForceLandscape(value)
          .catchError((Object e, StackTrace s) => recordError(e, s, context: 'companion landscape lock')),
    );
  }

  Widget _landscapeToggle(AppLocalizations l, {required double iconSize}) => BkIconButton(
    key: const ValueKey('companion-landscape'),
    variance: _forceLandscape ? ButtonVariance.secondary : ButtonVariance.ghost,
    icon: Icon(LucideIcons.rotateCwSquare, size: iconSize),
    label: _forceLandscape ? l.companionUnlockLandscape : l.companionLockLandscape,
    onPressed: _toggleForceLandscape,
  );

  void _setFullScreen(bool value) {
    if (value == _fullScreen) return;
    _applySystemUi(value);
    setState(() {
      _fullScreen = value;
      if (value) _editing = false;
    });
  }

  /// The trainer BikeControl shifts itself, when there is one: its shifts
  /// and readings are what the page's gear buttons and ride data use.
  ProxyDevice? get _vsProxy => core.connection.proxyDevices.where((d) => d.isConnected).firstOrNull;

  Future<void> _loadHotkeys() async {
    _loadRecentValues();
    final savedHotkeys = core.settings.getButtonSimulatorHotkeys();

    // If no saved hotkeys, initialize with defaults
    if (savedHotkeys.isEmpty) {
      final allActions = _availableActions(_vsProxy?.fitnessBike != null);

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

    if (_fullScreen && event.logicalKey == LogicalKeyboardKey.escape) {
      _setFullScreen(false);
      return KeyEventResult.handled;
    }

    // Find the action associated with this key
    final action = _hotkeys.entries.firstOrNullWhere((entry) => entry.value == key)?.key;

    if (action == null) return KeyEventResult.ignored;

    if (!_canPress(action)) {
      buildToast(title: context.i18n.notConnected);
      return KeyEventResult.ignored;
    }

    setState(() => _pressedAction = action);
    _press(action, down: true);
    // Schedule key up event
    Future.delayed(_keyPressDuration, () {
      if (mounted) {
        setState(() => _pressedAction = null);
        _press(action, down: false);
      }
    });
    return KeyEventResult.handled;
  }

  /// The actions [connection] can send, under the trainer app's own names.
  List<InGameAction> _actionsOf(TrainerConnection connection) {
    return appControllerActions(
      connection.supportedActions == InGameAction.values
          ? core.settings.getTrainerApp()!.keymap.keyPairs.mapNotNull((k) => k.inGameAction).distinct().toList()
          : connection.supportedActions,
    ).distinct().toList();
  }

  /// Everything the page can press: the trainer apps' actions; − / + and
  /// the trainer's own controls whenever BikeControl shifts the trainer
  /// itself (also with no trainer app connection on this page, as when Rouvy
  /// rides BikeControl's bridge); and a connected Headwind's or incline
  /// device's.
  List<InGameAction> _availableActions(bool hasRideData) => [
    if (hasRideData) ...[
      InGameAction.shiftDown,
      InGameAction.shiftUp,
    ],
    for (final c in core.logic.enabledNonLocalTrainerConnections) ..._actionsOf(c),
    if (hasRideData) ...[
      if (_vsProxy?.fitnessBike?.frontShiftEnabled == true) InGameAction.frontShift,
      InGameAction.trainerSwitchMode,
      InGameAction.trainerIntensityDown,
      InGameAction.trainerIntensityUp,
    ],
    if (_hasHeadwind) ..._headwindActions,
    if (_hasIncline) ..._inclineActions,
  ].distinct().toList();

  static const _headwindActions = [
    InGameAction.headwindSpeedDec,
    InGameAction.headwindSpeedInc,
    InGameAction.headwindSpeedCyclicInc,
    InGameAction.headwindHeartRateMode,
  ];
  static const _inclineActions = [
    InGameAction.inclineDecrease,
    InGameAction.inclineIncrease,
    InGameAction.inclineZero,
    InGameAction.inclineAutoMode,
  ];

  bool get _hasHeadwind => core.connection.accessories.any((d) => d.isConnected);
  bool get _hasIncline => core.connection.inclineDevices.any((d) => d.isConnected);

  /// A Headwind's or incline device's action: BikeControl does it itself.
  bool _isDeviceAction(InGameAction action) =>
      (_headwindActions.contains(action) && _hasHeadwind) || (_inclineActions.contains(action) && _hasIncline);

  /// The music controls this platform can send.
  List<CompanionMusic> get _availableMusic {
    if (!core.actionHandler.supportedModes.contains(SupportedMode.media)) return const [];
    // Android's media control has no "previous".
    return [
      for (final m in CompanionMusic.values)
        if (!(core.actionHandler is AndroidActions && m == CompanionMusic.previous)) m,
    ];
  }

  static PhysicalKeyboardKey _musicKey(CompanionMusic music) => switch (music) {
    CompanionMusic.playPause => PhysicalKeyboardKey.mediaPlayPause,
    CompanionMusic.previous => PhysicalKeyboardKey.mediaTrackPrevious,
    CompanionMusic.next => PhysicalKeyboardKey.mediaTrackNext,
    CompanionMusic.volumeDown => PhysicalKeyboardKey.audioVolumeDown,
    CompanionMusic.volumeUp => PhysicalKeyboardKey.audioVolumeUp,
  };

  static String _musicName(AppLocalizations l, CompanionMusic music) => switch (music) {
    CompanionMusic.playPause => l.playPause,
    CompanionMusic.previous => l.previous,
    CompanionMusic.next => l.next,
    CompanionMusic.volumeDown => l.volumeDown,
    CompanionMusic.volumeUp => l.volumeUp,
  };

  static IconData _musicIcon(CompanionMusic music) => switch (music) {
    CompanionMusic.playPause => LucideIcons.play,
    CompanionMusic.previous => LucideIcons.skipBack,
    CompanionMusic.next => LucideIcons.skipForward,
    CompanionMusic.volumeDown => LucideIcons.volume1,
    CompanionMusic.volumeUp => LucideIcons.volume2,
  };

  Future<void> _pressMusic(CompanionMusic music) async {
    try {
      final result = await core.actionHandler.performKeyPair(
        KeyPair(buttons: [], physicalKey: _musicKey(music), logicalKey: null),
        isKeyDown: true,
        isKeyUp: true,
      );
      if (result is Error && mounted) buildToast(title: result.message);
    } catch (e, s) {
      recordError(e, s, context: 'companion music ${music.name}');
    }
  }

  /// The connected trainer app connection that takes [action].
  TrainerConnection? _connectionFor(InGameAction action) =>
      core.logic.connectedNonLocalTrainerConnections.firstOrNullWhere((c) => _actionsOf(c).contains(action));

  bool _routesToVirtualShifting(InGameAction action) =>
      trainerActions.contains(action) && _vsProxy?.fitnessBike != null;

  bool _canPress(InGameAction action) =>
      _routesToVirtualShifting(action) || _isDeviceAction(action) || _connectionFor(action) != null;

  /// Presses [action]. Gear actions go the way a controller's do — through
  /// BikeControl's own virtual shifting when it runs (so ERG steps watts
  /// and the shift buzzes), else on to the trainer app; everything else
  /// straight to the trainer app connection that takes it.
  Future<void> _press(InGameAction action, {required bool down}) async {
    if (_routesToVirtualShifting(action)) {
      if (!down) return;
      try {
        final result = await core.actionHandler.performInGameAction(action, source: 'companion');
        if (result is Error && mounted) buildToast(title: result.message);
      } catch (e, s) {
        recordError(e, s, context: 'companion ${action.name}');
      }
      return;
    }
    if (_isDeviceAction(action)) {
      try {
        final result = await core.actionHandler.performKeyPair(
          KeyPair(buttons: [], physicalKey: null, logicalKey: null, inGameAction: action),
          isKeyDown: down,
          isKeyUp: !down,
        );
        if (result is Error && mounted) buildToast(title: result.message);
      } catch (e, s) {
        recordError(e, s, context: 'companion ${action.name}');
      }
      return;
    }
    final connection = _connectionFor(action);
    if (connection == null) {
      if (down) buildToast(title: context.i18n.notConnected);
      return;
    }
    await _sendKey(context, down: down, action: action, connection: connection);
  }

  // ── Layout ────────────────────────────────────────────────────────────

  /// The layout for this orientation: the rider's own, else ride mode with
  /// the other buttons below it.
  CompanionLayout _layoutFor({required bool landscape, required bool hasRideData}) {
    if (_saved[landscape] case final saved?) return saved;
    return CompanionLayout.initial(
      actions: _availableActions(hasRideData),
      landscape: landscape,
      hasRideData: hasRideData,
    );
  }

  void _save(CompanionLayout layout) {
    setState(() => _saved[layout.landscape] = layout);
    unawaited(
      core.settings
          .setCompanionLayout(layout.toJsonString(), landscape: layout.landscape)
          .catchError((Object e, StackTrace s) => recordError(e, s, context: 'companion layout save')),
    );
  }

  void _resetLayout(bool landscape) {
    setState(() => _saved[landscape] = null);
    unawaited(
      core.settings
          .setCompanionLayout(null, landscape: landscape)
          .catchError((Object e, StackTrace s) => recordError(e, s, context: 'companion layout reset')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final proxy = _vsProxy;
    return ValueListenableBuilder<FitnessBikeDefinition?>(
      valueListenable: proxy?.fitnessBikeListenable ?? _noDefinition,
      builder: (context, definition, _) => Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKey,
        child: _fullScreen ? _buildFullScreen(definition) : _buildPage(definition),
      ),
    );
  }

  Widget _buildFullScreen(FitnessBikeDefinition? definition) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final landscape = constraints.maxWidth > constraints.maxHeight;
                    final layout = _layoutFor(landscape: landscape, hasRideData: definition != null);
                    return SingleChildScrollView(
                      child: _canvas(layout, definition, rowHeight: constraints.maxHeight / _screenRows),
                    );
                  },
                ),
              ),
            ),
            PositionedDirectional(
              top: 4,
              end: 4,
              child: Opacity(
                opacity: 0.8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_canLockOrientation) _landscapeToggle(l, iconSize: 20),
                    BkIconButton.ghost(
                      key: const ValueKey('companion-exit-full-screen'),
                      icon: const Icon(LucideIcons.minimize2, size: 20),
                      label: l.companionExitFullScreen,
                      onPressed: () => _setFullScreen(false),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(FitnessBikeDefinition? definition) {
    final connections = core.logic.enabledNonLocalTrainerConnections;
    final hasRideData = definition != null;
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      headers: [
        BkPageHeader(
          title: context.i18n.simulateButtons,
          subtitle: _connectionStatus(connections, hasRideData),
          showDivider: false,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          actions: _editing
              ? [
                  Button.ghost(
                    key: const ValueKey('companion-done'),
                    onPressed: () => setState(() => _editing = false),
                    child: Text(l.done),
                  ),
                ]
              : [
                  BkIconButton.ghost(
                    key: const ValueKey('companion-edit'),
                    icon: const Icon(LucideIcons.layoutDashboard, size: 22),
                    label: l.companionEditLayout,
                    onPressed: () => setState(() => _editing = true),
                  ),
                  if (_canLockOrientation) _landscapeToggle(l, iconSize: 22),
                  BkIconButton.ghost(
                    key: const ValueKey('companion-full-screen'),
                    icon: const Icon(LucideIcons.maximize2, size: 22),
                    label: l.companionFullScreen,
                    onPressed: () => _setFullScreen(true),
                  ),
                ],
        ),
      ],
      child: LayoutBuilder(
        builder: (context, viewport) {
          final scroll = Scrollbar(
            controller: _scrollController,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: BkPageColumn(
                child: LayoutBuilder(
                  builder: (context, column) {
                    // One screen of grid fills what's left under the header.
                    final height = math.max(viewport.maxHeight - 32, 240.0);
                    final landscape = column.maxWidth > height;
                    final layout = _layoutFor(landscape: landscape, hasRideData: hasRideData);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_editing)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(BkGroupedSection.inset, 0, BkGroupedSection.inset, 8),
                            child: Text(
                              l.companionEditHint,
                              style: context.typography.small.copyWith(color: cs.mutedForeground),
                            ),
                          ),
                        _canvas(layout, definition, rowHeight: height / _screenRows),
                        const Gap(24),
                        _buildHotkeySection(_availableActions(hasRideData)),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
          if (!_editing) return scroll;
          // The tools stay put while the grid scrolls under them; the grid
          // keeps the size it has outside editing.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: BkPageColumn(child: _editToolbar(definition)),
              ),
              Expanded(child: scroll),
            ],
          );
        },
      ),
    );
  }

  /// While editing, what can be done to the layout, each with its name: in a
  /// row under the header, where a long title can't crowd them.
  Widget _editToolbar(FitnessBikeDefinition? definition) {
    final l = AppLocalizations.of(context);
    Widget tool(String key, IconData icon, String label, VoidCallback onPressed) => Expanded(
      child: SizedBox(
        height: 40,
        child: Button(
          key: ValueKey(key),
          style: const ButtonStyle.outline(size: ButtonSize.small),
          onPressed: onPressed,
          // Three to a row on a phone: a long label shrinks rather than wrap.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [Icon(icon, size: 14), Text(label, maxLines: 1)],
            ),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        spacing: 8,
        children: [
          tool('companion-add', LucideIcons.plus, l.companionAdd, () => _openAdd(definition)),
          tool('companion-compact', LucideIcons.foldVertical, l.companionCompact, () => _compact(definition)),
          tool('companion-reset', LucideIcons.rotateCcw, l.reset, _confirmReset),
        ],
      ),
    );
  }

  /// Closes the empty space between the tiles on this orientation's layout.
  void _compact(FitnessBikeDefinition? definition) {
    final layout = _layoutFor(landscape: _currentLandscape(context), hasRideData: definition != null);
    _save(layout.compacted());
  }

  /// Back to ride mode with every button, for this orientation.
  Future<void> _confirmReset() async {
    final l = AppLocalizations.of(context);
    final landscape = _currentLandscape(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.companionResetLayout),
        content: Text(l.companionResetLayoutBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(l.cancel)),
          Button.destructive(
            key: const ValueKey('companion-reset-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l.reset),
          ),
        ],
      ),
    );
    if (ok == true) _resetLayout(landscape);
  }

  /// Whether the page lays out in landscape right now, as [_buildPage]
  /// decides it.
  bool _currentLandscape(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return math.min(size.width - 32, BkPageColumn.defaultMaxWidth) > size.height - 120;
  }

  Future<void> _openAdd(FitnessBikeDefinition? definition) async {
    final l = AppLocalizations.of(context);
    final landscape = _currentLandscape(context);
    final layout = _layoutFor(landscape: landscape, hasRideData: definition != null);
    final actions = _availableActions(definition != null).where((a) => layout.tileFor(a) == null).toList();
    final data = CompanionTileKind.values.where((k) => k.isRideData && !layout.tiles.any((t) => t.kind == k)).toList();
    final music = _availableMusic.where((m) => layout.tileForMusic(m) == null).toList();
    void add(CompanionTileKind kind, {InGameAction? action, CompanionMusic? music}) {
      Navigator.of(context).pop();
      _save(layout.added(kind: kind, action: action, music: music));
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.companionAddTile),
        content: SizedBox(
          width: 360,
          height: math.min(MediaQuery.sizeOf(dialogContext).height * 0.6, 520),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (actions.isEmpty && music.isEmpty && (data.isEmpty || definition == null))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(l.companionAllAdded),
                  ),
                if (actions.isNotEmpty)
                  BkGroupedSection(
                    header: l.companionAddButtons,
                    children: [
                      for (final action in actions)
                        BkGroupedRow(
                          key: ValueKey('companion-add-${action.name}'),
                          icon: action.icon ?? LucideIcons.squareMousePointer,
                          quietIcon: true,
                          title: action.title,
                          onPressed: () => add(CompanionTileKind.action, action: action),
                        ),
                    ],
                  ),
                if (music.isNotEmpty) ...[
                  const Gap(16),
                  BkGroupedSection(
                    header: l.simulateMediaKey,
                    children: [
                      for (final m in music)
                        BkGroupedRow(
                          key: ValueKey('companion-add-music-${m.name}'),
                          icon: _musicIcon(m),
                          quietIcon: true,
                          title: _musicName(l, m),
                          onPressed: () => add(CompanionTileKind.music, music: m),
                        ),
                    ],
                  ),
                ],
                if (data.isNotEmpty) ...[
                  const Gap(16),
                  BkGroupedSection(
                    header: l.companionAddRideData,
                    footer: definition == null ? l.companionRideDataHint : null,
                    children: [
                      for (final kind in data)
                        BkGroupedRow(
                          key: ValueKey('companion-add-${kind.name}'),
                          icon: companionTileIcon(kind),
                          quietIcon: true,
                          title: companionTileName(l, kind),
                          onPressed: definition == null ? null : () => add(kind),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l.close)),
        ],
      ),
    );
  }

  Widget _canvas(CompanionLayout layout, FitnessBikeDefinition? definition, {required double rowHeight}) {
    final l = AppLocalizations.of(context);
    return CompanionCanvas(
      key: ValueKey('companion-canvas-${layout.landscape ? 'landscape' : 'portrait'}'),
      layout: layout,
      rowHeight: rowHeight,
      editing: _editing,
      onChanged: _save,
      radiusOf: _tileRadius,
      removeLabel: (tile) => l.companionRemoveTile(switch (tile.kind) {
        CompanionTileKind.action => tile.action!.title,
        CompanionTileKind.music => _musicName(l, tile.music!),
        _ => companionTileName(l, tile.kind),
      }),
      tileBuilder: (context, tile) => _buildTile(tile, definition),
    );
  }

  /// The corner radius [tile] draws with.
  static double _tileRadius(CompanionTile tile) => switch (tile.action) {
    InGameAction.shiftUp || InGameAction.shiftDown => _padRadius(_PadSize.hero),
    InGameAction.steerLeft || InGameAction.steerRight => _padRadius(_PadSize.medium),
    _ => BkComponentThemes.cardRadius,
  };

  static double _padRadius(_PadSize size) => switch (size) {
    _PadSize.hero => 24,
    _PadSize.medium => 18,
    _PadSize.tile => BkComponentThemes.cardRadius,
  };

  Widget _buildTile(CompanionTile tile, FitnessBikeDefinition? definition) {
    if (tile.kind == CompanionTileKind.music) {
      final music = tile.music!;
      return _pad(
        label: _musicName(AppLocalizations.of(context), music),
        glyph: _musicIcon(music),
        tone: _PadTone.card,
        size: _PadSize.tile,
        onDown: () => _pressMusic(music),
      );
    }
    if (tile.kind != CompanionTileKind.action) {
      return CompanionInfoTile(kind: tile.kind, definition: definition);
    }
    final action = tile.action!;
    final enabled = _canPress(action);
    final Widget child;
    if (action.possibleValues != null) {
      child = _buildValueTile(action);
    } else {
      final (tone, size, icon) = switch (action) {
        InGameAction.shiftUp => (_PadTone.primary, _PadSize.hero, LucideIcons.plus),
        InGameAction.shiftDown => (_PadTone.fill, _PadSize.hero, LucideIcons.minus),
        InGameAction.steerLeft || InGameAction.steerRight => (_PadTone.fill, _PadSize.medium, null),
        _ => (_PadTone.card, _PadSize.tile, null),
      };
      child = _buildPad(action, tone, size, icon: icon);
    }
    // A button whose connection isn't there yet stays where it is, quieter.
    return AnimatedOpacity(duration: const Duration(milliseconds: 150), opacity: enabled ? 1 : 0.5, child: child);
  }

  /// The trainer app connection's state as one quiet line under the title.
  /// Not connected, it opens the method's card — the instructions and the
  /// network check — so the rider can fix it from here.
  Widget? _connectionStatus(List<TrainerConnection> connections, bool hasRideData) {
    if (connections.isEmpty) {
      if (hasRideData) return null;
      return BkStatusDot(label: context.i18n.trainerControlsNoConnection, tone: BkStatusTone.neutral);
    }
    return ListenableBuilder(
      listenable: Listenable.merge([for (final c in connections) c.isConnected]),
      builder: (context, _) {
        final down = connections.where((c) => !c.isConnected.value).toList();
        final dot = BkStatusDot(
          label: down.isEmpty ? context.i18n.connected : context.i18n.notConnected,
          tone: down.isEmpty ? BkStatusTone.success : BkStatusTone.neutral,
        );
        if (down.isEmpty) return dot;
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: BkTappable(
            key: const ValueKey('companion-connection-status'),
            onPressed: () => _showConnection(down),
            borderRadius: BorderRadius.circular(8),
            wash: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: [
                  Flexible(child: dot),
                  Icon(LucideIcons.chevronRight, size: 14, color: Theme.of(context).colorScheme.mutedForeground),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showConnection(List<TrainerConnection> connections) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(context.i18n.notConnected),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [for (final c in connections) ConnectionMethodWithoutSwitch(child: c.getTile())],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(context.i18n.close)),
      ],
    ),
  );

  /// An action that takes a value (camera angle, emote): its name opens the
  /// full list, and with room the two values used last sit under it, one
  /// tap each.
  Widget _buildValueTile(InGameAction action) {
    final cs = Theme.of(context).colorScheme;
    final scaling = Theme.of(context).scaling;
    final recent = _recentValues[action] ?? action.possibleValues!.take(2).toList();
    final hotkey = _hotkeys[action];
    final showKeycap = hotkey != null && !isCompactWindow(context) && !_fullScreen;
    return DecoratedBox(
      key: ValueKey('quick-values-${action.name}'),
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(BkComponentThemes.cardRadius),
        boxShadow: bkCardShadow(context),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final chipHeight = 44 * scaling;
          final roomForChips = constraints.maxHeight >= chipHeight + 52 * scaling && constraints.maxWidth >= 120;
          final title = Builder(
            builder: (context) => BkTappable(
              wash: true,
              onPressed: () => _openValueMenuFor(context, action),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(action.icon ?? LucideIcons.listOrdered, size: 18, color: BkBrandColors.of(context).tileInk),
                    const Gap(8),
                    Flexible(
                      // Beside a chevron on a small phone: shrink rather
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
          );
          if (!roomForChips) return Center(child: title);
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              title,
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 8,
                  children: [
                    for (final value in recent)
                      SizedBox(
                        width: 52 * scaling,
                        height: chipHeight,
                        child: Button(
                          style: ButtonStyle.secondary()
                              .withBorderRadius(borderRadius: BorderRadius.circular(999))
                              .withPadding(padding: EdgeInsets.zero),
                          onPressed: () {
                            final connection = _connectionFor(action);
                            if (connection == null) {
                              buildToast(title: context.i18n.notConnected);
                              return;
                            }
                            _sendQuickValue(action, value, connection);
                          },
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
        },
      ),
    );
  }

  void _openValueMenuFor(BuildContext context, InGameAction action) {
    final connection = _connectionFor(action);
    if (connection == null) {
      buildToast(title: context.i18n.notConnected);
      return;
    }
    _openValueMenu(context, action, connection);
  }

  Widget _buildHotkeySection(List<InGameAction> uniqueActions) {
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
    _PadSize size, {
    IconData? icon,
  }) => _pad(
    label: action.title,
    glyph: icon ?? action.icon,
    caption: RideControllerPress.caption(action),
    tone: tone,
    size: size,
    keyboardPressed: _pressedAction == action,
    hotkey: _hotkeys[action],
    onDown: () => _press(action, down: true),
    onUp: () => _press(action, down: false),
  );

  Widget _pad({
    required String label,
    required IconData? glyph,
    String? caption,
    required _PadTone tone,
    required _PadSize size,
    bool keyboardPressed = false,
    String? hotkey,
    required VoidCallback onDown,
    VoidCallback? onUp,
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
    final radius = BorderRadius.circular(_padRadius(size));
    final showKeycap = hotkey != null && !isCompactWindow(context) && !_fullScreen;
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

    Widget content(double iconSize, TextStyle labelStyle) {
      final title = BkWordSafeText(
        label,
        textAlign: size == _PadSize.medium ? TextAlign.start : TextAlign.center,
        style: labelStyle,
        maxLines: 2,
      );
      final captionLine = caption == null
          ? null
          : Text(
              caption.toUpperCase(),
              style: typography.caption.copyWith(color: subInk, fontWeight: FontWeight.w600, letterSpacing: 0.6),
            );

      return switch (size) {
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
                children: [title, ?captionLine],
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
            title,
            ?captionLine,
          ],
        ),
      };
    }

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
      onTapDown: (_) => onDown(),
      onTapUp: onUp == null ? null : (_) => onUp(),
      onTapCancel: onUp,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // A tile grows its glyph and words with it — a screen-high + in
          // ride mode reads from the saddle — and shrinks them rather than
          // overflow a small one.
          LayoutBuilder(
            builder: (context, constraints) {
              final side = math.min(constraints.maxWidth, constraints.maxHeight);
              final grow = size == _PadSize.hero && side.isFinite ? (side / 110).clamp(1.0, 3.5) : 1.0;
              return FittedBox(
                fit: BoxFit.scaleDown,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth.isFinite ? constraints.maxWidth : 400),
                  child: content(
                    iconSize * grow,
                    labelStyle.copyWith(fontSize: (labelStyle.fontSize ?? 18) * math.min(grow, 1.8)),
                  ),
                ),
              );
            },
          ),
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
