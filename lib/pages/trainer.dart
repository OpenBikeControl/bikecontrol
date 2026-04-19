import 'dart:async';

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/pages/configuration.dart';
import 'package:bike_control/pages/trainer_feedback.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/apps/local_tile.dart';
import 'package:bike_control/widgets/apps/mywhoosh_link_tile.dart';
import 'package:bike_control/widgets/apps/openbikecontrol_ble_tile.dart';
import 'package:bike_control/widgets/apps/openbikecontrol_mdns_tile.dart';
import 'package:bike_control/widgets/apps/zwift_mdns_tile.dart';
import 'package:bike_control/widgets/apps/zwift_tile.dart';
import 'package:bike_control/widgets/keyboard_pair_widget.dart';
import 'package:bike_control/widgets/mouse_pair_widget.dart';
import 'package:bike_control/widgets/trainer_features.dart';
import 'package:bike_control/widgets/ui/colored_title.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../utils/keymap/apps/zwift.dart';

class TrainerPage extends StatefulWidget {
  final bool isMobile;
  final VoidCallback onUpdate;
  final VoidCallback goToNextPage;
  const TrainerPage({super.key, required this.onUpdate, required this.goToNextPage, required this.isMobile});

  @override
  State<TrainerPage> createState() => _TrainerPageState();
}

class _TrainerPageState extends State<TrainerPage> {
  late final ScrollController _scrollController = ScrollController();
  StreamSubscription<BaseDevice>? _connectionSub;

  @override
  void initState() {
    super.initState();

    if (!kIsWeb) {
      core.whooshLink.isStarted.addListener(() {
        if (mounted) setState(() {});
      });

      core.zwiftEmulator.isConnected.addListener(() {
        if (mounted) setState(() {});
      });
    }

    _connectionSub = core.connection.connectionStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _connectionSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showLocalAsOther =
        //(core.logic.showObpBluetoothEmulator || core.logic.showObpMdnsEmulator) &&
        false && core.logic.showLocalControl && !core.settings.getLocalEnabled();
    final showWhooshLinkAsOther =
        (core.logic.showObpBluetoothEmulator || core.logic.showObpMdnsEmulator) && core.logic.showMyWhooshLink;

    final recommendedTiles = [
      if (core.logic.showObpMdnsEmulator) OpenBikeControlMdnsTile(),
      if (core.logic.showObpBluetoothEmulator) OpenBikeControlBluetoothTile(),

      if (core.logic.showZwiftMsdnEmulator)
        ZwiftMdnsTile(
          onUpdate: () {
            core.connection.signalNotification(
              LogNotification('Zwift Emulator status changed to ${core.zwiftEmulator.isConnected.value}'),
            );
          },
        ),
      if (core.logic.showZwiftBleEmulator)
        ZwiftTile(
          onUpdate: () {
            if (mounted) {
              core.connection.signalNotification(
                LogNotification('Zwift Emulator status changed to ${core.zwiftEmulator.isConnected.value}'),
              );
              setState(() {});
            }
          },
        ),
      if (core.logic.showLocalControl && !showLocalAsOther) LocalTile(),
      if (core.logic.showMyWhooshLink && !showWhooshLinkAsOther) MyWhooshLinkTile(),
    ];

    final otherTiles = [
      if (showWhooshLinkAsOther) MyWhooshLinkTile(),
      if (core.logic.showRemote) RemoteMousePairingWidget(),
      if (core.logic.showLocalControl && showLocalAsOther) LocalTile(),
      if (core.logic.showRemote && core.settings.getTrainerApp() is! Zwift) RemoteKeyboardPairingWidget(),
    ];

    return Scrollbar(
      controller: _scrollController,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: EdgeInsets.only(bottom: 16, left: 16, right: 16, top: 16),
        child: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: 800),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConfigurationPage(
                  onUpdate: () {
                    setState(() {});
                    widget.onUpdate();
                  },
                ),
                if (core.settings.getTrainerApp() != null) ...[
                  if (recommendedTiles.isNotEmpty) ...[
                    Gap(32),
                    ColoredTitle(text: context.i18n.recommendedConnectionMethods),
                    Gap(12),
                  ],

                  for (final tile in recommendedTiles) ...[
                    IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: tile,
                      ),
                    ),
                  ],
                  Gap(12),
                  if (otherTiles.isNotEmpty) ...[
                    SizedBox(height: 8),
                    Accordion(
                      items: [
                        AccordionItem(
                          trigger: AccordionTrigger(
                            child: ColoredTitle(text: context.i18n.otherConnectionMethods),
                          ),
                          content: Column(
                            children: [
                              for (final tile in otherTiles)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: IntrinsicHeight(child: tile),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Gap(8),
                    Divider(),
                  ],
                  const Gap(24),
                  TrainerFeatures(),
                  if (core.connection.proxyDevices.isNotEmpty) ...[
                    const Gap(12),
                    FeatureWidget(
                      icon: LucideIcons.messageSquare,
                      iconColor: BKColor.main,
                      bgColor: BKColor.main.withValues(alpha: 0.03),
                      iconBgColor: BKColor.main.withValues(alpha: 0.08),
                      title: 'Send Trainer Feedback',
                      description: 'Report how your trainer works with BikeControl',
                      onTap: () {
                        final device = core.connection.proxyDevices.whereType<ProxyDevice>().firstOrNull;
                        if (device == null) return;
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TrainerFeedbackPage(device: device),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
