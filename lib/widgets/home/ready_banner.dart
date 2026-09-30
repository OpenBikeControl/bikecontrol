import 'package:bike_control/pages/home/chain_state.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/home/ampel.dart';
import 'package:bike_control/widgets/home/chain_labels.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:bike_control/widgets/ui/bk_touch_target.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// One outstanding setup step as the banner lists it: the step, the card it
/// belongs to, and that card's fix — the same action and label as the step's
/// button on the Devices row. [onFix] is null for a step that waits on an
/// earlier one of the same card: its fix is that step's.
class ReadyBannerStep {
  const ReadyBannerStep({required this.linkId, required this.step, this.linkTitle, this.actionLabel, this.onFix});

  final String linkId;

  /// The card's name — the device or the trainer app — over the step, so
  /// "Unlock it with Zwift" says which "it".
  final String? linkTitle;
  final SetupStep step;

  /// The fix's label; null reads "Show me how", as on the Devices row.
  final String? actionLabel;
  final VoidCallback? onFix;
}

/// The one-glance answer at the top of the home screen: am I good?
///
/// Everything it says is derived from the cards below it (see [deriveBanner]),
/// so it can never contradict them. When everything is healthy it is a calm,
/// near-invisible row — a small green tick and nothing else. Only trouble gets
/// a coloured wash, so colour on this screen always means "look here".
class ReadyBanner extends StatelessWidget {
  const ReadyBanner({
    super.key,
    required this.banner,
    required this.brokenLinkName,
    this.appName,
    this.onAction,
    this.onRevealOutstanding,
    this.steps = const [],
  });

  /// How many steps the banner lists before "+N more".
  static const int maxSteps = 4;

  final ChainBanner banner;

  /// The display name of the link that broke — a device name reads better than
  /// a category ("Zwift Click V2 lost connection", not "Controller lost
  /// connection").
  final String? brokenLinkName;

  final String? appName;

  /// Opens the fix for [ChainBanner.targetLinkId].
  final VoidCallback? onAction;

  /// Takes the rider to every card in [ChainBanner.outstandingLinkIds]. The
  /// button runs this instead of [onAction] whenever
  /// [ChainBanner.revealsOutstandingCards].
  final VoidCallback? onRevealOutstanding;

  /// The outstanding steps, in card order. While setup is incomplete the
  /// banner lists them — up to [maxSteps], then "+N more", which runs
  /// [onRevealOutstanding] — instead of a count and a Show button.
  final List<ReadyBannerStep> steps;

