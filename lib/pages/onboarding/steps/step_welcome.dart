import 'package:bike_control/pages/onboarding/widgets/onboarding_theme.dart';
import 'package:bike_control/pages/onboarding/onboarding_page.dart' show kOnboardingBodyMaxWidth;
import 'package:bike_control/pages/onboarding/widgets/onboarding_reveal.dart';
import 'package:bike_control/pages/onboarding/widgets/onboarding_update_banner.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/ui/bk_touch_target.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The welcome screen: the headline's words arrive one after the other, then
/// the subtitle, the reassurance rows and the actions.
///
/// Shown on every platform. It is capped to the same measure as the wizard's
/// own body so a wide desktop window doesn't stretch a column of short lines
/// across the screen, and so stepping from here into the rail keeps the text
/// at one width instead of snapping narrower.
///
/// [onStart] enters the wizard; [onLater] leaves it — and marks onboarding
/// done, so riders who decline aren't asked again on every launch.
class OnboardingWelcome extends StatelessWidget {
  const OnboardingWelcome({super.key, required this.onStart, required this.onLater});
  final VoidCallback onStart;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final accent = onboardingAccent(context);
    final words = context.i18n.onboardingWelcomeTitle.split(' ');

    Widget point(IconData icon, String text, int index) => OnboardingReveal(
      delay: Duration(milliseconds: 900 + index * 110),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.12),
              ),
              child: Icon(icon, size: 15, color: accent),
            ),
            Gap(12),
            Expanded(child: Text(text).small),
          ],
        ),
      ),
    );

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kOnboardingBodyMaxWidth),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(flex: 2),
                const OnboardingUpdateBanner(),
                OnboardingReveal(
                  delay: Duration.zero,
                  child: Image.asset('icon.png', width: 64, height: 64),
                ),
                Gap(22),
                // Word-by-word reveal — the headline writes itself in.
                Wrap(
                  spacing: 9,
                  runSpacing: 2,
                  children: [
                    for (var i = 0; i < words.length; i++)
                      OnboardingReveal(
                        delay: Duration(milliseconds: 180 + i * 90),
                        child: Text(words[i]).x3Large.semiBold,
                      ),
                  ],
                ),
                Gap(12),
                OnboardingReveal(
                  delay: Duration(milliseconds: 180 + words.length * 90),
                  child: Text(context.i18n.onboardingWelcomeSubtitle).small.muted,
                ),
                Gap(26),
                point(LucideIcons.gamepad2, context.i18n.onboardingWelcomePointController, 0),
                point(LucideIcons.bike, context.i18n.onboardingWelcomePointTrainer, 1),
                point(LucideIcons.wifi, context.i18n.onboardingWelcomePointApp, 2),
                const Spacer(flex: 3),
                OnboardingReveal(
                  delay: const Duration(milliseconds: 1300),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      BkTouchTarget(
                        child: PrimaryButton(
                          alignment: Alignment.center,
                          onPressed: onStart,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(context.i18n.onboardingWelcomeStart),
                              Gap(8),
                              Icon(LucideIcons.arrowRight, size: 16),
                            ],
                          ),
                        ),
                      ),
                      Gap(8),
                      BkTouchTarget(
                        child: GhostButton(
                          alignment: Alignment.center,
                          onPressed: onLater,
                          child: Center(child: Text(context.i18n.onboardingWelcomeLater)),
                        ),
                      ),
                      Gap(6),
                      Center(child: Text(context.i18n.onboardingWelcomeFootnote).xSmall.muted),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
