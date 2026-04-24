import 'dart:io';
import 'package:bike_control/services/workout/workout_summary.dart';
import 'package:flutter/widgets.dart';

class WorkoutSummaryPage extends StatelessWidget {
  final WorkoutSummary summary;
  final File fitFile;
  const WorkoutSummaryPage({super.key, required this.summary, required this.fitFile});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
