import 'package:bike_control/pages/home/chain_state.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/home/ampel.dart';
import 'package:bike_control/widgets/home/chain_labels.dart';
import 'package:bike_control/widgets/ui/bk_touch_target.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

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
  });

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

  @override
  Widget build(BuildContext context) {
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
}
