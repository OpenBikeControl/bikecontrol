import 'dart:async';

import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/core.dart';
import 'package:swift_control/widgets/scan.dart';
import 'package:swift_control/widgets/ui/warning.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../bluetooth/devices/base_device.dart';
import '../widgets/ignored_devices_dialog.dart';

class DevicePage extends StatefulWidget {
  final VoidCallback onUpdate;
  const DevicePage({super.key, required this.onUpdate});

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> with WidgetsBindingObserver {
  late StreamSubscription<BaseDevice> _connectionStateSubscription;
  bool _showNameChangeWarning = false;

  @override
  void initState() {
    super.initState();

    _showNameChangeWarning = !core.settings.knowsAboutNameChange();
    _connectionStateSubscription = core.connection.connectionStream.listen((state) async {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _connectionStateSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
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

          ScanWidget(),
          ...core.connection.controllerDevices.map(
            (device) => Card(child: device.showInformation(context)),
          ),

          if (core.settings.getIgnoredDevices().isNotEmpty)
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

          if (core.connection.controllerDevices.isNotEmpty)
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
