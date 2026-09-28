import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/home/ampel.dart';
import 'package:bike_control/pages/home/chain_state.dart';
import 'package:bike_control/widgets/ui/bk_touch_target.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// What the licence card has to say, as plain data — so the numbers can be
/// checked without a store connection.
class TrialCardState {
  const TrialCardState({
    required this.daysRemaining,
    required this.daysTotal,
    required this.expired,
    required this.commandsRemaining,
    required this.commandsTotal,
    this.bridgeMinutesRemaining,
    this.bridgeMinutesTotal,
  });

  final int daysRemaining;
  final int daysTotal;
  final bool expired;
  final int commandsRemaining;
  final int commandsTotal;

  /// Only set when a smart trainer is actually present — virtual shifting
  /// minutes are meaningless otherwise, and an idle meter is just noise.
  final int? bridgeMinutesRemaining;
  final int? bridgeMinutesTotal;

  bool get showsBridgeMeter => bridgeMinutesRemaining != null && (bridgeMinutesTotal ?? 0) > 0;

  bool get _bridgeLow => showsBridgeMeter && bridgeMinutesRemaining! / bridgeMinutesTotal! <= 0.25;

  /// Urgency is earned, not constant: the card only turns amber when one of
  /// the budgets is genuinely close to running out.
  bool get urgent => expired || daysRemaining <= 1 || _bridgeLow;
}

/// The licence card, deliberately built from the same parts as the chain cards
/// — same surface, same 1.5px border, same tile + title + action header — so it
/// belongs to the stack instead of sitting in it as a foreign slab.
///
/// Both limits are shown as meters. "80 commands left" is meaningless without
/// its ceiling; "80 of 100" tells a rider how much runway they have.
class TrialCard extends StatelessWidget {
  const TrialCard({super.key, required this.state, this.onUpgrade, this.onRestore});

  final TrialCardState state;
  final VoidCallback? onUpgrade;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.i18n;
    final warning = AmpelStyle.of(context, LinkStatus.attention);

