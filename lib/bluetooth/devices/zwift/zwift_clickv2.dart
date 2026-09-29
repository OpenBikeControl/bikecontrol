import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/utils/click_v2_onboarding.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/widgets/controller/controller_layout.dart';
import 'package:bike_control/widgets/unlock_toggle.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_unlock.dart' show zwiftUnlockBlogUrl;

// The shared bridge moved to the unlock capability; re-exported for callers
// that have always imported it from here.
export 'package:bike_control/bluetooth/devices/zwift/zwift_unlock.dart'
    show ftmsEmulator, bridgeServesStandardDirconPort;

class ZwiftClickV2 extends ZwiftRide {
  ZwiftClickV2(super.scanResult, {List<ControllerButton>? availableButtons})
    : super(
        isBeta: true,
        availableButtons:
            availableButtons ??
            [
              ZwiftButtons.navigationLeft,
              ZwiftButtons.navigationRight,
              ZwiftButtons.navigationUp,
              ZwiftButtons.navigationDown,
              ZwiftButtons.a,
              ZwiftButtons.b,
              ZwiftButtons.y,
              ZwiftButtons.z,
              ZwiftButtons.shiftUpLeft,
              ZwiftButtons.shiftUpRight,
            ],
      );

  /// The Click V2 always runs through the unlock-with-Zwift machinery — its
  /// left puck is locked to Zwift whichever mode the rider picked.
  @override
  bool get usesZwiftUnlock => true;

  @override
  bool get offersUnlockModes => true;

  @override
  String get unlockKeyPrefix => 'clickV2';

  @override
  String get unlockHelpUrl => zwiftUnlockBlogUrl;

  @override
  List<int> get startCommand => ZwiftConstants.RIDE_ON + ZwiftConstants.RESPONSE_START_CLICK_V2;

  @override
  String get latestFirmwareVersion => '1.2.0';

  @override
  bool get canVibrate => false;

  @override
  ControllerLayout get controllerLayout => ControllerLayout(
    aspectRatio: 494.86 / 252.86,
    shape: ContourShape.pill,
    svgAsset: 'assets/contours/zwift_click_v2.svg',
    positions: {
      // Left puck — navigation diamond + minus (shift-up-left) under "down".
      ZwiftButtons.navigationUp: const Offset(0.227, 0.25),
      ZwiftButtons.navigationLeft: const Offset(0.119, 0.44),
      ZwiftButtons.navigationRight: const Offset(0.335, 0.44),
      ZwiftButtons.navigationDown: const Offset(0.227, 0.62),
      ZwiftButtons.shiftUpLeft: const Offset(0.227, 0.87),
      // Right puck — face-button diamond. Per the physical device: Y top,
      // Z left, A right, B bottom. Plus (shift-up-right) sits under B.
      ZwiftButtons.y: const Offset(0.773, 0.25),
      ZwiftButtons.z: const Offset(0.665, 0.44),
      ZwiftButtons.a: const Offset(0.870, 0.44),
      ZwiftButtons.b: const Offset(0.773, 0.62),
      ZwiftButtons.shiftUpRight: const Offset(0.773, 0.87),
    },
  );

  /// The name written to the ignored-devices list alongside the id. Matched
  /// back by [ClickV2Onboarding.restoreLeftSides], which has to recognise both
  /// this and [ZwiftClickV2LeftSide.label]: in the legacy representation the
  /// left puck IS this unified controller.
  static const label = 'Zwift Click V2';

  @override
  String toString() {
    return screenshotControllerNamesAnonymised ? 'Controller' : label;
  }

  /// Held out of the connect queue until the rider has chosen an unlock mode.
  /// Zwift Click V2 behaviour depends entirely on that choice, so connecting
  /// first would hand them a controller that half-works for reasons they have
  /// not been told about yet.
  @override
  bool get shouldAutoConnect => !ClickV2Onboarding.isPending;

  @override
  Future<void> connect() async {
    // Mirrors ProxyDevice: stay listed and keep the queue's listener wiring,
    // but open no transport and run no handshake while onboarding is pending.
    if (!shouldAutoConnect) return;
    await super.connect();
  }

  @override
  List<Widget> showAdditionalInformation(BuildContext context) {
    // The unlock modes are a Zwift-specific caveat and name the controller
    // outright — neither belongs on an anonymized store board.
    if (screenshotMode) return [];
    return [
      // The unified controller is where unlock-with-Zwift lands the rider, so
      // the way back into the explainer has to be here too — otherwise
      // arriving on it is a one-way trip with no route to right-side-only.
      // Empty children: unlike the left puck, this card shows its unlock
      // warnings in every mode (below), not only in unlock-with-Zwift.
      const UnlockToggle(children: []),
      ...unlockWarnings(context),
    ];
  }
}
