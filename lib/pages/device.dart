import 'dart:async';
import 'dart:io';

import 'package:device_auto_rotate_checker/device_auto_rotate_checker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:swift_control/bluetooth/devices/zwift/protocol/zp.pbenum.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_device.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/pages/markdown.dart';
import 'package:swift_control/pages/touch_area.dart';
import 'package:swift_control/utils/actions/android.dart';
import 'package:swift_control/utils/actions/desktop.dart';
import 'package:swift_control/utils/actions/link.dart';
import 'package:swift_control/utils/keymap/manager.dart';
import 'package:swift_control/widgets/beta_pill.dart';
import 'package:swift_control/widgets/ingameactions_customizer.dart';
import 'package:swift_control/widgets/keymap_explanation.dart';
import 'package:swift_control/widgets/loading_widget.dart';
import 'package:swift_control/widgets/logviewer.dart';
import 'package:swift_control/widgets/small_progress_indicator.dart';
import 'package:swift_control/widgets/testbed.dart';
import 'package:swift_control/widgets/title.dart';
import 'package:swift_control/widgets/warning.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../bluetooth/devices/base_device.dart';
import '../utils/actions/remote.dart';
import '../utils/keymap/apps/custom_app.dart';
import '../utils/keymap/apps/supported_app.dart';
import '../utils/requirements/remote.dart';
import '../widgets/menu.dart';

