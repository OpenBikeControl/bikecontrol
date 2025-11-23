import 'dart:async';
import 'dart:io';

import 'package:device_auto_rotate_checker/device_auto_rotate_checker.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_device.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_emulator.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/actions/desktop.dart';
import 'package:swift_control/utils/keymap/apps/my_whoosh.dart';
import 'package:swift_control/utils/keymap/manager.dart';
import 'package:swift_control/utils/requirements/multi.dart';
import 'package:swift_control/widgets/apps/mywhoosh_link_tile.dart';
import 'package:swift_control/widgets/apps/zwift_tile.dart';
import 'package:swift_control/widgets/beta_pill.dart';
import 'package:swift_control/widgets/keymap_explanation.dart';
import 'package:swift_control/widgets/logviewer.dart';
import 'package:swift_control/widgets/scan.dart';
import 'package:swift_control/widgets/small_progress_indicator.dart';
import 'package:swift_control/widgets/status.dart';
import 'package:swift_control/widgets/testbed.dart';
import 'package:swift_control/widgets/title.dart';
import 'package:swift_control/widgets/warning.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../bluetooth/devices/base_device.dart';
import '../utils/actions/android.dart';
import '../utils/actions/remote.dart';
import '../utils/keymap/apps/custom_app.dart';
import '../utils/keymap/apps/supported_app.dart';
import '../utils/requirements/remote.dart';
import '../widgets/changelog_dialog.dart';
import '../widgets/menu.dart';

