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
import '../bluetooth/devices/zwift/zwift_clickv2_left_side.dart';
import '../bluetooth/devices/zwift/zwift_clickv2_right_side.dart';

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

  /// Groups controller devices for display: a Zwift Click V2 left/right pair
  /// is rendered side by side in one group (left side first), every other
  /// device gets its own group.
  List<List<BaseDevice>> get _deviceGroups {
    final devices = core.connection.controllerDevices;
    final leftSide = devices.whereType<ZwiftClickV2LeftSide>().firstOrNull;
    final rightSide = devices.whereType<ZwiftClickV2RightSide>().firstOrNull;
    if (leftSide == null || rightSide == null) {
      return devices.map((device) => [device]).toList();
    }
    final groups = <List<BaseDevice>>[];
    var paired = false;
    for (final device in devices) {
      if (device == leftSide || device == rightSide) {
        if (!paired) {
          groups.add([leftSide, rightSide]);
          paired = true;
        }
      } else {
        groups.add([device]);
      }
    }
    return groups;
  }

  Widget _buildDeviceCard(BaseDevice device) {
    // Grey out (and mute) the entry while the device reboots due to an
    // automatic reset — it reconnects on its own within a few seconds.
    final muted = device.isResetting;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 12.0),
      key: widget.cardKeys[device.uniqueId],
      child: AnimatedOpacity(
        opacity: muted ? 0.4 : 1,
        duration: const Duration(milliseconds: 300),
        child: IgnorePointer(
          ignoring: muted,
          child: Button.ghost(
            onPressed: () async {
              await context.push(ControllerSettingsPage(device: device));
              widget.onUpdate();
            },
            child: device.showInformation(
              context,
              showFull: false,
              footer: widget.footerBuilder(device),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deviceGroups = _deviceGroups;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // leave it in for the extra scanning options
        ScanWidget(),

        ...deviceGroups
            .mapIndexed(
              (index, group) => [
                if (group.length == 1)
                  _buildDeviceCard(group.single)
                else
                  IntrinsicHeight(
                    child: Row(
                      spacing: 12,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: group
                          .map<Widget>((device) => Expanded(child: _buildDeviceCard(device)))
                          .joinSeparator(
                            VerticalDivider(
                              thickness: Theme.of(context).brightness == Brightness.dark ? 1 : 0.5,
                              endIndent: 12,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                if (index != deviceGroups.length - 1) ...[
                  Divider(
                    thickness: Theme.of(context).brightness == Brightness.dark ? 1 : 0.5,
                    indent: 20,
                    endIndent: 20,
                    height: 5,
                  ),
                  SizedBox(height: 12),
                ],
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
