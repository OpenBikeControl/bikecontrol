// After buying Base: the smart trainer is handed back to the trainer app
// (disconnected from BikeControl, auto-connect off), so the rider's app
// shifts on its own instead of running into BikeControl's daily virtual
// shifting trial. The dialog says so only when a trainer was handed back.
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

  const handedBackLine = ValueKey('purchase-base-trainer-handed-back');

  testWidgets('hands the trainer back before the dialog and says so', (tester) async {
    final ctx = await pump(tester);
    final l = AppLocalizations.of(ctx);
    var calls = 0;
    unawaited(
      confirmBasePurchase(
        ctx,
        handTrainersBack: () async {
          calls++;
          return 1;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text(l.purchaseBaseDoneTitle), findsOneWidget);
    expect(find.byKey(handedBackLine), findsOneWidget);
  });

  testWidgets('no trainer was bridged: the dialog stays as it was', (tester) async {
    final ctx = await pump(tester);
    final l = AppLocalizations.of(ctx);
    unawaited(confirmBasePurchase(ctx, handTrainersBack: () async => 0));
    await tester.pumpAndSettle();

    expect(find.text(l.purchaseBaseDoneTitle), findsOneWidget);
    expect(find.byKey(handedBackLine), findsNothing);
  });

  testWidgets('a failing hand-back still confirms the purchase', (tester) async {
    final ctx = await pump(tester);
    final l = AppLocalizations.of(ctx);
    unawaited(confirmBasePurchase(ctx, handTrainersBack: () async => throw StateError('boom')));
    await tester.pumpAndSettle();

    expect(find.text(l.purchaseBaseDoneTitle), findsOneWidget);
    expect(find.byKey(handedBackLine), findsNothing);
  });

  testWidgets('names the selected trainer app', (tester) async {
    final ctx = await pump(tester);
    unawaited(confirmBasePurchase(ctx, appName: 'MyWhoosh', handTrainersBack: () async => 1));
    await tester.pumpAndSettle();

    expect(find.textContaining('MyWhoosh'), findsNWidgets(2));
  });

  group('Black Friday: Base bought today travels to the other devices', () {
    const signInLine = ValueKey('purchase-base-cross-platform-sign-in');
    const signedInLine = ValueKey('purchase-base-cross-platform-signed-in');
    const signInButton = ValueKey('purchase-base-sign-in');

    Future<void> confirm(WidgetTester tester, BuildContext ctx, {required bool deal, required bool signedIn, Future<void> Function(BuildContext)? openSignIn}) async {
      unawaited(
        confirmBasePurchase(
          ctx,
          handTrainersBack: () async => 0,
          crossPlatformDeal: deal,
          isSignedIn: signedIn,
          openSignIn: openSignIn,
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('signed out: asks to sign in, and Sign in opens sign-in', (tester) async {
      tester.view.physicalSize = const Size(390, 900) * 3.0;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final ctx = await pump(tester);
      var opened = 0;
      await confirm(tester, ctx, deal: true, signedIn: false, openSignIn: (_) async => opened++);

      expect(find.byKey(signInLine), findsOneWidget);
      await tester.tap(find.byKey(signInButton));
      await tester.pumpAndSettle();

      expect(opened, 1);
      expect(find.byKey(signInLine), findsNothing, reason: 'the dialog closes');
    });

    testWidgets('signed in: says it is already on the account, no sign-in button', (tester) async {
      final ctx = await pump(tester);
      await confirm(tester, ctx, deal: true, signedIn: true);

      expect(find.byKey(signedInLine), findsOneWidget);
      expect(find.byKey(signInButton), findsNothing);
    });

    testWidgets('outside the deal: neither line', (tester) async {
      final ctx = await pump(tester);
      await confirm(tester, ctx, deal: false, signedIn: false);

      expect(find.byKey(signInLine), findsNothing);
      expect(find.byKey(signedInLine), findsNothing);
      expect(find.byKey(signInButton), findsNothing);
    });
  });
}
