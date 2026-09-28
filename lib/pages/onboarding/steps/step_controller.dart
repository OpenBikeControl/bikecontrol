import 'package:bike_control/pages/onboarding/widgets/onboarding_theme.dart';
import 'package:bike_control/pages/onboarding/widgets/onboarding_reveal.dart';
import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/sram/sram_axs.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2_right_side.dart';
import 'package:bike_control/pages/onboarding/onboarding_models.dart';
import 'package:bike_control/utils/click_v2_onboarding.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/controller/controller_canvas.dart';
import 'package:bike_control/widgets/ui/animated_button_widget.dart';
import 'package:bike_control/widgets/guided_operation_sheet.dart';
import 'package:bike_control/widgets/ui/bk_touch_target.dart';
import 'package:bike_control/widgets/ui/wifi_animation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// A tip row in the onboarding info blocks. When [linkLabel]/[onLink] are
/// given the row grows a trailing link, so a tip that points at another app
/// can actually take the rider there instead of just naming it.
Widget _infoRow(
  BuildContext context,
  IconData icon,
  String title,
  String sub, {
  String? linkLabel,
  VoidCallback? onLink,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.muted,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18),
        Gap(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title).small.semiBold,
              if (sub.isNotEmpty) Text(sub).xSmall.muted,
              if (linkLabel != null && onLink != null)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Button.link(
                    onPressed: onLink,
                    trailing: const Icon(LucideIcons.externalLink, size: 12),
                    child: Text(linkLabel).xSmall,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Whether a connected controller [device] still needs its guided sub-flow
/// run (SRAM AXS "disable on-device shifting" setup, or Click V2 unlock).
bool onboardingDeviceNeedsSetup(BaseDevice device) {
  // A new Click V2 is held out of the connect queue until the rider has
  // picked an unlock mode in the existing ClickV2OnboardingPage explainer.
  if (device is ZwiftClickV2 || device is ZwiftClickV2RightSide) return ClickV2Onboarding.isPending;
  if (device is SramAxs) return device.needsGuidedSetup;
  return false;
}

Widget onboardingDeviceRow(BuildContext context, BaseDevice device, {bool needsSetup = false, VoidCallback? onSetup}) {
  final connected = device.isConnected;
  final scheme = Theme.of(context).colorScheme;
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: connected ? const Color(0xFF22C55E) : scheme.border, width: 1.5),
      borderRadius: BorderRadius.circular(12),
      color: scheme.card,
    ),
    child: Row(
      children: [
        Icon(connected ? LucideIcons.check : device.icon, size: 20, color: connected ? const Color(0xFF22C55E) : null),
        Gap(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // displayName, not `name`: `name` is the raw BLE advertised name,
              // which is plain "Zwift Click" for both Click V2 pucks — the two
              // rows were indistinguishable.
              Text(device.displayName(context)).small.semiBold,
              // A device held for setup (Click V2 pending its unlock-mode choice)
              // is deliberately not connecting — don't pretend it is.
              Text(
                connected
                    ? context.i18n.onboardingDeviceConnected
                    : needsSetup
                    ? context.i18n.onboardingSetupNeeded
                    : context.i18n.onboardingDeviceConnecting,
              ).xSmall.muted,
            ],
          ),
        ),
        if (needsSetup)
          // A real button: the auto-opened sub-flow can be cancelled, and this
          // is the way back in.
          BkTouchTarget(
            child: SecondaryButton(
              alignment: Alignment.center,
              size: ButtonSize.small,
              onPressed: onSetup,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.i18n.onboardingSetupNeeded),
                  Gap(5),
                  Icon(LucideIcons.chevronRight, size: 12),
                ],
              ),
            ),
          )
        else if (connected)
          SecondaryBadge(child: Text(context.i18n.onboardingDeviceConnected)),
      ],
    ),
  );
}

Widget _contourCard(
  BuildContext context,
  BaseDevice device, {
  required Map<String, ControllerButton> pressedButtons,
  required Map<String, int> pressGenerations,
  VoidCallback? onUpdate,
}) {
  final scheme = Theme.of(context).colorScheme;
  final pressed = pressedButtons[device.uniqueId];
  final generation = pressGenerations[device.uniqueId] ?? 0;
  final keymap = core.actionHandler.supportedApp?.keymap;
  final size = 56 / Theme.of(context).scaling;
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      border: Border.all(color: scheme.border, width: 1.5),
      borderRadius: BorderRadius.circular(12),
      color: scheme.card,
    ),
    child: ControllerCanvas(
      layout: device.controllerLayout!,
      availableButtons: device.availableButtons,
      buttonSize: size,
      buttonBuilder: (btn) => AnimatedButtonWidget(
        key: ValueKey(btn.name),
        button: btn,
        pressGeneration: pressed?.name == btn.name ? generation : 0,
        keymap: keymap,
        device: device,
        size: size,
        onUpdate: onUpdate ?? () {},
      ),
    ),
  );
}

