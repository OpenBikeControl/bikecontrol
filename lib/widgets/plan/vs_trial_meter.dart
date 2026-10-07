import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show screenshotMode;
import 'package:bike_control/pages/home/chain_state.dart' show LinkStatus;
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/home/ampel.dart' show AmpelStyle;
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

/// [VsTrialMeter] behind a [gap], or nothing when [vsTrialMeterShown] says so.
/// Rebuilds as trainers connect and disconnect.
class VsTrialMeterSlot extends StatelessWidget {
  const VsTrialMeterSlot({super.key, required this.gap, this.compact = false});

  final double gap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BaseDevice>(
      stream: core.connection.connectionStream,
      builder: (context, _) {
        if (!vsTrialMeterShown()) return const SizedBox.shrink();
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [Gap(gap), VsTrialMeter(compact: compact)],
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
    final remainingText = l10n.bridgeMinutesRemainingToday(minutes);
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
