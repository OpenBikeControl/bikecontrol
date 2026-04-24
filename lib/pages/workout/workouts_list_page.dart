import 'dart:io';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/services/workout/past_workout.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class WorkoutsListPage extends StatefulWidget {
  const WorkoutsListPage({super.key});

  @override
  State<WorkoutsListPage> createState() => _WorkoutsListPageState();
}

class _WorkoutsListPageState extends State<WorkoutsListPage> {
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
          title: Text(l10n.miniWorkoutPastWorkouts),
          trailing: [
            if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux))
              IconButton.ghost(
                icon: const Icon(LucideIcons.folder, size: 20),
                onPressed: () async {
                  final dir = await core.workoutRepository.rootDirectory();
                  await launchUrl(Uri.file(dir.path));
                },
              ),
          ],
        ),
        const Divider(),
      ],
      child: FutureBuilder<List<PastWorkout>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.miniWorkoutNoPastWorkouts),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(thickness: 0.5),
            itemBuilder: (context, i) => _row(items[i], l10n),
          );
        },
      ),
    );
  }

  Widget _row(PastWorkout w, AppLocalizations l10n) {
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
                Text(w.fileName, style: const TextStyle(fontSize: 11)),
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
}
