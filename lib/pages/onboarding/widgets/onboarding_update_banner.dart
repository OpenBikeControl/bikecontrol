import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/pages/onboarding/widgets/onboarding_theme.dart';
import 'package:bike_control/services/app_update.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/ui/bk_touch_target.dart';
import 'package:bike_control/widgets/ui/loading_widget.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Offers a waiting update at the very start of setup — a rider who is about
/// to configure everything should do it on the current version, and a
/// Shorebird patch in particular is already downloaded and one restart away.
///
/// Renders nothing while checking and nothing when the app is current, so it
/// can be dropped into a layout unconditionally.
class OnboardingUpdateBanner extends StatefulWidget {
  const OnboardingUpdateBanner({super.key});

  @override
  State<OnboardingUpdateBanner> createState() => _OnboardingUpdateBannerState();
}

class _OnboardingUpdateBannerState extends State<OnboardingUpdateBanner> {
  AppUpdate? _update;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final update = await checkForAppUpdate();
      if (mounted) setState(() => _update = update);
    } catch (e, s) {
      recordError(e, s, context: 'onboarding update check');
    }
  }

  @override
  Widget build(BuildContext context) {
    final update = _update;
    if (update == null) return const SizedBox.shrink();
    final accent = onboardingAccent(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: accent.withValues(alpha: 0.09),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.circleArrowUp, size: 18, color: accent),
          Gap(11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(appUpdateLabel(update)).small.semiBold,
                Text(
                  update.isPatch ? context.i18n.onboardingUpdatePatchBody : context.i18n.onboardingUpdateStoreBody,
                ).xSmall.muted,
              ],
            ),
          ),
          Gap(10),
          LoadingWidget(
            futureCallback: () => applyAppUpdate(update),
            renderChild: (isLoading, tap) => BkTouchTarget(
              child: PrimaryButton(
                alignment: Alignment.center,
                size: ButtonSize.small,
                onPressed: tap,
                child: isLoading
                    ? SmallProgressIndicator()
                    : Text(
                        update.isPatch ? context.i18n.onboardingUpdateRestart : context.i18n.onboardingUpdateOpenStore,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
