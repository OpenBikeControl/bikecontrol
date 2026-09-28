import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_page_header.dart';
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
      Scaffold(headers: const [BkPageHeader(title: 'Gear Settings')], child: const SizedBox()),
    );

    expect(find.semantics.byLabel('Gear Settings'), isSemantics(isHeader: true));
    expect(find.semantics.byLabel('Back'), isSemantics(isButton: true, hasTapAction: true));
    expect(find.byIcon(LucideIcons.x), findsNothing);

    tester.semantics.tap(find.semantics.byLabel('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Gear Settings'), findsNothing);
    handle.dispose();
  });

  testWidgets('back respects a PopScope guard on the page', (tester) async {
    var blocked = 0;
    await pumpPushed(
      tester,
      PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) => blocked++,
        child: Scaffold(headers: const [BkPageHeader(title: 'Connection')], child: const SizedBox()),
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
        headers: [BkPageHeader(title: 'Logs', actions: [Button.outline(onPressed: () {}, child: const Text('Reset'))])],
        child: const SizedBox(),
      ),
    );
    expect(find.text('Reset'), findsOneWidget);
  });

  testWidgets('title uses the typography scale, not a one-off size', (tester) async {
    await pumpPushed(tester, Scaffold(headers: const [BkPageHeader(title: 'Help')], child: const SizedBox()));
    final context = tester.element(find.text('Help'));
    final style = DefaultTextStyle.of(context).style.merge(tester.widget<Text>(find.text('Help')).style);
    expect(style.fontSize, Theme.of(context).typography.xLarge.fontSize);
  });
}
