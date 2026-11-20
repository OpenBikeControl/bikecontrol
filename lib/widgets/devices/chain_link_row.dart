import 'package:bike_control/pages/home/chain_state.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/home/ampel.dart';
import 'package:bike_control/widgets/home/chain_card.dart'
    show chainCardFooterKey, chainCardHighlightKey, chainCardSubtitleKey;
import 'package:bike_control/widgets/home/chain_labels.dart';
import 'package:bike_control/widgets/home/chain_highlight.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:bike_control/widgets/ui/bk_status_dot.dart';
import 'package:bike_control/widgets/ui/bk_tappable.dart';
import 'package:bike_control/widgets/ui/bk_touch_target.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// A text action's padding without its sides, so its words start where the
/// line above starts rather than a button's inset further in — and half its
/// height, so it sits in the checklist's rhythm rather than in a tall box.
EdgeInsets _flushStart(EdgeInsets padding) => EdgeInsets.only(top: padding.top / 2, bottom: padding.bottom / 2);

/// The status tone a link's state reads in.
BkStatusTone chainStatusTone(LinkStatus status) => switch (status) {
  LinkStatus.ready => BkStatusTone.success,
  LinkStatus.attention => BkStatusTone.warning,
  LinkStatus.problem => BkStatusTone.danger,
  LinkStatus.off => BkStatusTone.neutral,
};

/// Where a link row's text starts: the row inset, the icon tile and the gap.
const double chainRowTextInset = BkGroupedSection.inset + BkIconTile.size + BkGroupedRow.gap;

/// The chevron a row with somewhere to go ends its header with.
const Key chainRowChevronKey = ValueKey('chain-row-chevron');

/// The active step's fix, at the end of the row's header.
const Key chainRowStepActionKey = ValueKey('chain-row-step-action');

/// An optional later step's line, when it is a button itself.
Key chainRowOfferKey(SetupStepId id) => ValueKey('chain-row-offer-${id.name}');

/// A later step's line under the row.
Key chainRowLaterStepKey(SetupStepId id) => ValueKey('chain-row-later-step-${id.name}');

/// One link of the setup chain as a row of a Devices group: the device's tile,
/// its name and a detail line, and its status as a dot and words at the end.
///
/// While the link still needs something, the status moves under the name
/// (with the transport after it, quieter); what to do sits under that,
/// indented to the text, with the step's fix ("Show me how") below it and the
/// steps after it as a quiet checklist. Said once, in the row itself —
/// not repeated as the title of a box inside the card. Then any live readout
/// ([body]) and an offer along the bottom ([footer]).
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
    this.action,
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

  /// The row's one direct action, under its name — "Connect" on a trainer
  /// that is nearby but not connected — for a row with no steps to carry it.
  final ({String label, IconData? icon, VoidCallback onPressed})? action;

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

class _ChainLinkRowState extends State<ChainLinkRow> with TickerProviderStateMixin {
  late final AnimationController _highlight = AnimationController(
    vsync: this,
    duration: chainHighlightDuration,
    // Reduced motion keeps the row still; the flash itself must still last.
    animationBehavior: AnimationBehavior.preserve,
  );

