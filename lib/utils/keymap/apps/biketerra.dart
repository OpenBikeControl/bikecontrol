import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/services.dart';

import '../buttons.dart';
import '../keymap.dart';

/// Biketerra (https://biketerra.com) — officially supported via the open
/// OpenBikeControl protocol over Bluetooth. Biketerra announces the buttons it
/// understands over the protocol; the Zwift-style Bluetooth connection and the
/// keyboard shortcuts below remain for setups that don't use it.
class Biketerra extends SupportedApp {
  @override
  String? get officialUrl => 'https://biketerra.com';

  @override
  String get helpSlug => 'biketerra';

  @override
  List<(AppConnectionMethod, ConnectionSupport)> get connections => [
    (AppConnectionMethod.obpBle, ConnectionSupport.supported),
    (AppConnectionMethod.zwiftBle, ConnectionSupport.beta),
  ];

  /// Biketerra pairs trainers over Bluetooth only — it has no WiFi (DirCon)
  /// trainer connection, so the WiFi bridge is never offered.
  @override
  Set<TrainerConnectionType> get virtualShiftingTransports => const {TrainerConnectionType.bluetooth};

  @override
  String? get logoAsset => 'assets/biketerra.png';

  @override
  String? get logoUrl => 'https://bikecontrol.app/images/partners/biketerra-icon.png';

  Biketerra()
    : super(
        name: 'Biketerra',
        packageName: "Biketerra",
        officialIntegration: true,
        // Each pair keeps its button's in-game action: that is what goes out
        // over OpenBikeControl. The keyboard keys are only the fallback.
        keymap: Keymap(
          keyPairs: [
            ...ControllerButton.values
                .filter((e) => e.action == InGameAction.shiftDown)
                .map(
                  (b) => KeyPair(
                    buttons: [b],
                    physicalKey: PhysicalKeyboardKey.keyS,
                    logicalKey: LogicalKeyboardKey.keyS,
                    inGameAction: b.action,
                  ),
                ),
            ...ControllerButton.values
                .filter((e) => e.action == InGameAction.shiftUp)
                .map(
                  (b) => KeyPair(
                    buttons: [b],
                    physicalKey: PhysicalKeyboardKey.keyW,
                    logicalKey: LogicalKeyboardKey.keyW,
                    inGameAction: b.action,
                  ),
                ),
            ...ControllerButton.values
                .filter((e) => e.action == InGameAction.navigateRight)
                .map(
                  (b) => KeyPair(
                    buttons: [b],
                    physicalKey: PhysicalKeyboardKey.arrowRight,
                    logicalKey: LogicalKeyboardKey.arrowRight,
                    inGameAction: b.action,
                  ),
                ),
            ...ControllerButton.values
                .filter((e) => e.action == InGameAction.navigateLeft)
                .map(
                  (b) => KeyPair(
                    buttons: [b],
                    physicalKey: PhysicalKeyboardKey.arrowLeft,
                    logicalKey: LogicalKeyboardKey.arrowLeft,
                    inGameAction: b.action,
                  ),
                ),

            ...ControllerButton.values
                .filter((e) => e.action == InGameAction.toggleUi)
                .map(
                  (b) => KeyPair(
                    buttons: [b],
                    physicalKey: PhysicalKeyboardKey.keyU,
                    logicalKey: LogicalKeyboardKey.keyU,
                    inGameAction: b.action,
                  ),
                ),
          ],
        ),
      );
}
