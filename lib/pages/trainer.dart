import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/pages/button_simulator.dart';
import 'package:bike_control/pages/configuration.dart';
import 'package:bike_control/pages/navigation.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/apps/local_tile.dart';
import 'package:bike_control/widgets/apps/mywhoosh_link_tile.dart';
import 'package:bike_control/widgets/apps/openbikecontrol_ble_tile.dart';
import 'package:bike_control/widgets/apps/openbikecontrol_mdns_tile.dart';
import 'package:bike_control/widgets/apps/zwift_mdns_tile.dart';
import 'package:bike_control/widgets/apps/zwift_tile.dart';
import 'package:bike_control/widgets/iap_status_widget.dart';
import 'package:bike_control/widgets/keyboard_pair_widget.dart';
import 'package:bike_control/widgets/mouse_pair_widget.dart';
import 'package:bike_control/widgets/ui/colored_title.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/prop.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../utils/keymap/apps/supported_app.dart';
import '../utils/keymap/apps/zwift.dart';

class TrainerPage extends StatefulWidget {
  final bool isMobile;
  final VoidCallback onUpdate;
  final VoidCallback goToNextPage;
  const TrainerPage({super.key, required this.onUpdate, required this.goToNextPage, required this.isMobile});

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
          buildToast(navigatorKey.currentContext!, title: AppLocalizations.current.touchSimulationForegroundMessage);
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
            buildToast(navigatorKey.currentContext!, title: AppLocalizations.current.touchSimulationForegroundMessage);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final showLocalAsOther =
        (core.logic.showObpBluetoothEmulator || core.logic.showObpMdnsEmulator) &&
        core.logic.showLocalControl &&
        !core.settings.getLocalEnabled();
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
      if (core.logic.showRemote && core.settings.getTrainerApp() is! Zwift) RemoteKeyboardPairingWidget(),
    ];

    final otherTiles = [
      if (core.logic.showRemote) RemoteMousePairingWidget(),
      if (showLocalAsOther) LocalTile(),
      if (showWhooshLinkAsOther) MyWhooshLinkTile(),
    ];

    return Scrollbar(
      controller: _scrollController,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: EdgeInsets.only(bottom: widget.isMobile ? 166 : 16, left: 16, right: 16, top: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ValueListenableBuilder(
              valueListenable: IAPManager.instance.isPurchased,
              builder: (context, value, child) => value ? SizedBox.shrink() : IAPStatusWidget(small: true),
            ),
            SizedBox(
              width: double.infinity,
              child: Accordion(
                items: [
                  AccordionItem(
                    trigger: AccordionTrigger(
                      child: IgnorePointer(
                        child: Row(
                          spacing: 12,
                          children: [
                            Flexible(
                              child: Select<SupportedApp>(
                                itemBuilder: (c, app) => Row(
                                  spacing: 4,
                                  children: [
                                    Expanded(child: Text(screenshotMode ? 'Trainer app' : app.name)),
                                    if (app.supportsOpenBikeProtocol.isNotEmpty) Icon(Icons.star),
                                  ],
                                ),
                                popup: SelectPopup(
                                  items: SelectItemList(
                                    children: SupportedApp.supportedApps.map((app) {
                                      return SelectItemButton(
                                        value: app,
                                        child: Row(
                                          spacing: 4,
                                          children: [
                                            Text(app.name),
                                            if (app.supportsOpenBikeProtocol.isNotEmpty) Icon(Icons.star),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ).call,
                                placeholder: Text(context.i18n.selectTrainerAppPlaceholder),
                                value: core.settings.getTrainerApp(),
                                onChanged: (selectedApp) async {},
                              ),
                            ),
                            if (core.settings.getLastTarget() != null) ...[
                              if (!widget.isMobile) Icon(core.settings.getLastTarget()!.icon),
                              Text(core.settings.getLastTarget()!.getTitle(context)),
                            ],
                          ],
                        ),
                      ),
                    ),
                    content: ConfigurationPage(
                      onUpdate: () {
                        setState(() {});
                        widget.onUpdate();
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (core.settings.getTrainerApp() != null) ...[
              if (recommendedTiles.isNotEmpty) ...[
                Gap(22),
                ColoredTitle(text: context.i18n.recommendedConnectionMethods),
                Gap(12),
              ],

              for (final grouped in recommendedTiles.chunked(widget.isMobile ? 1 : 2)) ...[
                IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      spacing: 8,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: grouped.map((tile) => Expanded(child: tile)).toList(),
                    ),
                  ),
                ),
              ],
              Gap(12),
              if (otherTiles.isNotEmpty) ...[
                SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: Accordion(
                    items: [
                      AccordionItem(
                        expanded: recommendedTiles.isEmpty || (core.logic.showRemote && core.remotePairing.isStarted.value),
                        trigger: AccordionTrigger(child: ColoredTitle(text: context.i18n.otherConnectionMethods)),
                        content: Column(
                          children: [
                            for (final grouped in otherTiles.chunked(widget.isMobile ? 1 : 2)) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: IntrinsicHeight(
                                  child: Row(
                                    spacing: 8,
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: grouped.map((tile) => Expanded(child: tile)).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Gap(12),

              SizedBox(height: 4),
              Flex(
                direction: widget.isMobile || MediaQuery.sizeOf(context).width < 750 ? Axis.vertical : Axis.horizontal,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  PrimaryButton(
                    leading: Icon(Icons.computer_outlined),
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
                    leading: Icon(BCPage.customization.icon),
                    onPressed: () {
                      widget.goToNextPage();
                    },
                    child: Text(context.i18n.adjustControllerButtons),
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
