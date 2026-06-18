import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/widgets/ui/connection_method.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

export 'package:bike_control/widgets/ui/connection_method.dart' show ConnectionMethodType, ConnectionMethodTypee;

abstract class TrainerConnection {
  /// Re-evaluated on each access so the localized title follows the active
  /// locale (the value isn't frozen at construction time).
  final String Function() _titleBuilder;
  String get title => _titleBuilder();
  final ConnectionMethodType type;
  List<InGameAction> supportedActions;

  final ValueNotifier<bool> isStarted = ValueNotifier(false);
  final ValueNotifier<bool> isConnected = ValueNotifier(false);

  TrainerConnection({required String Function() title, required this.type, required this.supportedActions})
    : _titleBuilder = title;

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

  Widget getTile({bool small = false});
}
