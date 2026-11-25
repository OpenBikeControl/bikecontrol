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
}
