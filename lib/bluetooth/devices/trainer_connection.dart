import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/widgets/ui/connection_method.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

export 'package:bike_control/widgets/ui/connection_method.dart' show ConnectionMethodTypee;

abstract class TrainerConnection {
  final String title;
  final ConnectionMethodType type;
  List<InGameAction> supportedActions;

  final ValueNotifier<bool> isStarted = ValueNotifier(false);
  final ValueNotifier<bool> isConnected = ValueNotifier(false);

  TrainerConnection({required this.title, required this.type, required this.supportedActions});

  Future<ActionResult> sendAction(KeyPair keyPair, {required bool isKeyDown, required bool isKeyUp});

  Widget getTile();
}