Widget onboardingControllerBody(
  BuildContext context, {
  required ControllerPhase phase,
  required List<BaseDevice> devices,
  required String appName,
  Map<String, ControllerButton> pressedButtons = const {},
  Map<String, int> pressGenerations = const {},
  void Function(BaseDevice)? onSetupDevice,
  VoidCallback? onUpdate,
}) {
  final reduceMotion = MediaQuery.of(context).disableAnimations;
  final anyConnected = devices.any((d) => d.isConnected);

  switch (phase) {
    case ControllerPhase.permission:
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: onboardingReveal([
          Text(context.i18n.onboardingBluetoothTitle).h4,
          Gap(6),
          Text(context.i18n.onboardingBluetoothSubtitle).small.muted,
          Gap(16),
          Center(
            child: StageBadge(
              icon: LucideIcons.bluetooth,
              tone: onboardingAccent(context),
              wash: onboardingAccent(context).withValues(alpha: 0.1),
              reduceMotion: reduceMotion,
            ),
          ),
          Gap(20),
          _infoRow(
            context,
            LucideIcons.radar,
            context.i18n.onboardingBluetoothFindTitle,
            context.i18n.onboardingBluetoothFindSub,
          ),
          _infoRow(
            context,
            LucideIcons.bell,
            context.i18n.onboardingBluetoothNotifyTitle,
            context.i18n.onboardingBluetoothNotifySub,
          ),
          Gap(6),
          _infoRow(context, LucideIcons.shieldCheck, context.i18n.onboardingBluetoothPrivacy, ''),
        ]),
      );
    case ControllerPhase.scanning:
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: onboardingReveal([
          Text(context.i18n.onboardingScanTitle).h4,
          Gap(6),
          Text(context.i18n.onboardingScanSubtitle).small.muted,
          Gap(24),
          Center(child: SmoothWifiAnimation()),
          Gap(20),
          Center(child: Text(context.i18n.scanningForDevices).small.muted),
        ]),
      );
    case ControllerPhase.empty:
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: onboardingReveal([
          Text(context.i18n.onboardingScanEmptyTitle).h4,
          Gap(6),
          Text(context.i18n.onboardingScanEmptySubtitle).small.muted,
          Gap(18),
          _infoRow(
            context,
            LucideIcons.power,
            context.i18n.onboardingScanEmptyWakeTitle,
            context.i18n.onboardingScanEmptyWakeSub,
          ),
          _infoRow(
            context,
            LucideIcons.unlink,
            context.i18n.onboardingScanEmptyDisconnectTitle,
            context.i18n.onboardingScanEmptyDisconnectSub,
          ),
          _infoRow(
            context,
            LucideIcons.ruler,
            context.i18n.onboardingScanEmptyCloserTitle,
            context.i18n.onboardingScanEmptyCloserSub,
          ),
          // Riders rarely know controller firmware is updated from the Zwift
          // Companion app, so the tip links straight to it.
          _infoRow(
            context,
            LucideIcons.refreshCw,
            context.i18n.onboardingScanEmptyFirmwareTitle,
            context.i18n.onboardingScanEmptyFirmwareSub,
            linkLabel: context.i18n.zwiftCompanionApp,
            onLink: () => launchUrlString(ZwiftConstants.ZWIFT_COMPANION_URL, mode: LaunchMode.externalApplication),
          ),
        ]),
      );
    case ControllerPhase.list:
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: onboardingReveal([
          Text(
            anyConnected ? context.i18n.onboardingControllerReadyTitle : context.i18n.onboardingControllerListTitle,
          ).h4,
          Gap(6),
          Text(
            anyConnected
                ? context.i18n.onboardingControllerReadySubtitle
                : context.i18n.onboardingControllerListSubtitle,
          ).small.muted,
          Gap(16),
          for (final d in devices) ...[
            onboardingDeviceRow(
              context,
              d,
              needsSetup: onboardingDeviceNeedsSetup(d),
              onSetup: onSetupDevice == null ? null : () => onSetupDevice(d),
            ),
            // Each connected controller shows its contour right below its row
            // so riders can see the buttons they just gained (same canvas the
            // home screen uses).
            if (d.isConnected && d.controllerLayout != null)
              _contourCard(
                context,
                d,
                pressedButtons: pressedButtons,
                pressGenerations: pressGenerations,
                onUpdate: onUpdate,
              ),
          ],

          // Once a controller is connected the job is done — don't keep
          // suggesting the wizard is waiting for something.
          if (!anyConnected) ...[
            Gap(10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(size: 14)),
                Gap(8),
                Text(context.i18n.onboardingStillScanning).xSmall.muted,
              ],
            ),
          ],
          if (anyConnected) ...[
            Gap(12),
            _infoRow(context, LucideIcons.lightbulb, context.i18n.onboardingControllerMapped(appName), ''),
          ],
        ]),
      );
  }
}
