import 'package:bike_control/pages/home/chain_state.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/home/ampel.dart';
import 'package:bike_control/widgets/home/chain_labels.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// One link of the setup chain.
///
/// Every card in the chain has the same three parts, so the rider learns the
/// shape once: an Ampel that says how this link is doing, an `Edit` in the same
/// place on every card, and a tick-off checklist whose next action carries its
/// own instructions. Instructions sit next to the thing they are about — the
/// rider never leaves the card to find out what is missing.
class ChainCard extends StatefulWidget {
  const ChainCard({
    super.key,
    required this.link,
    required this.tile,
    required this.title,
    required this.statusLabel,
    this.statusBadges = const [],
    this.appName,
    this.editLabel,
    this.onEdit,
    this.onInstructions,
    this.instructionsLabel,
    this.body,
    this.onTap,
  });

  final ChainLink link;

  /// The card's visual identity — a device icon or the trainer app's logo.
  final Widget tile;

  final String title;
  final String statusLabel;

  /// Inline warning glyphs beside the status — see [StatusLine.badges].
  final List<Widget> statusBadges;

  /// Used to fill "{app} is connected" style step wording.
  final String? appName;

  final String? editLabel;
  final VoidCallback? onEdit;

  /// Opens the guide for the active step. Only the active step offers it, so
  /// there is exactly one next action visible per card.
  final VoidCallback? onInstructions;
  final String? instructionsLabel;

  /// Extra content between the header and the checklist — the controller
  /// contour, for instance.
  final Widget? body;

  /// Opens this link's own page. The whole card carries it, not just [onEdit]:
  /// a card that is entirely about one device should behave like the row it
  /// looks like. Buttons inside the card still win the tap they sit under.
  final VoidCallback? onTap;

  @override
  State<ChainCard> createState() => _ChainCardState();
}

/// Long enough to read as a movement, short enough not to hold the rider up.
const Duration _statusChangeDuration = Duration(milliseconds: 260);

/// One left edge for every step in a card's checklist, so the column reads as a
/// column however many steps are outstanding.
const double _rowInset = 14;

/// The tick circle, so a test can assert the steps share a left edge.
const Key stepTickKey = ValueKey('chain-step-tick');

const double _leadingSize = 17;
const double _leadingGap = 10;

/// Whether this card is an optional slot nobody has filled — the state the
/// faded border and the OPTIONAL tag both describe.
///
/// [ChainLink.optional] stays true for the whole life of a trainer card, because
/// that is what keeps a trainer nobody owns from blocking "Ready to ride". But
/// once a smart trainer is actually connected the card is doing a job, and
/// labelling working hardware OPTIONAL is noise — the word is there to reassure
/// a rider looking at an empty slot, not to caption a live one.
bool _atRest(ChainLink link) => link.optional && link.status == LinkStatus.off;

class _ChainCardState extends State<ChainCard> {
  @override
  Widget build(BuildContext context) {
    final link = widget.link;
    final theme = Theme.of(context);
    final dimmed = _atRest(link);
    final border = BorderSide(
      color: dimmed ? theme.colorScheme.mutedForeground.withAlpha(90) : theme.colorScheme.border,
      width: 1.5,
    );

    return AnimatedContainer(
      duration: _statusChangeDuration,
      curve: Curves.easeOut,
      decoration: ShapeDecoration(
        color: theme.colorScheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          // A dashed border isn't available here, so an optional card at rest is
          // marked by a faded border plus the OPTIONAL tag instead.
          side: border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: _tappable(context, _content(context)),
    );
  }

  /// Wraps the card in its own tap target when there is somewhere to go.
  ///
  /// A ghost button rather than a bare GestureDetector, so the card picks up
  /// the pointer cursor and hover wash every other tappable surface here has.
  Widget _tappable(BuildContext context, Widget content) {
    if (widget.onTap == null) return content;
    return SizedBox(
      width: double.infinity,
      child: Button.ghost(
        style: ButtonStyle.ghost()
            .withPadding(padding: EdgeInsets.zero)
            .withBackgroundColor(hoverColor: bkCardHover(context)),
        onPressed: widget.onTap,
        child: content,
      ),
    );
  }

  Widget _content(BuildContext context) {
    final link = widget.link;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context),
        if (widget.body != null) Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), child: widget.body!),
        // The checklist grows and shrinks rather than blinking in and out: when
        // the last step of a card finally ticks, the card shrinks to its
        // header as a movement the eye can follow, which is what makes
        // "that's done now" legible instead of just sudden.
        AnimatedSize(
          duration: _statusChangeDuration,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: link.pendingSteps.isEmpty ? const SizedBox(width: double.infinity) : _checklist(context),
        ),
      ],
    );
  }

  Widget _header(BuildContext context) {
    final link = widget.link;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 13, 6, 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          TileWithAmpel(status: link.status, child: widget.tile),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (_atRest(link)) ...[
                      const Gap(7),
                      const OptionalTag(),
                    ],
                  ],
                ),
                StatusLine(
                  status: link.status,
                  label: widget.statusLabel,
                  meta: link.subtitleArg,
                  badges: widget.statusBadges,
                ),
              ],
            ),
          ),
          if (widget.onEdit != null)
            Button.ghost(
              onPressed: widget.onEdit,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.editLabel ?? context.i18n.chainEdit,
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
                  ),
                  Icon(LucideIcons.chevronRight, size: 15, color: theme.colorScheme.primary),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// What is left to do, and only that. A ticked step has already told the
  /// rider everything it can; keeping it on screen buries the one line that
  /// still matters under a list of things that don't.
  Widget _checklist(BuildContext context) {
    final theme = Theme.of(context);
    final pending = widget.link.pendingSteps;

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.colorScheme.border, width: 0.5)),
      ),
      // Steps carry their own inset (see StepRow) so the active step's
      // highlight can bleed slightly wider than the text column — but only
      // slightly: at 4 the highlight almost touched the card edge, which read
      // as a panel the card had failed to contain rather than a row inside it.
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, step) in pending.indexed)
            StepRow(
              // The first outstanding step is the next thing to do, and the
              // only one that offers instructions.
              step: step,
              active: index == 0,
              appName: widget.appName,
              onInstructions: index == 0 ? widget.onInstructions : null,
              instructionsLabel: widget.instructionsLabel,
            ),
        ],
      ),
    );
  }
}

