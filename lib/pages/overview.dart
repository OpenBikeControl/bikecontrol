import 'dart:async';
import 'dart:ui' as ui;

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/trainer_connection.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/pages/controller_settings.dart';
import 'package:bike_control/pages/trainer_connection_settings.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/widgets/iap_status_widget.dart';
import 'package:bike_control/widgets/ui/button_widget.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:prop/emulators/shared.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../utils/iap/iap_manager.dart';
import 'device.dart';

// ── Data for a single device lane (90° routed path) ──────────────────
class _Lane {
  final String deviceId;
  final double startX, startY;
  final double channelX;
  final double endX, endY;

  const _Lane(
    this.deviceId, {
    required this.startX,
    required this.startY,
    required this.channelX,
    required this.endX,
    required this.endY,
  });

  double get _seg1 => (channelX - startX).abs();
  double get _seg2 => (endY - startY).abs();
  double get _seg3 => (channelX - endX).abs();
  double get totalLength => _seg1 + _seg2 + _seg3;

  Offset positionAt(double t) {
    final total = totalLength;
    if (total == 0) return Offset(startX, startY);
    final d = t * total;
    if (d <= _seg1) {
      final f = _seg1 > 0 ? d / _seg1 : 0.0;
      return Offset(startX + f * (channelX - startX), startY);
    }
    if (d <= _seg1 + _seg2) {
      final f = _seg2 > 0 ? (d - _seg1) / _seg2 : 0.0;
      return Offset(channelX, startY + f * (endY - startY));
    }
    final f = _seg3 > 0 ? (d - _seg1 - _seg2) / _seg3 : 0.0;
    return Offset(channelX + f * (endX - channelX), endY);
  }

  /// Error path: horizontal → vertical straight down to [targetY], then left to [targetX].
  Offset errorPositionAt(double t, double targetX, double targetY) {
    final seg1 = (channelX - startX).abs();
    final seg2 = (targetY - startY).abs();
    final seg3 = (channelX - targetX).abs();
    final total = seg1 + seg2 + seg3;
    if (total == 0) return Offset(startX, startY);
    final d = t * total;
    if (d <= seg1) {
      final f = seg1 > 0 ? d / seg1 : 0.0;
      return Offset(startX + f * (channelX - startX), startY);
    }
    if (d <= seg1 + seg2) {
      final f = seg2 > 0 ? (d - seg1) / seg2 : 0.0;
      return Offset(channelX, startY + f * (targetY - startY));
    }
    final f = seg3 > 0 ? (d - seg1 - seg2) / seg3 : 0.0;
    return Offset(channelX + f * (targetX - channelX), targetY);
  }
}

// ── CustomPainter: 90° routed paths with start/end dots ──────────────
class _FlowLinePainter extends CustomPainter {
  final List<_Lane> lanes;
  final Color color;
  final bool isTrainerConnected;
  _FlowLinePainter({required this.lanes, required this.color, required this.isTrainerConnected});

