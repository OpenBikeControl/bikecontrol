import 'dart:async';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/pages/button_edit.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/trainer_setup.dart';
import 'package:bike_control/widgets/keymap/trainer_app_keymap_prompt.dart';
import 'package:bike_control/utils/keymap/apps/bike_control.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:bike_control/widgets/ui/bk_tappable.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:bike_control/widgets/ui/openbikecontrol_logo.dart';
import 'package:bike_control/widgets/ui/warning.dart';
import 'package:bike_control/widgets/ui/trainer_app_logo.dart';
import 'package:bike_control/widgets/trainer_app_picker.dart';
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
        Builder(
          builder: (context) {
            return StatefulBuilder(
              builder: (c, setState) => Column(
                spacing: 8,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TrainerAppCard(
                    onUpdate: () {
                      widget.onUpdate();
                      setState(() {});
                    },
                  ),
                  if (core.settings.getTrainerApp() != null) ...[
                    if ((core.settings.getTrainerApp()!.supports(AppConnectionMethod.obpBle) ||
                            core.settings.getTrainerApp()!.supports(AppConnectionMethod.obpMdns)) &&
                        !screenshotMode &&
                        !widget.onboardingMode)
                      _OpenBikeControlNote(appName: core.settings.getTrainerApp()!.name),
                    // BikeControl is self-hosted — no external target to pick.
                    if (core.settings.getTrainerApp() is! BikeControl) ...[
                      SizedBox(height: 0),
                      Text(
                        context.i18n.onboardingWhereTitle(
                          shownTrainerAppName(core.settings.getTrainerApp()!.name),
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

/// The note that the trainer app speaks the OpenBikeControl Protocol: a quiet card
/// that opens the protocol's site.
class _OpenBikeControlNote extends StatelessWidget {
  const _OpenBikeControlNote({required this.appName});

  final String appName;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(BkComponentThemes.cardRadius);
    return BkTappable(
      key: const ValueKey('connection-obc-announcement'),
      borderRadius: radius,
      onPressed: () => launchUrlString('https://openbikecontrol.org', mode: LaunchMode.externalApplication),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        decoration: BoxDecoration(color: cs.card, borderRadius: radius),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Container(
                width: BkIconTile.size,
                height: BkIconTile.size,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: cs.muted, borderRadius: BorderRadius.circular(8)),
                child: OpenBikeControlLogo(size: 18, color: bkAccentText(context)),
              ),
            ),
            const Gap(BkGroupedRow.gap),
            Expanded(
              child: Text(
                AppLocalizations.of(context).openBikeControlAnnouncement(appName),
                style: context.typography.small.copyWith(color: cs.mutedForeground, height: 1.4),
              ),
            ),
            const Gap(8),
            Icon(LucideIcons.chevronRight, size: 16, color: cs.mutedForeground),
          ],
        ),
      ),
    );
  }
}

/// The trainer app on top of Connection settings: its logo, "Trainer app"
/// over its name, and Change, which opens the app grid
/// ([openTrainerAppPicker]). With no app picked yet the whole card opens it.
class TrainerAppCard extends StatelessWidget {
  const TrainerAppCard({super.key, required this.onUpdate, this.showRealName = false});

  /// Called after the trainer app changed.
  final VoidCallback onUpdate;

  /// Shows the real name and logo even under [screenshotMode], which otherwise
  /// replaces them with a generic "Trainer app" for the anonymized store
  /// screenshots. The per-app website setup guides need the real one.
  final bool showRealName;

  Future<void> _pick(BuildContext context) async {
    final app = await openTrainerAppPicker(context);
    if (app == null || !context.mounted) return;
    // Asks first when the rider's own button mapping was made for another
    // app; dismissing it leaves the trainer app unchanged.
    if (!await pickTrainerApp(context, app)) return;
    onUpdate();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final app = core.settings.getTrainerApp();
    final logo = app?.logoAsset;
    final name = app == null ? null : (showRealName ? app.name : shownTrainerAppName(app.name));
    final radius = BorderRadius.circular(BkComponentThemes.cardRadius);
    final card = Container(
      key: const ValueKey('connection-trainer-app'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(color: cs.card, borderRadius: radius, boxShadow: bkCardShadow(context)),
      child: Row(
        children: [
          if (logo != null && (!screenshotMode || showRealName))
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TrainerAppLogo(asset: logo, url: app?.logoUrl, width: BkIconTile.size, height: BkIconTile.size),
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
            // Its own context, so the popover opens under the button.
            Builder(
              builder: (buttonContext) => Button.ghost(
                onPressed: () => _pick(buttonContext),
                child: Text(
                  context.i18n.rideChange,
                  style: context.typography.base.copyWith(color: bkAccentText(context)),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(LucideIcons.chevronRight, size: 18, color: cs.mutedForeground),
            ),
        ],
      ),
    );
    if (app != null) return card;
    return Builder(
      builder: (cardContext) => BkTappable(borderRadius: radius, onPressed: () => _pick(cardContext), child: card),
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
