import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/pages/proxy_device_details/metric_card.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/emulators/definitions/proxy_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class LiveMetricsSection extends StatelessWidget {
  final ProxyDevice device;
  const LiveMetricsSection({super.key, required this.device});

  ProxyBikeDefinition? get _def =>
      device.emulator.activeDefinition is ProxyBikeDefinition
          ? device.emulator.activeDefinition as ProxyBikeDefinition
          : null;

  @override
  Widget build(BuildContext context) {
    final def = _def;
    if (def == null) {
      return const SizedBox.shrink();
    }
    return Column(
      spacing: 10,
      children: [
        Row(
          spacing: 10,
          children: [
            _bind<int?>(def.powerW, (v) => MetricCard(
                  icon: LucideIcons.zap,
                  iconColor: const Color(0xFFF59E0B),
                  label: 'POWER',
                  value: v?.toString(),
                  unit: 'W',
                )),
            _bind<int?>(def.heartRateBpm, (v) => MetricCard(
                  icon: LucideIcons.heart,
                  iconColor: const Color(0xFFEF4444),
                  label: 'HEART',
                  value: v?.toString(),
                  unit: 'bpm',
                )),
          ],
        ),
        Row(
          spacing: 10,
          children: [
            _bind<int?>(def.cadenceRpm, (v) => MetricCard(
                  icon: LucideIcons.rotateCw,
                  iconColor: const Color(0xFF8B5CF6),
                  label: 'CADENCE',
                  value: v?.toString(),
                  unit: 'rpm',
                )),
            _bind<double?>(def.speedKph, (v) => MetricCard(
                  icon: LucideIcons.gauge,
                  iconColor: const Color(0xFF0EA5E9),
                  label: 'SPEED',
                  value: v?.toStringAsFixed(1),
                  unit: 'km/h',
                )),
          ],
        ),
      ],
    );
  }

  Widget _bind<T>(ValueListenable<T> ln, Widget Function(T) build) {
    return ValueListenableBuilder<T>(
      valueListenable: ln,
      builder: (_, v, _) => build(v),
    );
  }
}
