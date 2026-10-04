// A pushed page in a wide window: its content column centred in the window,
// the header's back arrow and title inset to the same column.
import 'package:bike_control/widgets/ui/bk_page_column.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void expectCentredPageColumn(
  WidgetTester tester, {
  double maxWidth = BkPageColumn.defaultMaxWidth,
  bool hasHeader = true,
}) {
  final column = find.byKey(BkPageColumn.columnKey);
  expect(column, findsOneWidget);
  final rect = tester.getRect(column);
  final window = tester.view.physicalSize / tester.view.devicePixelRatio;
  expect(rect.width, lessThanOrEqualTo(maxWidth), reason: 'keeps its column width');
  expect(rect.left, greaterThan(40), reason: 'not stuck to the left edge of a ${window.width} window');
  expect(rect.center.dx, moreOrLessEquals(window.width / 2, epsilon: 1), reason: 'centred in the window');
  if (!hasHeader) return;
  final back = tester.getRect(find.byKey(const ValueKey('page-header-back')));
  expect(back.left, greaterThanOrEqualTo(rect.left - 16), reason: 'back arrow sits at the column edge');
  expect(back.left, lessThanOrEqualTo(rect.left + 16), reason: 'back arrow sits at the column edge');
}
