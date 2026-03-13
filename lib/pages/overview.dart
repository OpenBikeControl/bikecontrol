import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/trainer_connection.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/controller_settings.dart';
import 'package:bike_control/pages/trainer_connection_settings.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/widgets/iap_status_widget.dart';
import 'package:bike_control/widgets/ignored_devices_dialog.dart';
import 'package:bike_control/widgets/status_icon.dart';
import 'package:bike_control/widgets/trainer_features.dart';
import 'package:bike_control/widgets/ui/button_widget.dart';
import 'package:bike_control/widgets/ui/colored_title.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:bike_control/widgets/ui/trainer_label.dart';
import 'package:flutter/foundation.dart';
import 'package:lottie/lottie.dart';
import 'package:prop/emulators/shared.dart';
import 'package:prop/prop.dart' show LogLevel;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../main.dart';
import '../utils/iap/iap_manager.dart';
import 'device.dart';

// ── Quadratic Bezier helper ──────────────────────────────────────────
Offset _quadBezier(double t, Offset p0, Offset p1, Offset p2) {
  final u = 1 - t;
  return Offset(
    u * u * p0.dx + 2 * u * t * p1.dx + t * t * p2.dx,
    u * u * p0.dy + 2 * u * t * p1.dy + t * t * p2.dy,
  );
}

// ── Horizontal flow line painter ──────────────────────────────────────
class _HorizontalFlowPainter extends CustomPainter {
  final double bicycleX, bicycleY;
  final double logoLeftX, logoRightX, logoCenterY;
  final double trainerCenterX, trainerCenterY;
  final Color color;
  final bool isTrainerConnected;

