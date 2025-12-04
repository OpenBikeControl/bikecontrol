import 'package:flutter/material.dart' show SwitchListTile;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_device.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/core.dart';
import 'package:swift_control/utils/i18n_extension.dart';
import 'package:swift_control/utils/keymap/apps/custom_app.dart';
import 'package:swift_control/utils/keymap/apps/supported_app.dart';
import 'package:swift_control/utils/keymap/manager.dart';
import 'package:swift_control/widgets/keymap_explanation.dart';
import 'package:swift_control/widgets/ui/beta_pill.dart';
import 'package:swift_control/widgets/ui/colored_title.dart';
import 'package:swift_control/widgets/ui/warning.dart';

class CustomizePage extends StatefulWidget {
  const CustomizePage({super.key});

  @override
  State<CustomizePage> createState() => _CustomizeState();
}

class _CustomizeState extends State<CustomizePage> {
  @override
  Widget build(BuildContext context) {
    final canVibrate = core.connection.bluetoothDevices.any(
      (device) => device.isConnected && device is ZwiftDevice && device.canVibrate,
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        spacing: 12,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 8.0),
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            width: double.infinity,
            child: ColoredTitle(
              text: context.i18n.customizeControllerButtons(
                screenshotMode ? 'Trainer app' : (core.settings.getTrainerApp()?.name ?? ''),
              ),
            ),
          ),

          if (core.settings.getLastTarget()?.warning != null) ...[
            Warning(
              children: [
                Icon(Icons.warning_amber),
                Text(core.settings.getLastTarget()!.warning!),
              ],
            ),
          ],
          Select<SupportedApp?>(
            constraints: BoxConstraints(minWidth: 300),
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
                          Text(a.name),
                          if (a is CustomApp) PrimaryBadge(child: Text('CUSTOM')),
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
                        Text(context.i18n.createNewKeymap).normal.muted,
                      ],
                    ),
                  ),
                ],
              ),
            ).call,
            itemBuilder: (c, app) => Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(screenshotMode ? 'Trainer app' : app!.name),
                if (app is CustomApp) BetaPill(text: 'CUSTOM'),
              ],
            ),
            /*DropdownMenuEntry(
                                  value: CustomApp(profileName: 'New'),
                                  label: 'Create new keymap',
                                  labelWidget: Text('Create new keymap'),
                                  leadingIcon: Icon(Icons.add),
                                ),*/
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
                core.actionHandler.supportedApp = app;
                await core.settings.setKeyMap(app);
                setState(() {});
              }
            },
          ),

          KeymapManager().getManageProfileDialog(
            context,
            core.actionHandler.supportedApp is CustomApp ? core.actionHandler.supportedApp?.name : null,
            onDone: () {
              setState(() {});
            },
          ),
          if (core.actionHandler.supportedApp is! CustomApp)
            Text(
              context.i18n.customizeKeymapHint,
              style: TextStyle(fontSize: 12),
            ),
          Gap(12),
          if (core.actionHandler.supportedApp != null && core.connection.controllerDevices.isNotEmpty)
            KeymapExplanation(
              key: Key(core.actionHandler.supportedApp!.keymap.runtimeType.toString()),
              keymap: core.actionHandler.supportedApp!.keymap,
              onUpdate: () {
                setState(() {});

                if (core.actionHandler.supportedApp is CustomApp) {
                  core.settings.setKeyMap(core.actionHandler.supportedApp!);
                }
              },
            )
          else if (core.connection.controllerDevices.isEmpty)
            Warning(
              important: false,
              children: [Text(context.i18n.connectControllerToPreview).small],
            ),
          if (canVibrate) ...[
            SwitchListTile(
              title: Text(context.i18n.enableVibrationFeedback),
              value: core.settings.getVibrationEnabled(),
              contentPadding: EdgeInsets.zero,
              onChanged: (value) async {
                await core.settings.setVibrationEnabled(value);
                setState(() {});
              },
            ),
          ],
        ],
      ),
    );
  }

  List<SupportedApp> _getAllApps() {
    final baseApp = core.settings.getTrainerApp();
    final customProfiles = core.settings.getCustomAppProfiles();

    final customApps = customProfiles.map((profile) {
      final customApp = CustomApp(profileName: profile);
      final savedKeymap = core.settings.getCustomAppKeymap(profile);
      if (savedKeymap != null) {
        customApp.decodeKeymap(savedKeymap);
      }
      return customApp;
    }).toList();

    // If no custom profiles exist, add the default "Custom" one
    if (customApps.isEmpty) {
      customApps.add(CustomApp());
    }

    return [if (baseApp != null) baseApp, ...customApps];
  }
}
