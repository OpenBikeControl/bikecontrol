import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/apps/strappo.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/apps/training_peaks.dart';
import 'package:bike_control/pages/onboarding/widgets/onboarding_theme.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// The "Then in $app" mini-guide shown at the bottom of the onboarding
/// connection step: numbered steps plus optional screenshots and a link to
/// the full setup guide on the marketing site.
class OnboardingAppGuide {
  const OnboardingAppGuide({required this.steps, this.screenshotUrls = const [], this.guideUrl});

  final List<String> steps;
  final List<String> screenshotUrls;
  final String? guideUrl;
}

const String _shots = 'https://bikecontrol.app/images/';

OnboardingAppGuide onboardingGuideFor(BuildContext context, SupportedApp app) {
  final l = context.i18n;
  if (app is MyWhoosh) {
    return OnboardingAppGuide(
      steps: [l.onboardingGuideMyWhoosh1, l.onboardingGuideMyWhoosh2, l.onboardingGuideMyWhoosh3],
      screenshotUrls: [
        '$_shots' 'mywhoosh_obc/4-mywhoosh-connection-screen.jpg',
        '$_shots' 'mywhoosh_obc/5-mywhoosh-openbikecontrol.jpg',
        '$_shots' 'mywhoosh_obc/6-bikecontrol-connected.jpg',
      ],
      guideUrl: 'https://bikecontrol.app/blog/mywhoosh-bikecontrol-partnership/',
    );
  }
  if (app is Rouvy) {
    return OnboardingAppGuide(
      steps: [l.onboardingGuideRouvy1, l.onboardingGuideRouvy2],
      screenshotUrls: ['$_shots' 'blog_rouvy_screenshot.jpg'],
      guideUrl: 'https://bikecontrol.app/blog/rouvy-bikecontrol-integration/',
    );
  }
  if (app is TrainingPeaks) {
    return OnboardingAppGuide(
      steps: [l.onboardingGuideTp1, l.onboardingGuideTp2, l.onboardingGuideTp3],
      guideUrl: 'https://bikecontrol.app/blog/trainingpeaks-bikecontrol-partnership/',
    );
  }
  if (app is Strappo) {
    return OnboardingAppGuide(steps: [l.onboardingGuideStrappo1, l.onboardingGuideStrappo2]);
  }
  return OnboardingAppGuide(steps: [l.onboardingGuideGeneric1(app.name), l.onboardingGuideGeneric2]);
}

/// The "Then in {app}" card: numbered steps, screenshots and a link to the full
/// guide on the marketing site.
///
/// Shared by the onboarding connection step and the home screen's trainer-app
/// instructions sheet. A rider who hits "not connected" after setup gets
/// exactly the same instructions — including the screenshots — that walked them
/// through it the first time, instead of a thinner second-hand retelling.
class OnboardingAppGuideCard extends StatelessWidget {
  const OnboardingAppGuideCard({super.key, required this.app, this.bordered = true});

  final SupportedApp app;

