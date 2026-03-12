import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/customize.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/widgets/device_script_drawer.dart';
import 'package:bike_control/widgets/ui/loading_widget.dart';
import 'package:bike_control/widgets/ui/pro_badge.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class ControllerSettingsPage extends StatefulWidget {
  final BaseDevice device;

  const ControllerSettingsPage({super.key, required this.device});

  @override
  State<ControllerSettingsPage> createState() => _ControllerSettingsPageState();
}

class _ControllerSettingsPageState extends State<ControllerSettingsPage> {
  @override
  Widget build(BuildContext context) {
    final device = widget.device;
    final trainerApp = core.settings.getTrainerApp();
    final keymap = core.actionHandler.supportedApp?.keymap;

    return Scaffold(
      headers: [
        AppBar(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          leading: [
            IconButton.ghost(
              icon: Icon(LucideIcons.arrowLeft, size: 24),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
          title: Text(
            AppLocalizations.of(context).controllerSettings,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.3),
          ),
          trailing: [
            IconButton.ghost(
              icon: Icon(LucideIcons.x, size: 22, color: Theme.of(context).colorScheme.mutedForeground),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
          backgroundColor: Theme.of(context).colorScheme.background,
        ),
        Divider(),
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
                const Gap(24),

                // Button mapping
                _buildSectionHeader(
                  AppLocalizations.of(context).buttonMapping,
                  trailing: _buildTrainerLabel(trainerApp?.name ?? '-'),
                ),
                const Gap(12),
                CustomizePage(isMobile: false, filterDevice: widget.device),
                const Gap(24),

                // Preferences
                if (device.buildPreferences(context) != null) ...[
                  _buildSectionHeader(AppLocalizations.of(context).preferences),
                  const Gap(16),
                  device.buildPreferences(context)!,
                  const Gap(24),
                ],

                // Actions
                _buildActions(device, keymap),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceCard(BaseDevice device) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.border),
      ),
      child: device.showInformation(context, showFull: true),
    );
  }

  Widget _buildSectionHeader(String title, {Widget? trailing}) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        ),
        if (trailing != null) ...[
          const Spacer(),
          trailing,
        ],
      ],
    );
  }

  Widget _buildTrainerLabel(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.muted,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          Icon(LucideIcons.monitor, size: 14, color: Theme.of(context).colorScheme.mutedForeground),
          Text(
            name.split(' ').first,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BaseDevice device, Keymap? keymap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        if (keymap != null) ...[
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
                  context: context,
                  position: OverlayPosition.end,
                  builder: (c) => DeviceScriptDrawer(deviceType: device.runtimeType.toString()),
                );
              },
            );
          },
        ),
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
    );
  }

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