  _HorizontalFlowPainter({
    required this.bicycleX,
    required this.bicycleY,
    required this.logoLeftX,
    required this.logoRightX,
    required this.logoCenterY,
    required this.trainerCenterX,
    required this.trainerCenterY,
    required this.color,
    required this.isTrainerConnected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = 2
      ..strokeCap = ui.StrokeCap.round
      ..style = ui.PaintingStyle.stroke;

    // Left segment: bicycle → logo left edge
    final leftPath = ui.Path()
      ..moveTo(bicycleX, bicycleY)
      ..quadraticBezierTo((bicycleX + logoLeftX) / 2, logoCenterY, logoLeftX, logoCenterY);
    canvas.drawPath(leftPath, paint);

    // Right segment: logo right edge → trainer center
    final rightColor = isTrainerConnected ? color : const Color(0xFFEF4444);

    if (isTrainerConnected) {
      final rightPaint = Paint()
        ..color = rightColor.withValues(alpha: 0.3)
        ..strokeWidth = 2
        ..strokeCap = ui.StrokeCap.round
        ..style = ui.PaintingStyle.stroke;
      final rightPath = ui.Path()
        ..moveTo(logoRightX, logoCenterY)
        ..quadraticBezierTo((logoRightX + trainerCenterX) / 2, logoCenterY, trainerCenterX, trainerCenterY);
      canvas.drawPath(rightPath, rightPaint);
    } else {
      final dashPaint = Paint()
        ..color = rightColor.withValues(alpha: 0.3)
        ..strokeWidth = 2
        ..strokeCap = ui.StrokeCap.round;
      const dash = 5.0;
      const gap = 7.0;
      final span = (trainerCenterX - logoRightX).clamp(1.0, double.infinity);
      for (double x = logoRightX; x < trainerCenterX; x += dash + gap) {
        final end = (x + dash).clamp(x, trainerCenterX);
        final frac = (x - logoRightX) / span;
        final y = logoCenterY + (trainerCenterY - logoCenterY) * frac;
        final endFrac = (end - logoRightX) / span;
        final endY = logoCenterY + (trainerCenterY - logoCenterY) * endFrac;
        canvas.drawLine(Offset(x, y), Offset(end, endY), dashPaint);
      }
    }

    // Chevrons
    final chevronPaint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = 2
      ..strokeCap = ui.StrokeCap.round
      ..style = ui.PaintingStyle.stroke;

    final lP0 = Offset(bicycleX, bicycleY);
    final lP1 = Offset((bicycleX + logoLeftX) / 2, logoCenterY);
    final lP2 = Offset(logoLeftX, logoCenterY);
    final c1 = _quadBezier(0.4, lP0, lP1, lP2);
    final chevron1 = ui.Path()
      ..moveTo(c1.dx - 4, c1.dy - 5)
      ..lineTo(c1.dx + 2, c1.dy)
      ..lineTo(c1.dx - 4, c1.dy + 5);
    canvas.drawPath(chevron1, chevronPaint);

    if (isTrainerConnected) {
      final rP0 = Offset(logoRightX, logoCenterY);
      final rP1 = Offset((logoRightX + trainerCenterX) / 2, logoCenterY);
      final rP2 = Offset(trainerCenterX, trainerCenterY);
      final c2 = _quadBezier(0.6, rP0, rP1, rP2);
      final chevron2 = ui.Path()
        ..moveTo(c2.dx - 4, c2.dy - 5)
        ..lineTo(c2.dx + 2, c2.dy)
        ..lineTo(c2.dx - 4, c2.dy + 5);
      canvas.drawPath(chevron2, chevronPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HorizontalFlowPainter old) {
    return old.bicycleX != bicycleX ||
        old.bicycleY != bicycleY ||
        old.logoLeftX != logoLeftX ||
        old.logoRightX != logoRightX ||
        old.logoCenterY != logoCenterY ||
        old.trainerCenterX != trainerCenterX ||
        old.trainerCenterY != trainerCenterY ||
        old.isTrainerConnected != isTrainerConnected;
  }
}

// ── Bubble pointer painter ──────────────────────────────────────────
class _BubblePointerPainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;

  _BubblePointerPainter({required this.fillColor, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final path = ui.Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = fillColor);

    // Only draw the two diagonal sides (not the bottom, which merges into the card)
    final borderPath = ui.Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height);
    canvas.drawPath(
      borderPath,
      Paint()
        ..color = borderColor
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _BubblePointerPainter old) =>
      old.fillColor != fillColor || old.borderColor != borderColor;
}

// ── Activity log entry ───────────────────────────────────────────────

class _ActivityEntry {
  final ControllerButton? button;
  final DateTime time;
  final ActionResult? result;
  final String? alertMessage;
  final LogLevel? alertLevel;
  final String? buttonTitle;
  final VoidCallback? onTap;

  _ActivityEntry({
    this.button,
    required this.time,
    this.result,
    this.alertMessage,
    this.alertLevel,
    this.buttonTitle,
    this.onTap,
  });

  bool get isAlert => alertMessage != null;
  bool get isError => result is Error || result is NotHandled || alertLevel == LogLevel.LOGLEVEL_ERROR;
  bool get isSuccess => result is Success;
  bool get isWarning => alertLevel == LogLevel.LOGLEVEL_WARNING;

  String get message => alertMessage ?? result?.message ?? '';
}

// ── OverviewPage ─────────────────────────────────────────────────────

class OverviewPage extends StatefulWidget {
  final bool isMobile;
  const OverviewPage({super.key, required this.isMobile});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> with TickerProviderStateMixin, WidgetsBindingObserver {
  late StreamSubscription<BaseNotification> _actionListener;
  late Timer _timeRefreshTimer;

  late double _screenWidth;

  // Layout keys
  final Map<String, GlobalKey> _cardKeys = {};
  final GlobalKey _trainerKey = GlobalKey();
  final GlobalKey _errorBannerKey = GlobalKey();
  final GlobalKey _flowRowKey = GlobalKey();
  final GlobalKey _bicycleKey = GlobalKey();
  final GlobalKey _logoKey = GlobalKey();
  final GlobalKey _trainerLabelKey = GlobalKey();

  // Flow row measured positions (relative to _flowRowKey)
  double? _bicycleCenterX;
  double? _bicycleCenterY;
  double? _logoCenterX;
  double? _logoCenterY;
  double? _logoLeftX;
  double? _logoRightX;
  double? _trainerLabelCenterX;
  double? _trainerCenterY;
  bool _hasMeasured = false;

  final GlobalKey _activityLogKey = GlobalKey();
  bool _isInForeground = true;

  // Per-device flow animation state
  final Map<String, AnimationController> _flowControllers = {};
  final Map<String, ControllerButton> _flowButton = {};
  final Map<String, bool> _flowIsError = {};
  final Map<String, ActionResult> _flowResult = {};
  final Map<String, int> _flowGeneration = {};

  // Per-device button press animation state (separate from flow)
  final Map<String, ControllerButton> _pressedButton = {};
  final Map<String, int> _pressGeneration = {};

  // Activity log
  final List<_ActivityEntry> _activityLog = [];
  final GlobalKey<AnimatedListState> _activityListKey = GlobalKey<AnimatedListState>();
  static const _maxLogEntries = 30;

  // Error banner
  _ActivityEntry? _latestError;
  late final AnimationController _errorBannerController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  )..addListener(_onErrorBannerTick);
  late final AnimationController _errorShakeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  void _onErrorBannerTick() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measurePositions();
    });
  }

  @override
  void initState() {
    super.initState();

    // keep screen on - this is required for iOS to keep the bluetooth connection alive
    if (!screenshotMode) {
      WakelockPlus.enable();
    }

    _timeRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_activityLog.isNotEmpty) setState(() {});
    });
    _actionListener = core.connection.actionStream.listen((notification) {
      Logger.warn('Notification received: ${notification.runtimeType} - $notification');
      if (notification is ButtonNotification && notification.buttonsClicked.isNotEmpty) {
        _onButtonPressed(notification.device, notification.buttonsClicked.first);
      } else if (notification is ActionNotification) {
        _onActionResult(notification.result, notification.button);
      } else if (notification is AlertNotification) {
        _onAlert(notification);
      }
    });

    WidgetsBinding.instance.addObserver(this);

    if (!kIsWeb) {
      if (core.logic.showForegroundMessage) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // show snackbar to inform user that the app needs to stay in foreground
          buildToast(title: AppLocalizations.current.touchSimulationForegroundMessage);
        });
      }

      core.whooshLink.isStarted.addListener(() {
        if (mounted) setState(() {});
      });

      core.zwiftEmulator.isConnected.addListener(() {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void didChangeDependencies() {
    _screenWidth = MediaQuery.sizeOf(context).width;
    super.didChangeDependencies();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasForeground = _isInForeground;
    _isInForeground = state == AppLifecycleState.resumed;
    if (_isInForeground != wasForeground && mounted) setState(() {});

    if (state == AppLifecycleState.resumed) {
      if (core.logic.showForegroundMessage) {
        UniversalBle.getBluetoothAvailabilityState().then((state) {
          if (state == AvailabilityState.poweredOn && mounted) {
            core.remotePairing.reconnect();
            buildToast(title: AppLocalizations.current.touchSimulationForegroundMessage);
          }
        });
      }
    }
  }

  // ── Position measurement ──────────────────────────────────────────

  void _measurePositions() {
    final flowRowBox = _flowRowKey.currentContext?.findRenderObject() as RenderBox?;
    if (flowRowBox == null || !flowRowBox.hasSize) return;

    bool changed = false;

    double? measureCenterX(GlobalKey key) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return null;
      final offset = box.localToGlobal(Offset.zero, ancestor: flowRowBox);
      return offset.dx + box.size.width / 2;
    }

    final bx = measureCenterX(_bicycleKey);
    final lx = measureCenterX(_logoKey);
    final tx = measureCenterX(_trainerLabelKey);

    if (bx != null && bx != _bicycleCenterX) {
      _bicycleCenterX = bx;
      changed = true;
    }
    if (lx != null && lx != _logoCenterX) {
      _logoCenterX = lx;
      changed = true;
    }
    if (tx != null && tx != _trainerLabelCenterX) {
      _trainerLabelCenterX = tx;
      changed = true;
    }

    // Bicycle center Y
    final bicycleBox = _bicycleKey.currentContext?.findRenderObject() as RenderBox?;
    if (bicycleBox != null && bicycleBox.hasSize) {
      final offset = bicycleBox.localToGlobal(Offset.zero, ancestor: flowRowBox);
      final newY = offset.dy + bicycleBox.size.height / 2;
      if (newY != _bicycleCenterY) {
        _bicycleCenterY = newY;
        changed = true;
      }
    }

    // Trainer label center Y
    final trainerBox = _trainerLabelKey.currentContext?.findRenderObject() as RenderBox?;
    if (trainerBox != null && trainerBox.hasSize) {
      final offset = trainerBox.localToGlobal(Offset.zero, ancestor: flowRowBox);
      final newCenterY = offset.dy + trainerBox.size.height / 2;
      if (newCenterY != _trainerCenterY) {
        _trainerCenterY = newCenterY;
        changed = true;
      }
    }

    // Logo center Y, left X, right X
    final logoBox = _logoKey.currentContext?.findRenderObject() as RenderBox?;
    if (logoBox != null && logoBox.hasSize) {
      final offset = logoBox.localToGlobal(Offset.zero, ancestor: flowRowBox);
      final newCenterY = offset.dy + logoBox.size.height / 2;
      final newLeftX = offset.dx;
      final newRightX = offset.dx + logoBox.size.width;
      if (newCenterY != _logoCenterY) {
        _logoCenterY = newCenterY;
        changed = true;
      }
      if (newLeftX != _logoLeftX) {
        _logoLeftX = newLeftX;
        changed = true;
      }
      if (newRightX != _logoRightX) {
        _logoRightX = newRightX;
        changed = true;
      }
    }

    if (changed || !_hasMeasured) {
      _hasMeasured = true;
      setState(() {});
    }
  }

  // ── Per-device animation helpers ──────────────────────────────────

  AnimationController _controllerFor(String deviceId) {
    return _flowControllers.putIfAbsent(deviceId, () {
      final c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );
      c.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _onDeviceFlowDone(deviceId);
        }
      });
      return c;
    });
  }

  void _onButtonPressed(BaseDevice device, ControllerButton button) {
    final id = device.uniqueId;
    _pressGeneration[id] = (_pressGeneration[id] ?? 0) + 1;
    setState(() {
      _pressedButton[id] = button;
    });
  }

  void _insertActivityEntry(_ActivityEntry entry) {
    _activityLog.insert(0, entry);
    _activityListKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 300));
    if (_activityLog.length > _maxLogEntries) {
      final removed = _activityLog.removeLast();
      final removeIndex = _activityLog.length;
      _activityListKey.currentState?.removeItem(
        removeIndex,
        (context, animation) => _buildAnimatedActivityItem(removed, removeIndex, animation),
        duration: const Duration(milliseconds: 200),
      );
    }
  }

  void _onActionResult(ActionResult result, ControllerButton button) {
    final entry = _ActivityEntry(button: button, time: DateTime.now(), result: result);
    _insertActivityEntry(entry);

    if (entry.isError) {
      final alreadyShown = _latestError != null && _errorBannerController.value > 0;
      _latestError = entry;
      if (alreadyShown) {
        _errorShakeController.forward(from: 0);
      } else {
        _errorBannerController.forward(from: 0);
      }
      setState(() {});
    } else if (_latestError != null) {
      _errorBannerController.reverse().then((_) {
        if (mounted) setState(() => _latestError = null);
      });
    }

    final id = button.sourceDeviceId;
    if (id == null || !_hasMeasured || _bicycleCenterX == null || _logoCenterX == null) {
      setState(() {});
      return;
    }

    _flowGeneration[id] = (_flowGeneration[id] ?? 0) + 1;

    setState(() {
      _flowButton[id] = button;
      _flowIsError[id] = result is! Success;
      _flowResult[id] = result;
    });

    final c = _controllerFor(id);
    c.reset();
    c.forward();
  }

  void _onAlert(AlertNotification notification) {
    final entry = _ActivityEntry(
      time: DateTime.now(),
      alertMessage: notification.alertMessage,
      alertLevel: notification.level,
      buttonTitle: notification.buttonTitle,
      onTap: notification.onTap,
    );
    _insertActivityEntry(entry);

    if (notification.onTap != null) {
      final alreadyShown = _latestError != null && _errorBannerController.value > 0;
      _latestError = entry;
      if (alreadyShown) {
        _errorShakeController.forward(from: 0);
      } else {
        _errorBannerController.forward(from: 0);
      }
    }

    setState(() {});
  }

  void _onDeviceFlowDone(String deviceId) {
    final gen = _flowGeneration[deviceId];
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted && _flowGeneration[deviceId] == gen) {
        setState(() {
          _flowButton.remove(deviceId);
          _flowIsError.remove(deviceId);
          _flowResult.remove(deviceId);
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _horizontalScrollController.dispose();

    for (final c in _flowControllers.values) {
      c.dispose();
    }
    _errorBannerController.dispose();
    _errorShakeController.dispose();
    _timeRefreshTimer.cancel();
    _actionListener.cancel();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final devices = core.connection.controllerDevices;
    final trainerApp = core.settings.getTrainerApp();
    final enabledTrainers = core.logic.enabledTrainerConnections;

    for (final d in devices) {
      _cardKeys.putIfAbsent(d.uniqueId, GlobalKey.new);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measurePositions();
    });

    final leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Gap(8),
        ValueListenableBuilder(
          valueListenable: IAPManager.instance.isPurchased,
          builder: (context, value, child) => value ? SizedBox(height: 12) : IAPStatusWidget(small: false),
        ),
        Card(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12.0, left: 12, right: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSectionHeader(icon: Icons.gamepad, title: AppLocalizations.of(context).controllers),
                    ),
                    if (core.settings.getIgnoredDevices().isNotEmpty)
                      Button.text(
                        style: ButtonStyle.menu(),
                        leading: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.muted,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          margin: EdgeInsets.only(right: 4),
                          child: Text(
                            core.settings.getIgnoredDevices().length.toString(),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.mutedForeground,
                            ),
                          ),
                        ),
                        onPressed: () async {
                          await showDialog(
                            context: context,
                            builder: (context) => IgnoredDevicesDialog(),
                          );
                          setState(() {});
                        },
                        child: Text(context.i18n.manageIgnoredDevices).small,
                      ),
                  ],
                ),
              ),
              Gap(8),
              DevicePage(
                cardKeys: _cardKeys,
                isMobile: widget.isMobile,
                footerBuilder: (device) {
                  final id = device.uniqueId;
                  final pressedButton = _pressedButton[id];
                  final generation = _pressGeneration[id] ?? 0;
                  return [
                    const Gap(12),
                    Wrap(
                      alignment: WrapAlignment.start,
                      runAlignment: WrapAlignment.start,
                      crossAxisAlignment: WrapCrossAlignment.start,
                      spacing: 9,
                      runSpacing: 9,
                      children: device.availableButtons.map((btn) {
                        final pressGen = pressedButton?.name == btn.name ? generation : 0;
                        return _AnimatedButtonWidget(
                          key: ValueKey(btn.name),
                          button: btn,
                          pressGeneration: pressGen,
                        );
                      }).toList(),
                    ),
                  ];
                },
                onUpdate: () {
                  _clearErrorBanner();
                  setState(() {});
                },
              ),
            ],
          ),
        ),
        const Gap(22),
        _buildFlowRow(trainerApp, enabledTrainers),
        const Gap(22),

        KeyedSubtree(
          key: _trainerKey,
          child: _buildTrainerCard(trainerApp, enabledTrainers),
        ),
        if (widget.isMobile) Gap(MediaQuery.viewPaddingOf(context).bottom + 32),
      ],
    );

    final activityColumn = KeyedSubtree(
      key: _activityLogKey,
      child: _buildActivityLog(),
    );

    if (_screenWidth < 800) {
      // Mobile: horizontally scrollable, left side 90% width, activity peeks from right
      final hPad = 12.0;

      return Column(
        children: [
          Container(
            color: Theme.of(context).colorScheme.muted,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _Tabs(
              controller: _horizontalScrollController,
              leftWidth: _screenWidth - 50,
              hasErrors: _activityLog.any((e) => e.isError),
            ),
          ),
          Divider(),
          Expanded(
            child: PageView(
              controller: _horizontalScrollController,
              scrollDirection: Axis.horizontal,
              physics: const PageScrollPhysics(),
              children: [
                SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: hPad,
                    right: hPad,
                    bottom: widget.isMobile ? MediaQuery.viewPaddingOf(context).bottom + 20 : 0,
                  ),
                  child: leftColumn,
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.gray.shade900 : Color(0xFFF8FAFB),
                    border: Border(
                      left: BorderSide(color: Theme.of(context).colorScheme.border, width: 1),
                      bottom: BorderSide(color: Theme.of(context).colorScheme.border, width: 1),
                    ),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      right: 20,
                      bottom: widget.isMobile ? MediaQuery.viewPaddingOf(context).bottom + 20 : 0,
                    ),
                    child: activityColumn,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Desktop: two-column layout
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Gap(20),
        Expanded(
          child: SingleChildScrollView(
            child: leftColumn,
          ),
        ),
        Container(
          height: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.gray.shade900 : Color(0xFFF8FAFB),
            border: Border(
              left: BorderSide(color: Theme.of(context).colorScheme.border, width: 1),
              bottom: BorderSide(color: Theme.of(context).colorScheme.border, width: 1),
            ),
          ),
          padding: EdgeInsets.symmetric(vertical: 20),
          constraints: BoxConstraints(maxWidth: min(500, MediaQuery.sizeOf(context).width * 0.4)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(right: 20),
            child: activityColumn,
          ),
        ),
      ],
    );
  }

  // ── Flow row ──────────────────────────────────────────────────────

  static const _chipSize = 26.0;

  late final PageController _horizontalScrollController = PageController();

  Widget _buildFlowRow(SupportedApp? trainerApp, List<TrainerConnection> enabledTrainers) {
    final isConnected = enabledTrainers.any((t) => t.isConnected.value);
    final appName = trainerApp?.name ?? '-';
    final compact = _screenWidth < 518;

    // Find first active flow for the chip animation
    final activeDeviceId = _flowButton.keys.firstOrNull;

    final flowStack = Stack(
      key: _flowRowKey,
      clipBehavior: Clip.none,
      children: [
        // Flow lines (painted BEHIND content)
        if (_hasMeasured &&
            _bicycleCenterX != null &&
            _bicycleCenterY != null &&
            _logoCenterY != null &&
            _logoLeftX != null &&
            _logoRightX != null &&
            _trainerLabelCenterX != null &&
            _trainerCenterY != null)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _HorizontalFlowPainter(
                  bicycleX: _bicycleCenterX!,
                  bicycleY: _bicycleCenterY!,
                  logoLeftX: _logoLeftX!,
                  logoRightX: _logoRightX!,
                  logoCenterY: _logoCenterY!,
                  trainerCenterX: _trainerLabelCenterX!,
                  trainerCenterY: _trainerCenterY!,
                  color: BKColor.mainEnd,
                  isTrainerConnected: isConnected,
                ),
              ),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            KeyedSubtree(
              key: _bicycleKey,
              child: Lottie.asset('assets/bicycle.json', width: 80, height: 60, animate: _isInForeground),
            ),
            Expanded(
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _errorBannerController,
                    builder: (context, child) {
                      final t = compact
                          ? 0.0
                          : CurvedAnimation(
                              parent: _errorBannerController,
                              curve: Curves.easeOutCubic,
                            ).value;
                      return Padding(
                        padding: EdgeInsets.only(bottom: 12 * (1 - t)),
                        child: child,
                      );
                    },
                    child: KeyedSubtree(
                      key: _logoKey,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset('icon.png', width: 40, height: 40),
                      ),
                    ),
                  ),
                  // Error banner below logo (wide layout)
                  _buildErrorBanner(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 21),
              child: KeyedSubtree(
                key: _trainerLabelKey,
                child: TrainerLabel(name: appName),
              ),
            ),
          ],
        ),
        // Animated flow chip (on top of everything)
        if (activeDeviceId != null) _buildAnimatedFlowChip(activeDeviceId, isConnected),
      ],
    );

    if (compact) {
      return Column(
        children: [
          flowStack,
          // Error banner below the flow row (compact layout)
          _buildErrorBanner(),
        ],
      );
    }

    return flowStack;
  }

  Widget _buildAnimatedFlowChip(String deviceId, bool isTrainerConnected) {
    final controller = _flowControllers[deviceId];
    final button = _flowButton[deviceId];
    final isError = _flowIsError[deviceId] ?? false;
    if (controller == null || button == null) return const SizedBox.shrink();
    if (_bicycleCenterX == null || _logoCenterX == null || _logoCenterY == null || _bicycleCenterY == null) {
      return const SizedBox.shrink();
    }

    // Left curve: bicycle → logo left
    final lP0 = Offset(_bicycleCenterX!, _bicycleCenterY!);
    final lP1 = Offset((_bicycleCenterX! + (_logoLeftX ?? _logoCenterX!)) / 2, _logoCenterY!);
    final lP2 = Offset(_logoLeftX ?? _logoCenterX!, _logoCenterY!);

    // Right curve: logo right → trainer center
    final rP0 = Offset(_logoRightX ?? _logoCenterX!, _logoCenterY!);
    final rP1 = Offset(((_logoRightX ?? _logoCenterX!) + (_trainerLabelCenterX ?? _logoCenterX!)) / 2, _logoCenterY!);
    final rP2 = Offset(_trainerLabelCenterX ?? _logoCenterX!, _trainerCenterY ?? _logoCenterY!);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        final travelT = Curves.easeOutCubic.transform(t.clamp(0.0, 1.0));

        final Offset pos;
        final bool showResult;

        if (isError) {
          // Follow left curve from bicycle to logo
          pos = _quadBezier(travelT, lP0, lP1, lP2);
          showResult = travelT > 0.4;
        } else if (isTrainerConnected) {
          // Follow left curve then right curve
          if (travelT <= 0.5) {
            pos = _quadBezier(travelT * 2, lP0, lP1, lP2);
          } else {
            pos = _quadBezier((travelT - 0.5) * 2, rP0, rP1, rP2);
          }
          showResult = travelT >= 0.95;
        } else {
          // No trainer: follow left curve to logo
          pos = _quadBezier(travelT, lP0, lP1, lP2);
          showResult = travelT >= 0.95;
        }

        double opacity = 1.0;
        if (t < 0.08) {
          opacity = t / 0.08;
        } else if (t > 0.82) {
          opacity = (1.0 - t) / 0.18;
        }

        return Positioned(
          left: pos.dx - _chipSize / 2,
          top: pos.dy - _chipSize / 2,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: _buildFlowChip(
              button: button,
              isError: isError,
              showResult: showResult,
            ),
          ),
        );
      },
    );
  }

  Widget _buildFlowChip({
    required ControllerButton button,
    required bool isError,
    required bool showResult,
  }) {
    final Color bgColor;
    final Widget icon;

    if (showResult && isError) {
      bgColor = const Color(0xFFEF4444);
      icon = const Icon(LucideIcons.x, size: 14, color: Colors.white);
    } else if (showResult) {
      bgColor = const Color(0xFF22C55E);
      icon = const Icon(LucideIcons.check, size: 14, color: Colors.white);
    } else {
      bgColor = BKColor.mainEnd;
      icon = Icon(
        button.action?.icon ?? LucideIcons.chevronDown,
        size: 12,
        color: Colors.white,
      );
    }

    return Container(
      width: _chipSize,
      height: _chipSize,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: bgColor.withValues(alpha: 0.45),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(child: icon),
    );
  }

  // ── Controller card ───────────────────────────────────────────────

  Future<void> _openControllerSettings(BaseDevice device) async {
    await context.push(ControllerSettingsPage(device: device));
    _clearErrorBanner();
    setState(() {});
  }

  Future<void> _openTrainerConnectionSettings() async {
    await context.push(const TrainerConnectionSettingsPage());
    _clearErrorBanner();
    setState(() {});
  }

  void _clearErrorBanner() {
    if (_latestError != null) {
      _errorBannerController.reverse().then((_) {
        if (mounted) setState(() => _latestError = null);
      });
    }
  }

  // ── Trainer card ──────────────────────────────────────────────────

  Widget _buildTrainerCard(
    SupportedApp? trainerApp,
    List<TrainerConnection> enabledTrainers,
  ) {
    final appName = trainerApp?.name ?? 'No app selected';

    return Card(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Button.ghost(
            onPressed: _openTrainerConnectionSettings,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Gap(4),
                _buildSectionHeader(icon: Icons.monitor, title: AppLocalizations.of(context).trainerConnection),
                const Gap(16),
                Row(
                  spacing: 12,
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.muted,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(appName).small.semiBold,
                            Icon(
                              Icons.keyboard_arrow_down,
                              size: 14,
                              color: Theme.of(context).colorScheme.mutedForeground,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.muted,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Icon(
                          LucideIcons.settings,
                          size: 14,
                          color: Theme.of(context).colorScheme.mutedForeground,
                        ),
                      ),
                    ),
                  ],
                ),
                if (enabledTrainers.isNotEmpty) ...[
                  const Gap(12),
                  for (final enabledTrainer in enabledTrainers) ...[
                    _buildTrainerConnectionRow(enabledTrainer),
                    if (enabledTrainer != enabledTrainers.last) const Gap(8),
                  ],
                  const Gap(12),
                ] else ...[
                  const Gap(12),
                  Text(context.i18n.noConnectionMethodIsConnectedOrActive).small.muted,
                  const Gap(12),
                ],
              ],
            ),
          ),
          Divider(thickness: 0.5),
          TrainerFeatures(withCard: false),
        ],
      ),
    );
  }

  Widget _buildTrainerConnectionRow(TrainerConnection trainer) {
    final connected = trainer.isConnected.value;
    final started = trainer.isStarted.value;

    return Row(
      children: [
        StatusIcon(
          icon: trainer.type.icon,
          status: connected,
          started: started,
        ),
        const Gap(8),
        Expanded(
          child: connected ? Text(trainer.title).small.semiBold : Text(trainer.title).small.muted,
        ),
      ],
    );
  }

  // ── Activity log ────────────────────────────────────────────────────

  Widget _buildActivityLog() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Row(
          children: [
            Gap(16),
            Expanded(
              child: _buildSectionHeader(icon: Icons.list, title: 'Activity'),
            ),
            GhostButton(
              onPressed: _clearActivityLog,
              child: Text('Clear').xSmall.muted,
            ),
          ],
        ),
        AnimatedList(
          key: _activityListKey,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          initialItemCount: _activityLog.length,
          itemBuilder: (context, index, animation) {
            return _buildAnimatedActivityItem(_activityLog[index], index, animation);
          },
        ),
      ],
    );
  }

  Widget _buildAnimatedActivityItem(_ActivityEntry entry, int index, Animation<double> animation) {
    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
      child: FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (index > 0)
              Divider(
                color: Theme.of(context).colorScheme.border.withAlpha(160),
                endIndent: 16,
                indent: 16,
                thickness: 0.5,
              ),
            _buildActivityRow(entry, isLatest: index == 0),
          ],
        ),
      ),
    );
  }

  void _clearActivityLog() {
    for (int i = _activityLog.length - 1; i >= 0; i--) {
      final entry = _activityLog[i];
      _activityListKey.currentState?.removeItem(
        i,
        (context, animation) => _buildAnimatedActivityItem(entry, i, animation),
        duration: const Duration(milliseconds: 200),
      );
    }
    _activityLog.clear();
    setState(() {});
  }

  Widget _buildActivityRow(_ActivityEntry entry, {required bool isLatest}) {
    final button = entry.button;
    final isError = entry.isError;
    final isSuccess = entry.isSuccess;

    final actionText = entry.message;

    // Time
    final ago = DateTime.now().difference(entry.time);
    final String timeText;
    if (ago.inSeconds < 2) {
      timeText = AppLocalizations.of(context).justNow;
    } else if (ago.inSeconds < 60) {
      timeText = '${ago.inSeconds}s ago';
    } else {
      timeText = '${ago.inMinutes}m ago';
    }

    // Row bg
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color rowBg;
    if (isError) {
      rowBg = isDark ? const Color(0x1AEF4444) : const Color(0xFFFEF2F2);
    } else if (entry.isWarning) {
      rowBg = isDark ? const Color(0x1AF59E0B) : const Color(0xFFFFFBEB);
    } else if (isSuccess) {
      rowBg = isDark ? const Color(0x1A22C55E) : const Color(0xFFF0FDFA);
    } else if (entry.button == null) {
      rowBg = Color(0xFFDBEAFE);
    } else {
      rowBg = Colors.transparent;
    }

    // Error fix action
    final errorFix = _errorFixAction(entry);

    const size = 14.0;
    // Leading icon
    final Widget leadingIcon;
    if (button != null) {
      leadingIcon = (!isSuccess)
          ? ButtonWidget(button: button, size: size - 4, color: const Color(0xFFEF4444))
          : ButtonWidget(button: button, size: size - 4, color: const Color(0xFF22C55E));
    } else if (entry.alertLevel == LogLevel.LOGLEVEL_ERROR) {
      leadingIcon = Icon(LucideIcons.circleX, size: 16, color: const Color(0xFFEF4444));
    } else if (entry.alertLevel == LogLevel.LOGLEVEL_WARNING) {
      leadingIcon = Icon(LucideIcons.triangleAlert, size: 16, color: const Color(0xFFF59E0B));
    } else if (entry.button == null) {
      leadingIcon = Icon(LucideIcons.bluetooth, size: 16, color: Color(0xFF2563EB));
    } else {
      leadingIcon = Icon(LucideIcons.info, size: 16, color: Theme.of(context).colorScheme.mutedForeground);
    }

    return SizedBox(
      width: double.infinity,
      child: Basic(
        padding: EdgeInsets.all(16),
        leading: Container(
          width: 22,
          height: 24,
          decoration: BoxDecoration(
            color: rowBg,
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: leadingIcon,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            isError ? Text(actionText, style: TextStyle(color: Color(0xFFEF4444))).small : Text(actionText).small,
            if (errorFix != null) ...[
              Gap(4),
              OutlineButton(
                onPressed: errorFix.$2,
                child: Text(errorFix.$1).xSmall,
              ),
            ],
            if (entry.onTap != null && entry.buttonTitle != null) ...[
              Gap(4),
              OutlineButton(
                onPressed: entry.onTap!,
                child: Text(entry.buttonTitle!).xSmall,
              ),
            ],
          ],
        ),
        trailing: Text(timeText).xSmall.muted,
      ),
    );
  }

  (String, VoidCallback)? _errorFixAction(_ActivityEntry entry) {
    final result = entry.result;
    if (result is! Error) return null;
    final button = entry.button;
    if (button == null) return null;

    final device = core.connection.controllerDevices
        .where((d) => d.availableButtons.any((b) => b.name == button.name))
        .firstOrNull;

    return switch (result.type) {
      ErrorType.noActionAssigned || ErrorType.noKeymapSet => (
        'Configure button mapping',
        () {
          if (device != null) {
            _openControllerSettings(device);
          } else {
            _openTrainerConnectionSettings();
          }
        },
      ),
      ErrorType.noConnectionMethod || ErrorType.trainerNotConnected => (
        'Open connection settings',
        () => _openTrainerConnectionSettings(),
      ),
      ErrorType.proRequired => (
        AppLocalizations.of(context).goPro,
        () {}, // handled elsewhere
      ),
      ErrorType.headwindNotConnected => (
        'Connect Headwind fan',
        () {}, // no dedicated page
      ),
      ErrorType.other => null,
    };
  }

  Widget _buildErrorBanner() {
    final entry = _latestError;
    if (entry == null && _errorBannerController.value == 0) {
      return const SizedBox.shrink();
    }

    return KeyedSubtree(
      key: _errorBannerKey,
      child: SizeTransition(
        sizeFactor: CurvedAnimation(
          parent: _errorBannerController,
          curve: Curves.easeOutCubic,
        ),
        axisAlignment: -1.0,
        child: entry != null
            ? Padding(
                padding: const EdgeInsets.only(top: 4),
                child: AnimatedBuilder(
                  animation: _errorShakeController,
                  builder: (context, child) {
                    final t = _errorShakeController.value;
                    final scale = 1.0 + 0.03 * sin(t * pi);
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: Stack(
                    alignment: Alignment.topCenter,
                    clipBehavior: Clip.none,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: 400),
                            child: Card(
                              padding: EdgeInsets.all(2),
                              borderRadius: BorderRadius.circular(22),
                              child: _buildActivityRow(entry, isLatest: true),
                            ),
                          ),
                        ),
                      ),
                      if (_logoCenterX != null)
                        Positioned(
                          left: _logoCenterX! - 5,
                          top: 0,
                          child: SizedBox(
                            width: 14,
                            height: 7,
                            child: CustomPaint(
                              painter: _BubblePointerPainter(
                                fillColor: Theme.of(context).colorScheme.card,
                                borderColor: Theme.of(context).colorScheme.border,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildSectionHeader({required IconData icon, required String title}) {
    return ColoredTitle(text: title, icon: icon);
  }
}

// ── Animated button press widget ────────────────────────────────────

class _AnimatedButtonWidget extends StatefulWidget {
  final ControllerButton button;
  final int pressGeneration;

  const _AnimatedButtonWidget({super.key, required this.button, required this.pressGeneration});

  @override
  State<_AnimatedButtonWidget> createState() => _AnimatedButtonWidgetState();
}

class _AnimatedButtonWidgetState extends State<_AnimatedButtonWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0), weight: 70),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(_AnimatedButtonWidget old) {
    super.didUpdateWidget(old);
    if (widget.pressGeneration != old.pressGeneration && widget.pressGeneration > 0) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.scale(
        scale: _scale.value,
        child: child,
      ),
      child: ButtonWidget(button: widget.button, color: Colors.gray),
    );
  }
}

class _Tabs extends StatefulWidget {
  final ScrollController controller;
  final double leftWidth;
  final bool hasErrors;

  const _Tabs({super.key, required this.controller, required this.leftWidth, required this.hasErrors});

  @override
  State<_Tabs> createState() => _TabsState();
}

class _TabsState extends State<_Tabs> {
  @override
  void initState() {
    widget.controller.addListener(_update);
    super.initState();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_update);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _Tabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hasErrors != widget.hasErrors) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tabs(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      expand: true,
      onChanged: (index) {
        if (index == 1) {
          widget.controller.animateTo(
            widget.leftWidth,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        } else {
          widget.controller.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      },
      index: widget.controller.hasClients && widget.controller.offset > widget.leftWidth / 2 ? 1 : 0,
      children: [
        TabItem(
          child: Text('Main'),
        ),
        TabItem(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Activity'),
              if (widget.hasErrors) ...[
                Gap(6),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.destructive.withAlpha(160),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _update() {
    setState(() {});
  }
}
