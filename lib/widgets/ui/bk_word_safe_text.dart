import 'dart:math' as math;

import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Text for a box too narrow to promise the room it needs — a tile, a card
/// in a row of three — that breaks only between words.
///
/// Flutter wraps a word that is wider than its line anywhere, so a German or
/// French label in a narrow tile reads "Kameraw" / "inkel" or "Sélection" /
/// "ner". Here, when the longest word is wider than the room, or the words
/// need more than [maxLines] lines, the type shrinks in small steps (never
/// below [minScale] of its size) until every word sits whole and the text
/// fits. Past [minScale] it ellipsizes like any other text.
///
/// Measures its width with a [LayoutBuilder], so it can't sit under an
/// [IntrinsicWidth] / [IntrinsicHeight].
class BkWordSafeText extends StatelessWidget {
  const BkWordSafeText(
    this.text, {
    super.key,
    this.style,
    this.maxLines = 2,
    this.textAlign,
    this.minScale = 0.7,
  });

  final String text;
  final TextStyle? style;
  final int maxLines;
  final TextAlign? textAlign;

  /// The smallest the type may get, as a fraction of its size.
  final double minScale;

  /// The size [text] takes in [style] to fit [maxWidth] — 1 when it already
  /// does, never below [minScale].
  static double fitScale({
    required String text,
    required TextStyle style,
    required double maxWidth,
    required int maxLines,
    required TextScaler textScaler,
    required TextDirection textDirection,
    double minScale = 0.7,
  }) {
    if (!maxWidth.isFinite || text.isEmpty) return 1;
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final fontSize = style.fontSize ?? 14;
    final painter = TextPainter(textDirection: textDirection, textScaler: textScaler);
    try {
      bool fits(double scale) {
        final scaled = style.copyWith(fontSize: fontSize * scale);
        for (final word in words) {
          painter
            ..text = TextSpan(text: word, style: scaled)
            ..maxLines = null
            ..layout();
          if (painter.width > maxWidth) return false;
        }
        painter
          ..text = TextSpan(text: text, style: scaled)
          ..maxLines = maxLines
          ..layout(maxWidth: maxWidth);
        return !painter.didExceedMaxLines;
      }

      var scale = 1.0;
      while (scale > minScale && !fits(scale)) {
        scale = math.max(minScale, scale - 0.025);
      }
      return scale;
    } finally {
      painter.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final resolved = DefaultTextStyle.of(context).style.merge(style);
        final scale = fitScale(
          text: text,
          style: resolved,
          maxWidth: constraints.maxWidth,
          maxLines: maxLines,
          textScaler: MediaQuery.textScalerOf(context),
          textDirection: Directionality.of(context),
          minScale: minScale,
        );
        return Text(
          text,
          style: scale == 1
              ? style
              : (style ?? const TextStyle()).copyWith(fontSize: (resolved.fontSize ?? 14) * scale),
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
        );
      },
    );
  }
}
