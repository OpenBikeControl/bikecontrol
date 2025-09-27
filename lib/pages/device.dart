import 'dart:async';
import 'dart:io';

import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
                    Text(
                      connection.devices.joinToString(
                        separator: '\n',
                        transform: (it) {
                          return "${it.device.name ?? it.runtimeType}: ${it.isConnected ? 'Connected' : 'Not connected'}${it.batteryLevel != null ? ' - Battery Level: ${it.batteryLevel}%' : ''}";
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
                                    SupportedApp.supportedApps
                                        .map((app) => DropdownMenuEntry<SupportedApp>(value: app, label: app.name))
                                        .toList(),
                                label: Text('Select Keymap / app'),
                                onSelected: (app) async {
                                  if (app == null) {
                                    return;
                                  }
                                  controller.text = app.name ?? '';
                                  actionHandler.supportedApp = app;
                                  settings.setApp(app);
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
                                      settings.setApp(customApp);
                                    }
                                    final result = await Navigator.of(
                                      context,
                                    ).push<bool>(MaterialPageRoute(builder: (_) => TouchAreaSetupPage()));

                                    if (result == true && actionHandler.supportedApp is CustomApp) {
                                      settings.setApp(actionHandler.supportedApp!);
                                    }
                                    setState(() {});
                                  },
                                  child: Text('Customize Keymap'),
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
                        ],
                      ),
                    SizedBox(height: 800, child: LogViewer()),
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
