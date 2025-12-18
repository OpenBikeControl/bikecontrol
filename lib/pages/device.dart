import 'dart:async';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/iap_status_widget.dart';
import 'package:bike_control/widgets/scan.dart';
import 'package:bike_control/widgets/ui/colored_title.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

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