  /// 1 while the row has a checklist, 0 once the last step has ticked away.
  ///
  /// Only that change is a movement — the checklist growing in, or the row
  /// shrinking to its header when everything is done. A change inside the
  /// checklist (a step appearing above the next one, a line rewording itself)
  /// lands at once: an AnimatedSize here clipped the new content to the old
  /// height while it caught up, and a step with a long hint showed its button
  /// cut off at the row's bottom edge.
  late final AnimationController _checklist = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: widget.link.pendingSteps.isEmpty ? 0 : 1,
  );

  late final Animation<double> _checklistSize = CurvedAnimation(parent: _checklist, curve: Curves.easeOutCubic);

  /// The steps last shown, so the checklist collapsing away still has its
  /// lines to collapse rather than vanishing first.
  late List<SetupStep> _lastPending = widget.link.pendingSteps;

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
    final hasChecklist = widget.link.pendingSteps.isNotEmpty;
    if (hasChecklist != oldWidget.link.pendingSteps.isNotEmpty) {
      if (hasChecklist) {
        _checklist.forward();
      } else {
        _checklist.reverse();
      }
    }
  }

  @override
  void dispose() {
    widget.highlight?.removeListener(_play);
    _highlight.dispose();
    _checklist.dispose();
    super.dispose();
  }

  void _play() => _highlight.forward(from: 0);

  @override
  Widget build(BuildContext context) {
    final link = widget.link;
    final pending = link.pendingSteps;
    return _highlighted(context, _content(context, link, pending));
  }

  Widget _content(BuildContext context, ChainLink link, List<SetupStep> pending) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _header(context),
        if (widget.action case final action?)
          Padding(
            padding: const EdgeInsets.fromLTRB(chainRowTextInset, 0, BkGroupedSection.inset, 12),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: BkTouchTarget(
                child: PrimaryButton(
                  alignment: Alignment.center,
                  size: ButtonSize.small,
                  onPressed: action.onPressed,
                  leading: action.icon == null ? null : Icon(action.icon, size: 14),
                  child: Text(action.label),
                ),
              ),
            ),
          ),
        // What to do right under the status it explains; the live numbers
        // after it, not wedged between the two.
        _checklistSection(context, link, pending),
        if (widget.body case final body?) ...[
          const BkGroupedDivider(indent: chainRowTextInset),
          Padding(
            padding: const EdgeInsets.fromLTRB(chainRowTextInset, 10, BkGroupedSection.inset, 12),
            child: body,
          ),
        ],
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
  }

  /// The step in front's fix as a quiet outlined button under its hint. Never
  /// beside the name: there it squeezed the status into a narrow column and
  /// gave the card two places for its actions.
  /// Small padding, body-size label: the default size made a box twice the
  /// height of the line it answers.
  Widget _fixButton(BuildContext context, VoidCallback onPressed) => BkTouchTarget(
    child: Button.outline(
      key: chainRowStepActionKey,
      alignment: Alignment.center,
      style: const ButtonStyle.outline(size: ButtonSize.small),
      onPressed: onPressed,
      leading: const Icon(LucideIcons.bookOpen, size: 15),
      child: Text(widget.instructionsLabel ?? context.i18n.chainShowMeHow, style: _buttonText(context)),
    ),
  );

  /// What the link still needs, indented to the row's text — see
  /// [_checklist] for when it moves. The step in front gives its hint (and
  /// its title, when the status says something else); the rest are a quiet
  /// checklist, each optional one with its own offer.
  Widget _checklistSection(BuildContext context, ChainLink link, List<SetupStep> pending) {
    if (pending.isNotEmpty) _lastPending = pending;
    final steps = pending.isNotEmpty ? pending : _lastPending;
    return AnimatedBuilder(
      animation: _checklist,
      builder: (context, child) {
        if (_checklist.isDismissed || steps.isEmpty) return const SizedBox(width: double.infinity);
        // At full size this lays the checklist out at exactly its own height.
        // Start-aligned: a hint narrower than the row (one short line on a
        // wide window) sat centred under the name while this ran.
        return SizeTransition(sizeFactor: _checklistSize, alignment: AlignmentDirectional.topStart, child: child);
      },
      child: steps.isEmpty ? const SizedBox.shrink() : _steps(context, link, steps),
    );
  }

  Widget _steps(BuildContext context, ChainLink link, List<SetupStep> steps) {
    final cs = Theme.of(context).colorScheme;
    final typography = context.typography;
    final first = chainStepText(context, steps.first, appName: widget.appName);
    final hint = first.hint;
    // The status already says it ("Waiting for MyWhoosh"): the step's own
    // title ("Waiting for connection") would only repeat it in other words.
    final showTitle = first.label != _statusLabel(context, steps) && !_statusSaysIt(steps.first);
    // "Asleep – press a button to wake it" is the whole instruction: a hint
    // saying "press a button to wake it" again, and a "Show me how" for
    // pressing a button, only repeated it.
    final statusSaysAll = _statusSaysAll(steps.first);
    final showSecondary = widget.onSecondaryAction != null && widget.secondaryActionLabel != null;
    if (statusSaysAll && steps.length == 1 && !showSecondary) return const SizedBox(width: double.infinity);
    return Padding(
      padding: const EdgeInsets.fromLTRB(chainRowTextInset, 0, BkGroupedSection.inset, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showTitle)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(first.label, style: typography.small.copyWith(fontWeight: FontWeight.w500)),
            ),
          if (!statusSaysAll && hint != null && hint.isNotEmpty)
            Text(hint, style: typography.small.copyWith(height: 1.4, color: cs.mutedForeground)),
          if (!statusSaysAll && widget.onInstructions != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              // Its own width, not the column's.
              child: Row(mainAxisSize: MainAxisSize.min, children: [_fixButton(context, widget.onInstructions!)]),
            ),
          if (showSecondary)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: BkTouchTarget(
                child: Button.ghost(
                  alignment: Alignment.center,
                  style: const ButtonStyle.ghost(size: ButtonSize.small),
                  onPressed: widget.onSecondaryAction,
                  child: Text(widget.secondaryActionLabel!),
                ),
              ),
            ),
          for (final step in steps.skip(1)) _laterStep(context, link, step),
        ],
      ),
    );
  }

  /// A step behind the one in front: its title, quiet — "Optional:" first for
  /// an optional one. An optional step with an offer is itself the button,
  /// and then the line is the offer ("Show your gear on top of MyWhoosh"): a
  /// step title that states a problem ("MyWhoosh still shows its own gear")
  /// says nothing about what tapping it does.
  Widget _laterStep(BuildContext context, ChainLink link, SetupStep step) {
    final cs = Theme.of(context).colorScheme;
    final text = chainStepText(context, step, appName: widget.appName);
    final offer = _offerFor(link, step);
    final actionable = step.optional && offer != null;
    final accent = bkAccentText(context);
    final style = context.typography.small.copyWith(
      color: actionable ? accent : cs.mutedForeground,
      fontWeight: actionable ? FontWeight.w500 : null,
      height: 1.4,
    );
    // No checklist circle: on its own it read as a radio button or a stray
    // dot. An optional step says what it is up front instead.
    final label = Text.rich(
      TextSpan(
        children: [
          if (step.optional)
            TextSpan(
              text: '${context.i18n.chainOptional}: ',
              style: TextStyle(color: cs.mutedForeground, fontWeight: FontWeight.w500),
            ),
          TextSpan(text: actionable ? offer : text.label),
          // After the last word, wherever the line wraps — not out at the
          // row's far edge.
          if (actionable)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(LucideIcons.chevronRight, size: 16, color: accent),
              ),
            ),
        ],
      ),
      style: style,
    );
    return Padding(
      key: chainRowLaterStepKey(step.id),
      padding: EdgeInsets.only(top: actionable ? 10 : 14),
      child: !actionable
          ? label
          : BkTouchTarget(
              child: Button.ghost(
                key: chainRowOfferKey(step.id),
                alignment: Alignment.centerLeft,
                style: const ButtonStyle.ghost(density: ButtonDensity(_flushStart)),
                onPressed: () => widget.onOffer!(step),
                child: label,
              ),
            ),
    );
  }

  /// What tapping [step]'s line does, or null when it has no action.
  String? _offerFor(ChainLink link, SetupStep step) =>
      link.standby || widget.onOffer == null ? null : widget.offerLabel?.call(step);

  /// Whether the status is the step's whole instruction — title, hint and
  /// fix alike: an asleep controller's "press a button to wake it".
  bool _statusSaysAll(SetupStep step) =>
      widget.statusLabel != null &&
      !widget.link.standby &&
      step.id == SetupStepId.controllerInRange &&
      step.variant == SetupStepVariant.controllerAsleep;

  /// The waiting steps' titles only ever restate the status ("Waiting for
  /// MyWhoosh …" over "Waiting for MyWhoosh"); their hint is what's new.
  bool _statusSaysIt(SetupStep step) =>
      widget.statusLabel != null &&
      switch (step.id) {
        // Its "pick up the controller tile" variant has news in its title.
        SetupStepId.appConnected => step.variant == SetupStepVariant.standard,
        SetupStepId.trainerAppBridged => true,
        // "Asleep – press a button to wake it" over "Wake it up" — not on a
        // controller ridden without, whose status says something else.
        SetupStepId.controllerInRange => step.variant == SetupStepVariant.controllerAsleep && !widget.link.standby,
        _ => false,
      };

  TextStyle _buttonText(BuildContext context) => context.typography.small.copyWith(fontWeight: FontWeight.w500);

  /// What the row says about itself while steps are open: the caller's
  /// status, else the step in front.
  String _statusLabel(BuildContext context, List<SetupStep> steps) =>
      widget.statusLabel ?? chainStepText(context, steps.first, appName: widget.appName).label;

  Widget _header(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final typography = context.typography;
    // A controller the rider is riding without reads quiet, not amber: it is
    // not something to fix right now — see [ChainLink.standby].
    final tone = widget.link.standby ? BkStatusTone.neutral : chainStatusTone(widget.link.status);
    final detail = widget.statusDetail;
    final badges = widget.statusBadges;
    // Open steps: the status moves under the name and the step in front's
    // fix takes its place at the end — see [ChainLinkRow].
    final pending = widget.link.pendingSteps;
    final open = pending.isNotEmpty;
    final detailRow = DefaultTextStyle.merge(
      style: typography.xSmall.copyWith(color: cs.mutedForeground),
      textAlign: open ? TextAlign.start : TextAlign.end,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          ...badges,
          if (detail != null) Flexible(child: detail),
        ],
      ),
    );

    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: BkGroupedSection.inset, vertical: 10),
        child: Row(
          children: [
            // A 30 px slot, as the text inset assumes; a larger mark (a
            // controller's silhouette) spills evenly into the space around it.
            SizedBox.square(
              dimension: BkIconTile.size,
              child: OverflowBox(maxWidth: 48, maxHeight: 48, child: widget.leading),
            ),
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
                  if (open)
                    // One line under the name: the state, then — quieter —
                    // how it is connected.
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        BkStatusDot(label: _statusLabel(context, pending), tone: tone),
                        // An optional step says so where its title now stands.
                        if (pending.first.optional && !widget.link.standby)
                          _metaSuffix(context, context.i18n.chainOptional),
                        if (widget.subtitle case final subtitle? when subtitle.isNotEmpty)
                          _metaSuffix(context, subtitle, key: chainCardSubtitleKey),
                      ],
                    )
                  else if (widget.subtitle case final subtitle? when subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      key: chainCardSubtitleKey,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: typography.xSmall.copyWith(color: cs.mutedForeground),
                    ),
                  if (open && (detail != null || badges.isNotEmpty)) detailRow,
                ],
              ),
            ),
            if (!open && (widget.statusLabel != null || detail != null || badges.isNotEmpty)) ...[
              const Gap(8),
              ConstrainedBox(
                // A long status ("Waiting for MyWhoosh to connect to …") wraps
                // rather than squeezing the name to nothing.
                constraints: const BoxConstraints(maxWidth: 170),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 3,
                  children: [
                    if (widget.statusLabel case final label?) BkStatusDot(label: label, tone: tone),
                    if (detail != null || badges.isNotEmpty) detailRow,
                  ],
                ),
              ),
            ],
            // The whole header opens the link's page — the same quiet chevron
            // as every other row that opens something, and Ride's step rows.
            if (widget.onTap != null) ...[
              const Gap(4),
              Icon(LucideIcons.chevronRight, key: chainRowChevronKey, size: 16, color: cs.mutedForeground),
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

  /// " · Network" after the status: the status line's size, muted. Its own
  /// widget, so it drops to the next line whole instead of squeezing the
  /// status.
  Widget _metaSuffix(BuildContext context, String text, {Key? key}) {
    final style = context.typography.xSmall.copyWith(color: Theme.of(context).colorScheme.mutedForeground);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(' · ', style: style),
        Flexible(
          child: Text(text, key: key, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
        ),
      ],
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
