import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_page_column.dart';
import 'package:bike_control/widgets/ui/bk_page_header.dart';
import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  Future<void> pumpPushed(WidgetTester tester, Widget page) async {
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        theme: BkTheme.build(Brightness.light),
        home: Builder(
          builder: (context) => Button.primary(
            onPressed: () => Navigator.of(context).push(PageRouteBuilder(pageBuilder: (_, _, _) => page)),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('one labelled back button, a header title, no duplicate close', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpPushed(
      tester,
      Scaffold(
        headers: const [BkPageHeader(title: 'Gear Settings')],
        child: const SizedBox(),
      ),
    );

    expect(find.semantics.byLabel('Gear Settings'), isSemantics(isHeader: true));
    expect(find.semantics.byLabel('Back'), isSemantics(isButton: true, hasTapAction: true));
    expect(find.byIcon(LucideIcons.x), findsNothing);

    tester.semantics.tap(find.semantics.byLabel('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Gear Settings'), findsNothing);
    handle.dispose();
  });

  testWidgets('on iOS, back is the iOS chevron; elsewhere the arrow', (tester) async {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    for (final (platform, icon) in [
      (TargetPlatform.iOS, LucideIcons.chevronLeft),
      (TargetPlatform.android, LucideIcons.arrowLeft),
      (TargetPlatform.macOS, LucideIcons.arrowLeft),
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      await pumpPushed(tester, Scaffold(headers: const [BkPageHeader(title: 'Help')], child: const SizedBox()));
      final back = find.byKey(const ValueKey('page-header-back'));
      expect(find.descendant(of: back, matching: find.byIcon(icon)), findsOneWidget, reason: '$platform');
      await tester.pumpWidget(const SizedBox());
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('back respects a PopScope guard on the page', (tester) async {
    var blocked = 0;
    await pumpPushed(
      tester,
      PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) => blocked++,
        child: Scaffold(
          headers: const [BkPageHeader(title: 'Connection')],
          child: const SizedBox(),
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Connection'), findsOneWidget);
    expect(blocked, 1);
  });

  testWidgets('keeps page-specific actions', (tester) async {
    await pumpPushed(
      tester,
      Scaffold(
        headers: [
          BkPageHeader(
            title: 'Logs',
            actions: [Button.outline(onPressed: () {}, child: const Text('Reset'))],
          ),
        ],
        child: const SizedBox(),
      ),
    );
    expect(find.text('Reset'), findsOneWidget);
  });

  testWidgets('title uses the typography scale, not a one-off size', (tester) async {
    await pumpPushed(
      tester,
      Scaffold(
        headers: const [BkPageHeader(title: 'Help')],
        child: const SizedBox(),
      ),
    );
    final context = tester.element(find.text('Help'));
    final style = DefaultTextStyle.of(context).style.merge(tester.widget<Text>(find.text('Help')).style);
    expect(style.fontSize, Theme.of(context).typography.xLarge.fontSize);
  });

  group('in a wide window', () {
    Future<void> pumpWide(WidgetTester tester, BkPageHeader header) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpPushed(
        tester,
        Scaffold(
          headers: [header],
          child: const SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: BkPageColumn(child: SizedBox(height: 40, width: double.infinity)),
          ),
        ),
      );
    }

    double backLeft(WidgetTester tester) => tester.getRect(find.byKey(const ValueKey('page-header-back'))).left;

    testWidgets('back arrow at the window\'s left edge; title on the page column\'s edge', (tester) async {
      await pumpWide(tester, const BkPageHeader(title: 'Gear Settings', actions: [Text('Reset')]));
      final column = tester.getRect(find.byKey(BkPageColumn.columnKey));
      expect(column.center.dx, moreOrLessEquals(640, epsilon: 1));
      expect(backLeft(tester), lessThan(20), reason: 'back is where it is on every desktop app: top left');
      expect(tester.getRect(find.text('Gear Settings')).left, moreOrLessEquals(column.left, epsilon: 16));
      // Back and title share a row.
      expect(
        tester.getRect(find.byKey(const ValueKey('page-header-back'))).center.dy,
        moreOrLessEquals(tester.getRect(find.text('Gear Settings')).center.dy, epsilon: 2),
      );
      // The actions end at the column's other edge, not the window's.
      expect(tester.getRect(find.text('Reset')).right, lessThanOrEqualTo(column.right + 16));
      // The divider still spans the window.
      expect(tester.getRect(find.byType(Divider)).width, 1280);
    });

    testWidgets('a full-width page keeps the header at the window edge', (tester) async {
      await pumpWide(tester, const BkPageHeader(title: 'Logs', columnWidth: null));
      expect(backLeft(tester), lessThan(20));
    });
  });
}
