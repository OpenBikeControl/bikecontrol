import 'package:flutter/material.dart' show SwitchListTile;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_device.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/keymap/apps/custom_app.dart';
import 'package:swift_control/utils/keymap/apps/supported_app.dart';
import 'package:swift_control/utils/keymap/manager.dart';
import 'package:swift_control/widgets/keymap_explanation.dart';
import 'package:swift_control/widgets/ui/beta_pill.dart';
import 'package:swift_control/widgets/ui/warning.dart';

class CustomizePage extends StatefulWidget {
  const CustomizePage({super.key});

  @override
  State<CustomizePage> createState() => _CustomizeState();
}

class _CustomizeState extends State<CustomizePage> {
  @override
  Widget build(BuildContext context) {
    final canVibrate = connection.bluetoothDevices.any(
      (device) => device.isConnected && device is ZwiftDevice && device.canVibrate,
    );

    return Column(
      spacing: 12,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 8.0),
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Customize ${screenshotMode ? 'Trainer app' : settings.getTrainerApp()?.name} on ${settings.getLastTarget()?.title}',
            ).bold,
          ),
        ),

        if (settings.getLastTarget()?.warning != null) ...[
          Warning(
            children: [
              Icon(Icons.warning_amber),
              Text(settings.getLastTarget()!.warning!),
            ],
          ),
        ],
        Select<SupportedApp?>(
          constraints: BoxConstraints(minWidth: 300),
          value: actionHandler.supportedApp,
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
                        if (a is CustomApp) BetaPill(text: 'CUSTOM'),
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
                      Text('Create new keymap').normal.muted,
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
          placeholder: Text('Select Keymap'),

          onChanged: (app) async {
            if (app == null) {
              return;
            } else if (app.name == 'New') {
              final profileName = await KeymapManager().showNewProfileDialog(context);
              if (profileName != null && profileName.isNotEmpty) {
                final customApp = CustomApp(profileName: profileName);
                actionHandler.init(customApp);
                await settings.setKeyMap(customApp);
                setState(() {});
              }
            } else {
              actionHandler.supportedApp = app;
              await settings.setKeyMap(app);
              setState(() {});
            }
          },
        ),

        KeymapManager().getManageProfileDialog(
          context,
          actionHandler.supportedApp is CustomApp ? actionHandler.supportedApp?.name : null,
          onDone: () {
            setState(() {});
          },
        ),
        if (actionHandler.supportedApp is! CustomApp)
          Text(
            'Customize the keymap if you experience any issues (e.g. wrong keyboard output, or misaligned touch placements)',
            style: TextStyle(fontSize: 12),
          ),
        Gap(12),
        if (actionHandler.supportedApp != null && connection.controllerDevices.isNotEmpty)
          KeymapExplanation(
            key: Key(actionHandler.supportedApp!.keymap.runtimeType.toString()),
            keymap: actionHandler.supportedApp!.keymap,
            onUpdate: () {
              setState(() {});

              if (actionHandler.supportedApp is CustomApp) {
                settings.setKeyMap(actionHandler.supportedApp!);
              }
            },
          )
        else if (connection.controllerDevices.isEmpty)
          Text(
            'Connect a controller device to preview and customize the keymap.',
          ),
        if (canVibrate) ...[
          SwitchListTile(
            title: Text('Enable vibration feedback when shifting gears'),
            value: settings.getVibrationEnabled(),
            contentPadding: EdgeInsets.zero,
            onChanged: (value) async {
              await settings.setVibrationEnabled(value);
              setState(() {});
            },
          ),
        ],
      ],
    );
  }

  List<SupportedApp> _getAllApps() {
    final baseApp = settings.getTrainerApp();
    final customProfiles = settings.getCustomAppProfiles();

    final customApps = customProfiles.map((profile) {
      final customApp = CustomApp(profileName: profile);
      final savedKeymap = settings.getCustomAppKeymap(profile);
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
