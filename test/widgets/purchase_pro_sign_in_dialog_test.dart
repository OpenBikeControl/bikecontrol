// After buying Pro while signed out: one dialog that says Pro works here and
// offers sign-in so it reaches the rider's other devices. "Sign in" closes it
// before Plan & account opens; "Not now" just closes it.
import 'dart:async';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/widgets/purchase_done_dialogs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<BuildContext> pump(WidgetTester tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(
          child: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
    return ctx;
  }

  testWidgets('Sign in closes the dialog, then opens sign-in', (tester) async {
    final ctx = await pump(tester);
    final l = AppLocalizations.of(ctx);
    var opened = 0;
    unawaited(showPurchaseProSignInDialog(ctx, openSignIn: (_) async => opened++));
    await tester.pumpAndSettle();
    expect(find.text(l.purchaseProSignInTitle), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('purchase-pro-sign-in')));
    await tester.pumpAndSettle();
    expect(find.text(l.purchaseProSignInTitle), findsNothing);
    expect(opened, 1);
  });

  testWidgets('Not now just closes it', (tester) async {
    final ctx = await pump(tester);
    final l = AppLocalizations.of(ctx);
    var opened = 0;
    unawaited(showPurchaseProSignInDialog(ctx, openSignIn: (_) async => opened++));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l.onboardingNotNow));
    await tester.pumpAndSettle();
    expect(find.text(l.purchaseProSignInTitle), findsNothing);
    expect(opened, 0);
  });
}