    return Container(
      decoration: ShapeDecoration(
        color: theme.colorScheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: state.urgent ? warning.color : theme.colorScheme.border, width: 1.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 13, 13, 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: warning.wash, borderRadius: BorderRadius.circular(11)),
                  child: Icon(LucideIcons.award, size: 19, color: warning.text),
                ),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        state.expired ? l.chainTrialExpiredTitle : l.chainTrialTitle,
                        style: context.typography.base.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const Gap(2),
                      Text(
                        state.expired
                            ? l.chainTrialCommandsLimited(state.commandsTotal)
                            : l.chainTrialDaysLeft(state.daysRemaining),
                        style: context.typography.xSmall.copyWith(
                          fontWeight: state.urgent ? FontWeight.w700 : FontWeight.w500,
                          color: state.urgent ? warning.text : theme.colorScheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(8),
                BkTouchTarget(
                  child: PrimaryButton(
                    alignment: Alignment.center,
                    size: ButtonSize.small,
                    onPressed: onUpgrade,
                    child: Text(l.chainUpgrade),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Commands are capped during the trial too — RevenueCatService
                // enforces the daily limit whatever the trial state, it just
                // raises the ceiling to 80 while the trial runs and drops it
                // afterwards. So the meter is always honest, and always shown.
                if (!state.expired) ...[
                  _Meter(label: l.chainTrialDaysMeter, value: state.daysRemaining, total: state.daysTotal),
                  const Gap(11),
                ],
                _Meter(
                  label: l.chainTrialCommandsMeter,
                  value: state.commandsRemaining,
                  total: state.commandsTotal,
                ),
                if (state.showsBridgeMeter) ...[
                  const Gap(11),
                  _Meter(
                    label: l.chainTrialBridgeMeter,
                    value: state.bridgeMinutesRemaining!,
                    total: state.bridgeMinutesTotal!,
                    suffix: l.chainTrialBridgeMeterSuffix,
                  ),
                ],
              ],
            ),
          ),
          if (onRestore != null)
            BkTouchTarget(
              child: Button.ghost(
                alignment: Alignment.center,
                onPressed: onRestore,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: theme.colorScheme.border, width: 0.5)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Icon(LucideIcons.rotateCcw, size: 14, color: theme.colorScheme.mutedForeground),
                      const Gap(7),
                      Expanded(
                        child: Text(
                          l.chainTrialRestoreRow,
                          style: context.typography.xSmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.mutedForeground,
                          ),
                        ),
                      ),
                      Icon(LucideIcons.chevronRight, size: 14, color: theme.colorScheme.mutedForeground),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Today's virtual-shifting budget for a Base owner.
class VsBudgetCardState {
  const VsBudgetCardState({required this.minutesRemaining, required this.minutesTotal});

  final int minutesRemaining;
  final int minutesTotal;
}

/// Base doesn't include BikeControl's virtual shifting — without Pro its daily
/// budget applies after buying Base too (see ProxyDevice._syncBridgeTracking).
/// The trial card is gone once Base is bought, so this is the only place a
/// Base owner can see the budget before hitting it. Null when it doesn't
/// apply: no bridged trainer, Pro on this device, or not bought yet (the trial
/// card shows the meter then).
VsBudgetCardState? vsBudgetCardState({
  required bool isPurchased,
  required bool isProForDevice,
  required bool trainerBridged,
  required Duration remainingToday,
  required Duration dailyLimit,
}) {
  if (!isPurchased || isProForDevice || !trainerBridged || dailyLimit <= Duration.zero) return null;
  final remaining = remainingToday.isNegative ? Duration.zero : remainingToday;
  return VsBudgetCardState(minutesRemaining: remaining.inMinutes, minutesTotal: dailyLimit.inMinutes);
}

/// The Base owner's virtual-shifting meter: one line, same surface as the
/// chain cards, and the way to Pro.
class VsBudgetCard extends StatelessWidget {
  const VsBudgetCard({super.key, required this.state, this.onUpgrade});

  final VsBudgetCardState state;
  final VoidCallback? onUpgrade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.i18n;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
      decoration: ShapeDecoration(
        color: theme.colorScheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colorScheme.border, width: 1.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _Meter(
              label: l.chainTrialBridgeMeter,
              value: state.minutesRemaining,
              total: state.minutesTotal,
              suffix: l.chainTrialBridgeMeterSuffix,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Button.ghost(
              onPressed: onUpgrade,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.vsBudgetProRemovesLimit).xSmall.semiBold,
                  const Gap(4),
                  const Icon(LucideIcons.chevronRight, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A budget-of-total bar. Turns amber in the last quarter — the point at which
/// the number starts to matter.
class _Meter extends StatelessWidget {
  const _Meter({required this.label, required this.value, required this.total, this.suffix});

  final String label;
  final int value;
  final int total;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = total > 0 ? (value / total).clamp(0.0, 1.0) : 0.0;
    final low = fraction <= 0.25;
    final warningStyle = AmpelStyle.of(context, LinkStatus.attention);
    final warning = warningStyle.color;
    final muted = theme.colorScheme.mutedForeground;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                label,
                style: context.typography.xSmall.copyWith(fontWeight: FontWeight.w500, color: muted),
              ),
            ),
            const Gap(6),
            Text(
              '$value',
              style: context.typography.xSmall.copyWith(
                fontWeight: FontWeight.w700,
                color: low ? warningStyle.text : theme.colorScheme.foreground,
              ),
            ),
            const Gap(4),
            Text(
              suffix == null ? '/ $total' : '/ $total $suffix',
              style: context.typography.caption.copyWith(color: muted),
            ),
          ],
        ),
        const Gap(5),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 4,
            backgroundColor: theme.colorScheme.muted,
            color: low ? warning : theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
