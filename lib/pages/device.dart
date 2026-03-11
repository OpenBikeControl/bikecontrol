import 'dart:async';
import 'dart:io';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/card_button.dart';
import 'package:bike_control/widgets/ui/colored_title.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../bluetooth/devices/base_device.dart';
import '../widgets/scan.dart';
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

        ...core.connection.controllerDevices
            .mapIndexed(
              (index, device) => [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  key: widget.cardKeys[device.uniqueId],
                  child: HoverCardButton(
                    buttonStyle: ButtonStyle.ghost(),
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ControllerSettingsPage(device: device)),
                      );
                      widget.onUpdate();
                    },
                    trailing: Icon(Icons.chevron_right, size: 16, color: Theme.of(context).colorScheme.mutedForeground),
                    child: Row(
                      children: [
                        Flexible(child: device.showInformation(context)),
                        if (!widget.isMobile)
                          Container(
                            constraints: BoxConstraints(maxWidth: 300),
                            child: Wrap(
                              children: widget.footerBuilder(device),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (index != core.connection.controllerDevices.length - 1)
                  Divider(
                    thickness: 0.5,
                    indent: 20,
                    endIndent: 20,
                  ),
              ],
            )
            .flatten(),

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
          OutlineButton(
            onPressed: () {
              launchUrlString('https://bikecontrol.app/#supported-devices');
            },
            leading: Icon(Icons.gamepad_outlined),
            child: Text(context.i18n.showSupportedControllers),
          ),

        if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isIOS))
          ValueListenableBuilder(
            valueListenable: core.mediaKeyHandler.isMediaKeyDetectionEnabled,
            builder: (context, value, child) {
              return Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Theme.of(context).colorScheme.border, width: 0.5)),
                ),
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Button.ghost(
                  onPressed: () {
                    final newValue = !core.mediaKeyHandler.isMediaKeyDetectionEnabled.value;
                    core.mediaKeyHandler.isMediaKeyDetectionEnabled.value = newValue;
                    core.settings.setMediaKeyDetectionEnabled(newValue);
                  },
                  child: Basic(
                    title: Text(context.i18n.enableMediaKeyDetection),
                    subtitle: Text(context.i18n.mediaKeyDetectionTooltip).xSmall.normal.muted,
                    trailing: Switch(
                      value: value,
                      onChanged: (val) {
                        core.mediaKeyHandler.isMediaKeyDetectionEnabled.value = val;
                        core.settings.setMediaKeyDetectionEnabled(val);
                      },
                    ),
                  ),
                ),
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
