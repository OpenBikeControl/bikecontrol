// Bottom sheets come down the way they went up: a drag handle on top, and a
// swipe down — on the handle, or past the top of their scrolling content —
// closes them.
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_bottom_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  Future<void> open(WidgetTester tester, {bool scrolls = false}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ShadcnApp(
        theme: BkTheme.build(Brightness.light),
        home: Scaffold(
          child: Builder(
            builder: (context) => Center(
              child: Button.primary(
                onPressed: () => openBottomSheet<void>(
                  context: context,
                  builder: (_) => scrolls
                      ? SizedBox(
                          height: 500,
                          child: ListView(children: [for (var i = 0; i < 40; i++) Text('row $i')]),
                        )
                      : const Padding(padding: EdgeInsets.all(24), child: Text('sheet body')),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('a swipe down closes it', (tester) async {
    await open(tester);
    expect(find.text('sheet body'), findsOneWidget);
    await tester.fling(find.text('sheet body'), const Offset(0, 400), 1500);
    await tester.pumpAndSettle();
    expect(find.text('sheet body'), findsNothing);
  });

  testWidgets('scrolling content: pulling down past its top closes it', (tester) async {
    await open(tester, scrolls: true);
    expect(find.text('row 0'), findsOneWidget);
    await tester.drag(find.text('row 3'), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.text('row 0'), findsNothing);
  });
}
