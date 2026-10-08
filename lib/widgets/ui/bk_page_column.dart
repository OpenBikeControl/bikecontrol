import 'package:flutter/widgets.dart';

/// A pushed page's content column: no wider than [maxWidth], centred in a
/// wide window. On a phone the column is simply the page's width.
///
/// Every pushed page wraps its content in one, and its [BkPageHeader] insets
/// the back arrow and title to the same column (`columnWidth`), so title and
/// content share an edge. The shell's sections are not pushed pages: they
/// stay at the left edge beside the sidebar.
class BkPageColumn extends StatelessWidget {
  const BkPageColumn({super.key, required this.child, this.maxWidth = defaultMaxWidth});

  /// The width of a single-column page, as Settings and its sections.
  static const double defaultMaxWidth = 720;

  /// Finds the column itself (the content's box, not the full-width slot).
  static const Key columnKey = ValueKey('page-column');

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        key: columnKey,
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
