import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/ui/bk_icon_button.dart';
import 'package:bike_control/widgets/ui/bk_page_column.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The header every pushed page shares: one labelled back button, the title
/// in the typography scale's page-title style, and the page's own actions.
///
/// In a wide window the title and actions are inset to the page's centred
/// [BkPageColumn] — [columnWidth] wide plus the page's [columnGutter] (its
/// scroll padding) each side — so title and content share an edge, while the
/// back arrow stays at the window's left edge, where back lives on every
/// desktop app. When the window has no room beside the column (a phone), the
/// arrow sits in front of the title as usual. The divider spans the window.
/// Pass `columnWidth: null` for a page whose content uses the whole window.
///
/// Back goes through `Navigator.maybePop`, so a page's `PopScope` guard (an
/// unsaved-changes prompt, say) still gets its say.
class BkPageHeader extends StatelessWidget {
  const BkPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.onBack,
    this.showBack = true,
    this.showDivider = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    this.columnWidth = BkPageColumn.defaultMaxWidth,
    this.columnGutter = 16,
  });

  /// The width the back arrow needs beside the column before it moves out.
  static const double _backSlot = 48;

  final String title;

  /// Optional line under the title (a status, a sign-in state).
  final Widget? subtitle;

  /// Trailing, page-specific controls.
  final List<Widget> actions;

  /// Overrides the default `Navigator.maybePop`.
  final VoidCallback? onBack;

  final bool showBack;
  final bool showDivider;
  final EdgeInsetsGeometry padding;

  /// The page's [BkPageColumn.maxWidth]; null for a full-width page.
  final double? columnWidth;

  /// The horizontal padding between the window and the page's column (0 when
  /// the column itself sits flush and pads its content inside).
  final double columnGutter;

  /// The one page-title style: the scale's xLarge, semibold, slightly tight.
  static TextStyle titleStyle(BuildContext context) => Theme.of(context).typography.xLarge.copyWith(
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
  );

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).colorScheme.background;
    final back = BkIconButton.ghost(
      key: const ValueKey('page-header-back'),
      icon: const Icon(LucideIcons.arrowLeft, size: 22),
      label: context.i18n.a11yBack,
      onPressed: onBack ?? () => Navigator.of(context).maybePop(),
    );
    Widget appBar({required bool withBack}) => AppBar(
      padding: padding,
      leading: [if (showBack && withBack) back],
      title: Semantics(
        header: true,
        child: Text(title, style: titleStyle(context)),
      ),
      subtitle: subtitle,
      trailing: actions,
      backgroundColor: background,
    );
    Widget bar = appBar(withBack: true);
    if (columnWidth case final width?) {
      final column = width + 2 * columnGutter;
      bar = ColoredBox(
        color: background,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final inset = padding.resolve(Directionality.of(context)).left;
            // Room for the arrow beside the column: back moves out to the edge.
            final aside = showBack && (constraints.maxWidth - column) / 2 >= _backSlot + inset;
            final centred = Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: column),
                child: appBar(withBack: !aside),
              ),
            );
            if (!aside) return centred;
            return Stack(
              children: [
                centred,
                Positioned(
                  left: inset,
                  top: 0,
                  bottom: 0,
                  child: Align(alignment: Alignment.centerLeft, child: back),
                ),
              ],
            );
          },
        ),
      );
    }
    if (!showDivider) return bar;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [bar, const Divider()],
    );
  }
}
