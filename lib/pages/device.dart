import 'dart:async';
import 'dart:io';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/pages/controller_settings.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/scan.dart';
import 'package:bike_control/widgets/trainer_features.dart';
import 'package:bike_control/widgets/ui/colored_title.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../bluetooth/devices/base_device.dart';

typedef ControllerFooterBuilder = Widget Function(BaseDevice device);

class DevicePage extends StatefulWidget {
  final bool isMobile;
  final Map<String, GlobalKey> cardKeys;
  final VoidCallback onUpdate;
  final ControllerFooterBuilder footerBuilder;
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
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(bottom: 12.0),
                  key: widget.cardKeys[device.uniqueId],
                  child: Button.ghost(
                    onPressed: () async {
                      await context.push(ControllerSettingsPage(device: device));
                      widget.onUpdate();
                    },
                    trailing: Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: Theme.of(context).colorScheme.mutedForeground,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 8,
                      children: [
                        device.showInformation(context, showFull: false),
                        if (!screenshotMode) widget.footerBuilder(device),
                        ...device.showAdditionalInformation(context),
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
                child: device.showInformation(context, showFull: false),
              ),
            ),
          ),
        ],

        if (!screenshotMode && core.connection.controllerDevices.isEmpty)
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Theme.of(context).colorScheme.border, width: 0.5)),
            ),
            child: FeatureWidget(
              onTap: () {
                launchUrlString('https://bikecontrol.app/#supported-devices');
              },
              icon: Icons.gamepad_outlined,
              title: context.i18n.showSupportedControllers,
              withCard: false,
            ),
          ),

        if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isIOS))
          ValueListenableBuilder(
            valueListenable: core.mediaKeyHandler.isMediaKeyDetectionEnabled,
            builder: (context, value, child) {
              return Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Theme.of(context).colorScheme.border, width: 0.5)),
                ),
                child: SwitchFeature(
                  isMobile: widget.isMobile,
                  onPressed: () {
                    final newValue = !core.mediaKeyHandler.isMediaKeyDetectionEnabled.value;
                    core.mediaKeyHandler.isMediaKeyDetectionEnabled.value = newValue;
                    core.settings.setMediaKeyDetectionEnabled(newValue);
                  },
                  title: context.i18n.enableMediaKeyDetection,
                  value: value,
                ),
              );
            },
          ),
        if (!kIsWeb && (Platform.isAndroid || Platform.isIOS))
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Theme.of(context).colorScheme.border, width: 0.5)),
            ),
            child: SwitchFeature(
              value: core.settings.getPhoneSteeringEnabled(),
              isProOnly: !IAPManager.instance.hasPurchasedBefore50RVC,
              isMobile: widget.isMobile,
              title: AppLocalizations.of(context).enableSteeringWithPhone,
              onPressed: () {
                final enable = !core.settings.getPhoneSteeringEnabled();
                core.settings.setPhoneSteeringEnabled(enable);
                core.connection.toggleGyroscopeSteering(enable);
                setState(() {});
              },
            ),
          ),
      ],
    );
  }
}

extension Screenshot on String {
  String get screenshot => screenshotMode ? replaceAll('Zwift ', '') : this;
}
