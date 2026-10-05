import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_tappable.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// A grouped list: an optional small upper-case header, then one card of
/// rows separated by inset hairlines, then an optional footnote. The
/// settings-app pattern the Devices, Settings and Activity screens are built
/// from.
///
/// Children are usually [BkGroupedRow]s; anything else is placed as-is.
class BkGroupedSection extends StatelessWidget {
  const BkGroupedSection({
    super.key,
    this.header,
    this.headerTrailing,
    this.footer,
    this.dividerIndent,
    required this.children,
  });

  /// Where the hairlines between rows start, when the rows are not
  /// [BkGroupedRow]s the section can measure (e.g. device rows).
  final double? dividerIndent;

  /// Shown upper-cased above the card and announced as a heading.
  final String? header;

  /// Sits at the end of the header line, e.g. a "Clear" ghost button.
  final Widget? headerTrailing;

  /// Secondary note under the card.
  final String? footer;

  final List<Widget> children;

  /// Horizontal inset of rows, header and footer.
  static const double inset = 16;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      final child = children[i];
      rows.add(child);
      if (i < children.length - 1) {
        final hasTile = child is BkGroupedRow && (child.icon != null || child.leading != null);
        rows.add(
          BkGroupedDivider(indent: dividerIndent ?? (hasTile ? inset + BkIconTile.size + BkGroupedRow.gap : inset)),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (header != null || headerTrailing != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(inset, 0, inset, 6),
            child: Row(
              children: [
                Expanded(child: header == null ? const SizedBox.shrink() : BkGroupedHeader(header!)),
                ?headerTrailing,
              ],
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: cs.card,
            borderRadius: BorderRadius.circular(BkComponentThemes.cardRadius),
            boxShadow: bkCardShadow(context),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(BkComponentThemes.cardRadius),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: rows,
            ),
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(inset, 6, inset, 0),
            child: Text(footer!, style: context.typography.caption.copyWith(color: cs.mutedForeground)),
          ),
      ],
    );
  }
}

/// A group's small upper-case header, announced as a heading. For a group
/// whose content is not one card of rows (e.g. connection method cards).
class BkGroupedHeader extends StatelessWidget {
  const BkGroupedHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        style: context.typography.caption.copyWith(
          color: Theme.of(context).colorScheme.mutedForeground,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// The hairline between two rows of a [BkGroupedSection], inset to where the
/// row's text starts.
class BkGroupedDivider extends StatelessWidget {
  const BkGroupedDivider({super.key, this.indent = BkGroupedSection.inset});

  final double indent;

  @override
  Widget build(BuildContext context) {
    final thickness = 1 / MediaQuery.devicePixelRatioOf(context);
    return Padding(
      padding: EdgeInsetsDirectional.only(start: indent),
      child: SizedBox(
        height: thickness < 0.5 ? 0.5 : thickness,
        child: ColoredBox(color: Theme.of(context).colorScheme.border),
      ),
    );
  }
}

/// One row of a [BkGroupedSection]: optional icon tile, title and subtitle,
/// then a trailing value/control and an optional chevron. At least 48 dp
/// tall. With [onPressed] the whole row is one button (read as its title and
/// value) with keyboard focus, the click cursor and hover / pressed washes.
class BkGroupedRow extends StatefulWidget {
  const BkGroupedRow({
    super.key,
    this.icon,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.chevron = false,
    this.onPressed,
    this.titleColor,
    this.badge,
    this.quietIcon = false,
  });

  /// Draws the icon tile grey instead of in the brand wash: for housekeeping
  /// rows (help, logs, app info) that should not compete with the rest.
  final bool quietIcon;

  /// Drawn in a [BkIconTile]. Ignored when [leading] is given.
  final IconData? icon;

  /// A custom leading widget in place of the icon tile.
  final Widget? leading;

  final String title;
  final String? subtitle;

  /// A value (Text, drawn secondary), a status, or a control. A bare
  /// [Switch]/[Checkbox] is labelled with [title] for screen readers.
  final Widget? trailing;

  /// Adds a trailing chevron: the row opens something.
  final bool chevron;

  final VoidCallback? onPressed;

  /// Overrides the title colour (e.g. accent for an action row).
  final Color? titleColor;

  /// Sits right after the title, e.g. the PRO badge.
  final Widget? badge;

  static const double minHeight = 48;

  /// Space between the leading tile and the text.
  static const double gap = 12;

  @override
  State<BkGroupedRow> createState() => _BkGroupedRowState();
}

class _BkGroupedRowState extends State<BkGroupedRow> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final typography = context.typography;
    final leading =
        widget.leading ??
        (widget.icon != null
            ? BkIconTile(icon: widget.icon!, color: widget.quietIcon ? cs.mutedForeground : null)
            : null);
    final trailing = widget.trailing;
    final title = Text(
      widget.title,
      style: typography.small.copyWith(
        fontWeight: FontWeight.w500,
        color: widget.titleColor ?? cs.foreground,
      ),
    );

    Widget content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: BkGroupedRow.minHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: BkGroupedSection.inset, vertical: 10),
        child: Row(
          children: [
            if (leading != null) ...[leading, const Gap(BkGroupedRow.gap)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                spacing: 2,
                children: [
                  if (widget.badge case final badge?)
                    Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [title, badge],
                    )
                  else
                    title,
                  if (widget.subtitle != null)
                    Text(widget.subtitle!, style: typography.xSmall.copyWith(color: cs.mutedForeground)),
                ],
              ),
            ),
            if (trailing != null) ...[
              const Gap(8),
              DefaultTextStyle.merge(
                style: typography.small.copyWith(color: cs.mutedForeground),
                // shadcn's Switch/Checkbox report neither a name nor their
                // state; the row's title names them and the value is added.
                child: switch (trailing) {
                  Switch(:final value) => Semantics(
                    container: true,
                    label: widget.title,
                    toggled: value,
                    child: trailing,
                  ),
                  Checkbox(:final state) => Semantics(
                    container: true,
                    label: widget.title,
                    checked: state == CheckboxState.checked,
                    child: trailing,
                  ),
                  _ => trailing,
                },
              ),
            ],
            if (widget.chevron) ...[
              const Gap(4),
              Icon(LucideIcons.chevronRight, size: 16, color: cs.mutedForeground),
            ],
          ],
        ),
      ),
    );

    if (widget.onPressed == null) return content;

    return BkTappable(onPressed: widget.onPressed, wash: true, child: content);
  }
}

/// A small rounded tile holding a row's icon: the brand's blue wash with a
/// blue glyph. A tile given its own [color] (a status, a quiet grey) keeps
/// the neutral fill, so state colours never sit on the brand wash.
class BkIconTile extends StatelessWidget {
  const BkIconTile({super.key, required this.icon, this.color, this.background});

  final IconData icon;

  /// Icon colour; defaults to the brand's tile ink.
  final Color? color;

  /// Tile fill; defaults to the brand's tile wash, or the muted fill when
  /// [color] is something other than the tile ink.
  final Color? background;

  static const double size = 30;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final brand = BkBrandColors.of(context);
    final ink = color ?? brand.tileInk;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background ?? (ink == brand.tileInk ? brand.tileWash : cs.muted),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: ink),
        ),
      ),
    );
  }
}
