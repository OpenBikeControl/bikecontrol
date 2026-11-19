import 'package:bike_control/pages/onboarding/widgets/onboarding_theme.dart';
import 'package:bike_control/pages/onboarding/onboarding_page.dart' show kOnboardingBodyMaxWidth;
import 'package:bike_control/pages/onboarding/widgets/onboarding_reveal.dart';
import 'package:bike_control/pages/onboarding/widgets/onboarding_update_banner.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/ui/bk_pill_button.dart';
import 'package:bike_control/widgets/ui/bk_touch_target.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The welcome screen: who this is, how long it takes, and what to have at
/// hand — the controller, the smart trainer and the trainer app, as three
/// pictures rather than three sentences — then start, or later.
///
/// Shown on every platform. It is capped to the same measure as the wizard's
/// own body so a wide desktop window doesn't stretch it across the screen, and
/// so stepping from here into the rail keeps the content at one width instead
/// of snapping narrower.
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
    final l = context.i18n;

    Widget need(IconData icon, String label, int index) => Expanded(
      child: OnboardingReveal(
        delay: Duration(milliseconds: 420 + index * 110),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withValues(alpha: 0.12)),
              child: Icon(icon, size: 22, color: accent),
            ),
            const Gap(8),
            Text(label, textAlign: TextAlign.center).small.semiBold,
          ],
        ),
      ),
    );

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kOnboardingBodyMaxWidth),
          // Scrolls when the content is taller than the screen (large system
          // text sizes); otherwise fills it so the spacers still centre it.
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  key: onboardingWelcomeContentKey,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(flex: 2),
                      const OnboardingUpdateBanner(),
                      OnboardingReveal(
                        delay: Duration.zero,
                        child: Center(child: Image.asset('icon.png', width: 72, height: 72)),
                      ),
                      const Gap(22),
                      OnboardingReveal(
                        delay: const Duration(milliseconds: 150),
                        child: Text(l.onboardingWelcomeTitle, textAlign: TextAlign.center).x3Large.semiBold,
                      ),
                      const Gap(8),
                      OnboardingReveal(
                        delay: const Duration(milliseconds: 280),
                        child: Text(l.onboardingWelcomeHaveReady, textAlign: TextAlign.center).small.muted,
                      ),
                      const Gap(28),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          need(LucideIcons.gamepad2, l.onboardingStepController, 0),
                          need(LucideIcons.bike, l.smartTrainer, 1),
                          need(LucideIcons.monitor, l.onboardingStepApp, 2),
                        ],
                      ),
                      const Spacer(flex: 3),
                      OnboardingReveal(
                        delay: const Duration(milliseconds: 800),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            BkPillButton(
                              key: onboardingWelcomeStartKey,
                              onPressed: onStart,
                              child: Text(l.onboardingWelcomeStart),
                            ),
                            const Gap(6),
                            BkTouchTarget(
                              child: GhostButton(
                                key: onboardingWelcomeLaterKey,
                                alignment: Alignment.center,
                                onPressed: onLater,
                                child: Center(child: Text(l.onboardingWelcomeLater).muted),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The welcome screen's start button, its "later", and its content column.
const Key onboardingWelcomeStartKey = ValueKey('onboarding-welcome-start');
const Key onboardingWelcomeLaterKey = ValueKey('onboarding-welcome-later');
const Key onboardingWelcomeContentKey = ValueKey('onboarding-welcome-content');
