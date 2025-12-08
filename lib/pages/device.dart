import 'dart:async';

import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/core.dart';
import 'package:swift_control/utils/i18n_extension.dart';
import 'package:swift_control/widgets/scan.dart';
import 'package:swift_control/widgets/ui/colored_title.dart';
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
    return Scrollbar(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            if (_showNameChangeWarning && !screenshotMode)
              Warning(
                important: false,
                children: [
                  Text(context.i18n.nameChangeNotice),
                  SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showNameChangeWarning = false;
                      });
                      launchUrlString('https://openbikecontrol.org');
                    },
                    child: Text(context.i18n.moreInformation),
                  ),
                ],
              ),

            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: ColoredTitle(
                text: core.connection.controllerDevices.isEmpty
                    ? context.i18n.connectControllers
                    : context.i18n.connectedControllers,
              ),
            ),

            if (core.connection.controllerDevices.isEmpty) ScanWidget(),
            ...core.connection.controllerDevices.map(
              (device) => Card(
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context).colorScheme.card
                    : Theme.of(context).colorScheme.card.withLuminance(0.95),
                child: device.showInformation(context),
              ),
            ),

            if (core.connection.accessories.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: ColoredTitle(
                  text: 'Accessories',
                ),
              ),
              ...core.connection.accessories.map(
                (device) => Card(
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.card
                      : Theme.of(context).colorScheme.card.withLuminance(0.95),
                  child: device.showInformation(context),
                ),
              ),
            ],

            if (core.settings.getIgnoredDevices().isNotEmpty)
              OutlineButton(
                child: Text(context.i18n.manageIgnoredDevices),
                onPressed: () async {
                  await showDialog(
                    context: context,
                    builder: (context) => IgnoredDevicesDialog(),
                  );
                  setState(() {});
                },
              ),

            if (core.connection.controllerDevices.isNotEmpty) ...[
              SizedBox(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  PrimaryButton(
                    child: Text(context.i18n.connectToTrainerApp),
                    onPressed: () {
                      widget.onUpdate();
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

extension Screenshot on String {
  String get screenshot => screenshotMode ? replaceAll('Zwift ', '') : this;
}
