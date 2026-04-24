import 'dart:io';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/services/workout/workout_summary.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class WorkoutSummaryPage extends StatelessWidget {
  final WorkoutSummary summary;
  final File fitFile;
  const WorkoutSummaryPage({super.key, required this.summary, required this.fitFile});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      headers: [
        AppBar(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          leading: [
            IconButton.ghost(
              icon: const Icon(LucideIcons.arrowLeft, size: 24),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
          title: Text(l10n.miniWorkoutSummaryTitle),
        ),
        const Divider(),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            _row(l10n.miniWorkoutSummaryDuration, _fmtDuration(summary.activeDuration)),
            _row(l10n.miniWorkoutSummaryDistance, '${summary.distanceKm.toStringAsFixed(2)} km'),
            _row(l10n.miniWorkoutSummaryAvgPower, '${summary.avgPowerW} W'),
            _row(l10n.miniWorkoutSummaryMaxPower, '${summary.maxPowerW} W'),
            _row(l10n.miniWorkoutSummaryAvgCadence, '${summary.avgCadenceRpm} rpm'),
            _row(l10n.miniWorkoutSummaryAvgSpeed, '${summary.avgSpeedKph.toStringAsFixed(1)} km/h'),
            if (summary.avgHeartRateBpm > 0)
              _row(l10n.miniWorkoutSummaryAvgHeartRate, '${summary.avgHeartRateBpm} bpm'),
            if (summary.maxHeartRateBpm > 0)
              _row(l10n.miniWorkoutSummaryMaxHeartRate, '${summary.maxHeartRateBpm} bpm'),
            const Gap(16),
            Button.primary(
              onPressed: () => SharePlus.instance.share(
                ShareParams(files: [XFile(fitFile.path)], text: 'Workout ${fitFile.uri.pathSegments.last}'),
              ),
              child: Text(l10n.miniWorkoutShareFit),
            ),
            Button.secondary(
              onPressed: () => _openFolder(fitFile),
              child: Text(l10n.miniWorkoutOpenFolder),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(value),
          ],
        ),
      );

  Future<void> _openFolder(File file) async {
    final dir = file.parent.path;
    // url_launcher opens `file://` dirs in Finder/Explorer on desktop; on
    // mobile nothing sensible happens, so we fall back to sharing the file
    // which at least lets the user inspect it through the system sheet.
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
