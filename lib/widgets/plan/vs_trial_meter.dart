import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show screenshotMode;
import 'package:bike_control/pages/home/chain_state.dart' show LinkStatus;
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/vs_trial_copy.dart';
import 'package:bike_control/widgets/home/ampel.dart' show AmpelStyle;
import 'package:bike_control/widgets/home/trial_card.dart' show BudgetMeter, trialDaysTotal;
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_brand_band.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Whether the plan cards (Settings, the sidebar) show today's virtual
/// shifting trial. Virtual shifting is Pro per device; everyone else gets the
/// daily trial of it. Base riders only see it while a smart trainer is
/// connected: without one their buttons shift in the trainer app and the
/// trial minutes are beside the point. Store renders stage a finished setup,
/// not a limit.
bool vsTrialMeterShown() =>
    !IAPManager.instance.isProEnabledForCurrentDevice &&
    core.bridgeUsageTracker.dailyLimit > Duration.zero &&
    !screenshotMode &&
    (!IAPManager.instance.isPurchased.value || core.connection.proxyDevices.any((d) => d.isConnected));

/// Whether the plan cards show the trial's days and today's presses: on the
/// free tier, as the licence card on Fahren does. Buying Base or Pro lifts
/// both limits. Store renders stage a finished setup, not a limit.
bool trialBudgetsShown() =>
    !IAPManager.instance.isPurchased.value && !IAPManager.instance.isProEnabledForCurrentDevice && !screenshotMode;

/// The plan's budgets behind a [gap], or nothing when none applies. The plan
/// cards (Settings, Plan & account) show the same meters as the licence card
/// on Fahren — trial days, presses left today, virtual shifting today — so
/// the three places agree. [compact] (the sidebar) shows only the virtual
/// shifting line. Rebuilds as trainers connect and disconnect, and as the Pro
/// state changes: signing in to Pro (the device registering) hides it without
/// waiting for a trainer to connect.
class VsTrialMeterSlot extends StatelessWidget {
  const VsTrialMeterSlot({super.key, required this.gap, this.compact = false});

  final double gap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final iap = IAPManager.instance;
    return ListenableBuilder(
      // Everything [vsTrialMeterShown] and [trialBudgetsShown] read from the
      // purchase state: the account's entitlements (and registration flag),
      // the purchase flag and the store-side Pro flag.
      listenable: Listenable.merge([iap.entitlements, iap.isPurchased, iap.isLocalPro]),
      builder: (context, _) => StreamBuilder<BaseDevice>(
        stream: core.connection.connectionStream,
        builder: (context, _) {
          final vs = vsTrialMeterShown();
          final budgets = !compact && trialBudgetsShown();
          if (!vs && !budgets) return const SizedBox.shrink();
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Gap(gap),
              if (compact) const VsTrialMeter(compact: true) else PlanBudgetMeters(vs: vs, budgets: budgets),
            ],
          );
        },
      ),
    );
  }
}

/// The plan cards' meters, as on the licence card: trial days (while the
/// trial runs), presses left today and virtual shifting today, each
/// "remaining / total" over a bar.
class PlanBudgetMeters extends StatelessWidget {
  const PlanBudgetMeters({super.key, required this.vs, required this.budgets});

  /// Show virtual shifting today.
  final bool vs;

  /// Show trial days and presses left today.
  final bool budgets;

  @override
  Widget build(BuildContext context) {
    final tracker = core.bridgeUsageTracker;
    return ValueListenableBuilder<Duration>(
      valueListenable: tracker.usedTodayListenable,
      builder: (context, _, _) {
        final l10n = AppLocalizations.of(context);
        final iap = IAPManager.instance;
        final days = iap.trialDaysRemaining;
        final presses = iap.commandsRemainingToday;
        final remaining = tracker.remainingToday;
        final minutes = remaining.isNegative ? 0 : remaining.inMinutes;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 11,
          children: [
            if (budgets && !iap.isTrialExpired)
              BudgetMeter(
                key: const ValueKey('plan-meter-days'),
                label: l10n.chainTrialDaysMeter,
                value: days,
                total: trialDaysTotal(days),
              ),
            // -1: no daily cap on this build.
            if (budgets && presses >= 0 && IAPManager.dailyCommandLimit > 0)
              BudgetMeter(
                key: const ValueKey('plan-meter-presses'),
                label: l10n.chainTrialCommandsMeter,
                value: presses,
                total: IAPManager.dailyCommandLimit,
              ),
            if (vs)
              Semantics(
                label: '${l10n.chainTrialBridgeMeter}: ${VsTrialCopy.current(l10n).minutesLeftToday(minutes)}',
                excludeSemantics: true,
                child: BudgetMeter(
                  key: const ValueKey('plan-meter-vs'),
                  label: l10n.chainTrialBridgeMeter,
                  value: minutes,
                  total: tracker.dailyLimit.inMinutes,
                  suffix: l10n.chainTrialBridgeMeterSuffix,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// "Virtual shifting today · 14 min remaining today" over a bar, following
/// the day's usage. [compact] (the sidebar) drops the title and thins the
/// bar; the spoken label stays the same.
class VsTrialMeter extends StatelessWidget {
  const VsTrialMeter({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tracker = core.bridgeUsageTracker;
    return ValueListenableBuilder<Duration>(
      valueListenable: tracker.usedTodayListenable,
      builder: (context, _, _) => _meter(context, tracker.remainingToday, tracker.dailyLimit),
    );
  }

  Widget _meter(BuildContext context, Duration remaining, Duration limit) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final minutes = remaining.isNegative ? 0 : remaining.inMinutes;
    final fraction = limit.inSeconds > 0 ? (remaining.inSeconds / limit.inSeconds).clamp(0.0, 1.0) : 0.0;
    final low = fraction <= 0.25;
    final status = BkStatusColors.of(context);
    final remainingText = VsTrialCopy.current(l10n).minutesLeftToday(minutes);
    final remainingStyle = context.typography.xSmall.copyWith(
      // On the brand band (the plan cards) only white reads; the bar still
      // turns amber when the day's minutes run low.
      color: low && !BkBrandBand.isOn(context) ? AmpelStyle.of(context, LinkStatus.attention).text : cs.mutedForeground,
    );
    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LinearProgressIndicator(
        value: fraction,
        minHeight: compact ? 4 : 6,
        backgroundColor: cs.muted,
        color: low ? status.warning : cs.primary,
      ),
    );
    return Semantics(
      label: '${l10n.chainTrialBridgeMeter}: $remainingText',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: compact ? 4 : 6,
        children: [
          if (compact)
            Text(remainingText, maxLines: 2, overflow: TextOverflow.ellipsis, style: remainingStyle)
          else
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.chainTrialBridgeMeter,
                    style: context.typography.small.copyWith(fontWeight: FontWeight.w500),
                  ),
                ),
                Text(remainingText, style: remainingStyle),
              ],
            ),
          bar,
        ],
      ),
    );
  }
}
