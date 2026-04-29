import 'dart:io';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/services/workout/past_workout.dart';
import 'package:bike_control/services/workout/workout_summary.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Reusable list of past workouts. Renders just the list contents (no
/// Scaffold) so it fits inside a sheet, drawer, or full-page Scaffold.
class WorkoutsList extends StatefulWidget {
  /// When true, prepends a small header with the localized title and an
  /// "open folder" action — meant for sheet/drawer usage where there's no
  /// surrounding AppBar.
  final bool showHeader;
  const WorkoutsList({super.key, this.showHeader = false});

  @override
  State<WorkoutsList> createState() => _WorkoutsListState();
}

class _WorkoutsListState extends State<WorkoutsList> {
  late Future<List<PastWorkout>> _future;

  @override
  void initState() {
    super.initState();
    _future = core.workoutRepository.list();
  }

  void _refresh() {
    setState(() {
      _future = core.workoutRepository.list();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<List<PastWorkout>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.showHeader)
              Padding(
                padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.miniWorkoutPastWorkouts,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux))
                      IconButton.ghost(
                        icon: const Icon(LucideIcons.folder, size: 18),
                        onPressed: () async {
                          final dir = await core.workoutRepository.rootDirectory();
                          await launchUrl(Uri.file(dir.path));
                        },
                      ),
                  ],
                ),
              ),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: Text(l10n.miniWorkoutNoPastWorkouts)),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(thickness: 0.5),
                itemBuilder: (context, i) => _row(items[i], l10n),
              ),
          ],
        );
      },
    );
  }

  Widget _row(PastWorkout w, AppLocalizations l10n) {
    final cs = Theme.of(context).colorScheme;
    final summary = w.summary;
    return Button.ghost(
      onPressed: () {}, // row tap reserved for future detail view
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Text(_fmtDate(w.startedAt), style: const TextStyle(fontWeight: FontWeight.w600)),
                if (summary != null)
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: _summaryChips(summary, cs),
                  )
                else
                  Text(w.fileName, style: TextStyle(fontSize: 11, color: cs.mutedForeground)),
              ],
            ),
          ),
          IconButton.ghost(
            icon: const Icon(LucideIcons.share2, size: 18),
            onPressed: () => SharePlus.instance.share(ShareParams(files: [XFile(w.file.path)])),
          ),
          IconButton.ghost(
            icon: const Icon(LucideIcons.trash, size: 18),
            onPressed: () => _confirmDelete(w, l10n),
          ),
        ],
      ),
    );
  }

  List<Widget> _summaryChips(WorkoutSummary s, ColorScheme cs) {
    Widget chip(IconData icon, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: cs.mutedForeground),
        const Gap(4),
        Text(label, style: TextStyle(fontSize: 11, color: cs.mutedForeground)),
      ],
    );

    return [
      chip(LucideIcons.clock, _fmtDuration(s.activeDuration)),
      if (s.distanceKm > 0) chip(LucideIcons.gauge, '${s.distanceKm.toStringAsFixed(1)} km'),
      if (s.avgPowerW > 0) chip(LucideIcons.zap, '${s.avgPowerW} W'),
      if (s.avgHeartRateBpm > 0) chip(LucideIcons.heart, '${s.avgHeartRateBpm} bpm'),
    ];
  }

  Future<void> _confirmDelete(PastWorkout w, AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.miniWorkoutConfirmDeleteTitle),
        content: Text(l10n.miniWorkoutConfirmDeleteBody),
        actions: [
          Button.secondary(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          Button.destructive(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.miniWorkoutDelete),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed == true) {
      await core.workoutRepository.delete(w.file);
      if (!mounted) return;
      _refresh();
    }
  }

  static String _fmtDate(DateTime d) {
    final local = d.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  static String _fmtDuration(Duration d) {
    String two(int v) => v.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }
}
