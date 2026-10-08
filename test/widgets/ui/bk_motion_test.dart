// The routine motion every Ride change runs through: rows that grow in and
// shrink out, and cards that crossfade into what they become. Each has to be
// visibly mid-way part of the way through, and instant under reduced motion.
import 'package:bike_control/widgets/ui/bk_motion.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {bool reduceMotion = false}) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 200, child: child),
    ),
  ),
);

Widget _row(String id) => SizedBox(key: ValueKey(id), height: 40, child: Text(id));

void main() {
  group('BkAnimatedColumn', () {
    testWidgets('rows on the first build are simply there', (tester) async {
      await tester.pumpWidget(_host(BkAnimatedColumn(children: [_row('a'), _row('b')])));
      expect(tester.getSize(find.byType(BkAnimatedColumn)).height, 80);
    });

    testWidgets('a new row grows in over ~250 ms', (tester) async {
      await tester.pumpWidget(_host(BkAnimatedColumn(children: [_row('a')])));
      await tester.pumpWidget(_host(BkAnimatedColumn(children: [_row('a'), _row('b')])));

      await tester.pump(const Duration(milliseconds: 60));
      final mid = tester.getSize(find.byType(BkAnimatedColumn)).height;
      expect(mid, greaterThan(40));
      expect(mid, lessThan(80));
      final opacity = tester.widget<FadeTransition>(
        find.ancestor(of: find.text('b'), matching: find.byType(FadeTransition)).first,
      );
      expect(opacity.opacity.value, lessThan(1));

      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.getSize(find.byType(BkAnimatedColumn)).height, 80);
    });

    testWidgets('a removed row shrinks out where it stood, then is gone', (tester) async {
      await tester.pumpWidget(_host(BkAnimatedColumn(children: [_row('a'), _row('b'), _row('c')])));
      await tester.pumpWidget(_host(BkAnimatedColumn(children: [_row('a'), _row('c')])));

      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('b'), findsOneWidget, reason: 'still leaving');
      final b = tester.getTopLeft(find.text('b')).dy;
      final c = tester.getTopLeft(find.text('c')).dy;
      expect(b, lessThan(c), reason: 'it leaves from its own place, above c');
      final height = tester.getSize(find.byType(BkAnimatedColumn)).height;
      expect(height, greaterThan(80));
      expect(height, lessThan(120));

      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('b'), findsNothing);
      expect(tester.getSize(find.byType(BkAnimatedColumn)).height, 80);
    });

    testWidgets('reduced motion: rows arrive and leave at once', (tester) async {
      await tester.pumpWidget(_host(BkAnimatedColumn(children: [_row('a')]), reduceMotion: true));
      await tester.pumpWidget(_host(BkAnimatedColumn(children: [_row('a'), _row('b')]), reduceMotion: true));
      await tester.pump();
      expect(tester.getSize(find.byType(BkAnimatedColumn)).height, 80);

      await tester.pumpWidget(_host(BkAnimatedColumn(children: [_row('b')]), reduceMotion: true));
      await tester.pump();
      expect(find.text('a'), findsNothing);
      expect(tester.getSize(find.byType(BkAnimatedColumn)).height, 40);
    });
  });

  group('BkAnimatedSwap', () {
    Widget box(String id, double height) => SizedBox(key: ValueKey(id), height: height, child: Text(id));

    testWidgets('crossfades and eases to the new height', (tester) async {
      await tester.pumpWidget(_host(BkAnimatedSwap(child: box('small', 60))));
      await tester.pumpWidget(_host(BkAnimatedSwap(child: box('tall', 160))));

      await tester.pump(const Duration(milliseconds: 60));
      final height = tester.getSize(find.byType(BkAnimatedSwap)).height;
      expect(height, greaterThan(60));
      expect(height, lessThan(160));
      expect(find.text('small'), findsOneWidget, reason: 'fading out');
      expect(find.text('tall'), findsOneWidget, reason: 'fading in');

      await tester.pumpAndSettle();
      expect(find.text('small'), findsNothing);
      expect(tester.getSize(find.byType(BkAnimatedSwap)).height, 160);
    });

    testWidgets('reduced motion: the swap is instant', (tester) async {
      await tester.pumpWidget(_host(BkAnimatedSwap(child: box('small', 60)), reduceMotion: true));
      await tester.pumpWidget(_host(BkAnimatedSwap(child: box('tall', 160)), reduceMotion: true));
      await tester.pump();
      expect(find.text('small'), findsNothing);
      expect(tester.getSize(find.byType(BkAnimatedSwap)).height, 160);
    });
  });
}
