import 'dart:async';
import 'dart:io';

import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:swift_control/bluetooth/devices/zwift_clickv2.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/pages/touch_area.dart';
import 'package:swift_control/widgets/keymap_explanation.dart';
import 'package:swift_control/widgets/logviewer.dart';
import 'package:swift_control/widgets/testbed.dart';
import 'package:swift_control/widgets/title.dart';

import '../bluetooth/devices/base_device.dart';
import '../utils/keymap/apps/custom_app.dart';
import '../utils/keymap/apps/supported_app.dart';
import '../widgets/menu.dart';

class DevicePage extends StatefulWidget {
  const DevicePage({super.key});

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  late StreamSubscription<BaseDevice> _connectionStateSubscription;
  final controller = TextEditingController(text: actionHandler.supportedApp?.name);
  
  List<SupportedApp> _getAllApps() {
    final baseApps = SupportedApp.supportedApps.where((app) => app is! CustomApp).toList();
    final customProfiles = settings.getCustomAppProfiles();
    
    // Get screen size for percentage-based decoding
    Size? screenSize;
    try {
      final view = WidgetsBinding.instance.platformDispatcher.views.first;
      screenSize = view.physicalSize / view.devicePixelRatio;
    } catch (e) {
      screenSize = MediaQuery.maybeOf(context)?.size;
    }
    
    final customApps = customProfiles.map((profile) {
      final customApp = CustomApp(profileName: profile);
      final savedKeymap = settings.getCustomAppKeymap(profile);
      if (savedKeymap != null) {
        customApp.decodeKeymap(savedKeymap, screenSize: screenSize);
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

    _connectionStateSubscription = connection.connectionStream.listen((state) async {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _connectionStateSubscription.cancel();
    controller.dispose();
    super.dispose();
  }

  final _snackBarMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
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
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 10,
                  children: [
                    Text('Connected Devices:', style: Theme.of(context).textTheme.titleMedium),

                    if (connection.devices.any((device) => (device is ZwiftClickV2) && device.isConnected))
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          '''To make your Zwift Click V2 work best you should connect it in the Zwift app once each day.\nIf you don't do that SwiftControl will need to reconnect every minute.

1. Open Zwift app
2. Log in (subscription not required) and open the device connection screen
3. Connect your Trainer, then connect the Zwift Click V2
4. Close the Zwift app again and connect again in SwiftControl''',
                        ),
                      ),
                    Text(
                      connection.devices.joinToString(
                        separator: '\n',
                        transform: (it) {
                          return """${it.device.name ?? it.runtimeType}: ${it.isConnected ? 'Connected' : 'Not connected'}
${it.batteryLevel != null ? ' - Battery Level: ${it.batteryLevel}%' : ''}
${it.firmwareVersion != null ? ' - Firmware Version: ${it.firmwareVersion}' : ''}""".trim();
                        },
                      ),
                    ),
                    Divider(color: Theme.of(context).colorScheme.primary, height: 30),
                    if (!kIsWeb)
                      Column(
                        spacing: 12,
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Flex(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            direction: MediaQuery.sizeOf(context).width > 600 ? Axis.horizontal : Axis.vertical,
                            spacing: 8,
                            children: [
                              DropdownMenu<SupportedApp>(
                                controller: controller,
                                dropdownMenuEntries:
                                    _getAllApps()
                                        .map((app) => DropdownMenuEntry<SupportedApp>(value: app, label: app.name))
                                        .toList(),
                                label: Text('Select Keymap / app'),
                                onSelected: (app) async {
                                  if (app == null) {
                                    return;
                                  }
                                  controller.text = app.name ?? '';
                                  actionHandler.supportedApp = app;
                                  await settings.setApp(app);
                                  setState(() {});
                                  if (app is! CustomApp && !kIsWeb && (Platform.isMacOS || Platform.isWindows)) {
                                    _snackBarMessengerKey.currentState!.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Customize the keymap if you experience any issues (e.g. wrong keyboard output)',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                initialSelection: actionHandler.supportedApp,
                                hintText: 'Select your Keymap',
                              ),

                              if (actionHandler.supportedApp != null)
                                ElevatedButton(
                                  onPressed: () async {
                                    if (actionHandler.supportedApp! is! CustomApp) {
                                      final customApp = CustomApp();

                                      final connectedDevice = connection.devices.firstOrNull;
                                      actionHandler.supportedApp!.keymap.keyPairs.forEachIndexed((pair, index) {
                                        pair.buttons
                                            .filter(
                                              (button) => connectedDevice?.availableButtons.contains(button) == true,
                                            )
                                            .forEachIndexed((button, indexB) {
                                              customApp.setKey(
                                                button,
                                                physicalKey: pair.physicalKey!,
                                                logicalKey: pair.logicalKey,
                                                isLongPress: pair.isLongPress,
                                                touchPosition:
                                                    pair.touchPosition != Offset.zero
                                                        ? pair.touchPosition
                                                        : Offset(((indexB + 1)) * 100, 200 + (index * 100)),
                                              );
                                            });
                                      });

                                      actionHandler.supportedApp = customApp;
                                      await settings.setApp(customApp);
                                    }
                                    final result = await Navigator.of(
                                      context,
                                    ).push<bool>(MaterialPageRoute(builder: (_) => TouchAreaSetupPage()));

                                    if (result == true && actionHandler.supportedApp is CustomApp) {
                                      await settings.setApp(actionHandler.supportedApp!);
                                    }
                                    setState(() {});
                                  },
                                  child: Text('Customize Keymap'),
                                ),
                              
                              ElevatedButton(
                                onPressed: () async {
                                  final profileName = await _showNewProfileDialog();
                                  if (profileName != null && profileName.isNotEmpty) {
                                    final customApp = CustomApp(profileName: profileName);
                                    actionHandler.supportedApp = customApp;
                                    await settings.setApp(customApp);
                                    controller.text = profileName;
                                    setState(() {});
                                  }
                                },
                                child: Text('New Custom Profile'),
                              ),
                              
                              if (actionHandler.supportedApp is CustomApp)
                                ElevatedButton(
                                  onPressed: () async {
                                    final currentProfile = (actionHandler.supportedApp as CustomApp).profileName;
                                    final action = await _showManageProfileDialog(currentProfile);
                                    if (action != null) {
                                      if (action == 'rename') {
                                        final newName = await _showRenameProfileDialog(currentProfile);
                                        if (newName != null && newName.isNotEmpty && newName != currentProfile) {
                                          await settings.duplicateCustomAppProfile(currentProfile, newName);
                                          await settings.deleteCustomAppProfile(currentProfile);
                                          final customApp = CustomApp(profileName: newName);
                                          final savedKeymap = settings.getCustomAppKeymap(newName);
                                          if (savedKeymap != null) {
                                            Size? screenSize;
                                            try {
                                              final view = WidgetsBinding.instance.platformDispatcher.views.first;
                                              screenSize = view.physicalSize / view.devicePixelRatio;
                                            } catch (e) {
                                              screenSize = MediaQuery.maybeOf(context)?.size;
                                            }
                                            customApp.decodeKeymap(savedKeymap, screenSize: screenSize);
                                          }
                                          actionHandler.supportedApp = customApp;
                                          await settings.setApp(customApp);
                                          controller.text = newName;
                                          setState(() {});
                                        }
                                      } else if (action == 'duplicate') {
                                        final newName = await _showDuplicateProfileDialog(currentProfile);
                                        if (newName != null && newName.isNotEmpty) {
                                          await settings.duplicateCustomAppProfile(currentProfile, newName);
                                          final customApp = CustomApp(profileName: newName);
                                          final savedKeymap = settings.getCustomAppKeymap(newName);
                                          if (savedKeymap != null) {
                                            Size? screenSize;
                                            try {
                                              final view = WidgetsBinding.instance.platformDispatcher.views.first;
                                              screenSize = view.physicalSize / view.devicePixelRatio;
                                            } catch (e) {
                                              screenSize = MediaQuery.maybeOf(context)?.size;
                                            }
                                            customApp.decodeKeymap(savedKeymap, screenSize: screenSize);
                                          }
                                          actionHandler.supportedApp = customApp;
                                          await settings.setApp(customApp);
                                          controller.text = newName;
                                          setState(() {});
                                        }
                                      } else if (action == 'delete') {
                                        final confirmed = await _showDeleteConfirmDialog(currentProfile);
                                        if (confirmed == true) {
                                          await settings.deleteCustomAppProfile(currentProfile);
                                          controller.text = '';
                                          setState(() {});
                                        }
                                      }
                                    }
                                  },
                                  child: Text('Manage Profile'),
                                ),
                              
                              if (actionHandler.supportedApp is CustomApp)
                                ElevatedButton(
                                  onPressed: () async {
                                    final currentProfile = (actionHandler.supportedApp as CustomApp).profileName;
                                    final jsonData = settings.exportCustomAppProfile(currentProfile);
                                    if (jsonData != null) {
                                      await Clipboard.setData(ClipboardData(text: jsonData));
                                      if (mounted) {
                                        _snackBarMessengerKey.currentState!.showSnackBar(
                                          SnackBar(
                                            content: Text('Profile "$currentProfile" exported to clipboard'),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  child: Text('Export Profile'),
                                ),
                              
                              ElevatedButton(
                                onPressed: () async {
                                  final jsonData = await _showImportDialog();
                                  if (jsonData != null && jsonData.isNotEmpty) {
                                    final success = await settings.importCustomAppProfile(jsonData);
                                    if (mounted) {
                                      if (success) {
                                        _snackBarMessengerKey.currentState!.showSnackBar(
                                          SnackBar(
                                            content: Text('Profile imported successfully'),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                        setState(() {});
                                      } else {
                                        _snackBarMessengerKey.currentState!.showSnackBar(
                                          SnackBar(
                                            content: Text('Failed to import profile. Invalid format.'),
                                            duration: Duration(seconds: 2),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  }
                                },
                                child: Text('Import Profile'),
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
                          if (connection.devices.any(
                            (device) =>
                                (device.device.name == 'Zwift Ride' || device.device.name == 'Zwift Play') &&
                                device.isConnected,
                          ))
                            SwitchListTile(
                              title: Text('Vibration on Shift'),
                              subtitle: Text('Enable vibration feedback when shifting gears'),
                              value: settings.getVibrationEnabled(),
                              onChanged: (value) async {
                                await settings.setVibrationEnabled(value);
                                setState(() {});
                              },
                            ),
                          if (kDebugMode &&
                              connection.devices.any((device) => (device is ZwiftClickV2) && device.isConnected))
                            ElevatedButton(
                              onPressed: () {
                                (connection.devices.first as ZwiftClickV2).test();
                              },
                              child: Text('Test'),
                            ),
                        ],
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
          decoration: InputDecoration(
            labelText: 'Profile Name',
            hintText: 'e.g., Workout, Race, Event',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text('Create'),
          ),
        ],
      ),
    );
  }
  
  Future<String?> _showManageProfileDialog(String currentProfile) async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Manage Profile: $currentProfile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit),
              title: Text('Rename'),
              onTap: () => Navigator.pop(context, 'rename'),
            ),
            ListTile(
              leading: Icon(Icons.copy),
              title: Text('Duplicate'),
              onTap: () => Navigator.pop(context, 'duplicate'),
            ),
            ListTile(
              leading: Icon(Icons.delete),
              title: Text('Delete'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
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
          decoration: InputDecoration(
            labelText: 'Profile Name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text('Rename'),
          ),
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
          decoration: InputDecoration(
            labelText: 'New Profile Name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text('Duplicate'),
          ),
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
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
              decoration: InputDecoration(
                labelText: 'JSON Data',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text('Import'),
          ),
        ],
      ),
    );
  }
}
