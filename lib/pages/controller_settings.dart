import 'package:bike_control/pages/trainer_connection_settings.dart';
import 'package:bike_control/utils/window_size.dart';
import 'package:bike_control/widgets/keymap/button_detail.dart';
import 'package:bike_control/widgets/keymap/mapping.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:bike_control/widgets/ui/bk_page_header.dart';
import 'dart:async';

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:bike_control/bluetooth/devices/gyroscope/gyroscope_steering.dart';
import 'package:bike_control/bluetooth/devices/steering_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show screenshotMode, shownKeymapName;
import 'package:bike_control/pages/customize.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/help_article.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/widgets/controller/steering_sections.dart';
import 'package:bike_control/widgets/device_script_drawer.dart';
import 'package:bike_control/widgets/emulation_card.dart';
import 'package:bike_control/widgets/ui/loading_widget.dart';
import 'package:bike_control/widgets/ui/pro_badge.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:bike_control/widgets/zwift_ride_firmware_notice.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:bike_control/widgets/ui/bk_page_column.dart';

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
    // The mapping opens on the first button: on a phone its triggers show
    // under it, in a wide window its detail sits beside the list.
    _selection.ensureFor(widget.device);
    // Rebuild when a device signals a state change (e.g. SRAM setup/restore
    // completing) so the device card's panels reflect the new state.
    _connectionStateSubscription = core.connection.connectionStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _connectionStateSubscription.cancel();
    _selection.dispose();
    super.dispose();
  }

  /// The master–detail's column and its distance from the window edge.
  static const double _wideColumnWidth = 1240;
  static const double _wideGutter = 24;

  /// Context under this page's [DrawerOverlay]; see the note in [build].
  BuildContext? _overlayContext;
  BuildContext get _sheetContext => _overlayContext ?? context;

  /// The button the mapping shows; in wide windows the detail pane beside the
  /// list follows it.
  final MappingSelection _selection = MappingSelection();

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
          // Master–detail from the keymap side-by-side width: the buttons on
          // the left, the picked one's triggers and actions on the right. A
          // pushed page spans the window, so the window's width decides — and
          // the header knows the column it sits over.
          final wide =
              MediaQuery.sizeOf(context).width >= Breakpoints.keymapSideBySide &&
              device is! Accessory &&
              device is! SteeringDevice &&
              core.actionHandler.supportedApp != null &&
              mappingButtonsOf(device).isNotEmpty;
          if (wide) _selection.ensureFor(device);
          return Scaffold(
            headers: [
              BkPageHeader(
                title: device is Accessory
                    ? AppLocalizations.of(context).deviceSettings
                    : device is SteeringDevice
                    ? AppLocalizations.of(context).steeringPageTitle
                    : AppLocalizations.of(context).controllerSettings,
                columnWidth: wide ? _wideColumnWidth : BkPageColumn.defaultMaxWidth,
                columnGutter: wide ? _wideGutter : 16,
              ),
            ],
            child: Builder(
              builder: (context) {
                final mapping = <Widget>[
                  // Button mapping. An accessory — a Headwind fan, a Climb —
                  // has no buttons of its own, so the section would render an
                  // empty mapping table under a heading that promises one.
                  // A steering input has an angle, not buttons: its two
                  // directions and their actions are in [SteeringSections].
                  if (device is! Accessory && device is! SteeringDevice) ...[
                    _buildSectionHeader(
                      AppLocalizations.of(context).buttonMapping,
                      trailing: _buildTrainerLabel(trainerApp == null ? '-' : shownKeymapName(trainerApp.name)),
                    ),
                    const Gap(8),
                    CustomizePage(
                      isMobile: false,
                      filterDevice: widget.device,
                      selection: _selection,
                      master: wide,
                      onChanged: () {
                        if (mounted) setState(() {});
                      },
                    ),
                    const Gap(24),
                  ],
                ];

                final rest = <Widget>[
                  // What an accessory gets instead: the actions it obeys,
                  // and the controller whose buttons can carry them.
                  if (device is Accessory && device.assignableActions.isNotEmpty) ...[
                    _buildSectionHeader(AppLocalizations.of(context).accessoryActions),
                    const Gap(8),
                    _buildAssignableActions(device),
                    const Gap(24),
                  ],

                  // What steering drives and how it is tuned.
                  if (device is SteeringDevice) ...[
                    SteeringSections(
                      device: device,
                      keymap: keymap,
                      onUpdate: () {
                        if (mounted) setState(() {});
                      },
                    ),
                    const Gap(24),
                  ],

                  // Preferences
                  if (device is! SteeringDevice && device.buildPreferences(context) != null) ...[
                    _buildSectionHeader(AppLocalizations.of(context).preferences),
                    const Gap(8),
                    device.buildPreferences(context)!,
                    const Gap(24),
                  ],

                  // Emulation (debug-only controls for an emulated device)
                  if (kDebugMode && device is BluetoothDevice && core.emulation.isAvailable) ...[
                    if (core.emulation.sessionFor(device.scanResult.deviceId) case final session?) ...[
                      _buildSectionHeader('Emulation'),
                      const Gap(8),
                      EmulationCard(session: session),
                      const Gap(24),
                    ],
                  ],

                  // Actions
                  _buildActions(device, keymap),
                ];

                final head = <Widget>[
                  // Device card
                  _buildDeviceCard(device),

                  // How-to-connect guide for this controller + the selected app.
                  // Named after both products, so it is left off the
                  // anonymized store boards.
                  if (helpArticle != null && !screenshotMode) ...[
                    const Gap(12),
                    BkGroupedSection(
                      children: [
                        BkGroupedRow(
                          icon: LucideIcons.bookOpen,
                          title: helpArticle.label,
                          trailing: const Icon(LucideIcons.externalLink, size: 16),
                          onPressed: () => launchUrlString(helpArticle.url),
                        ),
                      ],
                    ),
                  ],
                  const Gap(24),
                ];

                if (!wide) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: BkPageColumn(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [...head, ...mapping, ...rest],
                      ),
                    ),
                  );
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(_wideGutter, 16, _wideGutter, 24),
                  child: BkPageColumn(
                    maxWidth: _wideColumnWidth,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 392,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [...head, ...mapping, ...rest],
                          ),
                        ),
                        const Gap(24),
                        Expanded(
                          child: KeymapButtonDetail(
                            selection: _selection,
                            onUpdate: () {
                              if (mounted) setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildDeviceCard(BaseDevice device) {
    if (device is SteeringDevice) {
      return SteeringHeroCard(device: device, keymap: core.actionHandler.supportedApp?.keymap);
    }
    final footer = ZwiftRide.hasUnsupportedFirmware(device)
        ? Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ZwiftRideFirmwareNotice(device: device as ZwiftRide),
          )
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.card,
        borderRadius: BorderRadius.circular(BkComponentThemes.cardRadius),
      ),
      child: device.showInformation(_sheetContext, showFull: true, footer: footer),
    );
  }

  Widget _buildSectionHeader(String title, {Widget? trailing}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Gap(4),
        Semantics(
          header: true,
          child: Text(
            title,
            style: context.typography.xLarge.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
          ),
        ),
        if (trailing != null) ...[
          const Spacer(),
          trailing,
        ],
      ],
    );
  }

  /// "for MyWhoosh": which app the mapping is for; opens the connection
  /// settings, where the app is chosen.
  Widget _buildTrainerLabel(String name) {
    return Button.ghost(
      onPressed: () => context.push(const TrainerConnectionSettingsPage()),
      child: Text(
        AppLocalizations.of(context).mappingForApp(name),
        style: context.typography.small.copyWith(color: Theme.of(context).colorScheme.mutedForeground),
      ),
    );
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.card,
            borderRadius: BorderRadius.circular(BkComponentThemes.cardRadius),
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
          BkGroupedSection(
            children: [
              _buildActionButton(
                icon: LucideIcons.gamepad2,
                label: AppLocalizations.of(context).accessorySetUpOnController(controller.displayName(context)),
                onTap: () async {
                  await context.push(ControllerSettingsPage(device: controller));
                  if (mounted) setState(() {});
                },
              ),
            ],
          )
        else
          Text(AppLocalizations.of(context).accessoryNoControllerYet).xSmall.muted,
      ],
    );
  }

  Widget _buildActions(BaseDevice device, Keymap? keymap) {
    final noPurchase = !IAPManager.instance.isPurchased.value && !IAPManager.instance.hasActiveSubscription;
    return BkGroupedSection(
      dividerIndent: BkGroupedSection.inset + BkIconTile.size + BkGroupedRow.gap,
      children: [
        // The controller's own buzz on every shift, for the ones that can.
        if (device is ZwiftDevice && device.canVibrate)
          BkGroupedRow(
            key: const ValueKey('controller-vibration'),
            icon: LucideIcons.vibrate,
            title: AppLocalizations.of(context).enableVibrationFeedback,
            trailing: Switch(value: core.settings.getVibrationEnabled(), onChanged: (_) => _toggleVibration()),
            onPressed: _toggleVibration,
          ),
        // Same reason the mapping section is hidden: there is nothing to reset
        // for a device that never had a mapping.
        if (keymap != null && device is! Accessory)
          BkGroupedRow(
            icon: LucideIcons.rotateCcw,
            title: AppLocalizations.of(context).resetToDefaults,
            onPressed: () {
              core.settings.getTrainerApp()?.keymap.resetForDevice(device);
              setState(() {});
            },
          ),
        Builder(
          builder: (context) {
            return _buildActionButton(
              icon: LucideIcons.fileCode,
              label: AppLocalizations.of(context).runScript,
              badge: noPurchase ? const ProBadge() : null,
              onTap: () async {
                if (noPurchase) {
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
        if (device is GyroscopeSteering)
          // The phone is not a device to forget: steering with it is a
          // setting, and this is the way back out of it.
          BkGroupedRow(
            key: const ValueKey('steering-turn-off'),
            icon: LucideIcons.power,
            title: AppLocalizations.of(context).steeringTurnOff,
            onPressed: () {
              core.settings.setPhoneSteeringEnabled(false);
              core.connection.toggleGyroscopeSteering(false);
              Navigator.of(context).maybePop();
            },
          )
        else if (_isRemembered(device))
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

  Future<void> _toggleVibration() async {
    await core.settings.setVibrationEnabled(!core.settings.getVibrationEnabled());
    if (mounted) setState(() {});
  }

  /// True for a controller that only exists as a remembered stand-in — no live
  /// device has taken it over, so nothing is connected to disconnect from.
  bool _isRemembered(BaseDevice device) => core.connection.offlineControllers.any((d) => d.uniqueId == device.uniqueId);

  /// One action as a grouped row; destructive ones in red (words and icon).
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool isLoading = false,
    bool isDestructive = false,
    Widget? trailing,
    Widget? badge,
  }) {
    final danger = isDestructive ? BkStatusColors.of(context).danger : null;
    return BkGroupedRow(
      leading: BkIconTile(icon: icon, color: danger),
      title: label,
      titleColor: danger,
      badge: badge,
      trailing: isLoading ? SmallProgressIndicator() : trailing,
      chevron: trailing == null && !isLoading,
      onPressed: onTap,
    );
  }
}
