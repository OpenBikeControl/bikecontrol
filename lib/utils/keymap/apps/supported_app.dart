import 'dart:ui';

import 'package:accessibility/accessibility.dart';
import 'package:swift_control/utils/keymap/apps/training_peaks.dart';

import '../../single_line_exception.dart';
import '../buttons.dart';
import '../keymap.dart';
import 'custom_app.dart';
import 'my_whoosh.dart';

abstract class SupportedApp {
  final String packageName;
  final String name;
  final Keymap keymap;

  Offset resolveTouchPosition({required ZwiftButton action, required WindowEvent? windowInfo}) {
    if (this is CustomApp) {
      final keyPair = keymap.getKeyPair(action);
      if (keyPair == null || keyPair.touchPosition == Offset.zero) {
        throw SingleLineException("No key pair found for action: $action");
      }
      return keyPair.touchPosition;
    }
    return Offset.zero;
  }

  const SupportedApp({required this.name, required this.packageName, required this.keymap});

  static final List<SupportedApp> supportedApps = [MyWhoosh(), TrainingPeaks(), CustomApp()];

  @override
  String toString() {
    return runtimeType.toString();
  }
}
