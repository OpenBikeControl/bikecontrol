import 'dart:async';
import 'dart:io';

import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/pages/touch_area.dart';
import 'package:swift_control/widgets/logviewer.dart';

import '../bluetooth/devices/base_device.dart';
import '../widgets/menu.dart';

class DevicePage extends StatefulWidget {
  const DevicePage({super.key});

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  late StreamSubscription<BaseDevice> _connectionStateSubscription;

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
            title: Text('SwiftControl'),
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
                    return "${it.device.name}: ${it.isConnected ? 'Connected' : 'Not connected'}";
                  })}',
                ),
                Divider(color: Theme.of(context).colorScheme.primary, height: 30),
                if (!kIsWeb && (Platform.isAndroid || kDebugMode)) ...[
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (_) => TouchAreaSetupPage(
                                onSave: (gearUp, gearDown) {
                                  print("Gear Up Position: $gearUp");
                                  print("Gear Down Position: $gearDown");
                                  actionHandler.updateTouchPositions(gearUp, gearDown);
                                  settings.updateTouchPositions(gearUp, gearDown);
                                },
                              ),
                        ),
                      );
                    },
                    child: Text('Customize touch areas (optional)'),
                  ),
                ],
                Expanded(child: LogViewer()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
