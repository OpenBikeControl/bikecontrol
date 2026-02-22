import 'package:bike_control/models/device_limit_reached_error.dart';
import 'package:bike_control/models/user_device.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/ui/loading_widget.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class RegisteredDevicesView extends StatefulWidget {
  final VoidCallback onBack;

  const RegisteredDevicesView({super.key, required this.onBack});

  @override
  State<RegisteredDevicesView> createState() => _RegisteredDevicesViewState();
}

class _RegisteredDevicesViewState extends State<RegisteredDevicesView> {
  final IAPManager _iapManager = IAPManager.instance;
  bool _isLoading = false;
  Map<String, List<UserDevice>> _devicesByPlatform = {};

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final devices = await _iapManager.deviceManagement.getMyDevices();
      final grouped = <String, List<UserDevice>>{};
      for (final device in devices) {
        grouped.putIfAbsent(device.platform, () => <UserDevice>[]).add(device);
      }
      if (mounted) {
        setState(() {
          _devicesByPlatform = grouped;
        });
      }
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 16,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isLoading)
            Center(
              child: Column(
                spacing: 16,
                children: [
                  CircularProgressIndicator(),
                  Text('Loading devices...').small.muted,
                ],
              ),
            ),
          if (!IAPManager.instance.isProEnabledForCurrentDevice)
            LoadingWidget(
              futureCallback: _registerCurrentDevice,
              renderChild: (isLoading, tap) => Button.primary(
                onPressed: tap,
                child: isLoading
                    ? SmallProgressIndicator()
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          const Text('Register current device'),
                        ],
                      ),
              ),
            ),

          if (_devicesByPlatform.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.muted.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  spacing: 12,
                  children: [
                    Icon(
                      Icons.devices,
                      size: 48,
                      color: Theme.of(context).colorScheme.mutedForeground,
                    ),
                    Text('No devices registered').small.muted,
                  ],
                ),
              ),
            )
          else
            ..._devicesByPlatform.entries.map((entry) => _buildPlatformSection(entry.key, entry.value)),
        ],
      ),
    );
  }

  Widget _buildPlatformSection(String platform, List<UserDevice> devices) {
    return Card(
      child: Column(
        spacing: 12,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(platform.toUpperCase()).small.bold,
              const Spacer(),
              Text('${devices.where((d) => d.isActive).length} active').small.muted,
            ],
          ),
          Divider(),
          ...devices.map((device) => _buildDeviceTile(device)),
        ],
      ),
    );
  }

  Widget _buildDeviceTile(UserDevice device) {
    final isRevoked = device.isRevoked;

    return Card(
      filled: true,
      child: Row(
        children: [
          Icon(
            Icons.device_unknown,
            size: 20,
            color: isRevoked ? Theme.of(context).colorScheme.mutedForeground : Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Text(
                  device.deviceName?.isNotEmpty == true ? device.deviceName! : device.deviceId.split("|").first,
                ).small.bold,
                if (device.deviceName?.isNotEmpty == true) Text('ID: ${device.deviceId.split("|").first}').small.muted,
                Text('Last seen: ${_formatDate(device.lastSeenAt)}').small.muted,
              ],
            ),
          ),
          if (isRevoked)
            Text(
              'Revoked',
              style: TextStyle(color: Colors.red, fontSize: 12),
            )
          else
            Button.secondary(
              onPressed: () => _revokeDevice(device),
              child: Text('Revoke'),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Never';
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _revokeDevice(UserDevice device) async {
    try {
      await _iapManager.deviceManagement.revokeDevice(
        platform: device.platform,
        deviceId: device.deviceId,
      );
      await _iapManager.entitlements.refresh(force: true);
      await _loadDevices();
    } catch (e) {
      buildToast(title: 'Could not revoke device: $e');
    }
  }

  Future<void> _registerCurrentDevice() async {
    try {
      final platform = await _iapManager.deviceManagement.currentPlatform();
      final deviceName = 'BikeControl ${platform?.toUpperCase() ?? ''}';

      final package = await PackageInfo.fromPlatform();
      final version = package.version;

      final result = await _iapManager.deviceManagement.registerCurrentDevice(
        deviceName: deviceName,
        appVersion: version,
      );
      await _iapManager.entitlements.refresh(force: true);
      await _loadDevices();
      if (!mounted) return;
      setState(() {});
    } on DeviceLimitReachedError catch (error) {
      if (!mounted) return;
      buildToast(title: 'Device limit reached for ${error.platform}');
    } catch (error) {
      if (!mounted) return;
      buildToast(title: 'Could not register device: $error');
    }
  }
}
