import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:flutter/foundation.dart';

abstract class TrainerConnection {
  final String title;
  List<InGameAction> supportedActions;

  final ValueNotifier<bool> isStarted = ValueNotifier(false);
  final ValueNotifier<bool> isConnected = ValueNotifier(false);

  TrainerConnection({required this.title, required this.supportedActions});

  Future<ActionResult> sendAction(KeyPair keyPair, {required bool isKeyDown, required bool isKeyUp});
}
