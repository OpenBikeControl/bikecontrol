import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
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

  /// Which Bridge (Virtual Shifting) transport this connection actually rides on.
  /// Used by [CoreLogic.preferredBridgeTransport] to decide whether a Virtual
  /// Shifting session over this app should advertise via WiFi (FTMS/mDNS) or
  /// Bluetooth (BLE peripheral). `null` for connection methods that don't carry
  /// trainer telemetry (e.g. [ConnectionMethodType.local]).
  TrainerConnectionType? get virtualShiftingTransport => switch (type) {
        ConnectionMethodType.bluetooth => TrainerConnectionType.bluetooth,
        ConnectionMethodType.network => TrainerConnectionType.wifi,
        ConnectionMethodType.openBikeControl => null,
        ConnectionMethodType.local => null,
      };

  Future<ActionResult> sendAction(KeyPair keyPair, {required bool isKeyDown, required bool isKeyUp});

  Widget getTile();
}
