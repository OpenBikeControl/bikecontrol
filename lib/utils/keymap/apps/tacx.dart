import 'package:bike_control/bluetooth/devices/elite/elite_square.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/services.dart';
import 'package:prop/prop.dart' show BikeControlMdnsMarkers;

import '../keymap.dart';

/// Tacx Training (Garmin), https://tacxtraining.com.
///
/// The app pairs no external controllers — no OpenBikeControl, no Zwift
/// Click/Play/Ride — so [connections] is empty: buttons reach it as simulated
/// keystrokes (the Local method), and gears come from the Bridge, which does
/// the virtual shifting itself.
///
/// What Tacx does take from us is the trainer. It looks for trainers on the
/// local network, which is the advertisement the Bridge already publishes; see
/// [mdnsProductId] for the one extra field it wants to see there.
class Tacx extends SupportedApp {
  /// Product identifier the Bridge announces in its network trainer
  /// advertisement while Tacx is the selected app, so the app lists the Bridge
  /// among the trainers it can connect to. Value and reasoning in `prop`
  /// ([BikeControlMdnsMarkers.tacxProductId]).
  static const String mdnsProductId = BikeControlMdnsMarkers.tacxProductId;

  @override
  List<(AppConnectionMethod, ConnectionSupport)> get connections => const [];

  @override
  String? get officialUrl => 'https://tacxtraining.com';

  @override
  Map<String, String> get trainerMdnsTxt => const {'product-id': mdnsProductId};

  /// Tacx Training for Windows is a Microsoft Store (UWP) app: it lists the
  /// Bridge on the same PC but can never open a connection to it.
  @override
  bool get windowsStoreApp => true;

  Tacx()
    : super(
        name: 'Tacx Training',
        packageName: 'TacxTraining',
        officialIntegration: false,
        // Every entry mirrors a row of Tacx's Settings → Keyboard Shortcuts
        // screen. That screen is the complete list — there is no shift, steer,
        // select or menu shortcut to map, which is why those actions are absent
        // here rather than guessed at.
        keymap: Keymap(
          keyPairs: [
            // Space — "Pause or Resume Training".
            KeyPair(
              buttons: [ZwiftButtons.z, EliteSquareButtons.z],
              physicalKey: PhysicalKeyboardKey.space,
              logicalKey: LogicalKeyboardKey.space,
              inGameAction: InGameAction.pause,
            ),
            // Esc — "Quit Training". Ends the session, so it sits on the same
            // button every other app uses for Back rather than on a paddle.
            KeyPair(
              buttons: [ZwiftButtons.b, EliteSquareButtons.b],
              physicalKey: PhysicalKeyboardKey.escape,
              logicalKey: LogicalKeyboardKey.escape,
              inGameAction: InGameAction.back,
            ),
            // L — "Skip Current Step" (workout interval).
            KeyPair(
              buttons: [ZwiftButtons.y, EliteSquareButtons.y],
              physicalKey: PhysicalKeyboardKey.keyL,
              logicalKey: LogicalKeyboardKey.keyL,
              inGameAction: InGameAction.skipInterval,
            ),
            // Tab — "Change Training Views".
            ...ControllerButton.values
                .filter((e) => e.action == InGameAction.toggleUi)
                .map(
                  (b) => KeyPair(
                    buttons: [b],
                    physicalKey: PhysicalKeyboardKey.tab,
                    logicalKey: LogicalKeyboardKey.tab,
                    inGameAction: InGameAction.toggleUi,
                  ),
                ),
            // ↑ / ↓ — "Increase/Decrease Difficulty". Tacx scales the workout
            // setpoint, which is what Increase/Decrease Resistance means here.
            KeyPair(
              buttons: [ZwiftButtons.navigationUp],
              physicalKey: PhysicalKeyboardKey.arrowUp,
              logicalKey: LogicalKeyboardKey.arrowUp,
              inGameAction: InGameAction.increaseResistance,
            ),
            KeyPair(
              buttons: [ZwiftButtons.navigationDown],
              physicalKey: PhysicalKeyboardKey.arrowDown,
              logicalKey: LogicalKeyboardKey.arrowDown,
              inGameAction: InGameAction.decreaseResistance,
            ),
            ...ControllerButton.values
                .filter((e) => e.action == InGameAction.increaseResistance)
                .map(
                  (b) => KeyPair(
                    buttons: [b],
                    physicalKey: PhysicalKeyboardKey.arrowUp,
                    logicalKey: LogicalKeyboardKey.arrowUp,
                    inGameAction: InGameAction.increaseResistance,
                  ),
                ),
            ...ControllerButton.values
                .filter((e) => e.action == InGameAction.decreaseResistance)
                .map(
                  (b) => KeyPair(
                    buttons: [b],
                    physicalKey: PhysicalKeyboardKey.arrowDown,
                    logicalKey: LogicalKeyboardKey.arrowDown,
                    inGameAction: InGameAction.decreaseResistance,
                  ),
                ),
            // ← / → — "Previous/Next Screen". Tacx has no steering, so the
            // D-pad's steer defaults are worth more as page navigation.
            KeyPair(
              buttons: [ZwiftButtons.navigationLeft],
              physicalKey: PhysicalKeyboardKey.arrowLeft,
              logicalKey: LogicalKeyboardKey.arrowLeft,
              inGameAction: InGameAction.navigateLeft,
            ),
            KeyPair(
              buttons: [ZwiftButtons.navigationRight],
              physicalKey: PhysicalKeyboardKey.arrowRight,
              logicalKey: LogicalKeyboardKey.arrowRight,
              inGameAction: InGameAction.navigateRight,
            ),
            ...ControllerButton.values
                .filter((e) => e.action == InGameAction.navigateLeft)
                .map(
                  (b) => KeyPair(
                    buttons: [b],
                    physicalKey: PhysicalKeyboardKey.arrowLeft,
                    logicalKey: LogicalKeyboardKey.arrowLeft,
                    inGameAction: InGameAction.navigateLeft,
                  ),
                ),
            ...ControllerButton.values
                .filter((e) => e.action == InGameAction.navigateRight)
                .map(
                  (b) => KeyPair(
                    buttons: [b],
                    physicalKey: PhysicalKeyboardKey.arrowRight,
                    logicalKey: LogicalKeyboardKey.arrowRight,
                    inGameAction: InGameAction.navigateRight,
                  ),
                ),
            // L — "Skip Current Step" for controllers with a native skip
            // button instead of a face button.
            ...ControllerButton.values
                .filter((e) => e.action == InGameAction.skipInterval)
                .map(
                  (b) => KeyPair(
                    buttons: [b],
                    physicalKey: PhysicalKeyboardKey.keyL,
                    logicalKey: LogicalKeyboardKey.keyL,
                    inGameAction: InGameAction.skipInterval,
                  ),
                ),
            // Space — same, for a native pause button.
            ...ControllerButton.values
                .filter((e) => e.action == InGameAction.pause)
                .map(
                  (b) => KeyPair(
                    buttons: [b],
                    physicalKey: PhysicalKeyboardKey.space,
                    logicalKey: LogicalKeyboardKey.space,
                    inGameAction: InGameAction.pause,
                  ),
                ),
          ],
        ),
      );
}
