import 'package:bike_control/widgets/ui/bk_page_header.dart';
import 'dart:async';

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:bike_control/bluetooth/devices/steering_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show screenshotMode;
import 'package:bike_control/pages/customize.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/help_article.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/widgets/controller/steering_gauge.dart';
import 'package:bike_control/widgets/device_script_drawer.dart';
import 'package:bike_control/widgets/emulation_card.dart';
import 'package:bike_control/widgets/ui/loading_widget.dart';
import 'package:bike_control/widgets/ui/pro_badge.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:bike_control/widgets/ui/trainer_label.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:bike_control/widgets/zwift_ride_firmware_notice.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

class ControllerSettingsPage extends StatefulWidget {
  final BaseDevice device;

  const ControllerSettingsPage({super.key, required this.device});

  @override
  State<ControllerSettingsPage> createState() => _ControllerSettingsPageState();
}

class _ControllerSettingsPageState extends State<ControllerSettingsPage> {
  late final StreamSubscription<BaseDevice> _connectionStateSubscription;

  @override
  void initState() {
    super.initState();
    // Rebuild when a device signals a state change (e.g. SRAM setup/restore
    // completing) so the device card's panels reflect the new state.
    _connectionStateSubscription = core.connection.connectionStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _connectionStateSubscription.cancel();
    super.dispose();
  }

  /// Context under this page's [DrawerOverlay]; see the note in [build].
  BuildContext? _overlayContext;
  BuildContext get _sheetContext => _overlayContext ?? context;

