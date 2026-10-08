// Every way into the plan opens the same pushed Plan & account page — the
// plan badge, the sidebar's plan card, Settings' plan card, the Ride error
// fix for an unregistered device, and "manage devices" — never a side sheet.
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/plan/plan_account_page.dart';
import 'package:bike_control/pages/shell/app_shell.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/widgets/register_this_device.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:flutter/services.dart' show StandardMessageCodec;
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../helpers/shell_harness.dart';
import '../../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();
  quietShellEnvironment();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
    'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
    (_) async => const StandardMessageCodec().encodeMessage(<Object?>[null]),
  );

  AppLocalizations l10n() => AppLocalizations.current;

  setUp(() => IAPManager.instance.purchaseChannelForTesting = PurchaseChannel.appStore);
  tearDown(() => IAPManager.instance.purchaseChannelForTesting = null);

  /// The page is on screen as a route of its own, with no drawer around it.
  void expectPushedPage(WidgetTester tester) {
    final page = find.byType(PlanAccountPage);
    expect(page, findsOneWidget);
    expect(ModalRoute.of(tester.element(page)), isA<PageRoute<dynamic>>());
    expect(find.ancestor(of: page, matching: find.byType(DrawerWrapper)), findsNothing);
  }

  testWidgets('phone: the plan badge opens the page', (tester) async {
    await pumpShell(tester, const Size(390, 844));
    await tester.tap(find.byKey(const ValueKey('plan-badge')));
    await tester.pumpAndSettle();

    expectPushedPage(tester);
    expect(find.text(l10n().planAccountTitle), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('page-header-back')));
    await tester.pumpAndSettle();
    expect(find.byType(PlanAccountPage), findsNothing);
    await disposeShell(tester);
  });

  testWidgets('expanded: the sidebar\'s plan card opens the page beside the sidebar', (tester) async {
    await pumpShell(tester, const Size(1280, 800));
    await tester.tap(find.byKey(const ValueKey('plan-card')));
    await tester.pumpAndSettle();

    expectPushedPage(tester);
    expect(find.byType(ShellSidebar), findsOneWidget);
    // The page sits right of the sidebar.
    expect(
      tester.getTopLeft(find.byType(PlanAccountPage)).dx,
      greaterThanOrEqualTo(tester.getTopRight(find.byType(ShellSidebar)).dx),
    );

    // A section in the sidebar leaves the page for that section.
    await tester.tap(find.descendant(of: find.byType(ShellSidebar), matching: find.text(l10n().activity)));
    await tester.pumpAndSettle();
    expect(find.byType(PlanAccountPage), findsNothing);
    await disposeShell(tester);
  });

  testWidgets('Settings\' plan card opens the page', (tester) async {
    await pumpShell(tester, const Size(390, 844));
    await tester.tap(find.text(l10n().navSettings).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-plan')));
    await tester.pumpAndSettle();

    expectPushedPage(tester);
    await disposeShell(tester);
  });

  testWidgets('the Ride error for an unregistered device fixes itself on the page', (tester) async {
    await pumpShell(tester, const Size(390, 844));
    core.connection.signalNotification(
      ActionNotification(
        const Error(
          'Pro needs this device registered',
          button: ControllerButton('shiftUpRight'),
          type: ErrorType.deviceRegistrationNeeded,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text(l10n().activity).last);
    await tester.pumpAndSettle();

    final fix = find.text(l10n().registerThisDevice);
    expect(fix, findsWidgets);
    await tester.tap(fix.first);
    await tester.pumpAndSettle();

    expectPushedPage(tester);
    await disposeShell(tester);
  });

  testWidgets('"Manage devices" opens the page on its devices', (tester) async {
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
        theme: BkTheme.build(Brightness.dark),
        home: Scaffold(
          child: Builder(
            builder: (context) => Button.primary(
              onPressed: () => openRegisteredDevices(context),
              child: const Text('manage'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('manage'));
    await tester.pumpAndSettle();

    expectPushedPage(tester);
    expect(tester.widget<PlanAccountPage>(find.byType(PlanAccountPage)).showDevices, isTrue);
  });
}
