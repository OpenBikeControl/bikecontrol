import 'dart:io';

import 'package:bike_control/main.dart';
import 'package:bike_control/pages/button_edit.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:bike_control/widgets/ui/colored_title.dart';
import 'package:bike_control/widgets/ui/warning.dart';
import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class ConfigurationPage extends StatefulWidget {
  final VoidCallback onUpdate;
  const ConfigurationPage({super.key, required this.onUpdate});

  @override
  State<ConfigurationPage> createState() => _ConfigurationPageState();
}

class _ConfigurationPageState extends State<ConfigurationPage> {
  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 12,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        SizedBox(height: 4),
        ColoredTitle(text: context.i18n.setupTrainer),
        Card(
          fillColor: Theme.of(context).colorScheme.background,
          filled: true,
          borderWidth: 1,
          borderColor: Theme.of(context).colorScheme.border,
          child: Builder(
            builder: (context) {
              final isMobile = MediaQuery.sizeOf(context).width < 600;
              return StatefulBuilder(
                builder: (c, setState) => Column(
                  spacing: 8,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Select<SupportedApp>(
                      constraints: BoxConstraints(maxWidth: 400, minWidth: 400),
                      itemBuilder: (c, app) => Text(screenshotMode ? 'Trainer app' : app.name),
                      popup: SelectPopup(
                        items: SelectItemList(
                          children: SupportedApp.supportedApps.map((app) {
                            return SelectItemButton(
                              value: app,
                              child: Text(app.name),
                            );
                          }).toList(),
                        ),
                      ).call,
                      placeholder: Text(context.i18n.selectTrainerAppPlaceholder),
                      value: core.settings.getTrainerApp(),
                      onChanged: (selectedApp) async {
                        if (selectedApp is! MyWhoosh) {
                          if (core.whooshLink.isStarted.value) {
                            core.whooshLink.stopServer();
                          }
                        }
                        if (!selectedApp!.supportsZwiftEmulation) {
                          if (core.zwiftMdnsEmulator.isStarted.value) {
                            core.zwiftMdnsEmulator.stop();
                          }
                          if (core.zwiftEmulator.isStarted.value) {
                            core.zwiftEmulator.stopAdvertising();
                          }
                        }
                        if (!selectedApp.supportsOpenBikeProtocol) {
                          if (core.obpMdnsEmulator.isStarted.value) {
                            core.obpMdnsEmulator.stopServer();
                          }
                          if (core.obpBluetoothEmulator.isStarted.value) {
                            core.obpBluetoothEmulator.stopServer();
                          }
                        }

                        core.settings.setTrainerApp(selectedApp);
                        if (core.settings.getLastTarget() == null && Target.thisDevice.isCompatible) {
                          await _setTarget(context, Target.thisDevice);
                        } else if (core.settings.getLastTarget() == null && Target.otherDevice.isCompatible) {
                          await _setTarget(context, Target.otherDevice);
                        }
                        if (core.actionHandler.supportedApp == null ||
                            (core.actionHandler.supportedApp is! CustomApp && selectedApp is! CustomApp)) {
                          core.actionHandler.init(selectedApp);
                          core.settings.setKeyMap(selectedApp);
                        }
                        widget.onUpdate();
                        setState(() {});
                      },
                    ),
                    if (core.settings.getTrainerApp() != null) ...[
                      SizedBox(height: 8),
                      Text(
                        context.i18n.selectTargetWhereAppRuns(
                          screenshotMode ? 'Trainer app' : core.settings.getTrainerApp()?.name ?? 'the Trainer app',
                        ),
                      ).small,
                      Flex(
                        direction: isMobile ? Axis.vertical : Axis.horizontal,
                        spacing: 8,
                        children: [Target.thisDevice, Target.otherDevice]
                            .map(
                              (target) => SelectableCard(
                                title: Text(target.getTitle(context)),
                                icon: target.icon,
                                isActive: target == core.settings.getLastTarget(),
                                subtitle: !target.isCompatible
                                    ? Text(context.i18n.platformRestrictionNotSupported)
                                    : null,
                                onPressed: !target.isCompatible
                                    ? null
                                    : () async {
                                        await _setTarget(context, target);
                                        setState(() {});
                                        widget.onUpdate();
                                      },
                              ),
                            )
                            .map((e) => !isMobile ? Expanded(child: e) : e)
                            .toList(),
                      ),
                    ],

                    if (core.settings.getLastTarget() == Target.otherDevice &&
                        !core.logic.hasRecommendedConnectionMethods) ...[
                      SizedBox(height: 8),
                      Warning(
                        children: [
                          Text(
                            'BikeControl is available on iOS, Android, Windows and macOS. For proper support for ${core.settings.getTrainerApp()?.name} please download BikeControl on that device.',
                          ).small,
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _setTarget(BuildContext context, Target target) async {
    await core.settings.setLastTarget(target);

    if (core.settings.getTrainerApp()?.supportsOpenBikeProtocol == true && !core.logic.emulatorEnabled) {
      core.settings.setObpMdnsEnabled(true);
    }

    // enable local connection on Windows if the app doesn't support OBP
    if (target == Target.thisDevice &&
        core.settings.getTrainerApp()?.supportsOpenBikeProtocol == false &&
        !kIsWeb &&
        Platform.isWindows) {
      core.settings.setLocalEnabled(true);
    }
    core.logic.startEnabledConnectionMethod();
  }
}