/// The "OPTIONAL" tag, worn by a whole card (a trainer nobody has to own) and
/// by a single step (the gear overlay). Same words, same weight, so a rider
/// reads the two the same way.
class OptionalTag extends StatelessWidget {
  const OptionalTag({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.muted,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        context.i18n.chainOptional.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: theme.colorScheme.mutedForeground,
        ),
      ),
    );
  }
}

/// A single checklist line. The first unfinished step is the "active" one and
/// is the only place an instructions button appears — so there is exactly one
/// next action on the card.
class StepRow extends StatelessWidget {
  const StepRow({
    super.key,
    required this.step,
    required this.active,
    this.appName,
    this.onInstructions,
    this.instructionsLabel,
  });

  final SetupStep step;
  final bool active;
  final String? appName;
  final VoidCallback? onInstructions;
  final String? instructionsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = chainStepText(context, step, appName: appName);
    final success = AmpelStyle.of(context, LinkStatus.ready).color;
    final tone = step.done
        ? success
        : active
        ? theme.colorScheme.primary
        : theme.colorScheme.mutedForeground.withAlpha(120);
    final hint = text.hint;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 2),
      padding: EdgeInsets.symmetric(horizontal: _rowInset - 4, vertical: active ? 9 : 7),
      decoration: BoxDecoration(
        color: active ? theme.colorScheme.primary.withAlpha(15) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Container(
              key: stepTickKey,
              width: _leadingSize,
              height: _leadingSize,
              decoration: BoxDecoration(
                color: step.done ? success : Colors.transparent,
                shape: BoxShape.circle,
                border: step.done ? null : Border.all(color: tone, width: 2),
              ),
              child: step.done ? const Icon(LucideIcons.check, size: 11, color: Colors.white) : null,
            ),
          ),
          const Gap(_leadingGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Text(
                        text.label,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.35,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                          color: step.done ? theme.colorScheme.mutedForeground : theme.colorScheme.foreground,
                        ),
                      ),
                    ),
                    // An optional step sits in the same list as the required
                    // ones, so it has to say so on the line itself — otherwise
                    // a rider who doesn't want it reads the card as unfinished
                    // forever.
                    if (step.optional) ...[
                      const Gap(7),
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: OptionalTag(),
                      ),
                    ],
                  ],
                ),
                // A hint on a finished step is only worth the space when it says
                // something the label doesn't — the gear summary, for instance.
                if (hint != null && hint.isNotEmpty && (active || !step.done || step.hintArg != null)) ...[
                  const Gap(3),
                  Text(
                    hint,
                    style: TextStyle(fontSize: 12, height: 1.4, color: theme.colorScheme.mutedForeground),
                  ),
                ],
                if (active && onInstructions != null) ...[
                  const Gap(8),
                  PrimaryButton(
                    size: ButtonSize.small,
                    onPressed: onInstructions,
                    leading: const Icon(LucideIcons.bookOpen, size: 13),
                    child: Text(instructionsLabel ?? context.i18n.chainShowMeHow),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
