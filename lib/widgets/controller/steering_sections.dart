import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:bike_control/bluetooth/devices/gyroscope/gyroscope_steering.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/obc_steering_angle.dart';
import 'package:bike_control/bluetooth/devices/steering_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show recordError, shownKeymapName;
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/widgets/controller/steering_gauge.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/beta_pill.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:bike_control/widgets/ui/bk_status_dot.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The OpenBikeControl transports a steering angle can go out on right now.
Iterable<SteeringAngleSink> _liveSinks() => core.logic.connectedTrainerConnections.whereType<SteeringAngleSink>();

/// The top of a steering input's page: its name and state, one sentence on
/// what it does, and the live instrument — large, since this is the page
/// where the rider checks that it reads their bars right.
class SteeringHeroCard extends StatelessWidget {
  const SteeringHeroCard({super.key, required this.device, required this.keymap});

  final BaseDevice device;
  final Keymap? keymap;

  SteeringDevice get _steering => device as SteeringDevice;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final battery = device is BluetoothDevice ? (device as BluetoothDevice).batteryLevel : null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(BkComponentThemes.cardRadius),
        boxShadow: bkCardShadow(context),
      ),
      child: ValueListenableBuilder<bool>(
        valueListenable: _steering.steeringCalibrated,
        builder: (context, calibrated, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                BkIconTile(icon: device.icon),
                const Gap(BkGroupedRow.gap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Row(
                        spacing: 6,
                        children: [
                          Flexible(
                            child: Text(
                              device.displayName(context),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.typography.base.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.2),
                            ),
                          ),
                          if (device.isBeta) const BetaPill(),
                        ],
                      ),
                      Row(
                        spacing: 8,
                        children: [
                          Flexible(
                            child: BkStatusDot(
                              label: calibrated ? l.steeringReady : l.steeringCalibrating,
                              tone: calibrated ? BkStatusTone.success : BkStatusTone.neutral,
                            ),
                          ),
                          if (battery != null)
                            Text('$battery%', style: context.typography.xSmall.copyWith(color: cs.mutedForeground)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Gap(12),
            Text(l.steeringDescription, style: context.typography.small.copyWith(color: cs.mutedForeground)),
            const Gap(16),
            SteeringGauge(
              angle: _steering.steeringAngle,
              calibrated: _steering.steeringCalibrated,
              threshold: _steering.steeringThreshold,
              leftAction: steeringActionFor(keymap, _steering.steerLeftButton),
              rightAction: steeringActionFor(keymap, _steering.steerRightButton),
              large: true,
            ),
            if (!calibrated) ...[
              const Gap(12),
              Text(
                _calibratingHint(l),
                style: context.typography.xSmall.copyWith(color: cs.mutedForeground),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _calibratingHint(AppLocalizations l) {
    final d = device;
    if (d is GyroscopeSteering) return d.useMagnetometer ? l.calibratingMagnetometerHint : l.calibratingSensorsHint;
    return l.steeringHoldStill;
  }
}

/// What a steering input does in the trainer app and how it is tuned: each
/// direction with the action it sends (tap to change the action — there are
/// no triggers to pick), the exact angle when the app takes it, then the dead
/// zone, the sensor and Recalibrate.
class SteeringSections extends StatefulWidget {
  const SteeringSections({super.key, required this.device, required this.keymap, required this.onUpdate});

  final BaseDevice device;
  final Keymap? keymap;
  final VoidCallback onUpdate;

  @override
  State<SteeringSections> createState() => _SteeringSectionsState();
}

class _SteeringSectionsState extends State<SteeringSections> {
  static const double _indent = BkGroupedSection.inset + BkIconTile.size + BkGroupedRow.gap;

  SteeringDevice get _steering => widget.device as SteeringDevice;

  void _changed() {
    if (mounted) setState(() {});
    widget.onUpdate();
  }

  Widget _direction({required bool left}) {
    final l = AppLocalizations.of(context);
    final button = left ? _steering.steerLeftButton : _steering.steerRightButton;
    final icon = left ? LucideIcons.chevronsLeft : LucideIcons.chevronsRight;
    final title = left ? l.steeringTurnLeft : l.steeringTurnRight;
    final keymap = widget.keymap;
    final action = steeringActionFor(keymap, button);
    return Builder(
      key: ValueKey('steering-direction-${left ? 'left' : 'right'}'),
      builder: (context) => BkGroupedRow(
        icon: icon,
        title: title,
        trailing: Text(action ?? l.noActionAssigned),
        chevron: keymap != null,
        onPressed: keymap == null
            ? null
            : () => openSteeringActionEditor(
                context,
                device: widget.device,
                button: button,
                keymap: keymap,
                icon: icon,
                label: title,
                onUpdate: _changed,
              ),
      ),
    );
  }

  Future<void> _pickDeadZone(BuildContext context) async {
    final current = core.settings.getPhoneSteeringThreshold().round();
    showDropdown<void>(
      context: context,
      consumeOutsideTaps: true,
      builder: (c) => DropdownMenu(
        children: [
          for (var v = 3; v <= 12; v++)
            MenuButton(
              leading: v == current ? const Icon(LucideIcons.check, size: 16) : const SizedBox(width: 16),
              onPressed: (_) {
                core.settings.setPhoneSteeringThreshold(v);
                _changed();
              },
              child: Text(steeringDeadZoneText(v.toDouble())),
            ),
        ],
      ),
    );
  }

  Future<void> _setMagnetometer(GyroscopeSteering phone, bool value) async {
    try {
      await phone.setUseMagnetometer(value);
    } catch (e, s) {
      recordError(e, s, context: 'SteeringSections.setUseMagnetometer');
    }
    _changed();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final device = widget.device;
    final phone = device is GyroscopeSteering ? device : null;
    final recalibrate = device is RecalibratableSteering ? device as RecalibratableSteering : null;
    final sinks = _liveSinks().toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListenableBuilder(
          listenable: Listenable.merge([for (final s in sinks) s.connectedApp]),
          builder: (context, _) {
            final exactAngle = steeringAngleReachesApp(sinks) && obcSteeringAngleAllowed(_steering);
            final app = core.settings.getTrainerApp();
            return BkGroupedSection(
              header: l.steeringInTrainerApp,
              dividerIndent: _indent,
              children: [
                _direction(left: true),
                _direction(left: false),
                if (exactAngle)
                  BkGroupedRow(
                    key: const ValueKey('steering-exact-angle'),
                    icon: LucideIcons.gauge,
                    title: l.steeringExactAngle,
                    subtitle: l.steeringExactAngleBody(app == null ? '–' : shownKeymapName(app.name)),
                    trailing: BkStatusDot(label: l.steeringExactAngleActive),
                  ),
              ],
            );
          },
        ),
        const Gap(24),
        BkGroupedSection(
          header: l.preferences,
          dividerIndent: _indent,
          children: [
            Builder(
              key: const ValueKey('steering-dead-zone'),
              builder: (context) => BkGroupedRow(
                icon: LucideIcons.moveHorizontal,
                title: l.steeringDeadZone,
                subtitle: l.steeringDeadZoneBody,
                trailing: Text(steeringDeadZoneText(_steering.steeringThreshold)),
                chevron: phone != null,
                onPressed: phone == null ? null : () => _pickDeadZone(context),
              ),
            ),
            if (phone != null)
              BkGroupedRow(
                key: const ValueKey('steering-magnetometer'),
                icon: LucideIcons.compass,
                title: l.useMagnetometerMode,
                trailing: Switch(value: phone.useMagnetometer, onChanged: (v) => _setMagnetometer(phone, v)),
                onPressed: () => _setMagnetometer(phone, !phone.useMagnetometer),
              ),
            if (recalibrate != null)
              _RecalibrateRow(calibrated: _steering.steeringCalibrated, onPressed: recalibrate.recalibrate),
          ],
        ),
      ],
    );
  }
}

class _RecalibrateRow extends StatelessWidget {
  const _RecalibrateRow({required this.calibrated, required this.onPressed});

  final ValueListenable<bool> calibrated;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: calibrated,
      builder: (context, isCalibrated, _) => BkGroupedRow(
        key: const ValueKey('steering-recalibrate'),
        icon: LucideIcons.crosshair,
        title: l.steeringRecalibrate,
        trailing: isCalibrated ? null : SmallProgressIndicator(),
        onPressed: isCalibrated ? onPressed : null,
      ),
    );
  }
}