  @override
  Widget build(BuildContext context) {
    if (banner.kind == ChainBannerKind.pending && steps.isNotEmpty) return _stepList(context);
    final theme = Theme.of(context);
    final style = AmpelStyle.of(context, banner.status);
    final calm = banner.kind == ChainBannerKind.ready;
    final l = context.i18n;

    final String title;
    final String subtitle;
    switch (banner.kind) {
      case ChainBannerKind.ready:
        title = l.chainReadyTitle;
        final app = appName;
        subtitle = app == null ? l.chainReadySubtitleNoApp : l.chainReadySubtitle(app);
      case ChainBannerKind.broken:
        title = l.chainBrokenTitle(brokenLinkName ?? l.chainControllerTitle);
        subtitle = l.chainBrokenSubtitle;
      case ChainBannerKind.pending:
        title = l.chainStepsLeftTitle(banner.stepsLeft);
        final names = banner.outstandingKeys.map((k) => chainLinkName(context, k)).toList();
        // With the trainer already picked up and only the controller tile
        // left, "finish the Trainer app card" points back at a screen the
        // rider has already been on. Name the missing pairing instead.
        subtitle = banner.soleStep?.variant == SetupStepVariant.controllerLinkMissing
            ? l.chainPendingSubtitleController(appName ?? l.chainAppTitle)
            // The app worked earlier in this session and went away — most
            // often it was closed. Say that, and where it comes back from,
            // rather than "finish the card" about a card that was finished.
            // (An app still holding the trainer is never flagged: it is
            // plainly open, and the line above is its answer.)
            : banner.appDropped
            ? l.chainPendingSubtitleAppDropped(appName ?? l.chainAppTitle)
            : names.length == 1
            ? l.chainPendingSubtitleSingle(names.single)
            // "A, B and C" — the last name joined with "and", the rest with commas.
            : l.chainPendingSubtitleMultiple('${names.take(names.length - 1).join(', ')} & ${names.last}');
    }

    // With several cards unfinished the button shows the rider those cards
    // rather than opening whichever one comes first. Still "Show": only an
    // unfinished setup reveals, and a break keeps its "Fix".
    final action = banner.revealsOutstandingCards ? onRevealOutstanding : onAction;

    // The banner changes colour between calm and alarmed, so it animates
    // rather than snapping — the rider sees the screen resolve. Calm is a
    // plain card with a green tick; only trouble gets a wash and an outline,
    // so colour on this screen always means "look here".
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(bottom: 12),
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: ShapeDecoration(
        color: calm ? theme.colorScheme.card : style.wash,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: calm ? BorderSide.none : BorderSide(color: style.color, width: 1.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: style.text, shape: BoxShape.circle),
            child: Icon(calm ? LucideIcons.check : style.icon, size: 18, color: style.onText),
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: context.typography.base.copyWith(
                    fontWeight: FontWeight.w600,
                    color: calm ? theme.colorScheme.foreground : style.text,
                  ),
                ),
                const Gap(2),
                Text(
                  subtitle,
                  style: context.typography.small.copyWith(height: 1.3, color: theme.colorScheme.mutedForeground),
                ),
              ],
            ),
          ),
          if (banner.hasAction && action != null) ...[
            const Gap(8),
            BkTouchTarget(
              child: PrimaryButton(
                alignment: Alignment.center,
                size: ButtonSize.small,
                onPressed: action,
                child: Text(banner.kind == ChainBannerKind.broken ? l.chainBannerFix : l.chainBannerShow),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Setup incomplete: the count, then each outstanding step with its fix.
  Widget _stepList(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final style = AmpelStyle.of(context, banner.status);
    final l = context.i18n;
    final shown = steps.take(maxSteps).toList();
    final more = steps.length - shown.length;

    // Two cases say more than their step's own line: an app that went away
    // after working, and an app missing only its controller tile.
    final String? subtitle = banner.soleStep?.variant == SetupStepVariant.controllerLinkMissing
        ? l.chainPendingSubtitleController(appName ?? l.chainAppTitle)
        : banner.appDropped
        ? l.chainPendingSubtitleAppDropped(appName ?? l.chainAppTitle)
        : null;

    return Container(
      key: const ValueKey('ready-banner-steps'),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: cs.card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: style.text, shape: BoxShape.circle),
                  child: Icon(style.icon, size: 18, color: style.onText),
                ),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          l.chainStepsLeftTitle(banner.stepsLeft),
                          style: context.typography.base.copyWith(fontWeight: FontWeight.w600, color: cs.foreground),
                        ),
                      ),
                      if (subtitle != null) ...[
                        const Gap(2),
                        Text(
                          subtitle,
                          style: context.typography.small.copyWith(height: 1.3, color: cs.mutedForeground),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          for (final (index, step) in shown.indexed) ...[
            if (index > 0) const BkGroupedDivider(indent: _stepTextInset),
            _StepLine(step: step, appName: appName, tone: style.text),
          ],
          if (more > 0) ...[
            const BkGroupedDivider(indent: _stepTextInset),
            Padding(
              padding: const EdgeInsets.fromLTRB(_stepTextInset - 12, 2, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: BkTouchTarget(
                  child: Button.ghost(
                    alignment: Alignment.center,
                    style: const ButtonStyle.ghost(size: ButtonSize.small),
                    onPressed: onRevealOutstanding,
                    trailing: Icon(LucideIcons.chevronRight, size: 14, color: bkAccentText(context)),
                    child: Text(
                      l.readyBannerMoreSteps(more),
                      style: context.typography.small.copyWith(
                        fontWeight: FontWeight.w600,
                        color: bkAccentText(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          const Gap(6),
        ],
      ),
    );
  }
}

/// Where a step's words start: the card inset, the header icon and its gap —
/// so the steps line up under the count.
const double _stepTextInset = 16 + 32 + 12;

/// One outstanding step: a hollow ring in the banner's tone, the step and its
/// reason, and its fix at the end.
class _StepLine extends StatelessWidget {
  const _StepLine({required this.step, required this.appName, required this.tone});

  final ReadyBannerStep step;
  final String? appName;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = chainStepText(context, step.step, appName: appName);
    final hint = text.hint;
    final fix = step.onFix;
    return Padding(
      key: ValueKey('ready-step-${step.linkId}-${step.step.id.name}'),
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Under the header icon's centre.
          SizedBox(
            width: 32,
            child: Center(
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // The step to do now in the banner's tone; one that waits on
                  // it, quieter.
                  border: Border.all(color: fix != null ? tone : cs.mutedForeground, width: 2),
                ),
              ),
            ),
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: 2,
              children: [
                if (step.linkTitle case final title? when title.isNotEmpty)
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.xSmall.copyWith(color: cs.mutedForeground, fontWeight: FontWeight.w500),
                  ),
                Text(
                  text.label,
                  style: context.typography.small.copyWith(fontWeight: FontWeight.w600, color: cs.foreground),
                ),
                if (hint != null && hint.isNotEmpty)
                  Text(
                    hint,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.xSmall.copyWith(height: 1.35, color: cs.mutedForeground),
                  ),
              ],
            ),
          ),
          if (fix != null) ...[
            const Gap(8),
            BkTouchTarget(
              child: PrimaryButton(
                alignment: Alignment.center,
                size: ButtonSize.small,
                onPressed: fix,
                child: Text(step.actionLabel ?? context.i18n.chainShowMeHow),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
