import 'dart:async';
import 'dart:io';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/ignored_devices_dialog.dart';
import 'package:bike_control/widgets/scan.dart';
import 'package:bike_control/widgets/ui/colored_title.dart';
import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../bluetooth/devices/base_device.dart';
import 'button_edit.dart';
import 'controller_settings.dart';

class DevicePage extends StatefulWidget {
  final bool isMobile;
  final Map<String, GlobalKey> cardKeys;
  final VoidCallback onUpdate;
  final List<Widget> Function(BaseDevice) footerBuilder;
  const DevicePage({
    super.key,
    required this.onUpdate,
    required this.isMobile,
    required this.cardKeys,
    required this.footerBuilder,
  });

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // leave it in for the extra scanning options
        ScanWidget(),

        Gap(12),
        ...core.connection.controllerDevices.map(
          (device) => Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            key: widget.cardKeys[device.uniqueId],
            child: Button.card(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ControllerSettingsPage(device: device)),
                );
                widget.onUpdate();
              },
              child: Column(
                children: [
                  device.showInformation(context),
                  ...widget.footerBuilder(device),
                ],
              ),
            ),
          ),
        ),

        if (core.connection.accessories.isNotEmpty) ...[
          Gap(12),
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: ColoredTitle(text: AppLocalizations.of(context).accessories),
          ),
          ...core.connection.accessories.map(
            (device) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              key: widget.cardKeys[device.uniqueId],
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

        if (!screenshotMode && core.connection.controllerDevices.isEmpty)
          Column(
            spacing: 8,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OutlineButton(
                onPressed: () {
                  launchUrlString('https://bikecontrol.app/#supported-devices');
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
            ],
          ),

        if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isIOS))
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
                  final newValue = !core.mediaKeyHandler.isMediaKeyDetectionEnabled.value;
                  core.mediaKeyHandler.isMediaKeyDetectionEnabled.value = newValue;
                  core.settings.setMediaKeyDetectionEnabled(newValue);
                },
              );
            },
          ),
        if (!kIsWeb && (Platform.isAndroid || Platform.isIOS))
          SelectableCard(
            isActive: core.settings.getPhoneSteeringEnabled(),
            icon: core.settings.getPhoneSteeringEnabled() ? Icons.check_box : Icons.check_box_outline_blank,
            isProOnly: true,
            title: Row(
              spacing: 4,
              children: [
                Icon(LucideIcons.ferrisWheel, size: 16),
                SizedBox(),
                Expanded(child: Text(AppLocalizations.of(context).enableSteeringWithPhone)),
                IconButton.secondary(
                  icon: Icon(Icons.ondemand_video),
                  onPressed: () {
                    launchUrlString('https://youtube.com/shorts/zqD5ARGIVmE?feature=share');
                  },
                ),
              ],
            ),
            onPressed: () {
              final enable = !core.settings.getPhoneSteeringEnabled();
              core.settings.setPhoneSteeringEnabled(enable);
              core.connection.toggleGyroscopeSteering(enable);
              setState(() {});
            },
          ),
      ],
    );
  }
}

extension Screenshot on String {
  String get screenshot => screenshotMode ? replaceAll('Zwift ', '') : this;
}
