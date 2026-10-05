import 'dart:async';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/services/health/health_ride_service.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/ui/bk_touch_target.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// One-time home offer: "we noticed a ride, want rides saved to Apple Health
/// from now on?". Shown once — [HealthRideService.showsPrompt] already
/// folds in "the rider hasn't decided yet" and "dismissed for good" — and
/// built from the same parts as the trial card and the Pro-unregistered
/// banner so it belongs to the same stack.
class HealthRideCard extends StatelessWidget {
  const HealthRideCard({super.key, required this.service});

  final HealthRideService service;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service.changes,
      builder: (context, _) {
        if (!service.showsPrompt) return const SizedBox.shrink();

        final theme = Theme.of(context);
        final l = context.i18n;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            decoration: ShapeDecoration(
              color: theme.colorScheme.card,
              shadows: bkCardShadow(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide.none,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(13, 13, 13, 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(LucideIcons.heartPulse, size: 19, color: theme.colorScheme.primary),
                      ),
                      const Gap(12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l.healthRideCardTitle,
                              style: context.typography.base.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const Gap(2),
                            Text(
                              l.healthRideCardBody,
                              style: context.typography.xSmall.copyWith(
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Gap(12),
                  Row(
                    spacing: 8,
                    children: [
                      Expanded(
                        child: BkTouchTarget(
                          child: Button.ghost(
                            alignment: Alignment.center,
                            key: const Key('health-ride-card-dismiss'),
                            onPressed: () => unawaited(service.dismissPrompt()),
                            child: Text(l.healthRideCardDismiss),
                          ),
                        ),
                      ),
                      Expanded(
                        child: BkTouchTarget(
                          child: PrimaryButton(
                            alignment: Alignment.center,
                            key: const Key('health-ride-card-enable'),
                            onPressed: () => _enable(context),
                            child: Text(l.healthRideCardEnable),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _enable(BuildContext context) async {
    final granted = await IAPManager.instance.ensureProForFeature(
      context,
      featureName: AppLocalizations.current.healthRideCardTitle,
    );
    if (!context.mounted || !granted) return;
    await service.acceptPrompt();
  }
}
