import 'package:bike_control/widgets/ui/bk_icon_button.dart';
import 'dart:async';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/pages/button_edit.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/trainer_setup.dart';
import 'package:bike_control/utils/keymap/apps/bike_control.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:bike_control/widgets/ui/gradient_text.dart';
import 'package:bike_control/widgets/ui/openbikecontrol_logo.dart';
import 'package:bike_control/widgets/ui/warning.dart';
import 'package:d4rt/d4rt.dart';
import 'package:dartx/dartx.dart';
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
  /// Whether the trainer-app picker is open under the app's card. Always open
  /// while no app is picked yet.
  bool _changingApp = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 12,
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Builder(
          builder: (context) {
            return StatefulBuilder(
              builder: (c, setState) => Column(
                spacing: 8,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TrainerAppCard(
                    changing: _changingApp || core.settings.getTrainerApp() == null,
                    onChange: () => setState(() => _changingApp = !_changingApp),
                    picker: TrainerAppSelect(
                      onUpdate: () {
                        widget.onUpdate();
                        setState(() => _changingApp = false);
                      },
                    ),
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
                            trailing: Icon(LucideIcons.chevronRight, size: 16).iconMutedForeground,
                          ),
                        ),
                      ),
                    // BikeControl is self-hosted — no external target to pick.
                    if (core.settings.getTrainerApp() is! BikeControl) ...[
                      SizedBox(height: 0),
                      Text(
                        context.i18n.onboardingWhereTitle(
                          screenshotMode ? 'Trainer app' : core.settings.getTrainerApp()!.name,
                        ),
                      ).small,
                      Row(
                        spacing: 8,
                        children: Target.supportedFor(core.settings.getTrainerApp())
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
                  ],

                  if (core.settings.getTrainerApp() case final app?
                      when core.settings.getLastTarget() == Target.otherDevice &&
                          !core.logic.hasRecommendedConnectionMethods &&
                          // Nothing to install alongside an app that takes no
                          // controller input — it only ever sees us as a trainer.
                          app.receivesButtonEvents &&
                          app is! BikeControl) ...[
                    SizedBox(height: 8),
                    installOnTargetDeviceWarning(context, app),
                  ],
                  if (core.settings.getTrainerApp()?.star == true && !screenshotMode && !widget.onboardingMode)
                    Row(
                      spacing: 8,
                      children: [
                        Icon(LucideIcons.star),
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
    await applyTargetSelection(target);
  }
}

/// The trainer-app picker: a [Select] over [SupportedApp.supportedApps] that
/// reads/writes [core.settings.getTrainerApp]. Extracted from
/// [ConfigurationPage] so it can be rendered standalone (e.g. golden
/// snapshots). Behaviour is unchanged — it mutates the same `core.*`
/// singletons and notifies via [onUpdate].
/// The trainer app on top of Connection settings: its logo, "Trainer app"
/// over its name, and Change, which opens the picker underneath.
class _TrainerAppCard extends StatelessWidget {
  const _TrainerAppCard({required this.changing, required this.onChange, required this.picker});

  final bool changing;
  final VoidCallback onChange;
  final Widget picker;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final app = core.settings.getTrainerApp();
    final logo = app?.logoAsset;
    final name = app == null ? null : (screenshotMode ? 'Trainer app' : app.name);
    return Container(
      key: const ValueKey('connection-trainer-app'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(color: cs.card, borderRadius: BorderRadius.circular(BkComponentThemes.cardRadius)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (logo != null && !screenshotMode)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(logo, width: BkIconTile.size, height: BkIconTile.size),
                )
              else
                const BkIconTile(icon: LucideIcons.monitor),
              const Gap(BkGroupedRow.gap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.i18n.chainAppTitle,
                      style: context.typography.xSmall.copyWith(color: cs.mutedForeground),
                    ),
                    Text(
                      name ?? context.i18n.selectTrainerAppPlaceholder,
                      style: context.typography.base.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              if (app != null)
                Button.ghost(
                  onPressed: onChange,
                  child: Text(
                    context.i18n.rideChange,
                    style: context.typography.base.copyWith(color: bkAccentText(context)),
                  ),
                ),
            ],
          ),
          if (changing) ...[
            const Gap(10),
            Padding(padding: const EdgeInsets.only(right: 8), child: picker),
          ],
        ],
      ),
    );
  }
}

/// Tells the rider to put BikeControl on the device their trainer app runs on.
///
/// Apps that speak no controller protocol at all (Tacx Training) get two more
/// lines. For them the Local method — keystrokes typed into the app on the very
/// device it runs on — is not one option among several, it is the only way a
/// button press ever reaches them, so "install it over there" on its own reads
/// as a promise we can't keep. And Local doesn't exist on iOS: we can't tell
/// what the other device is, so rather than leave an iPad rider chasing a
/// method their device will never show, the second line names the platforms and
/// points at what still does work there — the Bridge and its virtual shifting.
Widget installOnTargetDeviceWarning(BuildContext context, SupportedApp app) {
  return Warning(
    children: [
      Text(context.i18n.warningInstallOnTargetDevice(app.name)).small,
      if (app.connections.isEmpty) ...[
        Text(context.i18n.warningAppLocalControlOnly(app.name)).small,
        Text(context.i18n.warningAppLocalControlIosNote(app.name)).small,
      ],
    ],
  );
}

class TrainerAppSelect extends StatelessWidget {
  /// Called after the trainer app changes so the host can rebuild.
  final VoidCallback onUpdate;

  /// Forces the real trainer-app name to show in the closed control even when
  /// [screenshotMode] is on (which otherwise replaces it with a generic
  /// "Trainer app" label for the anonymized marketing screenshots). Used by the
  /// MyWhoosh setup-guide snapshot, which needs the actual "MyWhoosh" name.
  final bool showRealName;
  const TrainerAppSelect({super.key, required this.onUpdate, this.showRealName = false});

  @override
  Widget build(BuildContext context) {
    final groupedByOfficial = SupportedApp.supportedApps.groupBy((e) => e.officialIntegration);
    return Select<SupportedApp>(
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
          Expanded(child: Text(screenshotMode && !showRealName ? 'Trainer app' : app.name)),
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
                      child: app == core.settings.getTrainerApp() ? Text(app.name).semiBold : Text(app.name),
                    ),
                    if (supportsObp) OpenBikeControlLogo(),
                    if (app.officialUrl != null)
                      BkIconButton.ghost(
                        icon: Icon(LucideIcons.externalLink, size: 16),
                        label: context.i18n.a11yOpenWebsite,
                        onPressed: () => launchUrlString(
                          app.officialUrl!,
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
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
                child: Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: app == core.settings.getTrainerApp() ? Text(app.name).semiBold : Text(app.name),
                    ),
                    if (app.officialUrl != null)
                      BkIconButton.ghost(
                        icon: Icon(LucideIcons.externalLink, size: 16),
                        label: context.i18n.a11yOpenWebsite,
                        onPressed: () => launchUrlString(
                          app.officialUrl!,
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ).call,
      placeholder: Text(context.i18n.selectTrainerAppPlaceholder),
      value: core.settings.getTrainerApp(),
      onChanged: (selectedApp) async {
        await applyTrainerAppSelection(selectedApp!);
        onUpdate();
      },
    );
  }
}
