import 'package:bike_control/bluetooth/devices/openbikecontrol/protocol_parser.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';

import '../buttons.dart';
import '../keymap.dart';

/// Grimpa (https://www.grimpa.cc) — officially supported via the open
/// OpenBikeControl protocol over Bluetooth. Grimpa runs in the browser (Web
/// Bluetooth) and announces the buttons it understands in its App Information
/// message, so it needs no keyboard keymap.
class Grimpa extends SupportedApp {
  @override
  List<(AppConnectionMethod, ConnectionSupport)> get connections => [
    (AppConnectionMethod.obpBle, ConnectionSupport.supported),
  ];

  @override
  String? get logoAsset => 'assets/grimpa.png';

  @override
  String? get officialUrl => 'https://www.grimpa.cc';

  /// Grimpa finds trainers over Bluetooth only.
  @override
  Set<TrainerConnectionType> get virtualShiftingTransports => const {
    TrainerConnectionType.bluetooth,
  };

  /// The buttons Grimpa lists in its App Information message, so riders can
  /// map them before Grimpa first connects.
  @override
  List<ControllerButton> get defaultObpSupportedButtons => const [
    0x01, // Shift Up
    0x02, // Shift Down
    0x03, // Gear Set
    0x10, // Up
    0x11, // Down
    0x12, // Left
    0x13, // Right
    0x14, // Select
    0x15, // Back
    0x30, // Increase Difficulty
    0x31, // Decrease Difficulty
    0x32, // Skip Interval
    0x33, // Pause
    0x34, // Resume
    0x38, // Change Mode
    0x40, // Camera View
  ].map((id) => OpenBikeProtocolParser.BUTTON_NAMES[id]!).toList();

  Grimpa()
    : super(
        name: 'Grimpa',
        packageName: 'Grimpa',
        officialIntegration: true,
        keymap: Keymap(keyPairs: []),
      );
}
