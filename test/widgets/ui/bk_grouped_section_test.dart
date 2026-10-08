import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:bike_control/widgets/ui/bk_pill_button.dart';
import 'package:bike_control/widgets/ui/bk_status_dot.dart';
import 'dart:ui' show Tristate;

import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../helpers/contrast.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child, {Brightness brightness = Brightness.light}) =>
      tester.pumpWidget(
        ShadcnApp(
          scaling: BkTheme.scaling,
          theme: BkTheme.build(brightness),
          home: SingleChildScrollView(child: Align(alignment: Alignment.topLeft, child: SizedBox(width: 390, child: child))),
        ),
      );

  Widget section({VoidCallback? onTap, ValueChanged<bool>? onToggle}) => BkGroupedSection(
    header: 'Riding with',
    children: [
      BkGroupedRow(
        icon: LucideIcons.monitor,
        title: 'Trainer app',
        trailing: const Text('MyWhoosh'),
        chevron: true,
        onPressed: onTap,
      ),
      BkGroupedRow(
        icon: LucideIcons.bluetooth,
        title: 'Connection settings',
        subtitle: 'Network',
      ),
      BkGroupedRow(
        title: 'Shift sound',
        trailing: Switch(value: true, onChanged: onToggle),
      ),
    ],
  );

  testWidgets('the header is uppercase and marked as a header', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, section());
    expect(find.text('RIDING WITH'), findsOneWidget);
    expect(find.semantics.byLabel('RIDING WITH'), isSemantics(isHeader: true));
    handle.dispose();
  });

  testWidgets('every row is at least 48 dp tall on touch', (tester) async {
    await pump(tester, section());
    for (final row in find.byType(BkGroupedRow).evaluate()) {
      expect(row.size!.height, greaterThanOrEqualTo(48), reason: (row.widget as BkGroupedRow).title);
    }
  });

  testWidgets('rows are separated by inset hairlines, none after the last', (tester) async {
    await pump(tester, section());
    final dividers = find.byType(BkGroupedDivider);
    expect(dividers, findsNWidgets(2));
    final sectionLeft = tester.getTopLeft(find.byType(BkGroupedSection)).dx;
    for (final line in find.descendant(of: dividers, matching: find.byType(ColoredBox)).evaluate()) {
      expect(tester.getTopLeft(find.byWidget(line.widget)).dx, greaterThan(sectionLeft + 16), reason: 'inset');
    }
  });

  testWidgets('a tappable row is one button named by its content, and taps through', (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await pump(tester, section(onTap: () => taps++));
    final node = find.semantics.byPredicate((n) => n.label.contains('Trainer app') && n.flagsCollection.isButton);
    expect(node, findsOneWidget);
    expect(node.evaluate().single.label, contains('MyWhoosh'));
    tester.semantics.tap(node);
    expect(taps, 1);
    // A non-tappable row is not reported as a button.
    expect(
      find.semantics.byPredicate((n) => n.label.contains('Connection settings') && n.flagsCollection.isButton),
      findsNothing,
    );
    handle.dispose();
  });

  testWidgets('a trailing switch carries the row title', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, section(onToggle: (_) {}));
    expect(
      find.semantics.byPredicate((n) => n.label == 'Shift sound' && n.flagsCollection.isToggled != Tristate.none),
      findsOneWidget,
    );
    handle.dispose();
  });

  for (final brightness in Brightness.values) {
    testWidgets('$brightness: all text is legible on the grouped card', (tester) async {
      await pump(tester, section(), brightness: brightness);
      expectLegibleText(
        tester,
        find.byType(BkGroupedSection),
        pageBackground: BkTheme.build(brightness).colorScheme.background,
      );
    });
  }

  testWidgets('status dot reads as its text, with a success-coloured dot', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, const BkStatusDot(label: 'Connected'));
    expect(find.text('Connected'), findsOneWidget);
    final dot = tester.widget<DecoratedBox>(
      find.descendant(of: find.byType(BkStatusDot), matching: find.byType(DecoratedBox)).first,
    );
    expect((dot.decoration as BoxDecoration).color, BkStatusColors.light.success);
    handle.dispose();
  });

  testWidgets('pill button is full width, at least 48 dp and fully rounded', (tester) async {
    var taps = 0;
    await pump(tester, BkPillButton(onPressed: () => taps++, child: const Text('Continue')));
    final size = tester.getSize(find.byType(BkPillButton));
    expect(size.width, 390);
    expect(size.height, greaterThanOrEqualTo(48));
    await tester.tap(find.text('Continue'));
    expect(taps, 1);
  });
}
