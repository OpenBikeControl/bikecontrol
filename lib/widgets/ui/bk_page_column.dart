import 'package:flutter/widgets.dart';

/// A page's content column: no wider than [maxWidth], starting at the page's
/// leading edge under the back arrow and title — like the shell's sections.
/// On a phone the column is simply the page's width.
///
/// Every pushed page wraps its content in one, so a wide window never floats
/// a page's column in the middle while the title sits at the left.
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
      alignment: AlignmentDirectional.topStart,
      child: ConstrainedBox(
        key: columnKey,
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
