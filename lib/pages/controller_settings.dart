import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/device_script_drawer.dart';
import 'package:bike_control/widgets/keymap_explanation.dart';
import 'package:bike_control/widgets/ui/loading_widget.dart';
import 'package:bike_control/widgets/ui/pro_badge.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:bike_control/widgets/ui/toast.dart';
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
    final keymap = trainerApp?.keymap;

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
            'Controller Settings',
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Device card
            _buildDeviceCard(device),
            const Gap(24),

            // Button mapping
            if (keymap != null) ...[
              _buildSectionHeader('Button Mapping', trailing: _buildTrainerLabel(trainerApp!.name)),
              const Gap(12),
              KeymapExplanation(
                keymap: keymap,
                onUpdate: () => setState(() {}),
                filterDevice: device,
              ),
              const Gap(24),
            ],

            // Preferences
            if (device.buildPreferences(context) != null) ...[
              _buildSectionHeader('Preferences'),
              const Gap(16),
              device.buildPreferences(context)!,
              const Gap(24),
            ],

            // Actions
            _buildActions(device),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard(BaseDevice device) {
    final btDevice = device is BluetoothDevice ? device : null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.muted,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(LucideIcons.gamepad2, size: 24),
          ),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.2),
                ),
                const Gap(2),
                Row(
                  spacing: 6,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: device.isConnected
                            ? const Color(0xFF22C55E)
                            : Theme.of(context).colorScheme.mutedForeground,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Text(
                      device.isConnected ? 'Connected' : 'Disconnected',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: device.isConnected
                            ? const Color(0xFF22C55E)
                            : Theme.of(context).colorScheme.mutedForeground,
                      ),
                    ),
                    if (btDevice?.batteryLevel != null) ...[
                      Text(
                        '  \u00b7  ',
                        style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.mutedForeground),
                      ),
                      Icon(LucideIcons.batteryMedium, size: 14, color: Theme.of(context).colorScheme.mutedForeground),
                      Text(
                        '${btDevice!.batteryLevel}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.mutedForeground,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
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

  Widget _buildActions(BaseDevice device) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        LoadingWidget(
          futureCallback: () async {
            await core.connection.disconnect(device, forget: true, persistForget: false);
            if (mounted) Navigator.of(context).pop();
          },
          renderChild: (isLoading, tap) => _buildActionButton(
            icon: LucideIcons.bluetoothOff,
            label: 'Disconnect and Forget for this session',
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
            label: 'Disconnect and Forget',
            isLoading: isLoading,
            isDestructive: true,
            onTap: tap,
          ),
        ),
        _buildActionButton(
          icon: LucideIcons.fileCode,
          label: 'Run Script',
          trailing: !IAPManager.instance.isPurchased.value && !IAPManager.instance.hasActiveSubscription
              ? ProBadge()
              : null,
          onTap: () {
            if (!IAPManager.instance.isPurchased.value && !IAPManager.instance.hasActiveSubscription) {
              buildToast(title: 'This feature is Full Version or Pro only.', duration: Duration(seconds: 4));
              return;
            }
            openDrawer(
              context: context,
              position: OverlayPosition.end,
              builder: (c) => DeviceScriptDrawer(deviceType: device.runtimeType.toString()),
            );
          },
        ),
        const Gap(4),
        GestureDetector(
          onTap: () {
            core.settings.getTrainerApp()?.keymap.resetForDevice(device);
            setState(() {});
            buildToast(title: 'Button mappings reset to defaults');
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).colorScheme.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 6,
                children: [
                  Icon(LucideIcons.rotateCcw, size: 16, color: Theme.of(context).colorScheme.mutedForeground),
                  Text(
                    'Reset to defaults',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
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
    final color = isDestructive
        ? Theme.of(context).colorScheme.destructive
        : Theme.of(context).colorScheme.foreground;
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).colorScheme.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (isLoading)
                  SmallProgressIndicator()
                else
                  Icon(icon, size: 16, color: color),
                const Gap(8),
                Expanded(
                  child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color)),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
