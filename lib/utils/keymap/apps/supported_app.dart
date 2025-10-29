import 'package:swift_control/main.dart';
import 'package:swift_control/utils/keymap/apps/biketerra.dart';
import 'package:swift_control/utils/keymap/apps/training_peaks.dart';
import 'package:swift_control/utils/keymap/apps/zwift.dart';
import 'package:swift_control/utils/requirements/multi.dart';

import '../keymap.dart';
import 'custom_app.dart';
import 'my_whoosh.dart';

abstract class SupportedApp {
  final List<Target> compatibleTargets;
  final String packageName;
  final String name;
  final Keymap keymap;
  final ConnectionType? connectionType;

  const SupportedApp({
    required this.name,
    required this.packageName,
    required this.keymap,
    required this.compatibleTargets,
    this.connectionType,
  });

  static final List<SupportedApp> supportedApps = [
    MyWhoosh(),
    Zwift(),
    TrainingPeaks(),
    Biketerra(),
    CustomApp(),
  ];

  @override
  String toString() {
    return runtimeType.toString();
  }
}