class DevicePage extends StatefulWidget {
  const DevicePage({super.key});

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> with WidgetsBindingObserver {
  late StreamSubscription<BaseDevice> _connectionStateSubscription;
  final controller = TextEditingController(text: actionHandler.supportedApp?.name);
  final _snackBarMessengerKey = GlobalKey<ScaffoldMessengerState>();
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
        _snackBarMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('To simulate touches the app needs to stay in the foreground.'),
            duration: Duration(seconds: 5),
          ),
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
    controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (actionHandler is RemoteActions && Platform.isIOS && (actionHandler as RemoteActions).isConnected) {
        UniversalBle.getBluetoothAvailabilityState().then((state) {
          if (state == AvailabilityState.poweredOn) {
            final requirement = RemoteRequirement();
            requirement.reconnect();
            _snackBarMessengerKey.currentState?.showSnackBar(
              SnackBar(
                content: Text('To simulate touches the app needs to stay in the foreground.'),
                duration: Duration(seconds: 5),
              ),
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
    final canVibrate = connection.bluetoothDevices.any(
      (device) => device.isConnected && device is ZwiftDevice && device.canVibrate,
    );

    final paddingMultiplicator = actionHandler is DesktopActions ? 2.5 : 1.0;

    return ScaffoldMessenger(
      key: _snackBarMessengerKey,
      child: PopScope(
        onPopInvokedWithResult: (hello, _) {
          connection.reset();
        },
        child: Stack(
          children: [
            Scaffold(
              appBar: AppBar(
                title: AppTitle(),
                actions: buildMenuButtons(),
                backgroundColor: Theme.brightnessOf(context) == Brightness.light
                    ? Theme.of(context).colorScheme.inversePrimary
                    : null,
              ),
              body: SingleChildScrollView(
                padding: EdgeInsets.only(
                  top: 16,
                  left: 8.0 * paddingMultiplicator,
                  right: 8 * paddingMultiplicator,
                  bottom: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_showNameChangeWarning)
                      Warning(
                        important: false,
                        children: [
                          Text(
                            'SwiftControl is now BikeControl! It is now part of the OpenBikeControl project, advocating for open standards in smart bike trainers - and building affordable hardware controllers!',
                          ),
                          SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              launchUrlString('https://openbikecontrol.org');
                            },
                            child: Text('More information'),
                          ),
                        ],
                      ),
                    if (_showAutoRotationWarning)
                      Warning(
                        children: [
                          Text('Enable auto-rotation on your device to make sure the app works correctly.'),
                        ],
                      ),
                    if (_showMiuiWarning)
                      Warning(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning_amber, color: Theme.of(context).colorScheme.error),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'MIUI Device Detected',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.close),
                                onPressed: () async {
                                  await settings.setMiuiWarningDismissed(true);
                                  setState(() {
                                    _showMiuiWarning = false;
                                  });
                                },
                                tooltip: 'Dismiss',
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(),
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
                          ElevatedButton.icon(
                            onPressed: () async {
                              final url = Uri.parse('https://dontkillmyapp.com/xiaomi');
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url, mode: LaunchMode.externalApplication);
                              }
                            },
                            icon: Icon(Icons.open_in_new),
                            label: Text('View Detailed Instructions'),
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
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Theme.of(context).colorScheme.primaryContainer,
                                  ),
                                ),
                              ),
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
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Theme.of(context).colorScheme.primaryContainer,
                                    ),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Text(
                                    'Remote Connections',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),

                            if (settings.getTrainerApp() is MyWhoosh &&
                                whooshLink.isCompatible(settings.getLastTarget()!))
                              MyWhooshLinkTile(),
                            if (settings.getTrainerApp()?.supportsZwiftEmulation == true)
                              ZwiftTile(
                                onUpdate: () {
                                  setState(() {});
                                },
                              ),

                            if (actionHandler is RemoteActions)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Remote Control Mode: ${(actionHandler as RemoteActions).isConnected ? 'Connected' : 'Not connected (optional)'}',
                                  ),
                                  PopupMenuButton(
                                    itemBuilder: (_) => [
                                      PopupMenuItem(
                                        child: Text('Reconnect'),
                                        onTap: () async {
                                          final requirement = RemoteRequirement();
                                          await requirement.reconnect();
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 20),
                    StatusWidget(),
                    SizedBox(height: 20),
                    if (!kIsWeb) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          'Customize ${screenshotMode ? 'Trainer app' : settings.getTrainerApp()?.name} on ${settings.getLastTarget()?.title}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),

                      if (settings.getLastTarget()?.warning != null) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.warning_amber,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            Text(
                              settings.getLastTarget()!.warning!,
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ],
                      Card(
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: 16.0,
                            right: 16,
                            top: 16,
                            bottom: canVibrate ? 0 : 12,
                          ),
                          child: Column(
                            spacing: 12,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                spacing: 8,
                                children: [
                                  Expanded(
                                    child: DropdownMenu<SupportedApp?>(
                                      controller: controller,
                                      dropdownMenuEntries: [
                                        ..._getAllApps().map(
                                          (app) => DropdownMenuEntry<SupportedApp>(
                                            value: app,
                                            label: screenshotMode ? 'Trainer app' : app.name,
                                            labelWidget: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(app.name),
                                                if (app is CustomApp) BetaPill(text: 'CUSTOM'),
                                              ],
                                            ),
                                          ),
                                        ),
                                        DropdownMenuEntry(
                                          value: CustomApp(profileName: 'New'),
                                          label: 'Create new keymap',
                                          labelWidget: Text('Create new keymap'),
                                          leadingIcon: Icon(Icons.add),
                                        ),
                                      ],
                                      label: Text('Select Keymap'),
                                      onSelected: (app) async {
                                        if (app == null) {
                                          return;
                                        } else if (app.name == 'New') {
                                          final profileName = await KeymapManager().showNewProfileDialog(context);
                                          if (profileName != null && profileName.isNotEmpty) {
                                            final customApp = CustomApp(profileName: profileName);
                                            actionHandler.init(customApp);
                                            await settings.setKeyMap(customApp);
                                            controller.text = profileName;
                                            setState(() {});
                                          }
                                        } else {
                                          controller.text = app.name ?? '';
                                          actionHandler.supportedApp = app;
                                          await settings.setKeyMap(app);
                                          setState(() {});
                                        }
                                      },
                                      initialSelection: actionHandler.supportedApp,
                                      hintText: 'Select your Keymap',
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      KeymapManager().getManageProfileDialog(
                                        context,
                                        actionHandler.supportedApp is CustomApp
                                            ? actionHandler.supportedApp?.name
                                            : null,
                                        onDone: () {
                                          setState(() {});
                                          controller.text = actionHandler.supportedApp?.name ?? '';
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              if (actionHandler.supportedApp is! CustomApp)
                                Text(
                                  'Customize the keymap if you experience any issues (e.g. wrong keyboard output, or misaligned touch placements)',
                                  style: TextStyle(fontSize: 12),
                                ),
                              if (actionHandler.supportedApp != null && connection.controllerDevices.isNotEmpty)
                                KeymapExplanation(
                                  key: Key(actionHandler.supportedApp!.keymap.runtimeType.toString()),
                                  keymap: actionHandler.supportedApp!.keymap,
                                  onUpdate: () {
                                    setState(() {});
                                    controller.text = actionHandler.supportedApp?.name ?? '';

                                    if (actionHandler.supportedApp is CustomApp) {
                                      settings.setKeyMap(actionHandler.supportedApp!);
                                    }
                                  },
                                ),
                              if (canVibrate) ...[
                                SwitchListTile(
                                  title: Text('Enable vibration feedback when shifting gears'),
                                  value: settings.getVibrationEnabled(),
                                  contentPadding: EdgeInsets.zero,
                                  onChanged: (value) async {
                                    await settings.setVibrationEnabled(value);
                                    setState(() {});
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                    SizedBox(height: 20),
                    ExpansionTile(
                      title: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text('Logs', style: Theme.of(context).textTheme.titleMedium),
                      ),
                      maintainState: true,
                      children: [
                        SizedBox(height: 500, child: LogViewer()),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Positioned.fill(child: Testbed()),
          ],
        ),
      ),
    );
  }

  List<SupportedApp> _getAllApps() {
    final baseApp = settings.getTrainerApp();
    final customProfiles = settings.getCustomAppProfiles();

    final customApps = customProfiles.map((profile) {
      final customApp = CustomApp(profileName: profile);
      final savedKeymap = settings.getCustomAppKeymap(profile);
      if (savedKeymap != null) {
        customApp.decodeKeymap(savedKeymap);
      }
      return customApp;
    }).toList();

    // If no custom profiles exist, add the default "Custom" one
    if (customApps.isEmpty) {
      customApps.add(CustomApp());
    }

    return [if (baseApp != null) baseApp, ...customApps];
  }
}

extension Screenshot on String {
  String get screenshot => screenshotMode ? replaceAll('Zwift ', '') : this;
}
