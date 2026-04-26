import 'dart:io';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/services/workout/workout_summary.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> showWorkoutSummaryDialog({
  required BuildContext context,
  required WorkoutSummary summary,
  required File fitFile,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _WorkoutSummaryDialog(summary: summary, fitFile: fitFile),
  );
}

class _WorkoutSummaryDialog extends StatelessWidget {
  final WorkoutSummary summary;
  final File fitFile;
  const _WorkoutSummaryDialog({required this.summary, required this.fitFile});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.miniWorkoutSummaryTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            _grid(context, l10n),
            const Gap(12),
            Row(
              spacing: 8,
              children: [
                Expanded(
                  child: Button.primary(
                    leading: const Icon(LucideIcons.share2, size: 16),
                    onPressed: () => SharePlus.instance.share(
                      ShareParams(files: [XFile(fitFile.path)], text: l10n.workoutShareText(fitFile.uri.pathSegments.last)),
                    ),
                    child: Text(l10n.miniWorkoutShareFit),
                  ),
                ),
                Expanded(
                  child: Button.secondary(
                    leading: const Icon(LucideIcons.folder, size: 16),
                    onPressed: () => _openFolder(fitFile),
                    child: Text(l10n.miniWorkoutOpenFolder),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        Button.outline(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
      ],
    );
  }

  Widget _grid(BuildContext context, AppLocalizations l10n) {
    final tiles = <Widget>[
      _tile(
        context: context,
        icon: LucideIcons.timer,
        color: const Color(0xFF0EA5E9),
        label: l10n.miniWorkoutSummaryDuration,
        value: _fmtDuration(summary.activeDuration),
      ),
      _tile(
        context: context,
        icon: LucideIcons.route,
        color: const Color(0xFF10B981),
        label: l10n.miniWorkoutSummaryDistance,
        value: '${summary.distanceKm.toStringAsFixed(2)} km',
      ),
      _tile(
        context: context,
        icon: LucideIcons.zap,
        color: const Color(0xFFF59E0B),
        label: l10n.miniWorkoutSummaryAvgPower,
        value: '${summary.avgPowerW} W',
      ),
      _tile(
        context: context,
        icon: LucideIcons.trendingUp,
        color: const Color(0xFFD97706),
        label: l10n.miniWorkoutSummaryMaxPower,
        value: '${summary.maxPowerW} W',
      ),
      _tile(
        context: context,
        icon: LucideIcons.rotateCw,
        color: const Color(0xFF8B5CF6),
        label: l10n.miniWorkoutSummaryAvgCadence,
        value: '${summary.avgCadenceRpm} rpm',
      ),
      _tile(
        context: context,
        icon: LucideIcons.gauge,
        color: const Color(0xFF0EA5E9),
        label: l10n.miniWorkoutSummaryAvgSpeed,
        value: '${summary.avgSpeedKph.toStringAsFixed(1)} km/h',
      ),
      if (summary.avgHeartRateBpm > 0)
        _tile(
          context: context,
          icon: LucideIcons.heart,
          color: const Color(0xFFEF4444),
          label: l10n.miniWorkoutSummaryAvgHeartRate,
          value: '${summary.avgHeartRateBpm} bpm',
        ),
      if (summary.maxHeartRateBpm > 0)
        _tile(
          context: context,
          icon: LucideIcons.heartPulse,
          color: const Color(0xFFDC2626),
          label: l10n.miniWorkoutSummaryMaxHeartRate,
          value: '${summary.maxHeartRateBpm} bpm',
        ),
    ];
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      rows.add(
        Row(
          spacing: 10,
          children: [
            Expanded(child: tiles[i]),
            Expanded(child: i + 1 < tiles.length ? tiles[i + 1] : const SizedBox.shrink()),
          ],
        ),
      );
    }
    return Column(spacing: 10, children: rows);
  }

  Widget _tile({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          Row(
            spacing: 6,
            children: [
              Icon(icon, size: 14, color: color),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: cs.mutedForeground,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3),
          ),
        ],
      ),
    );
  }

  Future<void> _openFolder(File file) async {
    final dir = file.parent.path;
    if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      await launchUrl(Uri.file(dir));
    } else {
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    }
  }

  static String _fmtDuration(Duration d) {
    String two(int v) => v.toString().padLeft(2, '0');
    final h = d.inHours, m = d.inMinutes.remainder(60), s = d.inSeconds.remainder(60);
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }
}
