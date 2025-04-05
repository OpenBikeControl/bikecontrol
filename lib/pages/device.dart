import 'dart:async';
import 'dart:io';

import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/pages/touch_area.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:swift_control/widgets/custom_keymap_selector.dart';
import 'package:swift_control/widgets/logviewer.dart';
import 'package:swift_control/widgets/title.dart';

import '../bluetooth/devices/base_device.dart';
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
        child: Scaffold(
          appBar: AppBar(
            title: AppTitle(),
            actions: buildMenuButtons(),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          ),
          body: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 10,
              children: [
                Text(
                  'Devices:\n${connection.devices.joinToString(separator: '\n', transform: (it) {
                    return "${it.device.name ?? it.runtimeType}: ${it.isConnected ? 'Connected' : 'Not connected'}";
                  })}',
                ),
                Divider(color: Theme.of(context).colorScheme.primary, height: 30),
                if (!kIsWeb && (Platform.isAndroid || kDebugMode))
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (_) => TouchAreaSetupPage(
                                onSave: (gearUp, gearDown) {
                                  final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);

                                  final convertedGearUp =
                                      gearUp.translate(touchAreaSize / 2, touchAreaSize / 2) * devicePixelRatio;

                                  final convertedGearDown =
                                      gearDown.translate(touchAreaSize / 2, touchAreaSize / 2) * devicePixelRatio;

                                  print("Gear Up Position: $gearUp - converted: $convertedGearUp");
                                  print("Gear Down Position: $gearDown - converted: $convertedGearDown");

                                  actionHandler.updateTouchPositions(convertedGearUp, convertedGearDown);
                                  settings.updateTouchPositions(convertedGearUp, convertedGearDown);
                                },
                              ),
                        ),
                      );
                    },
                    child: Text('Customize touch areas (optional)'),
                  ),
                if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || kDebugMode))
                  DropdownMenu<SupportedApp>(
                    controller: controller,
                    dropdownMenuEntries:
                        SupportedApp.supportedApps
                            .map((app) => DropdownMenuEntry<SupportedApp>(value: app, label: app.name))
                            .toList(),
                    onSelected: (app) async {
                      if (app is CustomApp) {
                        app = await showCustomKeymapDialog(context, customApp: app);
                      } else if (app is! CustomApp && (!kIsWeb && Platform.isWindows)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Use a Custom Keymap if you experience any issues on Windows')),
                        );
                      }
                      if (app == null) {
                        return;
                      }
                      controller.text = app.name ?? '';
                      actionHandler.init(app);
                      if (app is CustomApp) {
                        settings.setCustomApp(app);
                      }
                      setState(() {});
                    },
                    initialSelection: actionHandler.supportedApp,
                    hintText: 'Keymap',
                  ),
                Expanded(child: LogViewer()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