class DevicePage extends StatefulWidget {
  const DevicePage({super.key});

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> with WidgetsBindingObserver {
  late StreamSubscription<BaseDevice> _connectionStateSubscription;
  final controller = TextEditingController(text: actionHandler.supportedApp?.name);

  bool _showAutoRotateWarning = false;

  List<SupportedApp> _getAllApps() {
    final baseApps = SupportedApp.supportedApps.where((app) => app is! CustomApp).toList();
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

    return [...baseApps, ...customApps];
  }

  @override
  void initState() {
    super.initState();

    // keep screen on - this is required for iOS to keep the bluetooth connection alive
    WakelockPlus.enable();
    WidgetsBinding.instance.addObserver(this);

    if (actionHandler is RemoteActions && !kIsWeb && Platform.isIOS) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // show snackbar to inform user that the app needs to stay in foreground
        _snackBarMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('To keep working properly the app needs to stay in the foreground.'),
            duration: Duration(seconds: 5),
          ),
        );
      });
    } else if (actionHandler is AndroidActions) {
      DeviceAutoRotateChecker.checkAutoRotate().then((autoRotate) => _showAutoRotateWarning = !autoRotate);
      _deviceAutoRotateStream = DeviceAutoRotateChecker.autoRotateStream.listen((autoRotate) {
        setState(() {
          _showAutoRotateWarning = !autoRotate;
        });
      });
    }
    _connectionStateSubscription = connection.connectionStream.listen((state) async {
      setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _connectionStateSubscription.cancel();
    controller.dispose();
    _deviceAutoRotateStream?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (actionHandler is RemoteActions && Platform.isIOS) {
        UniversalBle.getBluetoothAvailabilityState().then((state) {
          if (state == AvailabilityState.poweredOn) {
            final requirement = RemoteRequirement();
            requirement.reconnect();
            _snackBarMessengerKey.currentState?.showSnackBar(
              SnackBar(
                content: Text('To keep working properly the app needs to stay in the foreground.'),
                duration: Duration(seconds: 5),
              ),
            );
          }
        });
      }
    }
  }

  final _snackBarMessengerKey = GlobalKey<ScaffoldMessengerState>();

  StreamSubscription<bool>? _deviceAutoRotateStream;

  @override
  Widget build(BuildContext context) {
    final canVibrate = connection.devices.any(
      (device) => (device.device.name == 'Zwift Ride' || device.device.name == 'Zwift Play') && device.isConnected,
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
                backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
                    if (_showAutoRotateWarning)
                      Warning(
                        children: [
                          Text('Enable auto-rotation on your device to make sure the app works correctly.'),
                        ],
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text('Connected Devices', style: Theme.of(context).textTheme.titleMedium),
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
                            if (connection.devices.isEmpty) Text('No devices connected. Searching...'),
                            ...connection.devices.map(
                              (device) => Row(
                                children: [
                                  Text(
                                    device.device.name?.screenshot ?? device.runtimeType.toString(),
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  if (device.isBeta) BetaPill(),
                                  if (device.batteryLevel != null) ...[
                                    Icon(switch (device.batteryLevel!) {
                                      >= 80 => Icons.battery_full,
                                      >= 60 => Icons.battery_6_bar,
                                      >= 50 => Icons.battery_5_bar,
                                      >= 25 => Icons.battery_4_bar,
                                      >= 10 => Icons.battery_2_bar,
                                      _ => Icons.battery_alert,
                                    }),
                                    Text('${device.batteryLevel}%'),
                                    if (device.firmwareVersion != null) Text(' - Firmware: ${device.firmwareVersion}'),
                                    if (device.firmwareVersion != null &&
                                        device is ZwiftDevice &&
                                        device.firmwareVersion != device.latestFirmwareVersion) ...[
                                      SizedBox(width: 8),
                                      Icon(Icons.warning, color: Theme.of(context).colorScheme.error),
                                      Text(
                                        ' (latest: ${device.latestFirmwareVersion})',
                                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                                      ),
                                    ],
                                  ],
                                ],
                              ),
                            ),
                            if (actionHandler is RemoteActions)
                              Row(
                                children: [
                                  Text(
                                    'Remote Control Mode: ${(actionHandler as RemoteActions).isConnected ? 'Connected' : 'Not connected'}',
                                  ),
                                  LoadingWidget(
                                    futureCallback: () async {
                                      final requirement = RemoteRequirement();
                                      await requirement.reconnect();
                                    },
                                    renderChild: (isLoading, tap) => TextButton(
                                      onPressed: tap,
                                      child: isLoading ? SmallProgressIndicator() : Text('Reconnect'),
                                    ),
                                  ),
                                ],
                              )
                            else if (actionHandler is LinkActions)
                              ValueListenableBuilder(
                                valueListenable: whooshLink.isConnected,
                                builder: (BuildContext context, value, Widget? child) {
                                  return Text(
                                    'Link connected: ${value ? 'Connected' : 'Not connected'}',
                                  );
                                },
                              ),

                            if (connection.devices.any((device) => (device is ZwiftClickV2) && device.isConnected))
                              Warning(
                                children: [
                                  Text(
                                    '''To make your Zwift Click V2 work best you should connect it in the Zwift app once each day.\nIf you don't do that SwiftControl will need to reconnect every minute.

1. Open Zwift app
2. Log in (subscription not required) and open the device connection screen
3. Connect your Trainer, then connect the Zwift Click V2
4. Close the Zwift app again and connect again in SwiftControl''',
                                  ),
                                  Row(
                                    children: [
                                      TextButton(
                                        onPressed: () {
                                          connection.devices.whereType<ZwiftClickV2>().forEach(
                                            (device) => device.sendCommand(Opcode.RESET, null),
                                          );
                                        },
                                        child: Text('Reset now'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => MarkdownPage(assetPath: 'TROUBLESHOOTING.md'),
                                            ),
                                          );
                                        },
                                        child: Text('Troubleshooting'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),

                    if (!kIsWeb) ...[
                      SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text('Customize', style: Theme.of(context).textTheme.titleMedium),
                      ),
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
                              if (actionHandler is! LinkActions)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  spacing: 8,
                                  children: [
                                    Expanded(
                                      child: DropdownMenu<SupportedApp?>(
                                        controller: controller,
                                        dropdownMenuEntries: [
                                          ..._getAllApps().map(
                                            (app) => DropdownMenuEntry<SupportedApp>(value: app, label: app.name),
                                          ),
                                          DropdownMenuEntry(
                                            value: CustomApp(profileName: 'New'),
                                            label: 'Create new keymap',
                                            labelWidget: Text('Create new keymap'),
                                            leadingIcon: Icon(Icons.add),
                                          ),
                                        ],
                                        label: Text('Select Keymap / app'),
                                        onSelected: (app) async {
                                          if (app == null) {
                                            return;
                                          } else if (app.name == 'New') {
                                            final profileName = await KeypadManager().showNewProfileDialog(context);
                                            if (profileName != null && profileName.isNotEmpty) {
                                              final customApp = CustomApp(profileName: profileName);
                                              actionHandler.supportedApp = customApp;
                                              await settings.setApp(customApp);
                                              controller.text = profileName;
                                              setState(() {});
                                            }
                                          } else {
                                            controller.text = app.name ?? '';
                                            actionHandler.supportedApp = app;
                                            await settings.setApp(app);
                                            setState(() {});
                                            if (app is! CustomApp &&
                                                !kIsWeb &&
                                                (Platform.isMacOS || Platform.isWindows)) {
                                              _snackBarMessengerKey.currentState!.showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Customize the keymap if you experience any issues (e.g. wrong keyboard output)',
                                                  ),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                        initialSelection: actionHandler.supportedApp,
                                        hintText: 'Select your Keymap',
                                      ),
                                    ),

                                    Row(
                                      children: [
                                        if (actionHandler.supportedApp != null)
                                          ElevatedButton.icon(
                                            onPressed: () async {
                                              if (actionHandler.supportedApp is! CustomApp) {
                                                final result = await KeypadManager().duplicate(
                                                  context,
                                                  actionHandler.supportedApp!.name,
                                                );
                                                if (result == null) {
                                                  return;
                                                }
                                              }
                                              final result = await Navigator.of(
                                                context,
                                              ).push<bool>(MaterialPageRoute(builder: (_) => TouchAreaSetupPage()));

                                              if (result == true && actionHandler.supportedApp is CustomApp) {
                                                await settings.setApp(actionHandler.supportedApp!);
                                              }
                                              setState(() {});
                                            },
                                            icon: Icon(Icons.edit),
                                            label: Text('Edit'),
                                          ),

                                        IconButton(
                                          onPressed: () async {
                                            final currentProfile = actionHandler.supportedApp?.name;
                                            final action = await KeypadManager().showManageProfileDialog(
                                              context,
                                              currentProfile,
                                            );
                                            if (action != null) {
                                              if (action == 'rename') {
                                                final newName = await KeypadManager().showRenameProfileDialog(
                                                  context,
                                                  currentProfile!,
                                                );
                                                if (newName != null &&
                                                    newName.isNotEmpty &&
                                                    newName != currentProfile) {
                                                  await settings.duplicateCustomAppProfile(currentProfile, newName);
                                                  await settings.deleteCustomAppProfile(currentProfile);
                                                  final customApp = CustomApp(profileName: newName);
                                                  final savedKeymap = settings.getCustomAppKeymap(newName);
                                                  if (savedKeymap != null) {
                                                    customApp.decodeKeymap(savedKeymap);
                                                  }
                                                  actionHandler.supportedApp = customApp;
                                                  await settings.setApp(customApp);
                                                  controller.text = newName;
                                                  setState(() {});
                                                }
                                              } else if (action == 'duplicate') {
                                                final newName = await KeypadManager().duplicate(
                                                  context,
                                                  currentProfile!,
                                                );

                                                if (newName != null) {
                                                  controller.text = newName;
                                                  setState(() {});
                                                }
                                              } else if (action == 'delete') {
                                                final confirmed = await KeypadManager().showDeleteConfirmDialog(
                                                  context,
                                                  currentProfile!,
                                                );
                                                if (confirmed == true) {
                                                  await settings.deleteCustomAppProfile(currentProfile);
                                                  controller.text = '';
                                                  setState(() {});
                                                }
                                              } else if (action == 'import') {
                                                final jsonData = await KeypadManager().showImportDialog(context);
                                                if (jsonData != null && jsonData.isNotEmpty) {
                                                  final success = await settings.importCustomAppProfile(jsonData);
                                                  if (mounted) {
                                                    if (success) {
                                                      _snackBarMessengerKey.currentState!.showSnackBar(
                                                        SnackBar(
                                                          content: Text('Profile imported successfully'),
                                                          duration: Duration(seconds: 5),
                                                        ),
                                                      );
                                                      setState(() {});
                                                    } else {
                                                      _snackBarMessengerKey.currentState!.showSnackBar(
                                                        SnackBar(
                                                          content: Text('Failed to import profile. Invalid format.'),
                                                          duration: Duration(seconds: 5),
                                                          backgroundColor: Colors.red,
                                                        ),
                                                      );
                                                    }
                                                  }
                                                }
                                              } else if (action == 'export') {
                                                final currentProfile =
                                                    (actionHandler.supportedApp as CustomApp).profileName;
                                                final jsonData = settings.exportCustomAppProfile(currentProfile);
                                                if (jsonData != null) {
                                                  await Clipboard.setData(ClipboardData(text: jsonData));
                                                  if (mounted) {
                                                    _snackBarMessengerKey.currentState!.showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          'Profile "$currentProfile" exported to clipboard',
                                                        ),
                                                        duration: Duration(seconds: 5),
                                                      ),
                                                    );
                                                  }
                                                }
                                              }
                                            }
                                          },
                                          icon: Icon(Icons.more_vert),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              if (actionHandler is LinkActions)
                                InGameActionsCustomizer()
                              else if (actionHandler.supportedApp != null)
                                KeymapExplanation(
                                  key: Key(actionHandler.supportedApp!.keymap.runtimeType.toString()),
                                  keymap: actionHandler.supportedApp!.keymap,
                                  onUpdate: () {
                                    setState(() {});
                                    controller.text = actionHandler.supportedApp?.name ?? '';
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text('Logs', style: Theme.of(context).textTheme.titleMedium),
                    ),
                    LogViewer(),
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
}

extension Screenshot on String {
  String get screenshot => screenshotMode ? replaceAll('Zwift ', '') : this;
}
