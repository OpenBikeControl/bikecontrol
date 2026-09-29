import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/services/network_self_test/network_probe_context.dart';
import 'package:bike_control/widgets/network_test/network_tokens.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The live test: the one check that asks the rider to do something, and the
/// only one that proves the whole path end to end.
///
/// It gets its own card rather than a row because it is the only check with a
/// duration — everything else has already resolved by the time it is read.
/// The head carries the ask and the countdown, the stepper shows how far the
/// trainer app has got, and the tinting sets it apart from the settled checks
/// above it.
class NetworkLiveTestCard extends StatelessWidget {
  const NetworkLiveTestCard({super.key, required this.watch, this.appName, this.onSkip});

  final WatchProgress watch;

  /// The trainer app being waited on, so the first step can name it.
  final String? appName;

  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tokens = NetworkTokens.of(context);
    final app = appName ?? '';

    final elapsed = watch.window - watch.remaining;
    final progress = watch.window.inMilliseconds == 0
        ? 0.0
        : (elapsed.inMilliseconds / watch.window.inMilliseconds).clamp(0.0, 1.0);

    // The four things the trainer app does, in the order it does them. The
    // rider is watching their own app move through this list.
    final steps = <(String, bool)>[
      (l10n.networkWatchFoundUs(app), watch.browsed),
      (l10n.networkWatchResolved, watch.resolved),
      (l10n.networkWatchAddressAsks(watch.addressAsks), watch.addressAsks > 0),
      (l10n.networkWatchConnected, watch.connected),
    ];
    // The first step not yet done is the one in progress; everything after it
    // is still ahead.
    final current = steps.indexWhere((s) => !s.$2);

    return Container(
      decoration: BoxDecoration(
        color: cs.card,
        border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _head(context, l10n, cs, app),
          _bar(context, cs, progress),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < steps.length; i++)
                  _Step(
                    label: steps[i].$1,
                    done: steps[i].$2,
                    current: i == current,
                    last: i == steps.length - 1,
                  ),
              ],
            ),
          ),
          _foot(context, l10n, cs, tokens),
        ],
      ),
    );
  }

  Widget _head(BuildContext context, AppLocalizations l10n, ColorScheme cs, String app) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 18),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.07),
        border: Border(bottom: BorderSide(color: cs.primary.withValues(alpha: 0.2))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(size: 22, strokeWidth: 2, color: cs.primary),
          ),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.networkWatchTitle, style: context.typography.small.copyWith(fontWeight: FontWeight.w700)),
                Text(
                  l10n.networkWatchPrompt(app),
                  style: context.typography.xSmall.copyWith(color: cs.mutedForeground),
                ),
              ],
            ),
          ),
          const Gap(12),
          Text(
            _clock(watch.remaining),
            style: Theme.of(context).typography.mono.copyWith(
              fontSize: context.typography.xSmall.fontSize,
              fontWeight: FontWeight.w600,
              color: cs.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar(BuildContext context, ColorScheme cs, double progress) {
    return SizedBox(
      height: 3,
      child: Stack(
        children: [
          Container(color: cs.primary.withValues(alpha: 0.2)),
          FractionallySizedBox(
            widthFactor: progress,
            child: Container(color: cs.primary),
          ),
        ],
      ),
    );
  }

  Widget _foot(BuildContext context, AppLocalizations l10n, ColorScheme cs, NetworkTokens tokens) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 18),
      decoration: BoxDecoration(
        color: tokens.pageBg,
        border: Border(top: BorderSide(color: tokens.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.networkWatchEndsItself,
              style: context.typography.xSmall.copyWith(color: cs.mutedForeground),
            ),
          ),
          const Gap(12),
          Button.ghost(
            style: ButtonStyle.ghost(size: ButtonSize.small),
            onPressed: onSkip,
            child: Text(l10n.networkWatchSkip),
          ),
        ],
      ),
    );
  }

  static String _clock(Duration d) {
    final seconds = d.inSeconds.clamp(0, 59 * 60);
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}

/// One line of the stepper: a bullet, the step, and the connector down to the
/// next one. The connector turns green behind a step that has happened, so the
/// card reads as a path being walked rather than a checklist.
class _Step extends StatelessWidget {
  const _Step({required this.label, required this.done, required this.current, required this.last});

  final String label;
  final bool done;
  final bool current;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tokens = NetworkTokens.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 18,
            child: Column(
              children: [
                SizedBox(
                  height: 26,
                  child: Center(
                    child: done
                        ? Icon(LucideIcons.check, size: 14, color: tokens.ok)
                        : Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: current ? cs.primary : cs.border,
                              boxShadow: current
                                  ? [BoxShadow(color: cs.primary.withValues(alpha: 0.18), spreadRadius: 4)]
                                  : null,
                            ),
                          ),
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 1.5,
                        color: done ? tokens.ok.withValues(alpha: 0.35) : tokens.hairline,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Gap(12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 7, bottom: 7),
              child: Text(
                label,
                style: context.typography.small.copyWith(
                  fontWeight: current ? FontWeight.w600 : FontWeight.w500,
                  color: done || current ? cs.foreground : cs.mutedForeground,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
