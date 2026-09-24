import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2_left_side.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/utils/click_v2_onboarding.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/utils/keymap/manager.dart';
import 'package:bike_control/widgets/click_v2/keep_awake_warning.dart';
import 'package:bike_control/widgets/controller/controller_layout.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:bike_control/widgets/unlock_toggle.dart';
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

  /// Held out of the connect queue until the rider has chosen an unlock mode.
  /// Zwift Click V2 behaviour depends entirely on that choice, so connecting
  /// first would hand them a controller that half-works for reasons they have
  /// not been told about yet.
  ///
  /// After the choice, this side connects in both of the modes the explainer
  /// offers — right-side-only and unlock-with-Zwift. The one mode it stays out
  /// of is the legacy left-side restart loop: `ClickLogic` drives that from a
  /// single shared timer which this side's handshake cancels
  /// (`ClickLogic.setupHandshake(isRight: true)`), so connecting here would
  /// stop the left puck restarting and strand it locked.
  ///
  /// This also keeps ClickV2Onboarding's _connectPending from picking it up:
  /// connectDevice still runs, but [connect] below is a no-op while false.
  @override
  bool get shouldAutoConnect =>
      !ClickV2Onboarding.isPending &&
      (core.settings.getClickV2RightSideOnly() || core.settings.getUnlockWithZwift());

  @override
  Future<void> connect() async {
    // Mirrors ProxyDevice: stay listed and keep the queue's listener wiring,
    // but open no transport and run no handshake while onboarding is pending.
    if (!shouldAutoConnect) return;
    await super.connect();
  }

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

  /// See [ZwiftClickV2LeftSide.displayName]. This side doesn't extend
  /// [ZwiftClickV2], so the unsuffixed name is spelled out rather than taken
  /// from `super.toString()` (which would yield the advertised BLE name).
  @override
  String displayName(BuildContext context) =>
      context.i18n.deviceSideRight(screenshotControllerNamesAnonymised ? 'Controller' : 'Zwift Click V2');

  @override
  Future<void> setupHandshake() async {
    await sendCommandBuffer(Uint8List.fromList(startCommand));
    ClickLogic.setupHandshake(services!, device.deviceId, isRight: true);
  }

  @override
  Future<void> disconnect() async {
    // Drops the remembered handle and the "connect the left side" prompt with
    // it — there is no longer a right puck for the rider to fix.
    ClickLogic.forgetKeepAwake();
    await super.disconnect();
  }

  @override
  List<Widget> showAdditionalInformation(BuildContext context) {
    // Connected, not merely discovered: right-side-only mode holds the left
    // side back rather than forgetting it, so it stays in the device list.
    // Offering to drop a puck that is already out would just be confusing.
    final hasLiveLeftSide = core.connection.devices.whereType<ZwiftClickV2LeftSide>().any((d) => d.isConnected);
    return [
      // The unlock mode is one setting covering both pucks, so the way back
      // into the explainer belongs on either card — a rider looking at the
      // right side shouldn't have to find the left one to change it.
      const UnlockToggle(children: []),
      if (isConnected && !screenshotMode) const ClickV2KeepAwakeWarning(),
      if (hasLiveLeftSide) ...[
        Text(context.i18n.unlock_useRightSideOnlyDescription).xSmall.normal,
        SizedBox(
          width: double.infinity,
          child: Button.outline(
            onPressed: () => _useRightSideOnly(context),
            child: Text(context.i18n.unlock_useRightSideOnly),
          ),
        ),
      ],
    ];
  }

  /// Switches to a "right side only" setup: the left controller (which needs
  /// unlocking / restarts) is dropped and the right side covers gear shifting
  /// on its own — ＋ still shifts up, B takes over shifting down.
  ///
  /// Delegates to [ClickV2Onboarding.chooseRightSideOnly] so this shortcut and
  /// the explainer's own option leave the app in exactly the same state — the
  /// left side held back by the setting rather than pushed onto the ignored
  /// devices list, which is what makes "Set up again" able to undo it.
  Future<void> _useRightSideOnly(BuildContext context) async {
    // Read localised text before the awaits below remove this card.
    final confirmation = context.i18n.unlock_rightSideOnlyConfigured;
    await ClickV2Onboarding.chooseRightSideOnly();
    buildToast(title: confirmation);
  }

  /// Remaps the active trainer-app keymap so the right side alone can shift in
  /// both directions: ＋ (shiftUpRight) shifts up, B shifts down. B loses its
  /// default "back"/Escape binding so it becomes a dedicated down-shift.
  ///
  /// Built-in app keymaps are code-defined templates that reset to their
  /// defaults on restart, and [Settings.setKeyMap] only persists key pairs for
  /// custom profiles. So, mirroring the button editor, a built-in profile is
  /// first forked into a custom copy (`"App (Copy)"`) which the remap then edits
  /// and persists — otherwise the change would be lost on the next launch.
  /// Static because [ClickV2Onboarding] applies this at the moment the rider
  /// picks right-side-only, which is before any Click V2 has connected — there
  /// is no instance to hang it off yet. It never touched instance state.
  static void configureRightSideShiftingKeymap() {
    final app = core.actionHandler.supportedApp;
    if (app == null) return;

    if (app is! CustomApp) {
      KeymapManager().duplicateSync(app.name, '${app.name} (Copy)');
    }

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

    final activeApp = core.actionHandler.supportedApp;
    if (activeApp != null) {
      core.settings.setKeyMap(activeApp);
    }
  }
}
