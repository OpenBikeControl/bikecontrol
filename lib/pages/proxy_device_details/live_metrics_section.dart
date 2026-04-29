import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/proxy_device_details/metric_card.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/emulators/definitions/proxy_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class LiveMetricsSection extends StatelessWidget {
  final ProxyDevice device;
  const LiveMetricsSection({super.key, required this.device});

  _LiveMetrics? _metrics() {
    final def = device.emulator.activeDefinition;
    if (def is ProxyBikeDefinition) {
      return _LiveMetrics(
        power: def.powerW,
        heartRate: def.heartRateBpm,
        cadence: def.cadenceRpm,
        speed: def.speedKph,
      );
    }
    if (def is FitnessBikeDefinition) {
      return _LiveMetrics(
        power: def.powerW,
        heartRate: def.heartRateBpm,
        cadence: def.cadenceRpm,
        speed: def.speedKph,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _metrics();
    if (metrics == null) {
      return const SizedBox.shrink();
    }
    return Column(
      spacing: 10,
      children: [
        Row(
          spacing: 10,
          children: [
            _bind<int?>(
              metrics.power,
              (v) => MetricCard(
                icon: LucideIcons.zap,
                iconColor: const Color(0xFFF59E0B),
                label: AppLocalizations.of(context).powerLabel,
                value: v?.toString(),
                unit: 'W',
              ),
            ),
            _bind<int?>(
              metrics.heartRate,
              (v) => MetricCard(
                icon: LucideIcons.heart,
                iconColor: const Color(0xFFEF4444),
                label: AppLocalizations.of(context).heartLabel,
                value: v?.toString(),
                unit: 'bpm',
              ),
            ),
          ],
        ),
        Row(
          spacing: 10,
          children: [
            _bind<int?>(
              metrics.cadence,
              (v) => MetricCard(
                icon: LucideIcons.rotateCw,
                iconColor: const Color(0xFF8B5CF6),
                label: AppLocalizations.of(context).cadenceLabel,
                value: v?.toString(),
                unit: 'rpm',
              ),
            ),
            _bind<double?>(
              metrics.speed,
              (v) => MetricCard(
                icon: LucideIcons.gauge,
                iconColor: const Color(0xFF0EA5E9),
                label: AppLocalizations.of(context).speedLabel,
                value: v?.toStringAsFixed(1),
                unit: 'km/h',
              ),
            ),
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

class _LiveMetrics {
  final ValueListenable<int?> power;
  final ValueListenable<int?> heartRate;
  final ValueListenable<int?> cadence;
  final ValueListenable<double?> speed;

  const _LiveMetrics({
    required this.power,
    required this.heartRate,
    required this.cadence,
    required this.speed,
  });
}
