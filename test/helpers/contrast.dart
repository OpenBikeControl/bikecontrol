import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// WCAG 2.x contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// The colour actually painted behind [box]: the nearest ancestor that fills
/// its area (a decorated box with a colour or gradient, or a ColoredBox),
/// blended over whatever sits behind that. [fallback] is the page background.
Color paintedBackgroundOf(RenderObject box, Color fallback) {
  final layers = <Color>[];
  RenderObject? node = box.parent;
  while (node != null) {
    Color? fill;
    // shadcn's buttons paint through a private `_RenderDecoratedBox`.
    if (node is RenderDecoratedBox || node.runtimeType.toString() == '_RenderDecoratedBox') {
      final d = (node as dynamic).decoration as Decoration;
      if (d is BoxDecoration) fill = d.color ?? d.gradient?.colors.first;
      if (d is ShapeDecoration) fill = d.color ?? d.gradient?.colors.first;
    } else if (node.runtimeType.toString() == '_RenderColoredBox') {
      fill = (node as dynamic).color as Color;
    }
    if (fill != null && fill.a > 0) {
      layers.add(fill);
      if (fill.a >= 1) break;
    }
    node = node.parent;
  }
  var result = fallback;
  for (final c in layers.reversed) {
    result = Color.alphaBlend(c, result);
  }
  return result;
}

/// Every visible piece of text under [root] reaches [minRatio] against what
/// is painted behind it (3:1 for large text, per WCAG).
void expectLegibleText(WidgetTester tester, Finder root, {required Color pageBackground, double minRatio = 4.5}) {
  final paragraphs = find
      .descendant(of: root, matching: find.byType(RichText))
      .evaluate()
      .map((e) => e.renderObject! as RenderParagraph);
  var checked = 0;
  for (final p in paragraphs) {
    final text = p.text.toPlainText().trim();
    if (text.isEmpty) continue;
    final style = p.text.style;
    final color = style?.color;
    if (color == null || color.a == 0) continue;
    final size = style?.fontSize ?? 14;
    final bold = (style?.fontWeight?.value ?? 400) >= 700;
    // Icon glyphs (private-use code points) are graphics: WCAG 1.4.11 asks
    // 3:1 of them, the same as large text.
    final rune = text.runes.first;
    final isIcon = text.runes.length == 1 && ((rune >= 0xE000 && rune <= 0xF8FF) || rune >= 0xF0000);
    final large = isIcon || size >= 18 || (bold && size >= 14);
    final bg = paintedBackgroundOf(p, pageBackground);
    final fg = Color.alphaBlend(color, bg);
    expect(contrast(fg, bg), greaterThanOrEqualTo(large ? 3.0 : minRatio),
        reason: '"$text" ($fg on $bg)');
    checked++;
  }
  expect(checked, greaterThan(0), reason: 'no text found to check');
}
