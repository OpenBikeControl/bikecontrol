import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/ui/bk_icon_button.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The header every pushed page shares: one labelled back button, the title
/// in the typography scale's page-title style, and the page's own actions.
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
  });

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

  /// The one page-title style: the scale's xLarge, semibold, slightly tight.
  static TextStyle titleStyle(BuildContext context) => Theme.of(context).typography.xLarge.copyWith(
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
  );

  @override
  Widget build(BuildContext context) {
    final bar = AppBar(
      padding: padding,
      leading: [
        if (showBack)
          BkIconButton.ghost(
            key: const ValueKey('page-header-back'),
            icon: const Icon(LucideIcons.arrowLeft, size: 22),
            label: context.i18n.a11yBack,
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
          ),
      ],
      title: Semantics(
        header: true,
        child: Text(title, style: titleStyle(context)),
      ),
      subtitle: subtitle,
      trailing: actions,
      backgroundColor: Theme.of(context).colorScheme.background,
    );
    if (!showDivider) return bar;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [bar, const Divider()],
    );
  }
}