  /// The onboarding step draws its own border; a sheet doesn't need one.
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final guide = onboardingGuideFor(context, app);
    final scheme = Theme.of(context).colorScheme;
    final guideUrl = guide.guideUrl;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(bordered ? 16 : 0),
      decoration: bordered
          ? BoxDecoration(
              color: scheme.card,
              borderRadius: BorderRadius.circular(16),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < guide.steps.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: onboardingAccent(context)),
                    child: DefaultTextStyle.merge(
                      style: const TextStyle(color: Color(0xFFFFFFFF)),
                      child: Text('${i + 1}').xSmall.semiBold,
                    ),
                  ),
                  const Gap(11),
                  Expanded(
                    child: Padding(padding: const EdgeInsets.only(top: 2), child: Text(guide.steps[i]).small),
                  ),
                ],
              ),
            ),
          if (guide.screenshotUrls.isNotEmpty) ...[
            const Gap(13),
            SizedBox(
              height: 118,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final url in guide.screenshotUrls)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(url, height: 118, errorBuilder: (_, _, _) => const SizedBox.shrink()),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (guideUrl != null) ...[
            const Gap(12),
            Button.ghost(
              onPressed: () => launchUrlString(guideUrl, mode: LaunchMode.externalApplication),
              child: Row(
                children: [
                  const Icon(LucideIcons.bookOpen, size: 15),
                  const Gap(8),
                  Flexible(child: Text(context.i18n.onboardingFullSetupGuide(app.name)).small),
                  const Gap(6),
                  const Icon(LucideIcons.externalLink, size: 13),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}


/// "Pair BikeControl as your trainer" — the bridge entry to look for in the
/// trainer app, which slots to assign it to, and the warning about pairing the
/// bare trainer instead.
///
/// Shared by the onboarding connection step and the home screen's trainer card.
/// A rider whose bridge is running but hasn't been picked up yet gets these
/// exact instructions, not a paraphrase of them.
class OnboardingPairAsTrainerCard extends StatelessWidget {
  const OnboardingPairAsTrainerCard({super.key, required this.app, required this.trainerName});

  final SupportedApp app;
  final String? trainerName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bridgeEntry = '${trainerName ?? ''} - BikeControl';
    return
    Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: scheme.card,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(context.i18n.onboardingPairAsTrainerBody(app.name)).small,
        Gap(12),
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
              color: scheme.muted, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Icon(LucideIcons.radio, size: 20, color: onboardingAccent(context)),
            Gap(12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(bridgeEntry).small.semiBold,
                Text(context.i18n.onboardingVirtualTrainerGears('${app.virtualGearAmount}')).xSmall.muted,
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: _success.withValues(alpha: 0.12),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: _success),
                ),
                Gap(5),
                DefaultTextStyle.merge(
                  style: TextStyle(color: BkStatusColors.of(context).success),
                  child: Text(context.i18n.onboardingLive).xSmall.semiBold,
                ),
              ]),
            ),
          ]),
        ),
        Gap(12),
        DefaultTextStyle.merge(
          style: TextStyle(letterSpacing: 0.8, color: scheme.mutedForeground),
          child: Text(context.i18n.onboardingSelectItFor.toUpperCase()).xSmall.semiBold,
        ),
        Gap(4),
        _slotRow(context, LucideIcons.zap, context.i18n.onboardingSlotPower, bridgeEntry, first: true),
        _slotRow(context, LucideIcons.slidersHorizontal, context.i18n.onboardingSlotControllable, bridgeEntry,
            first: false),
        _slotRow(context, LucideIcons.refreshCw, context.i18n.onboardingSlotCadence, bridgeEntry, first: false),
        Gap(12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: _warning.withValues(alpha: 0.12),
            border: Border.all(color: _warning.withValues(alpha: 0.5)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(LucideIcons.triangleAlert, size: 16, color: BkStatusColors.of(context).warning),
            Gap(10),
            Expanded(
              child: Text(context.i18n.onboardingPairAsTrainerWarning(trainerName ?? '', app.name)).xSmall,
            ),
          ]),
        ),
      ]),
    );
  }
}

Widget _slotRow(BuildContext context, IconData icon, String slot, String entryName, {required bool first}) {
  final scheme = Theme.of(context).colorScheme;
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 7),
    decoration: first ? null : BoxDecoration(border: Border(top: BorderSide(color: scheme.border, width: 0.5))),
    child: Row(children: [
      Icon(icon, size: 15, color: onboardingAccent(context)),
      const Gap(9),
      Expanded(child: Text(slot).xSmall.semiBold),
      Flexible(child: Text(entryName, overflow: TextOverflow.ellipsis, maxLines: 1).xSmall.muted),
    ]),
  );
}

const Color _success = Color(0xFF22C55E);
const Color _warning = Color(0xFFF59E0B);