  @override
  Widget build(BuildContext context) {
    final device = widget.device;
    final trainerApp = core.settings.getTrainerApp();
    final keymap = core.actionHandler.supportedApp?.keymap;
    final helpArticle = helpArticleFor(context, controller: device, app: trainerApp);

    return DrawerOverlay(
      child: Builder(
        builder: (context) {
          // Everything below is built from THIS context, not the State's: the
          // DrawerOverlay that hosts openDrawer is created right above this
          // Builder, so `State.context` sits outside it and any drawer opened
          // from a helper method that closes over it dies on "No DrawerOverlay
          // found in the widget tree" (the "Unlock again" button did exactly
          // that).
          _overlayContext = context;
          return Scaffold(
            headers: [
              BkPageHeader(
                title: device is Accessory
                    ? AppLocalizations.of(context).deviceSettings
                    : AppLocalizations.of(context).controllerSettings,
              ),
            ],
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: 16, left: 16, right: 16, top: 16),
              child: Center(
                child: Container(
                  constraints: BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Device card
                      _buildDeviceCard(device),

                      // How-to-connect guide for this controller + the selected app.
                      // Named after both products, so it is left off the
                      // anonymized store boards.
                      if (helpArticle != null && !screenshotMode) ...[
                        const Gap(12),
                        _buildActionButton(
                          icon: LucideIcons.bookOpen,
                          label: helpArticle.label,
                          onTap: () => launchUrlString(helpArticle.url),
                          trailing: Icon(LucideIcons.externalLink, size: 16),
                        ),
                      ],
                      const Gap(24),

                      // Button mapping. An accessory — a Headwind fan, a Climb —
                      // has no buttons of its own, so the section would render an
                      // empty mapping table under a heading that promises one.
                      if (device is! Accessory) ...[
                        _buildSectionHeader(
                          AppLocalizations.of(context).buttonMapping,
                          trailing: _buildTrainerLabel(trainerApp?.name ?? '-'),
                        ),
                        const Gap(12),
                        CustomizePage(isMobile: false, filterDevice: widget.device),
                        const Gap(24),
                      ],

                      // What an accessory gets instead: the actions it obeys,
                      // and the controller whose buttons can carry them.
                      if (device is Accessory && device.assignableActions.isNotEmpty) ...[
                        _buildSectionHeader(AppLocalizations.of(context).accessoryActions),
                        const Gap(12),
                        _buildAssignableActions(device),
                        const Gap(24),
                      ],

                      // Preferences
                      if (device.buildPreferences(context) != null) ...[
                        _buildSectionHeader(AppLocalizations.of(context).preferences),
                        const Gap(16),
                        device.buildPreferences(context)!,
                        const Gap(24),
                      ],

                      // Emulation (debug-only controls for an emulated device)
                      if (kDebugMode && device is BluetoothDevice && core.emulation.isAvailable) ...[
                        if (core.emulation.sessionFor(device.scanResult.deviceId) case final session?) ...[
                          _buildSectionHeader('Emulation'),
                          const Gap(16),
                          EmulationCard(session: session),
                          const Gap(24),
                        ],
                      ],

                      // Actions
                      _buildActions(device, keymap),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDeviceCard(BaseDevice device) {
    Widget? footer;
    if (device is SteeringDevice) {
      final steering = device as SteeringDevice;
      footer = Padding(
        padding: const EdgeInsets.only(top: 4),
        child: SteeringGauge(
          angle: steering.steeringAngle,
          calibrated: steering.steeringCalibrated,
          threshold: steering.steeringThreshold,
          device: device,
          leftButton: steering.steerLeftButton,
          rightButton: steering.steerRightButton,
          keymap: core.actionHandler.supportedApp?.keymap,
          onUpdate: () => setState(() {}),
        ),
      );
    }

    if (ZwiftRide.hasUnsupportedFirmware(device)) {
      final notice = Padding(
        padding: const EdgeInsets.only(top: 8),
        child: ZwiftRideFirmwareNotice(device: device as ZwiftRide),
      );
      footer = footer == null
          ? notice
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [footer, notice]);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.border),
      ),
      child: device.showInformation(_sheetContext, showFull: true, footer: footer),
    );
  }

  Widget _buildSectionHeader(String title, {Widget? trailing}) {
    return Row(
      children: [
        Text(
          title,
          style: context.typography.large.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.2),
        ),
        if (trailing != null) ...[
          const Spacer(),
          trailing,
        ],
      ],
    );
  }

  Widget _buildTrainerLabel(String name) {
    return TrainerLabel(name: name);
  }

  /// The actions an accessory obeys, and the way to actually assign one.
  ///
  /// Nothing here is editable in place: an accessory has no buttons, so these
  /// live on a *controller's* button. The page therefore names them and hands
  /// over to the controller that can carry them — the connected one, since
  /// that is the one the rider can test a mapping on right away.
  Widget _buildAssignableActions(BaseDevice device) {
    final theme = Theme.of(context);
    final controller =
        core.connection.controllerDevices.firstOrNullWhere((d) => d.isConnected) ??
        core.connection.controllerDevices.firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final action in device.assignableActions)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(action.icon ?? LucideIcons.circleDot, size: 16, color: theme.colorScheme.mutedForeground),
                      const Gap(10),
                      Expanded(child: Text(action.title).small),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const Gap(12),
        if (controller != null)
          _buildActionButton(
            icon: LucideIcons.gamepad2,
            label: AppLocalizations.of(context).accessorySetUpOnController(controller.displayName(context)),
            onTap: () async {
              await context.push(ControllerSettingsPage(device: controller));
              if (mounted) setState(() {});
            },
          )
        else
          Text(AppLocalizations.of(context).accessoryNoControllerYet).xSmall.muted,
      ],
    );
  }

  Widget _buildActions(BaseDevice device, Keymap? keymap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        // Same reason the mapping section is hidden: there is nothing to reset
        // for a device that never had a mapping.
        if (keymap != null && device is! Accessory) ...[
          Button.outline(
            onPressed: () {
              core.settings.getTrainerApp()?.keymap.resetForDevice(device);
              setState(() {});
            },
            leading: Icon(LucideIcons.rotateCcw, size: 16, color: Theme.of(context).colorScheme.mutedForeground),
            child: Text(AppLocalizations.of(context).resetToDefaults),
          ),
          const Gap(12),
        ],
        Builder(
          builder: (context) {
            return _buildActionButton(
              icon: LucideIcons.fileCode,
              label: AppLocalizations.of(context).runScript,
              trailing: !IAPManager.instance.isPurchased.value && !IAPManager.instance.hasActiveSubscription
                  ? ProBadge()
                  : null,
              onTap: () async {
                if (!IAPManager.instance.isPurchased.value && !IAPManager.instance.hasActiveSubscription) {
                  await IAPManager.instance.purchaseFullVersion(context);
                  return;
                }
                openDrawer(
                  context: _sheetContext,
                  position: OverlayPosition.end,
                  builder: (c) => DeviceScriptDrawer(deviceType: device.runtimeType.toString()),
                );
              },
            );
          },
        ),
        if (_isRemembered(device))
          // A remembered controller is a picture of a device, not a device:
          // there is no link to drop, so both disconnect variants collapse
          // into the one thing that can actually be done to it.
          LoadingWidget(
            futureCallback: () async {
              await core.connection.forgetRemembered(device.uniqueId);
              if (mounted) Navigator.of(context).pop();
            },
            renderChild: (isLoading, tap) => _buildActionButton(
              icon: LucideIcons.trash2,
              label: AppLocalizations.of(context).forget,
              isLoading: isLoading,
              isDestructive: true,
              onTap: tap,
            ),
          )
        else ...[
          LoadingWidget(
            futureCallback: () async {
              await core.connection.disconnect(device, forget: true, persistForget: false);
              if (mounted) Navigator.of(context).pop();
            },
            renderChild: (isLoading, tap) => _buildActionButton(
              icon: LucideIcons.bluetoothOff,
              label: AppLocalizations.of(context).disconnectAndForgetForThisSession,
              isLoading: isLoading,
              onTap: tap,
            ),
          ),
          LoadingWidget(
            futureCallback: () async {
              await core.connection.disconnect(device, forget: true, persistForget: true);
              if (mounted) Navigator.of(context).pop();
            },
            renderChild: (isLoading, tap) => _buildActionButton(
              icon: LucideIcons.trash2,
              label: AppLocalizations.of(context).disconnectAndForget,
              isLoading: isLoading,
              isDestructive: true,
              onTap: tap,
            ),
          ),
        ],
      ],
    );
  }

  /// True for a controller that only exists as a remembered stand-in — no live
  /// device has taken it over, so nothing is connected to disconnect from.
  bool _isRemembered(BaseDevice device) => core.connection.offlineControllers.any((d) => d.uniqueId == device.uniqueId);

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool isLoading = false,
    bool isDestructive = false,
    Widget? trailing,
  }) {
    return Button(
      style: isDestructive ? ButtonStyle.destructive() : ButtonStyle.outline(),
      onPressed: onTap,
      leading: isLoading ? SmallProgressIndicator() : Icon(icon, size: 18),
      trailing: trailing,
      child: Text(label),
    );
  }
}