  @override
  void paint(Canvas canvas, Size size) {
    if (lanes.isEmpty) return;
    const radius = 8.0;

    final redColor = const Color(0xFFEF4444);
    final bottomColor = isTrainerConnected ? color : redColor;

    Paint makeStroke(Color c) => Paint()
      ..color = c
      ..strokeWidth = 4
      ..strokeCap = ui.StrokeCap.round
      ..strokeJoin = ui.StrokeJoin.round
      ..style = ui.PaintingStyle.stroke;

    // Draw all strokes in a layer to prevent alpha accumulation at junctions
    canvas.saveLayer(Offset.zero & size, Paint()..color = const Color(0x73FFFFFF));

    final topPaint = makeStroke(color);
    final bottomPaint = makeStroke(bottomColor);

    for (final lane in lanes) {
      final midY = (lane.startY + lane.endY) / 2;

      // Top portion: horizontal → corner → vertical down to chevron
      final topPath = ui.Path()
        ..moveTo(lane.startX, lane.startY)
        ..lineTo(lane.channelX - radius, lane.startY)
        ..quadraticBezierTo(lane.channelX, lane.startY, lane.channelX, lane.startY + radius)
        ..lineTo(lane.channelX, midY + 6);
      canvas.drawPath(topPath, topPaint);

      // Middle vertical segment: solid if connected, dashed if not
      final segStart = midY + 6;
      final segEnd = lane.endY - radius;
      if (isTrainerConnected) {
        canvas.drawLine(Offset(lane.channelX, segStart), Offset(lane.channelX, segEnd), topPaint);
      } else {
        final dashPaint = makeStroke(redColor);
        const dash = 5.0;
        const gap = 7.0;
        for (double y = segStart; y < segEnd; y += dash + gap) {
          final end = (y + dash).clamp(y, segEnd);
          canvas.drawLine(Offset(lane.channelX, y), Offset(lane.channelX, end), dashPaint);
        }
      }

      // Bottom curve
      final curvePath = ui.Path()
        ..moveTo(lane.channelX, lane.endY - radius)
        ..quadraticBezierTo(lane.channelX, lane.endY, lane.channelX - radius, lane.endY);
      canvas.drawPath(curvePath, bottomPaint);
    }

    // Shared bottom horizontal (once)
    final outerLane = lanes.last;
    canvas.drawLine(
      Offset(outerLane.channelX - radius, outerLane.endY),
      Offset(outerLane.endX, outerLane.endY),
      bottomPaint,
    );

    canvas.restore();

    // Dots and chevrons drawn outside the layer (full opacity)
    final dotPaint = Paint()..color = color;
    final endDotPaint = Paint()..color = (isTrainerConnected ? color : redColor);
    for (final lane in lanes) {
      canvas.drawCircle(Offset(lane.startX, lane.startY), 4, dotPaint);

      final midY = (lane.startY + lane.endY) / 2;
      final arrowPaint = Paint()
        ..color = color.withValues(alpha: 0.5)
        ..strokeWidth = 3
        ..strokeCap = ui.StrokeCap.round
        ..style = ui.PaintingStyle.stroke;
      final chevron = ui.Path()
        ..moveTo(lane.channelX - 5, midY - 4)
        ..lineTo(lane.channelX, midY + 2)
        ..lineTo(lane.channelX + 5, midY - 4);
      canvas.drawPath(chevron, arrowPaint);
    }

    canvas.drawCircle(Offset(outerLane.endX, outerLane.endY), 4, endDotPaint);
  }

  @override
  bool shouldRepaint(covariant _FlowLinePainter old) {
    if (old.isTrainerConnected != isTrainerConnected) return true;
    if (old.lanes.length != lanes.length) return true;
    for (int i = 0; i < lanes.length; i++) {
      final a = old.lanes[i], b = lanes[i];
      if (a.startX != b.startX ||
          a.startY != b.startY ||
          a.channelX != b.channelX ||
          a.endX != b.endX ||
          a.endY != b.endY) {
        return true;
      }
    }
    return false;
  }
}

// ── Activity log entry ───────────────────────────────────────────────

class _ActivityEntry {
  final ControllerButton button;
  final DateTime time;
  final ActionResult result;

  _ActivityEntry({required this.button, required this.time, required this.result});

  bool get isError => result is Error || result is NotHandled;
  bool get isSuccess => result is Success;
}

// ── OverviewPage ─────────────────────────────────────────────────────

class OverviewPage extends StatefulWidget {
  final bool isMobile;
  const OverviewPage({super.key, required this.isMobile});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> with TickerProviderStateMixin {
  late StreamSubscription<BaseNotification> _actionListener;

  late double _screenWidth;

  // Layout keys
  final GlobalKey _stackKey = GlobalKey();
  final Map<String, GlobalKey> _cardKeys = {};
  final GlobalKey _trainerKey = GlobalKey();
  final GlobalKey _errorBannerKey = GlobalKey();

  // Measured pixel positions (relative to the Stack)
  final Map<String, double> _cardRightX = {};
  final Map<String, double> _cardCenterY = {};
  double? _trainerRightX;
  double? _trainerCenterY;
  double? _errorBannerRightX;
  double? _errorBannerCenterY;
  final GlobalKey _activityLogKey = GlobalKey();
  double? _activityLeftX;
  bool _hasMeasured = false;

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
  static const _maxLogEntries = 6;

  // Error banner
  _ActivityEntry? _latestError;
  late final AnimationController _errorBannerController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );

  @override
  void initState() {
    super.initState();
    _actionListener = core.connection.actionStream.listen((notification) {
      Logger.warn('Notification received: ${notification.runtimeType} - $notification');
      if (notification is ButtonNotification && notification.buttonsClicked.isNotEmpty) {
        _onButtonPressed(notification.device, notification.buttonsClicked.first);
      } else if (notification is ActionNotification) {
        _onActionResult(notification.result, notification.button);
      }
    });
  }

  @override
  void didChangeDependencies() {
    _screenWidth = MediaQuery.sizeOf(context).width;
    super.didChangeDependencies();
  }

  // ── Position measurement ──────────────────────────────────────────

  void _measurePositions() {
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null || !stackBox.hasSize) return;

    bool changed = false;

    for (final entry in _cardKeys.entries) {
      final box = entry.value.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final offset = box.localToGlobal(Offset.zero, ancestor: stackBox);
      final rightX = offset.dx + box.size.width;
      final centerY = offset.dy + box.size.height / 2;
      if (_cardRightX[entry.key] != rightX || _cardCenterY[entry.key] != centerY) {
        _cardRightX[entry.key] = rightX;
        _cardCenterY[entry.key] = centerY;
        changed = true;
      }
    }

    final trainerBox = _trainerKey.currentContext?.findRenderObject() as RenderBox?;
    if (trainerBox != null && trainerBox.hasSize) {
      final offset = trainerBox.localToGlobal(Offset.zero, ancestor: stackBox);
      final rightX = offset.dx + trainerBox.size.width;
      final centerY = offset.dy + trainerBox.size.height / 2;
      if (_trainerRightX != rightX || _trainerCenterY != centerY) {
        _trainerRightX = rightX;
        _trainerCenterY = centerY;
        changed = true;
      }
    }

    final errorBox = _errorBannerKey.currentContext?.findRenderObject() as RenderBox?;
    if (errorBox != null && errorBox.hasSize) {
      final offset = errorBox.localToGlobal(Offset.zero, ancestor: stackBox);
      _errorBannerRightX = offset.dx + errorBox.size.width;
      _errorBannerCenterY = offset.dy + errorBox.size.height / 2;
    }

