import 'package:bike_control/pages/home/chain_state.dart';
import 'package:bike_control/widgets/home/ampel.dart';
import 'package:bike_control/widgets/home/chain_card.dart'
    show StepRow, chainCardFooterKey, chainCardHighlightKey, chainCardSubtitleKey;
import 'package:bike_control/widgets/home/chain_highlight.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:bike_control/widgets/ui/bk_status_dot.dart';
import 'package:bike_control/widgets/ui/bk_tappable.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The status tone a link's state reads in.
BkStatusTone chainStatusTone(LinkStatus status) => switch (status) {
  LinkStatus.ready => BkStatusTone.success,
  LinkStatus.attention => BkStatusTone.warning,
  LinkStatus.problem => BkStatusTone.danger,
  LinkStatus.off => BkStatusTone.neutral,
};

/// Where a link row's text starts: the row inset, the icon tile and the gap.
const double chainRowTextInset = BkGroupedSection.inset + BkIconTile.size + BkGroupedRow.gap;

/// One link of the setup chain as a row of a Devices group: the device's tile,
/// its name and a detail line, and its status as a dot and words at the end.
///
/// Whatever the link still needs sits under the row, indented to the text:
/// the outstanding steps with the next one's fix ("Set up", "Enable overlay"),
/// then any live readout ([body]) and an offer along the bottom ([footer]).
/// Nothing a rider could reach from the old chain card is lost — only its
/// frame.
class ChainLinkRow extends StatefulWidget {
  const ChainLinkRow({
    super.key,
    required this.link,
    required this.leading,
    required this.title,
    this.statusLabel,
    this.subtitle,
    this.statusDetail,
    this.statusBadges = const [],
    this.appName,
    this.onTap,
    this.onInstructions,
    this.instructionsLabel,
    this.onSecondaryAction,
    this.secondaryActionLabel,
    this.onOffer,
    this.offerLabel,
    this.body,
    this.footer,
    this.highlight,
    this.titleColor,
  });

  final ChainLink link;

  /// The icon tile (or the trainer app's logo).
  final Widget leading;

  final String title;

  /// Quiet line under the title: firmware and signal, the transport.
  final String? subtitle;

  /// Null for an invitation row that has no state to report yet.
  final String? statusLabel;

  /// A second line under the status: battery, "to MyWhoosh", the broadcast's
  /// wire.
  final Widget? statusDetail;

  /// Warning glyphs beside [statusDetail] — a battery about to die, a
  /// firmware update, a weak signal.
  final List<Widget> statusBadges;

  /// Fills "{app}" in the steps' wording.
  final String? appName;

  /// Opens this link's own page.
  final VoidCallback? onTap;

  /// The active step's fix — see [StepRow].
  final VoidCallback? onInstructions;
  final String? instructionsLabel;
  final VoidCallback? onSecondaryAction;
  final String? secondaryActionLabel;

  /// An optional step's action while it is not the step in front — see
  /// [StepRow.onOffer]. [offerLabel] names it, or returns null for a step
  /// with nothing to offer.
  final ValueChanged<SetupStep>? onOffer;
  final String? Function(SetupStep step)? offerLabel;

  /// Live content under the row: the trainer's numbers, the sensor chips.
  final Widget? body;

  /// An offer along the row's bottom edge ("Share sensors instead").
  final Widget? footer;

  /// Makes the row jump out once every time its value changes — see
  /// [ChainHighlightController].
  final ValueListenable<int>? highlight;

  final Color? titleColor;

  @override
  State<ChainLinkRow> createState() => _ChainLinkRowState();
}

