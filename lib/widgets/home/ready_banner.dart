import 'package:bike_control/pages/home/chain_state.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/home/ampel.dart';
import 'package:bike_control/widgets/home/chain_labels.dart';
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
            : names.length == 1
            ? l.chainPendingSubtitleSingle(names.single)
            // "A, B and C" — the last name joined with "and", the rest with commas.
            : l.chainPendingSubtitleMultiple('${names.take(names.length - 1).join(', ')} & ${names.last}');
    }

    // With several cards unfinished the button shows the rider those cards
    // rather than opening whichever one comes first. Still "Show": only an
    // unfinished setup reveals, and a break keeps its "Fix".
    final action = banner.revealsOutstandingCards ? onRevealOutstanding : onAction;

    // The banner changes shape as well as colour between calm and alarmed, so
    // it animates rather than snapping — the rider sees the screen resolve.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.symmetric(horizontal: calm ? 13 : 14, vertical: calm ? 11 : 13),
      decoration: ShapeDecoration(
        color: calm ? theme.colorScheme.card : style.wash,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: calm ? theme.colorScheme.border : style.color, width: 1.5),
        ),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            width: calm ? 24 : 34,
            height: calm ? 24 : 34,
            decoration: BoxDecoration(color: style.color, shape: BoxShape.circle),
            child: Icon(calm ? LucideIcons.check : style.icon, size: calm ? 14 : 19, color: Colors.white),
          ),
          const Gap(11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: calm ? 14 : 15,
                    fontWeight: FontWeight.w700,
                    color: calm ? theme.colorScheme.foreground : style.color,
                  ),
                ),
                const Gap(2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12.5, height: 1.4, color: theme.colorScheme.mutedForeground),
                ),
              ],
            ),
          ),
          if (banner.hasAction && action != null) ...[
            const Gap(8),
            PrimaryButton(
              size: ButtonSize.small,
              onPressed: action,
              child: Text(banner.kind == ChainBannerKind.broken ? l.chainBannerFix : l.chainBannerShow),
            ),
          ],
        ],
      ),
    );
  }
}
