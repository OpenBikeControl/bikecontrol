import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Offsets into [finder]'s text at which its paragraph starts a new line.
List<int> lineBreaks(WidgetTester tester, Finder finder) {
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  final text = paragraph.text.toPlainText();
  // RenderParagraph doesn't expose its line boundaries; lay the same text out
  // again under the same constraints and read them off that.
  final painter = TextPainter(
    text: paragraph.text,
    textAlign: paragraph.textAlign,
    textDirection: paragraph.textDirection,
    textScaler: paragraph.textScaler,
    maxLines: paragraph.maxLines,
    locale: paragraph.locale,
    strutStyle: paragraph.strutStyle,
    textWidthBasis: paragraph.textWidthBasis,
    textHeightBehavior: paragraph.textHeightBehavior,
  )..layout(maxWidth: paragraph.constraints.maxWidth);
  final breaks = <int>[];
  var offset = 0;
  while (offset < text.length) {
    final end = painter.getLineBoundary(TextPosition(offset: offset)).end;
    if (end <= offset || end >= text.length) break;
    breaks.add(end);
    offset = end;
  }
  painter.dispose();
  return breaks;
}

/// Fails when [finder]'s text is broken across lines anywhere but between
/// two words — "Compac" / "t" is exactly what this catches.
void expectBreaksOnlyBetweenWords(WidgetTester tester, Finder finder, {String? reason}) {
  final text = tester.renderObject<RenderParagraph>(finder).text.toPlainText();
  for (final b in lineBreaks(tester, finder)) {
    final atWordGap = text[b - 1] == ' ' || text[b] == ' ';
    expect(atWordGap, isTrue,
        reason: '${reason ?? '"$text"'} breaks mid-word: "${text.substring(0, b)}" / "${text.substring(b)}"');
  }
}
