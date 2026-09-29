import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_tappable.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
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
    required this.children,
  });

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
        rows.add(BkGroupedDivider(indent: hasTile ? inset + BkIconTile.size + BkGroupedRow.gap : inset));
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
                Expanded(
                  child: header == null
                      ? const SizedBox.shrink()
                      : Semantics(
                          header: true,
                          child: Text(
                            header!.toUpperCase(),
                            style: context.typography.caption.copyWith(
                              color: cs.mutedForeground,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                ),
                ?headerTrailing,
              ],
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: cs.card,
            borderRadius: BorderRadius.circular(BkComponentThemes.cardRadius),
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
/// value) with keyboard focus and a hover wash.
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
  });

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

  static const double minHeight = 48;

  /// Space between the leading tile and the text.
  static const double gap = 12;

  @override
  State<BkGroupedRow> createState() => _BkGroupedRowState();
}

class _BkGroupedRowState extends State<BkGroupedRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final typography = context.typography;
    final leading = widget.leading ?? (widget.icon != null ? BkIconTile(icon: widget.icon!) : null);
    final trailing = widget.trailing;

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
                  Text(
                    widget.title,
                    style: typography.small.copyWith(
                      fontWeight: FontWeight.w500,
                      color: widget.titleColor ?? cs.foreground,
                    ),
                  ),
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

    return BkTappable(
      onPressed: widget.onPressed,
      onHover: (hovered) => setState(() => _hovered = hovered),
      child: ColoredBox(
        color: _hovered ? bkCardHover(context) : const Color(0x00000000),
        child: content,
      ),
    );
  }
}

/// A small rounded tile holding a row's icon.
class BkIconTile extends StatelessWidget {
  const BkIconTile({super.key, required this.icon, this.color, this.background});

  final IconData icon;

  /// Icon colour; defaults to the foreground.
  final Color? color;

  /// Tile fill; defaults to the muted fill.
  final Color? background;

  static const double size = 30;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background ?? cs.muted,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color ?? cs.foreground),
        ),
      ),
    );
  }
}