    final activityBox = _activityLogKey.currentContext?.findRenderObject() as RenderBox?;
    if (activityBox != null && activityBox.hasSize) {
      final offset = activityBox.localToGlobal(Offset.zero, ancestor: stackBox);
      _activityLeftX = offset.dx;
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

  void _onActionResult(ActionResult result, ControllerButton button) {
    final entry = _ActivityEntry(button: button, time: DateTime.now(), result: result);
    _activityLog.insert(0, entry);
    if (_activityLog.length > _maxLogEntries) _activityLog.removeLast();

    if (entry.isError) {
      _latestError = entry;
      _errorBannerController.forward(from: 0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _measurePositions();
      });
    } else if (_latestError != null) {
      _errorBannerController.reverse().then((_) {
        if (mounted) setState(() => _latestError = null);
      });
    }

    final id = button.sourceDeviceId;
    if (id == null || !_hasMeasured || !_cardCenterY.containsKey(id) || _trainerCenterY == null) {
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
    for (final c in _flowControllers.values) {
      c.dispose();
    }
    _errorBannerController.dispose();
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

    final gutterWidth = 12.0 + devices.length * _laneWidth;
    final lanes = _hasMeasured ? _buildLanes(devices) : <_Lane>[];

    final leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ValueListenableBuilder(
          valueListenable: IAPManager.instance.isPurchased,
          builder: (context, value, child) => value ? SizedBox.shrink() : IAPStatusWidget(small: false),
        ),
        _buildSectionHeader(icon: Icons.gamepad, title: 'Controllers'),
        DevicePage(
          cardKeys: _cardKeys,
          isMobile: widget.isMobile,
          footerBuilder: (device) {
            final id = device.uniqueId;
            final pressedButton = _pressedButton[id];
            final generation = _pressGeneration[id] ?? 0;
            return [
              const Gap(12),
              Divider(),
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
            setState(() {});
          },
        ),
        const Gap(16),
        _buildErrorBanner(),
        const Gap(16),
        _buildSectionHeader(icon: Icons.monitor, title: 'Trainer Connection'),
        const Gap(8),
        KeyedSubtree(
          key: _trainerKey,
          child: _buildTrainerCard(trainerApp, enabledTrainers),
        ),
      ],
    );

    final activityColumn = KeyedSubtree(
      key: _activityLogKey,
      child: _buildActivityLog(),
    );

    if (_screenWidth < 800) {
      // Mobile: horizontally scrollable, left side 90% width, activity peeks from right
      final screenWidth = _screenWidth;
      final leftWidth = screenWidth * 1;
      final rightWidth = screenWidth * 0.75;
      final hPad = 12.0;

      return Scrollbar(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: SizedBox(
            width: leftWidth + rightWidth,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Stack(
                key: _stackKey,
                clipBehavior: Clip.none,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: leftWidth,
                        child: Padding(
                          padding: EdgeInsets.only(left: hPad, right: gutterWidth + hPad),
                          child: leftColumn,
                        ),
                      ),
                      SizedBox(
                        width: rightWidth,
                        child: Padding(
                          padding: EdgeInsets.only(right: hPad, left: hPad),
                          child: activityColumn,
                        ),
                      ),
                    ],
                  ),
                  if (lanes.isNotEmpty)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _FlowLinePainter(
                            lanes: lanes,
                            color: BKColor.mainEnd,
                            isTrainerConnected: enabledTrainers.any((t) => t.isConnected.value),
                          ),
                        ),
                      ),
                    ),
                  for (final lane in lanes)
                    if (_flowButton.containsKey(lane.deviceId)) _buildAnimatedFlowChip(lane),
                  for (final lane in lanes)
                    if (_flowButton.containsKey(lane.deviceId)) _buildAnimatedActivityChip(lane),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Desktop: two-column layout
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Stack(
        key: _stackKey,
        clipBehavior: Clip.none,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Gap(20),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: gutterWidth),
                  child: leftColumn,
                ),
              ),
              SizedBox(width: gutterWidth + 20),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: SizedBox(
                  width: 400,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: activityColumn,
                  ),
                ),
              ),
            ],
          ),
          if (lanes.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _FlowLinePainter(
                    lanes: lanes,
                    color: BKColor.mainEnd,
                    isTrainerConnected: enabledTrainers.any((t) => t.isConnected.value),
                  ),
                ),
              ),
            ),
          for (final lane in lanes)
            if (_flowButton.containsKey(lane.deviceId)) _buildAnimatedFlowChip(lane),
          for (final lane in lanes)
            if (_flowButton.containsKey(lane.deviceId)) _buildAnimatedActivityChip(lane),
        ],
      ),
    );
  }

  // ── Lane building ─────────────────────────────────────────────────

  static const _chipSize = 26.0;
  static const _laneWidth = 16.0;

  List<_Lane> _buildLanes(List<BaseDevice> devices) {
    final lanes = <_Lane>[];
    if (_trainerCenterY == null || _trainerRightX == null) return lanes;

    for (int i = 0; i < devices.length; i++) {
      final id = devices[i].uniqueId;
      final startX = _cardRightX[id];
      final startY = _cardCenterY[id];
      if (startX == null || startY == null) continue;

      final channelX = startX + 12 + i * _laneWidth;
      lanes.add(
        _Lane(
          id,
          startX: startX,
          startY: startY,
          channelX: channelX,
          endX: _trainerRightX!,
          endY: _trainerCenterY!,
        ),
      );
    }
    return lanes;
  }

  Widget _buildAnimatedFlowChip(_Lane lane) {
    final controller = _flowControllers[lane.deviceId]!;
    final button = _flowButton[lane.deviceId]!;
    final isError = _flowIsError[lane.deviceId] ?? false;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        final travelT = Curves.easeOutCubic.transform(t.clamp(0.0, 1.0));

        final Offset pos;
        final bool showResult;
        if (isError && _errorBannerCenterY != null && _errorBannerRightX != null) {
          pos = lane.errorPositionAt(travelT, _errorBannerRightX!, _errorBannerCenterY!);
          showResult = travelT > 0.2;
        } else {
          pos = lane.positionAt(travelT);
          showResult = travelT >= 0.95;
        }

        double opacity = 1.0;
        if (t < 0.08) {
          opacity = t / 0.08;
        } else if (t > 0.82) {
          opacity = (1.0 - t) / 0.18;
        }

        const scale = 1.0;

        return Positioned(
          left: pos.dx - _chipSize / 2,
          top: pos.dy - _chipSize / 2,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: scale,
              child: _buildFlowChip(
                button: button,
                isError: isError,
                showResult: showResult,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedActivityChip(_Lane lane) {
    if (_activityLeftX == null) return const SizedBox.shrink();
    final controller = _flowControllers[lane.deviceId];
    final button = _flowButton[lane.deviceId];
    final isError = _flowIsError[lane.deviceId] ?? false;
    if (controller == null || button == null) return const SizedBox.shrink();

    final midY = (lane.startY + lane.endY) / 2;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;

        // Appear at 45% of raw animation time (~270ms) — after the main
        // chip has clearly passed the vertical channel center.
        if (t < 0.45) return const SizedBox.shrink();

        // Own eased progress from the split point to end of animation
        final localT = Curves.easeOutCubic.transform(((t - 0.45) / 0.55).clamp(0.0, 1.0));

        final pos = Offset(
          lane.channelX + localT * (_activityLeftX! - lane.channelX),
          midY,
        );

        double opacity = 1.0;
        if (localT < 0.15) {
          opacity = localT / 0.15;
        } else if (t > 0.82) {
          opacity = (1.0 - t) / 0.18;
        }

        final travelT = Curves.easeOutCubic.transform(t.clamp(0.0, 1.0));
        final showResult = isError ? travelT > 0.2 : travelT >= 0.95;

        return Positioned(
          left: pos.dx - _chipSize / 2,
          top: pos.dy - _chipSize / 2,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: _buildFlowChip(button: button, isError: isError, showResult: showResult),
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
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ControllerSettingsPage(device: device)),
    );
    setState(() {});
  }

  Future<void> _openTrainerConnectionSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TrainerConnectionSettingsPage()),
    );
    setState(() {});
  }

  // ── Trainer card ──────────────────────────────────────────────────

  Widget _buildTrainerCard(
    SupportedApp? trainerApp,
    List<TrainerConnection> enabledTrainers,
  ) {
    final appName = trainerApp?.name ?? 'No app selected';

    return Button.card(
      onPressed: _openTrainerConnectionSettings,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                      Icon(Icons.keyboard_arrow_down, size: 14, color: Theme.of(context).colorScheme.mutedForeground),
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
                  child: Icon(LucideIcons.settings, size: 14, color: Theme.of(context).colorScheme.mutedForeground),
                ),
              ),
            ],
          ),
          if (enabledTrainers.isNotEmpty) ...[
            const Gap(12),
            Divider(),
            const Gap(12),
            for (final enabledTrainer in enabledTrainers) ...[
              _buildTrainerConnectionRow(enabledTrainer),
              if (enabledTrainer != enabledTrainers.last) const Gap(6),
            ],
          ],
          const Gap(12),
          Divider(),
          const Gap(12),
          _buildFeatureBanner(
            icon: Icons.radio,
            iconColor: BKColor.mainEnd,
            bgColor: BKColor.mainEnd.withValues(alpha: 0.03),
            iconBgColor: BKColor.mainEnd.withValues(alpha: 0.08),
            title: 'Device Mirroring',
            description: 'BLE-to-WiFi bridge for trainers & sensors',
            isNew: true,
          ),
          const Gap(8),
          _buildFeatureBanner(
            icon: Icons.bolt,
            iconColor: BKColor.main,
            bgColor: BKColor.main.withValues(alpha: 0.03),
            iconBgColor: BKColor.main.withValues(alpha: 0.08),
            title: 'Legacy Trainer Support',
            description: 'Virtual shifting for older smart trainers',
            isNew: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTrainerConnectionRow(TrainerConnection trainer) {
    final connected = trainer.isConnected.value;
    final started = trainer.isStarted.value;
    final color = connected ? const Color(0xFF22C55E) : Theme.of(context).colorScheme.mutedForeground;

    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: connected ? null : Theme.of(context).colorScheme.muted,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(
            trainer.type.icon,
            size: 16,
            color: connected ? null : Theme.of(context).colorScheme.mutedForeground,
          ),
        ),
        const Gap(8),
        Expanded(
          child: connected ? Text(trainer.title).xSmall.semiBold : Text(trainer.title).xSmall.semiBold.muted,
        ),
        if (started && !connected)
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: Theme.of(context).colorScheme.mutedForeground,
            ),
          )
        else
          _dot(6, color),
      ],
    );
  }

  // ── Shared widgets ────────────────────────────────────────────────

  Widget _buildFeatureBanner({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color iconBgColor,
    required String title,
    required String description,
    bool isNew = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const Gap(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title).small.semiBold,
                    if (isNew) ...[
                      const Gap(6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: iconColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'NEW',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const Gap(2),
                Text(description).xSmall.muted,
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 16, color: Theme.of(context).colorScheme.mutedForeground),
        ],
      ),
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
            Expanded(
              child: _buildSectionHeader(icon: Icons.list, title: 'Activity'),
            ),
            GhostButton(
              onPressed: () => setState(() => _activityLog.clear()),
              child: Text('Clear').xSmall.muted,
            ),
          ],
        ),
        Card(
          fillColor: Theme.of(context).colorScheme.background,
          filled: true,
          padding: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (int i = 0; i < _activityLog.length; i++) ...[
                if (i > 0) Divider(),
                _buildActivityRow(_activityLog[i], isLatest: i == 0),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivityRow(_ActivityEntry entry, {required bool isLatest}) {
    final button = entry.button;
    final isError = entry.isError;
    final isSuccess = entry.isSuccess;

    final actionText = entry.result.message;

    // Time
    final ago = DateTime.now().difference(entry.time);
    final String timeText;
    if (ago.inSeconds < 2) {
      timeText = 'Just now';
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
    } else if (isSuccess) {
      rowBg = isDark ? const Color(0x1A22C55E) : const Color(0xFFF0FDFA);
    } else {
      rowBg = Colors.transparent;
    }

    // Error fix action
    final errorFix = _errorFixAction(entry);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: rowBg,
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: ButtonWidget(button: button),
          ),
          const Gap(8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                isError ? Text(actionText).xSmall.italic.muted : Text(actionText).xSmall,
                if (errorFix != null)
                  GhostButton(
                    onPressed: errorFix.$2,
                    child: Text(errorFix.$1).xSmall,
                  )
                else
                  Text(timeText).xSmall.muted,
              ],
            ),
          ),
          if (isSuccess) Icon(LucideIcons.check, size: 14, color: const Color(0xFF22C55E)),
          if (isError) Icon(LucideIcons.triangleAlert, size: 14, color: const Color(0xFFF59E0B)),
        ],
      ),
    );
  }

  (String, VoidCallback)? _errorFixAction(_ActivityEntry entry) {
    final result = entry.result;
    if (result is! Error) return null;

    final device = core.connection.controllerDevices
        .where((d) => d.availableButtons.any((b) => b.name == entry.button.name))
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
        'Upgrade to Pro',
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
    return KeyedSubtree(
      key: _errorBannerKey,
      child: AnimatedBuilder(
        animation: _errorBannerController,
        builder: (context, _) {
          final entry = _latestError;
          if (entry == null && _errorBannerController.value == 0) {
            return const SizedBox.shrink();
          }

          final t = CurvedAnimation(
            parent: _errorBannerController,
            curve: Curves.easeOutCubic,
          ).value;

          return Align(
            alignment: Alignment.centerRight,
            child: Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(20 * (1 - t), 0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxW = (constraints.maxWidth * 0.8).clamp(0.0, 400.0);
                    return ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxW),
                      child: entry != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: _buildActivityRow(entry, isLatest: true),
                            )
                          : const SizedBox.shrink(),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: BKColor.main),
        const Gap(6),
        Text(title).xSmall,
      ],
    );
  }

  Widget _dot(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
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
      child: ButtonWidget(button: widget.button),
    );
  }
}
