import 'dart:async';
import 'dart:ui' as ui;

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/trainer_connection.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/pages/controller_settings.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/widgets/ui/button_widget.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

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
}

// ── CustomPainter: 90° routed paths with start/end dots ──────────────
class _FlowLinePainter extends CustomPainter {
  final List<_Lane> lanes;
  final Color color;
  _FlowLinePainter({required this.lanes, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    for (final lane in lanes) {
      final linePaint = Paint()
        ..color = color.withValues(alpha: 0.25)
        ..strokeWidth = 2
        ..strokeCap = ui.StrokeCap.round
        ..strokeJoin = ui.StrokeJoin.miter
        ..style = ui.PaintingStyle.stroke;

      final path = ui.Path()
        ..moveTo(lane.startX, lane.startY)
        ..lineTo(lane.channelX, lane.startY)
        ..lineTo(lane.channelX, lane.endY)
        ..lineTo(lane.endX, lane.endY);
      canvas.drawPath(path, linePaint);

      // Start dot (card right edge)
      final dotPaint = Paint()..color = color;
      canvas.drawCircle(Offset(lane.startX, lane.startY), 4, dotPaint);

      // End dot (trainer card right edge, vertical center)
      canvas.drawCircle(Offset(lane.endX, lane.endY), 4, dotPaint);

      // Down-pointing chevron at vertical center of the connection line
      final midY = (lane.startY + lane.endY) / 2;
      final arrowPaint = Paint()
        ..color = color.withValues(alpha: 0.5)
        ..strokeWidth = 1.5
        ..strokeCap = ui.StrokeCap.round
        ..style = ui.PaintingStyle.stroke;
      final chevron = ui.Path()
        ..moveTo(lane.channelX - 4, midY - 3)
        ..lineTo(lane.channelX, midY + 1)
        ..lineTo(lane.channelX + 4, midY - 3);
      canvas.drawPath(chevron, arrowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FlowLinePainter old) {
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

// ── OverviewPage ─────────────────────────────────────────────────────

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> with TickerProviderStateMixin {
  bool _isTrainerConnected = false;
  late StreamSubscription<BaseNotification> _actionListener;

  // Layout keys
  final GlobalKey _stackKey = GlobalKey();
  final Map<String, GlobalKey> _cardKeys = {};
  final GlobalKey _trainerKey = GlobalKey();

  // Measured pixel positions (relative to the Stack)
  final Map<String, double> _cardRightX = {};
  final Map<String, double> _cardCenterY = {};
  double? _trainerRightX;
  double? _trainerCenterY;
  bool _hasMeasured = false;

  // Per-device flow animation state
  final Map<String, AnimationController> _flowControllers = {};
  final Map<String, ControllerButton> _flowButton = {};
  final Map<String, bool> _flowIsError = {};
  final Map<String, ActionResult> _flowResult = {};
  final Map<String, int> _flowGeneration = {};
  String? _lastPressedDeviceId;

  @override
  void initState() {
    super.initState();
    _actionListener = core.connection.actionStream.listen((notification) {
      if (notification is ButtonNotification && notification.buttonsClicked.isNotEmpty) {
        _onButtonPressed(notification.device, notification.buttonsClicked.first);
      } else if (notification is ActionNotification) {
        _onActionResult(notification.result);
      }
      _refreshTrainerStatus();
    });
    _refreshTrainerStatus();
  }

  void _refreshTrainerStatus() async {
    final connected = await core.logic.isTrainerConnected();
    if (mounted) {
      setState(() => _isTrainerConnected = connected);
    }
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
    _lastPressedDeviceId = id;

    if (!_hasMeasured || !_cardCenterY.containsKey(id) || _trainerCenterY == null) {
      return;
    }

    bool isError = false;
    ActionResult? immediate;
    if (button.action == null) {
      isError = true;
      immediate = const NotHandled('No action assigned');
    } else if (!_isTrainerConnected) {
      isError = true;
      immediate = const Error('Trainer not connected');
    }

    _flowGeneration[id] = (_flowGeneration[id] ?? 0) + 1;
    setState(() {
      _flowButton[id] = button;
      _flowIsError[id] = isError;
      if (immediate != null) {
        _flowResult[id] = immediate;
      } else {
        _flowResult.remove(id);
      }
    });

    final c = _controllerFor(id);
    c.reset();
    c.forward();
  }

  void _onActionResult(ActionResult result) {
    final id = _lastPressedDeviceId;
    if (id == null || !_flowButton.containsKey(id)) return;
    if (_flowResult.containsKey(id)) return;
    setState(() {
      _flowResult[id] = result;
      _flowIsError[id] = result is! Success;
    });
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
    _actionListener.cancel();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final devices = core.connection.controllerDevices;
    final trainerApp = core.settings.getTrainerApp();
    final connectedTrainers = core.logic.connectedTrainerConnections;

    for (final d in devices) {
      _cardKeys.putIfAbsent(d.uniqueId, GlobalKey.new);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measurePositions();
    });

    if (devices.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(icon: Icons.gamepad, title: 'Controllers'),
            const Gap(8),
            _buildEmptyCard('No controllers connected'),
            const Gap(16),
            _buildSectionHeader(icon: Icons.monitor, title: 'Trainer Connection'),
            const Gap(8),
            _buildTrainerCard(trainerApp, connectedTrainers),
          ],
        ),
      );
    }

    final gutterWidth = 12.0 + devices.length * _laneWidth;
    final lanes = _hasMeasured ? _buildLanes(devices) : <_Lane>[];

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(icon: Icons.gamepad, title: 'Controllers'),
                    const Gap(8),
                    for (int i = 0; i < devices.length; i++) ...[
                      if (i > 0) const Gap(8),
                      KeyedSubtree(
                        key: _cardKeys[devices[i].uniqueId],
                        child: _buildControllerCard(devices[i]),
                      ),
                    ],
                    const Gap(16),
                    _buildSectionHeader(icon: Icons.monitor, title: 'Trainer Connection'),
                    const Gap(8),
                    KeyedSubtree(
                      key: _trainerKey,
                      child: _buildTrainerCard(trainerApp, connectedTrainers),
                    ),
                    const Gap(12),
                    if (_isTrainerConnected && trainerApp != null) _buildFlowStatus(devices.first, trainerApp.name),
                  ],
                ),
              ),
              SizedBox(width: gutterWidth + 20),
            ],
          ),
          if (lanes.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _FlowLinePainter(
                    lanes: lanes,
                    color: BKColor.mainEnd,
                  ),
                ),
              ),
            ),
          for (final lane in lanes)
            if (_flowButton.containsKey(lane.deviceId)) _buildAnimatedFlowChip(lane),
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

        final maxProgress = isError ? 0.45 : 1.0;
        final progress = (travelT * maxProgress).clamp(0.0, maxProgress);

        final pos = lane.positionAt(progress);

        double opacity = 1.0;
        if (t < 0.08) {
          opacity = t / 0.08;
        } else if (t > 0.82) {
          opacity = (1.0 - t) / 0.18;
        }

        double scale = 1.0;
        if (isError && travelT >= maxProgress) {
          final p = ((travelT - maxProgress) / (1.0 - maxProgress)).clamp(0.0, 1.0);
          scale = 1.0 + 0.15 * (1.0 - Curves.easeOut.transform(p));
        }

        final showResult = travelT >= maxProgress * 0.95;

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

  void _openControllerSettings(BaseDevice device) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ControllerSettingsPage(device: device)),
    );
  }

  Widget _buildControllerCard(BaseDevice device) {
    return Button.card(
      onPressed: () => _openControllerSettings(device),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          device.showInformation(context),
          const Gap(12),
          Divider(),
          const Gap(12),
          Text(
            'Buttons',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
              color: Theme.of(context).colorScheme.mutedForeground,
            ),
          ),
          const Gap(8),
          Row(
            spacing: 9,
            children: device.availableButtons.map((btn) {
              return ButtonWidget(button: btn);
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Trainer card ──────────────────────────────────────────────────

  Widget _buildTrainerCard(
    SupportedApp? trainerApp,
    List<TrainerConnection> connectedTrainers,
  ) {
    final appName = trainerApp?.name ?? 'No app selected';
    final connectionType = connectedTrainers.isNotEmpty ? connectedTrainers.first.title : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.muted,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(appName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Icon(Icons.keyboard_arrow_down, size: 14, color: Theme.of(context).colorScheme.mutedForeground),
              ],
            ),
          ),
          const Gap(12),
          if (connectionType != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: BKColor.mainEnd.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi, size: 12, color: BKColor.mainEnd),
                  const Gap(4),
                  Text(
                    connectionType,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: BKColor.mainEnd,
                    ),
                  ),
                ],
              ),
            ),
            const Gap(12),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Status',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.mutedForeground,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dot(
                    6,
                    _isTrainerConnected ? const Color(0xFF22C55E) : Theme.of(context).colorScheme.mutedForeground,
                  ),
                  const Gap(4),
                  Text(
                    _isTrainerConnected ? 'Connected' : 'Not connected',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _isTrainerConnected
                          ? const Color(0xFF22C55E)
                          : Theme.of(context).colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Gap(12),
          Divider(),
          const Gap(12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Target Device',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.mutedForeground,
                ),
              ),
              Text('This Device', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
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
                    Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 16, color: Theme.of(context).colorScheme.mutedForeground),
        ],
      ),
    );
  }

  Widget _buildFlowStatus(BaseDevice device, String trainerName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: BKColor.mainEnd.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _dot(6, BKColor.mainEnd),
          const Gap(8),
          Text(
            'Data flowing: ${device.name} → ${trainerName.split(' ').first}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: BKColor.mainEnd,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: BKColor.main),
        const Gap(6),
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.border),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.mutedForeground,
        ),
      ),
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
