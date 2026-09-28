// After a Pro purchase that hits the account's device limit: one dialog that
// says Pro is on the account but this device can't be activated, with
// "Manage devices" (then an automatic retry) and "Contact support". It
// closes before either one opens, so nothing stacks.
import 'dart:async';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/models/device_limit_reached_error.dart';
import 'package:bike_control/widgets/purchase_done_dialogs.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

const _limit = DeviceLimitReachedError(platform: 'ios', maxDevices: 2, devices: []);

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

  testWidgets('manage devices closes the dialog, opens the devices, then retries', (tester) async {
    final ctx = await pump(tester);
    final l = AppLocalizations.of(ctx);
    final events = <String>[];
    final devicesClosed = Completer<void>();
    unawaited(
      showProDeviceLimitDialog(
        ctx,
        _limit,
        manageDevices: (_) {
          events.add('manage');
          return devicesClosed.future;
        },
        retryRegistration: () async {
          events.add('retry');
          return true;
        },
        contactSupport: (_, _) => events.add('support'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(l.purchaseProDeviceLimitTitle), findsOneWidget);
    expect(find.text(l.purchaseProDeviceLimitBody('2', 'iOS')), findsOneWidget);

    await tester.tap(find.text(l.purchaseManageDevices));
    await tester.pumpAndSettle();
    expect(find.text(l.purchaseProDeviceLimitTitle), findsNothing, reason: 'no dialog stacked under the devices view');
    expect(events, ['manage']);

    devicesClosed.complete();
    await tester.pumpAndSettle();
    expect(events, ['manage', 'retry']);
  });

  testWidgets('contact support closes the dialog and opens support with the limit details', (tester) async {
    final ctx = await pump(tester);
    final l = AppLocalizations.of(ctx);
    DeviceLimitReachedError? sent;
    unawaited(
      showProDeviceLimitDialog(
        ctx,
        _limit,
        manageDevices: (_) async {},
        retryRegistration: () async => false,
        contactSupport: (_, e) => sent = e,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.getSupport));
    await tester.pumpAndSettle();
    expect(find.text(l.purchaseProDeviceLimitTitle), findsNothing);
    expect(sent, same(_limit));
  });

  testWidgets('registering from the unregistered dialog at the limit swaps to the limit dialog', (tester) async {
    final ctx = await pump(tester);
    final l = AppLocalizations.of(ctx);
    unawaited(
      showPurchaseProUnregisteredDialog(
        ctx,
        registerCall: () async => throw _limit,
        manageDevices: (_) async {},
        retryRegistration: () async => false,
        contactSupport: (_, _) {},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(l.purchaseProUnregisteredBody), findsOneWidget);

    await tester.tap(find.text(l.registerThisDevice));
    await tester.pumpAndSettle();
    expect(find.text(l.purchaseProUnregisteredBody), findsNothing);
    expect(find.text(l.purchaseProDeviceLimitBody('2', 'iOS')), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget, reason: 'one dialog at a time');
  });
  testWidgets('"Not now" closes the dialog without opening anything', (tester) async {
    final ctx = await pump(tester);
    final l = AppLocalizations.of(ctx);
    final events = <String>[];
    unawaited(
      showProDeviceLimitDialog(
        ctx,
        _limit,
        manageDevices: (_) async => events.add('manage'),
        retryRegistration: () async {
          events.add('retry');
          return false;
        },
        contactSupport: (_, _) => events.add('support'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(l.purchaseProDeviceLimitTitle), findsOneWidget);
    await tester.tap(find.text(l.onboardingNotNow));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(events, isEmpty);
  });

  testWidgets('the crown uses the Pro orange', (tester) async {
    final ctx = await pump(tester);
    unawaited(showProDeviceLimitDialog(ctx, _limit, manageDevices: (_) async {}, retryRegistration: () async => false));
    await tester.pumpAndSettle();
    final crown = tester.widget<Icon>(find.byIcon(LucideIcons.crown));
    expect(crown.color, BkTheme.proOrange);
  });
}
