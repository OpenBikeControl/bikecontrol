import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2_left_side.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/widgets/controller/controller_layout.dart';
import 'package:bike_control/widgets/new_unlock_method_toggle.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/prop.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class ZwiftClickV2RightSide extends ZwiftRide {
  ZwiftClickV2RightSide(super.scanResult)
    : super(
        isBeta: false,
        availableButtons: [
          ZwiftButtons.a,
          ZwiftButtons.b,
          ZwiftButtons.y,
          ZwiftButtons.z,
          ZwiftButtons.shiftUpRight,
        ],
      );

  @override
  String get latestFirmwareVersion => '1.2.0';

  @override
  bool get canVibrate => false;

  @override
  List<int> get startCommand => ZwiftConstants.RIDE_ON + ZwiftConstants.RESPONSE_START_CLICK_V2;

  @override
  ControllerLayout get controllerLayout => ControllerLayout(
    aspectRatio: 215 / 252.9,
    shape: ContourShape.pill,
    svgAsset: 'assets/contours/zwift_click_v2_right_side.svg',
    positions: {
      // Right puck — face-button diamond. Per the physical device: Y top,
      // Z left, A right, B bottom. Plus (shift-up-right) sits under B.
      ZwiftButtons.y: const Offset(0.500, 0.25),
      ZwiftButtons.z: const Offset(0.252, 0.44),
      ZwiftButtons.a: const Offset(0.723, 0.44),
      ZwiftButtons.b: const Offset(0.500, 0.62),
      ZwiftButtons.shiftUpRight: const Offset(0.500, 0.87),
    },
  );

  @override
  String toString() {
    return "Zwift Click V2 (right)";
  }

  @override
  Future<void> setupHandshake() async {
    await sendCommandBuffer(Uint8List.fromList(startCommand));
    ClickLogic.setupHandshake(services!, device.deviceId, isRight: true);
  }

  @override
  List<Widget> showAdditionalInformation(BuildContext context) {
    final hasLeftSide = core.connection.devices.whereType<ZwiftClickV2LeftSide>().isNotEmpty;
    if (!hasLeftSide) return [];
    return [
      Text(context.i18n.unlock_useRightSideOnlyDescription).xSmall.normal,
      SizedBox(
        width: double.infinity,
        child: Button.outline(
          onPressed: () => _useRightSideOnly(context),
          child: Text(context.i18n.unlock_useRightSideOnly),
        ),
      ),
    ];
  }

  /// Detail page only: the new-unlock-method toggle lives under "Preferences"
  /// so it doesn't show on the compact overview card.
  @override
  Widget? buildPreferences(BuildContext context) {
    final superPreferences = super.buildPreferences(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        if (superPreferences != null) superPreferences,
        const NewUnlockMethodToggle(),
      ],
    );
  }

  /// Switches to a "right side only" setup: the left controller (which needs
  /// unlocking / restarts) is dropped and the right side covers gear shifting
  /// on its own — ＋ still shifts up, B takes over shifting down.
  Future<void> _useRightSideOnly(BuildContext context) async {
    // Read localised text before the awaits below remove this card.
    final confirmation = context.i18n.unlock_rightSideOnlyConfigured;

    // Ignore (don't just disconnect) the left side, otherwise the active scan
    // reconnects it within seconds. Ignoring is persistent and reversible from
    // the Ignored Devices list.
    final leftSides = core.connection.devices.whereType<ZwiftClickV2LeftSide>().toList();
    for (final left in leftSides) {
      await core.connection.disconnect(left, forget: true, persistForget: true);
    }

    _configureRightSideShiftingKeymap();
    buildToast(title: confirmation);
  }

  /// Remaps the active trainer-app keymap so the right side alone can shift in
  /// both directions: ＋ (shiftUpRight) shifts up, B shifts down. B loses its
  /// default "back"/Escape binding so it becomes a dedicated down-shift.
  ///
  /// This edits the currently active app's keymap; for a built-in app the
  /// change applies for the session (built-in keymaps reset to their template
  /// defaults on restart), for a custom profile it is persisted.
  void _configureRightSideShiftingKeymap() {
    final keymap = core.actionHandler.supportedApp?.keymap;
    if (keymap == null) return;

    keymap.getOrCreateKeyPair(ZwiftButtons.shiftUpRight, trigger: ButtonTrigger.singleClick).inGameAction =
        InGameAction.shiftUp;

    final shiftDown = keymap.getOrCreateKeyPair(ZwiftButtons.b, trigger: ButtonTrigger.singleClick);
    shiftDown.inGameAction = InGameAction.shiftDown;
    shiftDown.physicalKey = null;
    shiftDown.logicalKey = null;
    shiftDown.modifiers = [];

    keymap.signalUpdate();
    final app = core.actionHandler.supportedApp;
    if (app != null) {
      core.settings.setKeyMap(app);
    }
  }
}
