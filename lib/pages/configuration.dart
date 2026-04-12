import 'dart:async';
import 'dart:io';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/pages/button_edit.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:bike_control/widgets/ui/colored_title.dart';
import 'package:bike_control/widgets/ui/gradient_text.dart';
import 'package:bike_control/widgets/ui/openbikecontrol_logo.dart';
import 'package:bike_control/widgets/ui/warning.dart';
import 'package:d4rt/d4rt.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

class ConfigurationPage extends StatefulWidget {
  final bool onboardingMode;
  final VoidCallback onUpdate;
  const ConfigurationPage({super.key, required this.onUpdate, this.onboardingMode = false});

  @override
  State<ConfigurationPage> createState() => _ConfigurationPageState();
}

class _ConfigurationPageState extends State<ConfigurationPage> {
  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 12,
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ColoredTitle(text: context.i18n.setupTrainer),
        Builder(
          builder: (context) {
            final groupedByOfficial = SupportedApp.supportedApps.groupBy((e) => e.officialIntegration);
            return StatefulBuilder(
              builder: (c, setState) => Column(
                spacing: 8,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Select<SupportedApp>(
                    constraints: BoxConstraints(maxWidth: 400, minWidth: 400),
                    popupConstraints: BoxConstraints(maxWidth: 400, minWidth: 400, minHeight: 300),
                    itemBuilder: (c, app) => Row(
                      spacing: 8,
                      children: [
                        if (app.logoAsset != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.asset(app.logoAsset!, width: 22, height: 22),
                          ),
                        Expanded(child: Text(screenshotMode ? 'Trainer app' : app.name)),
                        if (app.supports(AppConnectionMethod.obpBle) ||
                            app.supports(AppConnectionMethod.obpMdns) ||
                            app.supports(AppConnectionMethod.obpDirCon))
                          OpenBikeControlLogo(),
                      ],
                    ),
                    popup: SelectPopup(
                      items: SelectItemList(
                        children: [
                          if (groupedByOfficial.get(true)?.isNotEmpty == true)
                            Container(
                              color: Theme.of(context).colorScheme.accent,
                              padding: const EdgeInsets.all(8.0),
                              child: GradientText(AppLocalizations.of(context).officiallySupported).xSmall,
                            ),
                          ...groupedByOfficial.get(true)?.map((app) {
                            final supportsObp =
                                app.supports(AppConnectionMethod.obpBle) ||
                                app.supports(AppConnectionMethod.obpMdns) ||
                                app.supports(AppConnectionMethod.obpDirCon);
                            return SelectItemButton(
                              value: app,
                              child: Row(
                                spacing: 8,
                                children: [
                                  if (app.logoAsset != null)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.asset(app.logoAsset!, width: 22, height: 22),
                                    ),
                                  Expanded(
                                    child: app == core.settings.getTrainerApp()
                                        ? Text(app.name).semiBold
                                        : Text(app.name),
                                  ),
                                  if (supportsObp) OpenBikeControlLogo(),
                                ],
                              ),
                            );
                          }),
                          if (groupedByOfficial.get(true)?.isNotEmpty == true)
                            Container(
                              color: Theme.of(context).colorScheme.accent,
                              padding: const EdgeInsets.all(8.0),
                              child: GradientText(AppLocalizations.of(context).otherTrainerApps).xSmall,
                            ),
                          ...groupedByOfficial.get(false)?.map((app) {
                            return SelectItemButton(
                              value: app,
                              child: app == core.settings.getTrainerApp() ? Text(app.name).semiBold : Text(app.name),
                            );
                          }),
                        ],
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
                      if (!selectedApp!.supports(AppConnectionMethod.zwiftMdns) &&
                          !selectedApp.supports(AppConnectionMethod.zwiftBle)) {
                        if (core.zwiftMdnsEmulator.isStarted.value) {
                          core.zwiftMdnsEmulator.stop();
                        }
                        if (core.zwiftEmulator.isStarted.value) {
                          core.zwiftEmulator.stopAdvertising();
                        }
                      }
                      if (core.obpMdnsEmulator.isStarted.value) {
                        core.obpMdnsEmulator.stopServer();
                      }
                      if (core.obpBluetoothEmulator.isStarted.value) {
                        core.obpBluetoothEmulator.stopServer();
                      }

                      core.settings.setTrainerApp(selectedApp);
                      if (core.actionHandler.supportedApp == null ||
                          (core.actionHandler.supportedApp is! CustomApp && selectedApp is! CustomApp)) {
                        core.actionHandler.init(selectedApp);
                        core.settings.setKeyMap(selectedApp);
                      }
                      core.logic.startEnabledConnectionMethod();
                      widget.onUpdate();
                      setState(() {});
                    },
                  ),
                  if (core.settings.getTrainerApp() != null) ...[
                    if ((core.settings.getTrainerApp()!.supports(AppConnectionMethod.obpBle) ||
                            core.settings.getTrainerApp()!.supports(AppConnectionMethod.obpMdns)) &&
                        !screenshotMode &&
                        !widget.onboardingMode)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Button.ghost(
                          onPressed: () {
                            launchUrlString('https://openbikecontrol.org', mode: LaunchMode.externalApplication);
                          },
                          child: Basic(
                            leading: OpenBikeControlLogo(),
                            title: Text(
                              AppLocalizations.of(
                                context,
                              ).openBikeControlAnnouncement(core.settings.getTrainerApp()!.name),
                            ).muted.xSmall.normal,
                            trailing: Icon(Icons.chevron_right, size: 16).iconMutedForeground,
                          ),
                        ),
                      ),
                    SizedBox(height: 0),
                    Text(
                      context.i18n.selectTargetWhereAppRuns(
                        screenshotMode ? 'Trainer app' : core.settings.getTrainerApp()?.name ?? 'the Trainer app',
                      ),
                    ).small,
                    Row(
                      spacing: 8,
                      children: [Target.thisDevice, Target.otherDevice]
                          .map(
                            (target) => Expanded(
                              child: SelectableCard(
                                title: Center(child: Icon(target.icon)),
                                isActive: target == core.settings.getLastTarget(),
                                subtitle: Center(
                                  child: Text(target.getTitle(context)),
                                ),
                                onPressed: () async {
                                  await _setTarget(context, target);
                                  setState(() {});
                                  widget.onUpdate();
                                },
                              ),
                            ),
                          )
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
                  if (core.settings.getTrainerApp()?.star == true && !screenshotMode && !widget.onboardingMode)
                    Row(
                      spacing: 8,
                      children: [
                        Icon(Icons.star),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(
                              context,
                            ).newConnectionMethodAnnouncement(core.settings.getTrainerApp()!.name),
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ).xSmall,
                        ),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _setTarget(BuildContext context, Target target) async {
    await core.settings.setLastTarget(target);

    if ((core.settings.getTrainerApp()?.supports(AppConnectionMethod.obpBle) == true ||
            core.settings.getTrainerApp()?.supports(AppConnectionMethod.obpMdns) == true) &&
        !core.logic.emulatorEnabled) {
      core.settings.setObpMdnsEnabled(true);
    }

    // enable local connection on Windows if the app doesn't support OBP
    if (target == Target.thisDevice &&
        !core.settings.getTrainerApp()!.supports(AppConnectionMethod.obpBle) &&
        !core.settings.getTrainerApp()!.supports(AppConnectionMethod.obpMdns) &&
        !kIsWeb &&
        Platform.isWindows) {
      core.settings.setLocalEnabled(true);
    }
    core.logic.startEnabledConnectionMethod();
  }
}
