import 'dart:async';
import 'dart:io';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/pages/button_simulator.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/iap_status_widget.dart';
import 'package:bike_control/widgets/ignored_devices_dialog.dart';
import 'package:bike_control/widgets/scan.dart';
import 'package:bike_control/widgets/ui/colored_title.dart';
import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../bluetooth/devices/base_device.dart';
import '../utils/keymap/buttons.dart';
import 'button_edit.dart';

class DevicePage extends StatefulWidget {
  final bool isMobile;
  final VoidCallback onUpdate;
  const DevicePage({super.key, required this.onUpdate, required this.isMobile});

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
        padding: EdgeInsets.only(bottom: widget.isMobile ? 166 : 16, left: 16, right: 16, top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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

            Gap(12),
            if (core.connection.controllerDevices.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: ColoredTitle(text: context.i18n.connectedControllers),
              ),

            Gap(12),
            ...core.connection.controllerDevices.map(
              (device) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Card(
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.card
                      : Theme.of(context).colorScheme.card.withLuminance(0.95),
                  child: device.showInformation(context),
                ),
              ),
            ),

            Gap(12),
            if (core.connection.accessories.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: ColoredTitle(text: AppLocalizations.of(context).accessories),
              ),
              ...core.connection.accessories.map(
                (device) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Card(
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(context).colorScheme.card
                        : Theme.of(context).colorScheme.card.withLuminance(0.95),
                    child: device.showInformation(context),
                  ),
                ),
              ),
            ],

            if (!kIsWeb && (Platform.isMacOS || Platform.isWindows))
              ValueListenableBuilder(
                valueListenable: core.mediaKeyHandler.isMediaKeyDetectionEnabled,
                builder: (context, value, child) {
                  return SelectableCard(
                    isActive: value,
                    icon: value ? Icons.check_box : Icons.check_box_outline_blank,
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 8,
                      children: [
                        Text(context.i18n.enableMediaKeyDetection),
                        Text(
                          context.i18n.mediaKeyDetectionTooltip,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    onPressed: () {
                      core.mediaKeyHandler.isMediaKeyDetectionEnabled.value =
                          !core.mediaKeyHandler.isMediaKeyDetectionEnabled.value;
                    },
                  );
                },
              ),
            SizedBox(),
            if (!kIsWeb && (Platform.isAndroid || Platform.isIOS) && !core.settings.getShowOnboarding())
              SelectableCard(
                isActive: core.settings.getPhoneSteeringEnabled(),
                icon: core.settings.getPhoneSteeringEnabled() ? Icons.check_box : Icons.check_box_outline_blank,
                title: Row(
                  spacing: 4,
                  children: [
                    Icon(InGameAction.navigateRight.icon!, size: 16),
                    Icon(InGameAction.navigateLeft.icon!, size: 16),
                    SizedBox(),
                    Expanded(child: Text(AppLocalizations.of(context).enableSteeringWithPhone)),
                  ],
                ),
                onPressed: () {
                  final enable = !core.settings.getPhoneSteeringEnabled();
                  core.settings.setPhoneSteeringEnabled(enable);
                  core.connection.toggleGyroscopeSteering(enable);
                  setState(() {});
                },
              ),

            Gap(12),
            if (!screenshotMode)
              Column(
                spacing: 8,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: "${AppLocalizations.of(context).noControllerUseCompanionMode.split("?").first}?\n",
                            ),
                            TextSpan(
                              text: AppLocalizations.of(context).noControllerUseCompanionMode.split("? ").last,
                              style: TextStyle(color: Theme.of(context).colorScheme.muted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            Gap(12),
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
