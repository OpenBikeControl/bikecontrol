import 'dart:async';
import 'dart:io';

import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:swift_control/bluetooth/devices/zwift/protocol/zp.pbenum.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/pages/markdown.dart';
import 'package:swift_control/pages/touch_area.dart';
import 'package:swift_control/utils/actions/desktop.dart';
import 'package:swift_control/widgets/keymap_explanation.dart';
import 'package:swift_control/widgets/loading_widget.dart';
import 'package:swift_control/widgets/logviewer.dart';
import 'package:swift_control/widgets/small_progress_indicator.dart';
import 'package:swift_control/widgets/testbed.dart';
import 'package:swift_control/widgets/title.dart';
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
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && actionHandler is RemoteActions && Platform.isIOS) {
      final requirement = RemoteRequirement();
      requirement.reconnect();
      _snackBarMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('To keep working properly the app needs to stay in the foreground.'),
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  final _snackBarMessengerKey = GlobalKey<ScaffoldMessengerState>();

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
                          children: [
                            if (connection.devices.isEmpty)
                              Text('No devices connected. Go back and connect a device to get started.'),
                            ...connection.devices.map(
                              (device) => Row(
                                children: [
                                  Text(
                                    device.device.name?.screenshot ?? device.runtimeType.toString(),
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  if (device.isBeta)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8.0),
                                      child: Container(
                                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.orange,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'BETA',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
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
                              ),

                            if (connection.devices.any((device) => (device is ZwiftClickV2) && device.isConnected))
                              Container(
                                margin: EdgeInsets.only(bottom: 6),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.start,
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
                                          final profileName = await _showNewProfileDialog();
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
                                              await _duplicate(actionHandler.supportedApp!.name);
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
                                          final action = await _showManageProfileDialog(currentProfile);
                                          if (action != null) {
                                            if (action == 'rename') {
                                              final newName = await _showRenameProfileDialog(currentProfile!);
                                              if (newName != null && newName.isNotEmpty && newName != currentProfile) {
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
                                              _duplicate(currentProfile!);
                                            } else if (action == 'delete') {
                                              final confirmed = await _showDeleteConfirmDialog(currentProfile!);
                                              if (confirmed == true) {
                                                await settings.deleteCustomAppProfile(currentProfile);
                                                controller.text = '';
                                                setState(() {});
                                              }
                                            } else if (action == 'import') {
                                              final jsonData = await _showImportDialog();
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
                                                      content: Text('Profile "$currentProfile" exported to clipboard'),
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
                              if (actionHandler.supportedApp != null)
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

  Future<String?> _showNewProfileDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('New Custom Profile'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: 'Profile Name', hintText: 'e.g., Workout, Race, Event'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: Text('Create')),
        ],
      ),
    );
  }

  Future<String?> _showManageProfileDialog(String? currentProfile) async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Manage Profile: ${currentProfile ?? ''}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (currentProfile != null && actionHandler.supportedApp is CustomApp)
              ListTile(
                leading: Icon(Icons.edit),
                title: Text('Rename'),
                onTap: () => Navigator.pop(context, 'rename'),
              ),
            if (currentProfile != null)
              ListTile(
                leading: Icon(Icons.copy),
                title: Text('Duplicate'),
                onTap: () => Navigator.pop(context, 'duplicate'),
              ),
            ListTile(
              leading: Icon(Icons.file_upload),
              title: Text('Import'),
              onTap: () => Navigator.pop(context, 'import'),
            ),
            if (currentProfile != null)
              ListTile(
                leading: Icon(Icons.share),
                title: Text('Export'),
                onTap: () => Navigator.pop(context, 'export'),
              ),
            if (currentProfile != null)
              ListTile(
                leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                title: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel'))],
      ),
    );
  }

  Future<String?> _showRenameProfileDialog(String currentName) async {
    final controller = TextEditingController(text: currentName);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rename Profile'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: 'Profile Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: Text('Rename')),
        ],
      ),
    );
  }

  Future<String?> _showDuplicateProfileDialog(String currentName) async {
    final controller = TextEditingController(text: '$currentName (Copy)');
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Duplicate Profile'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: 'New Profile Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: Text('Duplicate')),
        ],
      ),
    );
  }

  Future<bool?> _showDeleteConfirmDialog(String profileName) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Profile'),
        content: Text('Are you sure you want to delete "$profileName"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  Future<String?> _showImportDialog() async {
    final controller = TextEditingController();

    // Try to get data from clipboard
    try {
      final clipboardData = await Clipboard.getData('text/plain');
      if (clipboardData?.text != null) {
        controller.text = clipboardData!.text!;
      }
    } catch (e) {
      // Ignore clipboard errors
    }

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Import Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Paste the exported JSON data below:'),
            SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(labelText: 'JSON Data', border: OutlineInputBorder()),
              maxLines: 5,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: Text('Import')),
        ],
      ),
    );
  }

  Future<void> _duplicate(String currentProfile) async {
    final newName = await _showDuplicateProfileDialog(currentProfile);
    if (newName != null && newName.isNotEmpty) {
      if (actionHandler.supportedApp is CustomApp) {
        await settings.duplicateCustomAppProfile(currentProfile, newName);
        final customApp = CustomApp(profileName: newName);
        final savedKeymap = settings.getCustomAppKeymap(newName);
        if (savedKeymap != null) {
          customApp.decodeKeymap(savedKeymap);
        }
        actionHandler.supportedApp = customApp;
        await settings.setApp(customApp);
        controller.text = newName;
        setState(() {});
      } else {
        final customApp = CustomApp(profileName: newName);

        final connectedDevice = connection.devices.firstOrNull;
        actionHandler.supportedApp!.keymap.keyPairs.forEachIndexed((pair, index) {
          pair.buttons.filter((button) => connectedDevice?.availableButtons.contains(button) == true).forEachIndexed((
            button,
            indexB,
          ) {
            customApp.setKey(
              button,
              physicalKey: pair.physicalKey,
              logicalKey: pair.logicalKey,
              isLongPress: pair.isLongPress,
              touchPosition: pair.touchPosition != Offset.zero
                  ? pair.touchPosition
                  : Offset(((indexB + 1)) * 10, 20 + (index * 10)),
            );
          });
        });

        actionHandler.supportedApp = customApp;
        await settings.setApp(customApp);
        controller.text = newName;
        setState(() {});
      }
    }
  }
}

extension Screenshot on String {
  String get screenshot => screenshotMode ? replaceAll('Zwift ', '') : this;
}
