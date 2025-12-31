import 'dart:async';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/pages/button_simulator.dart';
import 'package:bike_control/pages/markdown.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/iap_status_widget.dart';
import 'package:bike_control/widgets/ignored_devices_dialog.dart';
import 'package:bike_control/widgets/scan.dart';
import 'package:bike_control/widgets/ui/colored_title.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../bluetooth/devices/base_device.dart';

class DevicePage extends StatefulWidget {
  final VoidCallback onUpdate;
  const DevicePage({super.key, required this.onUpdate});

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  late StreamSubscription<BaseDevice> _connectionStateSubscription;

  @override
  void initState() {
    super.initState();

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
        primary: true,
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            ValueListenableBuilder(
              valueListenable: IAPManager.instance.isPurchased,
              builder: (context, value, child) => value ? SizedBox.shrink() : IAPStatusWidget(small: false),
            ),

            if (core.connection.controllerDevices.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: ColoredTitle(text: context.i18n.connectControllers),
              ),

            // leave it in for the extra scanning options
            ScanWidget(),

            if (core.connection.controllerDevices.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: ColoredTitle(text: context.i18n.connectedControllers),
              ),

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
                child: ColoredTitle(text: AppLocalizations.of(context).accessories),
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

            if (!screenshotMode)
              Column(
                spacing: 8,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlineButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (c) => MarkdownPage(assetPath: 'TROUBLESHOOTING.md')),
                      );
                    },
                    leading: Icon(Icons.help_outline),
                    child: Text(context.i18n.showTroubleshootingGuide),
                  ),
                  OutlineButton(
                    onPressed: () {
                      launchUrlString(
                        'https://github.com/jonasbark/swiftcontrol/?tab=readme-ov-file#supported-devices',
                      );
                    },
                    leading: Icon(Icons.gamepad_outlined),
                    child: Text(context.i18n.showSupportedControllers),
                  ),
                  if (core.settings.getIgnoredDevices().isNotEmpty)
                    OutlineButton(
                      leading: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.destructive,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        margin: EdgeInsets.only(right: 4),
                        child: Text(
                          core.settings.getIgnoredDevices().length.toString(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primaryForeground,
                          ),
                        ),
                      ),
                      onPressed: () async {
                        await showDialog(
                          context: context,
                          builder: (context) => IgnoredDevicesDialog(),
                        );
                        setState(() {});
                      },
                      child: Text(context.i18n.manageIgnoredDevices),
                    ),

                  if (core.connection.controllerDevices.isEmpty)
                    PrimaryButton(
                      leading: Icon(Icons.computer_outlined),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (c) => ButtonSimulator(),
                          ),
                        );
                      },
                      child: Text(AppLocalizations.of(context).noControllerUseCompanionMode),
                    ),
                ],
              ),
            SizedBox(),
            if (core.connection.controllerDevices.isNotEmpty)
              Row(
                spacing: 8,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
        ),
      ),
    );
  }
}

extension Screenshot on String {
  String get screenshot => screenshotMode ? replaceAll('Zwift ', '') : this;
}
