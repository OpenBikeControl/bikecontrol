// A pushed page on iOS goes back with a swipe from anywhere on the screen, as
// in iOS's own apps — not only from the 20 px strip at the left edge.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_page_header.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  Future<void> pushPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        theme: BkTheme.build(Brightness.light),
        materialTheme: BkTheme.material(Brightness.light),
        home: Builder(
          builder: (context) => Center(
            child: Button.primary(
              onPressed: () => context.push(
                const Scaffold(headers: [BkPageHeader(title: 'Pushed')], child: SizedBox.expand()),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Pushed'), findsOneWidget);
  }

  testWidgets('iOS: a swipe from the middle of the screen goes back', (tester) async {
    await pushPage(tester);
    await tester.flingFrom(const Offset(180, 420), const Offset(250, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.text('Pushed'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('iOS: the edge swipe still works', (tester) async {
    await pushPage(tester);
    await tester.flingFrom(const Offset(4, 420), const Offset(300, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.text('Pushed'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Android: a sideways swipe does not go back (it has its own back)', (tester) async {
    await pushPage(tester);
    await tester.flingFrom(const Offset(180, 420), const Offset(250, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.text('Pushed'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