class _ChainLinkRowState extends State<ChainLinkRow> with SingleTickerProviderStateMixin {
  late final AnimationController _highlight = AnimationController(
    vsync: this,
    duration: chainHighlightDuration,
    // Reduced motion keeps the row still; the flash itself must still last.
    animationBehavior: AnimationBehavior.preserve,
  );

  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    widget.highlight?.addListener(_play);
  }

  @override
  void didUpdateWidget(covariant ChainLinkRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.highlight != widget.highlight) {
      oldWidget.highlight?.removeListener(_play);
      widget.highlight?.addListener(_play);
    }
  }

  @override
  void dispose() {
    widget.highlight?.removeListener(_play);
    _highlight.dispose();
    super.dispose();
  }

  void _play() => _highlight.forward(from: 0);

  @override
  Widget build(BuildContext context) {
    final link = widget.link;
    final pending = link.pendingSteps;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _header(context),
        if (widget.body case final body?) ...[
          const BkGroupedDivider(indent: chainRowTextInset),
          Padding(
            padding: const EdgeInsets.fromLTRB(chainRowTextInset, 10, BkGroupedSection.inset, 12),
            child: body,
          ),
        ],
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: pending.isEmpty
              ? const SizedBox(width: double.infinity)
              : Padding(
                  // The step's own tick sits where the row's text starts.
                  padding: const EdgeInsets.fromLTRB(chainRowTextInset - 10, 0, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (index, step) in pending.indexed)
                        StepRow(
                          step: step,
                          active: index == 0,
                          appName: widget.appName,
                          onInstructions: index == 0 ? widget.onInstructions : null,
                          instructionsLabel: widget.instructionsLabel,
                          onSecondaryAction: index == 0 ? widget.onSecondaryAction : null,
                          secondaryActionLabel: widget.secondaryActionLabel,
                          onOffer: widget.onOffer == null ? null : () => widget.onOffer!(step),
                          offerLabel: widget.offerLabel?.call(step),
                        ),
                    ],
                  ),
                ),
        ),
        if (widget.footer case final footer?)
          Column(
            key: chainCardFooterKey,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const BkGroupedDivider(indent: chainRowTextInset),
              footer,
            ],
          ),
      ],
    );
    return _highlighted(context, content);
  }

  Widget _header(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final typography = context.typography;
    // A controller the rider is riding without reads quiet, not amber: it is
    // not something to fix right now — see [ChainLink.standby].
    final tone = widget.link.standby ? BkStatusTone.neutral : chainStatusTone(widget.link.status);
    final detail = widget.statusDetail;
    final badges = widget.statusBadges;

    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: BkGroupedSection.inset, vertical: 10),
        child: Row(
          children: [
            widget.leading,
            const Gap(BkGroupedRow.gap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                spacing: 2,
                children: [
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typography.base.copyWith(
                      fontWeight: FontWeight.w600,
                      color: widget.titleColor ?? cs.foreground,
                    ),
                  ),
                  if (widget.subtitle case final subtitle? when subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      key: chainCardSubtitleKey,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: typography.xSmall.copyWith(color: cs.mutedForeground),
                    ),
                ],
              ),
            ),
            if (widget.statusLabel != null || detail != null || badges.isNotEmpty) ...[
              const Gap(8),
              ConstrainedBox(
                // A long status ("Waiting for MyWhoosh to pick it up") wraps
                // rather than squeezing the name to nothing.
                constraints: const BoxConstraints(maxWidth: 170),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 3,
                  children: [
                    if (widget.statusLabel case final label?) BkStatusDot(label: label, tone: tone),
                    if (detail != null || badges.isNotEmpty)
                      DefaultTextStyle.merge(
                        style: typography.xSmall.copyWith(color: cs.mutedForeground),
                        textAlign: TextAlign.end,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 4,
                          children: [
                            ...badges,
                            if (detail != null) Flexible(child: detail),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (widget.onTap == null) return row;
    return BkTappable(
      onPressed: widget.onTap,
      onHover: (hovered) => setState(() => _hovered = hovered),
      child: ColoredBox(
        color: _hovered ? bkCardHover(context) : const Color(0x00000000),
        child: row,
      ),
    );
  }

  /// The highlight: an accent outline and wash over the row that fade out.
  /// Rows sit inside a clipped group, so unlike the old card this one keeps
  /// still — the flash alone says "this one", with or without motion.
  Widget _highlighted(BuildContext context, Widget content) {
    final accent = AmpelStyle.of(
      context,
      widget.link.status == LinkStatus.problem ? LinkStatus.problem : LinkStatus.attention,
    ).color;
    return AnimatedBuilder(
      animation: _highlight,
      child: content,
      builder: (context, content) {
        final opacity = chainHighlightBorderOpacity(_highlight.value);
        // Always a stack, so the row's live content is never rebuilt from
        // scratch when a flash starts or ends.
        return Stack(
          fit: StackFit.passthrough,
          children: [
            content!,
            if (_highlight.isAnimating)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    key: chainCardHighlightKey(widget.link.id),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10 * opacity),
                      border: Border.all(color: accent.withValues(alpha: opacity), width: 2),
                      borderRadius: BorderRadius.circular(BkGroupedSection.inset),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// An action row inside a Devices group: an accent "+" tile and an accent
/// title — "Connect Controllers", "Connect a smart trainer".
class DeviceAddRow extends StatelessWidget {
  const DeviceAddRow({super.key, required this.title, this.subtitle, required this.onPressed, this.icon});

  final String title;
  final String? subtitle;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final accent = bkAccentText(context);
    return BkGroupedRow(
      leading: BkIconTile(icon: icon ?? LucideIcons.plus, color: accent),
      title: title,
      subtitle: subtitle,
      titleColor: accent,
      onPressed: onPressed,
    );
  }
}
