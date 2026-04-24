import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/workout/mini_workout_page.dart';
import 'package:bike_control/pages/workout/workouts_list_page.dart';
import 'package:bike_control/services/workout/trainer_metrics.dart';
import 'package:bike_control/services/workout/workout_recorder.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class MiniWorkoutCard extends StatelessWidget {
  final ProxyDevice device;
  const MiniWorkoutCard({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final metrics = TrainerMetrics.fromDefinition(device.emulator.activeDefinition);
    if (metrics == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Row(spacing: 8, children: [
            const Icon(LucideIcons.activity, size: 18),
            Text(l10n.miniWorkout, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ]),
          ValueListenableBuilder<WorkoutState>(
            valueListenable: core.workoutRecorder.state,
            builder: (_, s, _) => Button.primary(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => MiniWorkoutPage(device: device)),
                );
              },
              child: Text(s == WorkoutState.idle ? l10n.miniWorkoutStart : l10n.miniWorkoutRecording),
            ),
          ),
          Button.ghost(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WorkoutsListPage()),
            ),
            child: Text(l10n.miniWorkoutPastWorkouts),
          ),
        ],
      ),
    );
  }
}
