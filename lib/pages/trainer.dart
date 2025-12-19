import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/pages/button_simulator.dart';
import 'package:bike_control/pages/configuration.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:bike_control/widgets/apps/local_tile.dart';
import 'package:bike_control/widgets/apps/mywhoosh_link_tile.dart';
import 'package:bike_control/widgets/apps/openbikecontrol_ble_tile.dart';
import 'package:bike_control/widgets/apps/openbikecontrol_mdns_tile.dart';
import 'package:bike_control/widgets/apps/zwift_mdns_tile.dart';
import 'package:bike_control/widgets/apps/zwift_tile.dart';
import 'package:bike_control/widgets/iap_status_widget.dart';
import 'package:bike_control/widgets/pair_widget.dart';
import 'package:bike_control/widgets/ui/colored_title.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../bluetooth/devices/zwift/protocol/zp.pbenum.dart';

class TrainerPage extends StatefulWidget {
  final VoidCallback onUpdate;
  final VoidCallback goToNextPage;
  const TrainerPage({super.key, required this.onUpdate, required this.goToNextPage});

  @override
  State<TrainerPage> createState() => _TrainerPageState();
}

class _TrainerPageState extends State<TrainerPage> with WidgetsBindingObserver {
  late final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // keep screen on - this is required for iOS to keep the bluetooth connection alive
    if (!screenshotMode) {
      WakelockPlus.enable();
    }

    if (!kIsWeb) {
      if (core.logic.showForegroundMessage) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // show snackbar to inform user that the app needs to stay in foreground
          buildToast(context, title: AppLocalizations.current.touchSimulationForegroundMessage);
        });
      }

      core.whooshLink.isStarted.addListener(() {
        if (mounted) setState(() {});
      });

      core.zwiftEmulator.isConnected.addListener(() {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (core.logic.showForegroundMessage) {
        UniversalBle.getBluetoothAvailabilityState().then((state) {
          if (state == AvailabilityState.poweredOn && mounted) {
            core.remotePairing.reconnect();
            buildToast(context, title: AppLocalizations.current.touchSimulationForegroundMessage);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final showLocalAsOther =
        (core.logic.showObpBluetoothEmulator || core.logic.showObpMdnsEmulator) && core.logic.showLocalControl;
    final showWhooshLinkAsOther =
        (core.logic.showObpBluetoothEmulator || core.logic.showObpMdnsEmulator) && core.logic.showMyWhooshLink;

    final isMobile = MediaQuery.sizeOf(context).width < 800;
    return Scrollbar(
      controller: _scrollController,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            ValueListenableBuilder(
              valueListenable: IAPManager.instance.isPurchased,
              builder: (context, value, child) => value ? SizedBox.shrink() : IAPStatusWidget(small: true),
            ),
            ConfigurationPage(
              onUpdate: () {
                setState(() {});
                widget.onUpdate();
                if (_scrollController.position.pixels != _scrollController.position.maxScrollExtent &&
                    core.settings.getLastTarget() == Target.otherDevice) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollController.animateTo(
                      _scrollController.offset + 300,
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  });
                }
              },
            ),
            if (core.settings.getTrainerApp() != null) ...[
              SizedBox(height: 8),
              if (core.logic.hasRecommendedConnectionMethods)
                ColoredTitle(text: context.i18n.recommendedConnectionMethods),

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
                    core.connection.signalNotification(
                      LogNotification('Zwift Emulator status changed to ${core.zwiftEmulator.isConnected.value}'),
                    );
                    setState(() {});
                  },
                ),
              if (core.logic.showLocalControl && !showLocalAsOther) LocalTile(),
              if (core.logic.showMyWhooshLink && !showWhooshLinkAsOther) MyWhooshLinkTile(),
              if (core.logic.showRemote || showLocalAsOther || showWhooshLinkAsOther) ...[
                SizedBox(height: 16),
                Accordion(
                  items: [
                    AccordionItem(
                      trigger: AccordionTrigger(child: ColoredTitle(text: context.i18n.otherConnectionMethods)),
                      content: Column(
                        children: [
                          if (core.logic.showRemote) RemotePairingWidget(),
                          if (showLocalAsOther) LocalTile(),
                          if (showWhooshLinkAsOther) MyWhooshLinkTile(),
                        ],
                      ),
                    ),
                  ],
                ),
              ],

              SizedBox(height: 4),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '${context.i18n.needHelpClickHelp} '),
                    WidgetSpan(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Icon(Icons.help_outline),
                      ),
                    ),
                    TextSpan(text: ' ${context.i18n.needHelpDontHesitate}'),
                  ],
                ),
              ).small.muted,
              SizedBox(),
              Flex(
                direction: isMobile ? Axis.vertical : Axis.horizontal,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  PrimaryButton(
                    child: Text(
                      AppLocalizations.of(
                        context,
                      ).manualyControllingButton(core.settings.getTrainerApp()?.name ?? 'your trainer'),
                    ),
                    onPressed: () {
                      if (core.settings.getTrainerApp() == null) {
                        buildToast(
                          context,
                          level: LogLevel.LOGLEVEL_WARNING,
                          title: context.i18n.selectTrainerApp,
                        );
                        widget.onUpdate();
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (c) => ButtonSimulator(),
                          ),
                        );
                      }
                    },
                  ),
                  PrimaryButton(
                    child: Text(context.i18n.adjustControllerButtons),
                    onPressed: () {
                      widget.goToNextPage();
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
