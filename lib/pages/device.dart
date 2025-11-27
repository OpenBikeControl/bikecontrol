import 'dart:async';
import 'dart:io';

import 'package:device_auto_rotate_checker/device_auto_rotate_checker.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_emulator.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/actions/desktop.dart';
import 'package:swift_control/utils/keymap/apps/my_whoosh.dart';
import 'package:swift_control/utils/requirements/multi.dart';
import 'package:swift_control/widgets/apps/mywhoosh_link_tile.dart';
import 'package:swift_control/widgets/apps/zwift_tile.dart';
import 'package:swift_control/widgets/logviewer.dart';
import 'package:swift_control/widgets/scan.dart';
import 'package:swift_control/widgets/status.dart';
import 'package:swift_control/widgets/ui/small_progress_indicator.dart';
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
import '../widgets/changelog_dialog.dart';

class DevicePage extends StatefulWidget {
  const DevicePage({super.key});

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowChangelog();
    });

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

  Future<void> _checkAndShowChangelog() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final lastSeenVersion = settings.getLastSeenVersion();

      if (mounted) {
        await ChangelogDialog.showIfNeeded(context, currentVersion, lastSeenVersion);
      }

      // Update last seen version
      await settings.setLastSeenVersion(currentVersion);
    } catch (e) {
      print('Failed to check changelog: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final paddingMultiplicator = actionHandler is DesktopActions ? 2.5 : 1.0;

    return PopScope(
      onPopInvokedWithResult: (hello, _) {
        connection.reset();
      },
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          top: 16,
          left: 8.0 * paddingMultiplicator,
          right: 8 * paddingMultiplicator,
          bottom: 8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
            Card(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16.0,
                  right: 16,
                  top: 16,
                  bottom: actionHandler is RemoteActions ? 0 : 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 8.0),
                      width: double.infinity,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Connected Controllers',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (connection.controllerDevices.isEmpty) SmallProgressIndicator(),
                          ],
                        ),
                      ),
                    ),
                    if (connection.controllerDevices.isEmpty)
                      ScanWidget()
                    else
                      ...connection.controllerDevices.map(
                        (device) => device.showInformation(context),
                      ),

                    if (actionHandler is RemoteActions ||
                        whooshLink.isCompatible(settings.getLastTarget() ?? Target.thisDevice) ||
                        actionHandler.supportedApp?.supportsZwiftEmulation == true)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8.0),
                        width: double.infinity,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            'Remote Connections',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),

                    if (settings.getTrainerApp() is MyWhoosh && whooshLink.isCompatible(settings.getLastTarget()!))
                      MyWhooshLinkTile(),
                    if (settings.getTrainerApp()?.supportsZwiftEmulation == true)
                      ZwiftTile(
                        onUpdate: () {
                          setState(() {});
                        },
                      ),

                    if (actionHandler is RemoteActions && isAdvertisingPeripheral)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Remote Control Mode: ${(actionHandler as RemoteActions).isConnected ? 'Connected' : 'Not connected (optional)'}',
                          ),
                          IconButton.secondary(
                            icon: Icon(Icons.more_vert),
                            onPressed: () {
                              showDropdown(
                                context: context,
                                builder: (context) {
                                  return DropdownMenu(
                                    children: [
                                      MenuButton(
                                        child: const Text('Reconnect'),
                                        onPressed: (c) async {
                                          final requirement = RemoteRequirement();
                                          await requirement.reconnect();
                                        },
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      )
                    else
                      SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),
            StatusWidget(),
            SizedBox(height: 20),
            Collapsible(
              children: [
                CollapsibleTrigger(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text('Logs'),
                  ),
                ),
                CollapsibleContent(child: SizedBox(height: 500, width: 500, child: LogViewer())),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

extension Screenshot on String {
  String get screenshot => screenshotMode ? replaceAll('Zwift ', '') : this;
}
