import 'package:swift_control/utils/keymap/apps/biketerra.dart';
import 'package:swift_control/utils/keymap/apps/training_peaks.dart';

import '../keymap.dart';
import 'custom_app.dart';
import 'my_whoosh.dart';

abstract class SupportedApp {
  final String packageName;
  final String name;
  final Keymap keymap;

  const SupportedApp({required this.name, required this.packageName, required this.keymap});

  static final List<SupportedApp> supportedApps = [MyWhoosh(), TrainingPeaks(), Biketerra(), CustomApp()];

  @override
  String toString() {
    return runtimeType.toString();
  }
}
