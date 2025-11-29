import 'dart:async';
import 'dart:io';

import 'package:device_auto_rotate_checker/device_auto_rotate_checker.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_emulator.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/widgets/scan.dart';
import 'package:swift_control/widgets/ui/toast.dart';
import 'package:swift_control/widgets/ui/warning.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../bluetooth/devices/base_device.dart';
import '../utils/actions/android.dart';
import '../utils/actions/remote.dart';
import '../utils/requirements/remote.dart';
import '../widgets/ignored_devices_dialog.dart';

class DevicePage extends StatefulWidget {
  final VoidCallback onUpdate;
  const DevicePage({super.key, required this.onUpdate});

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> with WidgetsBindingObserver {
  late StreamSubscription<BaseDevice> _connectionStateSubscription;
  bool _showAutoRotationWarning = false;
  bool _showMiuiWarning = false;
  bool _showNameChangeWarning = false;
  StreamSubscription<bool>? _autoRotateStream;

  @override
  void initState() {
    super.initState();

    // keep screen on - this is required for iOS to keep the bluetooth connection alive
    if (!screenshotMode) {
      WakelockPlus.enable();
    }
    _showNameChangeWarning = !settings.knowsAboutNameChange();
    WidgetsBinding.instance.addObserver(this);

    if (!kIsWeb) {
      whooshLink.isStarted.addListener(() {
        if (mounted) setState(() {});
      });

      zwiftEmulator.isConnected.addListener(() {
        if (mounted) setState(() {});
      });

      if (settings.getZwiftEmulatorEnabled() && actionHandler.supportedApp?.supportsZwiftEmulation == true) {
        zwiftEmulator.startAdvertising(() {
          if (mounted) setState(() {});
        });
      }
    }

    if (actionHandler is RemoteActions && !kIsWeb && Platform.isIOS && (actionHandler as RemoteActions).isConnected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // show snackbar to inform user that the app needs to stay in foreground
        showToast(
          builder: (c, overlay) =>
              buildToast(c, overlay, title: 'To simulate touches the app needs to stay in the foreground.'),
          context: context,
        );
      });
    }
    _connectionStateSubscription = connection.connectionStream.listen((state) async {
      setState(() {});
    });

    if (!kIsWeb && Platform.isAndroid) {
      DeviceAutoRotateChecker.checkAutoRotate().then((isEnabled) {
        if (!isEnabled) {
          setState(() {
            _showAutoRotationWarning = true;
          });
        }
      });
      _autoRotateStream = DeviceAutoRotateChecker.autoRotateStream.listen((isEnabled) {
        setState(() {
          _showAutoRotationWarning = !isEnabled;
        });
      });

      // Check if device is MIUI and using local accessibility service
      if (actionHandler is AndroidActions) {
        _checkMiuiDevice();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _autoRotateStream?.cancel();
    _connectionStateSubscription.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (actionHandler is RemoteActions && Platform.isIOS && (actionHandler as RemoteActions).isConnected) {
        UniversalBle.getBluetoothAvailabilityState().then((state) {
          if (state == AvailabilityState.poweredOn && mounted) {
            final requirement = RemoteRequirement();
            requirement.reconnect();
            showToast(
              builder: (c, overlay) =>
                  buildToast(c, overlay, title: 'To simulate touches the app needs to stay in the foreground.'),
              context: context,
            );
          }
        });
      }
    }
  }

  Future<void> _checkMiuiDevice() async {
    try {
      // Don't show if user has dismissed the warning
      if (settings.getMiuiWarningDismissed()) {
        return;
      }

      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      final isMiui =
          deviceInfo.manufacturer.toLowerCase() == 'xiaomi' ||
          deviceInfo.brand.toLowerCase() == 'xiaomi' ||
          deviceInfo.brand.toLowerCase() == 'redmi' ||
          deviceInfo.brand.toLowerCase() == 'poco';
      if (isMiui && mounted) {
        setState(() {
          _showMiuiWarning = true;
        });
      }
    } catch (e) {
      // Silently fail if device info is not available
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          if (_showNameChangeWarning && !screenshotMode)
            Warning(
              important: false,
              children: [
                Text(
                  'SwiftControl is now BikeControl!\nIt is part of the OpenBikeControl project, advocating for open standards in smart bike trainers - and building affordable hardware controllers!',
                ),
                SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showNameChangeWarning = false;
                    });
                    launchUrlString('https://openbikecontrol.org');
                  },
                  child: Text('More Information'),
                ),
              ],
            ),
          if (_showAutoRotationWarning)
            Warning(
              important: false,
              children: [
                Text('Enable auto-rotation on your device to make sure the app works correctly.'),
              ],
            ),
          if (_showMiuiWarning)
            Warning(
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'MIUI Device Detected',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton.destructive(
                      icon: Icon(Icons.close),
                      onPressed: () async {
                        await settings.setMiuiWarningDismissed(true);
                        setState(() {
                          _showMiuiWarning = false;
                        });
                      },
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Your device is running MIUI, which is known to aggressively kill background services and accessibility services.',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 8),
                Text(
                  'To ensure BikeControl works properly:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Text(
                  '• Disable battery optimization for BikeControl',
                  style: TextStyle(fontSize: 14),
                ),
                Text(
                  '• Enable autostart for BikeControl',
                  style: TextStyle(fontSize: 14),
                ),
                Text(
                  '• Lock the app in recent apps',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 12),
                IconButton.secondary(
                  onPressed: () async {
                    final url = Uri.parse('https://dontkillmyapp.com/xiaomi');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: Icon(Icons.open_in_new),
                  trailing: Text('View Detailed Instructions'),
                ),
              ],
            ),

          ScanWidget(),
          ...connection.controllerDevices.map(
            (device) => Card(child: device.showInformation(context)),
          ),

          if (settings.getIgnoredDevices().isNotEmpty)
            OutlineButton(
              child: Text('Manage Ignored Devices'),
              onPressed: () async {
                await showDialog(
                  context: context,
                  builder: (context) => IgnoredDevicesDialog(),
                );
                setState(() {});
              },
            ),

          if (connection.controllerDevices.isNotEmpty)
            PrimaryButton(
              child: Text('Continue'),
              onPressed: () {
                widget.onUpdate();
              },
            ),
        ],
      ),
    );
  }
}

extension Screenshot on String {
  String get screenshot => screenshotMode ? replaceAll('Zwift ', '') : this;
}
