import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/pages/trainer_connection_settings.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/manager.dart';
import 'package:bike_control/widgets/keymap_explanation.dart';
import 'package:bike_control/widgets/status_icon.dart';
import 'package:bike_control/widgets/ui/beta_pill.dart';
import 'package:bike_control/widgets/ui/warning.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class CustomizePage extends StatefulWidget {
  final bool isMobile;

  final BaseDevice? filterDevice;
  const CustomizePage({super.key, required this.isMobile, this.filterDevice});

  @override
  State<CustomizePage> createState() => _CustomizeState();
}

class _CustomizeState extends State<CustomizePage> {
  @override
  void initState() {
    IAPManager.instance.entitlements.addListener(_onIAPChange);
    super.initState();
  }

  @override
  void dispose() {
    IAPManager.instance.entitlements.removeListener(_onIAPChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 12,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (core.actionHandler.supportedApp != null)
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: Select<SupportedApp?>(
                  value: core.actionHandler.supportedApp,
                  popup: SelectPopup(
                    items: SelectItemList(
                      children: [
                        ..._getAllApps().map(
                          (a) => SelectItemButton(
                            value: a,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(a.name)),
                                if (a is CustomApp)
                                  BetaPill(text: 'CUSTOM')
                                else if (a.supports(AppConnectionMethod.obpBle) ||
                                    a.supports(AppConnectionMethod.obpMdns) ||
                                    a.supports(AppConnectionMethod.obpDirCon))
                                  Icon(Icons.star, size: 16),
                              ],
                            ),
                          ),
                        ),
                        SelectItemButton(
                          value: CustomApp(profileName: 'New'),
                          child: Row(
                            spacing: 6,
                            children: [
                              Icon(Icons.add, color: Theme.of(context).colorScheme.mutedForeground),
                              Expanded(child: Text(context.i18n.createNewKeymap).normal.muted),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).call,
                  itemBuilder: (c, app) => Row(
                    spacing: 8,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(screenshotMode ? 'Trainer app' : app!.name)),
                      if (app is CustomApp) BetaPill(text: 'CUSTOM'),
                    ],
                  ),
                  placeholder: Text(context.i18n.selectKeymap),

                  onChanged: (app) async {
                    if (app == null) {
                      return;
                    } else if (app.name == 'New') {
                      final profileName = await KeymapManager().showNewProfileDialog(context);
                      if (profileName != null && profileName.isNotEmpty) {
                        final customApp = CustomApp(profileName: profileName);
                        core.actionHandler.init(customApp);
                        await core.settings.setKeyMap(customApp);

                        setState(() {});
                      }
                    } else {
                      core.actionHandler.init(app);
                      await core.settings.setKeyMap(app);
                      setState(() {});
                    }
                  },
                ),
              ),
              Tooltip(
                tooltip: (c) => Text(context.i18n.synchronizeAcrossDevices),
                child: StatusIcon(
                  status: IAPManager.instance.isProEnabled,
                  icon: Icons.cloud_upload,
                  started: IAPManager.instance.isProEnabled,
                  onPressed: IAPManager.instance.isProEnabled
                      ? null
                      : () {
                          IAPManager.instance.ensureProForFeature(context);
                        },
                ),
              ),
              KeymapManager().getManageProfileDialog(
                context,
                core.actionHandler.supportedApp is CustomApp ? core.actionHandler.supportedApp?.name : null,
                onDone: () {
                  setState(() {});
                },
              ),
            ],
          ),

        if (!screenshotMode) Gap(12),
        if (core.actionHandler.supportedApp != null && core.connection.controllerDevices.isNotEmpty)
          KeymapExplanation(
            key: Key(core.actionHandler.supportedApp!.keymap.runtimeType.toString()),
            keymap: core.actionHandler.supportedApp!.keymap,
            filterDevice: widget.filterDevice,
            onUpdate: () {
              setState(() {});
            },
          )
        else
          Warning(
            children: [
              Text(context.i18n.noConnectionMethodSelected).small,
              Button.outline(
                child: Text('Open connection settings'),
                onPressed: () async {
                  await context.push(const TrainerConnectionSettingsPage());
                  setState(() {});
                },
              ),
            ],
          ),
      ],
    );
  }

  List<SupportedApp> _getAllApps() {
    final baseApp = core.settings.getTrainerApp();
    final customProfiles = core.settings.getCustomAppProfiles();

    final customApps = customProfiles.map((profile) {
      final customApp = CustomApp(profileName: profile);
      final savedKeymap = core.settings.getCustomAppKeymap(profile);
      if (savedKeymap != null) {
        try {
          customApp.decodeKeymap(savedKeymap);
        } catch (e, s) {
          recordError(e, s, context: 'getAllApps');
        }
      }
      return customApp;
    }).toList();

    // If no custom profiles exist, add the default "Custom" one
    if (customApps.isEmpty) {
      customApps.add(CustomApp());
    }

    return [if (baseApp != null) baseApp, ...customApps];
  }

  void _onIAPChange() {
    setState(() {});
  }
}
