// Plan & account: one pushed page that opens on the rider's next step (go
// Pro, bring Pro to this device, sign in), then the account, the registered
// devices, purchases and help as grouped rows.
import 'dart:convert';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/models/device_limit_reached_error.dart';
import 'package:bike_control/models/subscription_term.dart';
import 'package:bike_control/models/user_device.dart';
import 'package:bike_control/pages/plan/plan_account_page.dart';
import 'package:bike_control/pages/subscriptions/email_login_form.dart';
import 'package:bike_control/services/email_otp_auth_service.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/plan_format.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_page_column.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/page_column.dart';
import '../../widget_snapshot.dart';

class _FakeEmailOtpAuth implements EmailOtpAuth {
  final List<String> sentTo = [];
  Object? verifyError;

  @override
  Future<void> sendCode(String email) async => sentTo.add(email);

  @override
  Future<void> verifyCode({required String email, required String code}) async {
    if (verifyError != null) throw verifyError!;
  }
}

class _NoHttp extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(Stream.value(utf8.encode('{}')), 404, headers: const {'content-type': 'application/json'});
}

class _MemoryStorage extends GotrueAsyncStorage {
  final _store = <String, String>{};

  @override
  Future<String?> getItem({required String key}) async => _store[key];

  @override
  Future<void> setItem({required String key, required String value}) async => _store[key] = value;

  @override
  Future<void> removeItem({required String key}) async => _store.remove(key);
}

Map<String, dynamic> _session({required String provider, String email = 'anna.radler@example.com'}) => {
  'access_token': 'token',
  'token_type': 'bearer',
  'expires_in': 3600,
  'refresh_token': 'refresh',
  'user': {
    'id': 'user-id',
    'aud': 'authenticated',
    'created_at': '2026-08-24T00:00:00Z',
    'app_metadata': {'provider': provider},
    'user_metadata': <String, dynamic>{},
    'is_anonymous': false,
    'email': email,
    'identities': [
      {
        'id': 'identity',
        'user_id': 'user-id',
        'identity_id': 'identity',
        'identity_data': <String, dynamic>{},
        'provider': provider,
        'created_at': '2026-08-24T00:00:00Z',
        'last_sign_in_at': '2026-08-24T00:00:00Z',
        'updated_at': '2026-08-24T00:00:00Z',
      },
    ],
  },
};

UserDevice _device(String id, String platform, {String? name, DateTime? lastSeen, DateTime? revokedAt}) => UserDevice(
  id: 'row-$id',
  userId: 'user-id',
  platform: platform,
  deviceId: id,
  deviceName: name,
  appVersion: '7.1.0',
  lastSeenAt: lastSeen ?? DateTime(2026, 10, 2),
  createdAt: DateTime(2026, 1, 1),
  revokedAt: revokedAt,
);

Future<void> main() async {
  await ensureSnapshotHarness();
  late SupabaseClient client;
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.load(const Locale('en'));
  });

  setUp(() {
    client = SupabaseClient(
      'https://example.test',
      'anon',
      httpClient: _NoHttp(),
      authOptions: AuthClientOptions(autoRefreshToken: false, pkceAsyncStorage: _MemoryStorage()),
    );
    IAPManager.instance.setProForTesting(enabled: false);
    IAPManager.instance.isPurchased.value = true;
    IAPManager.instance.purchaseChannelForTesting = PurchaseChannel.appStore;
    IAPManager.instance.setSubscriptionTermForTesting(null);
  });

  tearDown(() {
    client.dispose();
    IAPManager.instance.setProForTesting(enabled: false);
    IAPManager.instance.isPurchased.value = true;
    IAPManager.instance.purchaseChannelForTesting = null;
    IAPManager.instance.setSubscriptionTermForTesting(null);
  });

  Future<void> signIn(String provider) => client.auth.recoverSession(jsonEncode(_session(provider: provider)));

  Future<void> pumpPage(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    EmailOtpAuth? emailAuth,
    Future<void> Function(OAuthProvider provider)? socialSignIn,
    Future<List<UserDevice>> Function()? loadDevices,
    Future<void> Function(UserDevice device)? removeDevice,
    Future<void> Function()? registerDevice,
    Future<void> Function()? restorePurchases,
    Future<void> Function()? manageSubscription,
    bool showDevices = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ShadcnApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        theme: BkTheme.build(Brightness.dark),
        home: PlanAccountPage(
          showDevices: showDevices,
          client: client,
          emailAuth: emailAuth ?? _FakeEmailOtpAuth(),
          socialSignIn: socialSignIn ?? (_) async {},
          loadDevices: loadDevices ?? () async => const [],
          currentDeviceId: () async => 'ios_this',
          currentPlatform: () async => 'ios',
          removeDevice: removeDevice ?? (_) async {},
          registerDevice: registerDevice ?? () async {},
          restorePurchases: restorePurchases ?? () async {},
          manageSubscription: manageSubscription ?? () async {},
          loadLastSynced: () async => DateTime.now().subtract(const Duration(minutes: 5)),
          hasBillingPortal: () async => true,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder inKey(String key, Finder finder) => find.descendant(of: find.byKey(ValueKey(key)), matching: finder);

  group('Base, signed out', () {
    testWidgets('the plan first, with what it covers and Go Pro; then Konto in the app\'s own buttons', (tester) async {
      await pumpPage(tester);

      expect(inKey('plan-summary', find.text(l.currentPlan)), findsOneWidget);
      expect(inKey('plan-summary', find.text(l.planOneTimePurchase)), findsOneWidget);
      expect(inKey('plan-summary', find.text(l.planBaseUnlimitedCommands)), findsOneWidget);
      expect(inKey('plan-summary', find.text(l.goPro)), findsOneWidget);
      expect(inKey('plan-account', find.text(l.signInWithApple)), findsOneWidget);
      expect(inKey('plan-account', find.text(l.signInWithGoogle)), findsOneWidget);
      expect(find.byKey(EmailLoginForm.emailFieldKey), findsOneWidget);
      // Account first on the page? No: the plan leads on the store builds.
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('plan-summary'))).dy,
        lessThan(tester.getTopLeft(find.byKey(const ValueKey('plan-account'))).dy),
      );
    });

    testWidgets('GitHub and Facebook wait behind "More options"', (tester) async {
      await pumpPage(tester);
      expect(find.text(l.signInWithGithub), findsNothing);
      expect(find.text(l.signInWithFacebook), findsNothing);

      await tester.ensureVisible(find.byKey(const ValueKey('plan-more-options')));
      await tester.tap(find.byKey(const ValueKey('plan-more-options')));
      await tester.pumpAndSettle();

      expect(find.text(l.signInWithGithub), findsOneWidget);
      expect(find.text(l.signInWithFacebook), findsOneWidget);
    });

    testWidgets('sync and devices carry the PRO badge without Pro', (tester) async {
      await pumpPage(tester);
      expect(find.byKey(const ValueKey('plan-sync-row')), findsOneWidget);
      expect(find.byKey(const ValueKey('plan-devices-row')), findsOneWidget);
    });
  });

  testWidgets('code sent: the Konto group steps forward in place, nothing navigates', (tester) async {
    final auth = _FakeEmailOtpAuth();
    await pumpPage(tester, emailAuth: auth);

    await tester.enterText(find.byKey(EmailLoginForm.emailFieldKey), 'anna.radler@example.com');
    await tester.ensureVisible(find.byKey(EmailLoginForm.sendButtonKey));
    await tester.tap(find.byKey(EmailLoginForm.sendButtonKey));
    await tester.pumpAndSettle();

    expect(auth.sentTo, ['anna.radler@example.com']);
    expect(inKey('plan-account', find.byKey(EmailLoginForm.codeFieldKey)), findsOneWidget);
    expect(find.byType(PlanAccountPage), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-summary')), findsOneWidget);
  });

  testWidgets('a sign-in error shows inside Konto, in words, not as a raw exception', (tester) async {
    await pumpPage(tester, socialSignIn: (_) async => throw const AuthException('invalid_grant: boom'));

    await tester.ensureVisible(find.byKey(const ValueKey('plan-sign-in-google')));
    await tester.tap(find.byKey(const ValueKey('plan-sign-in-google')));
    await tester.pumpAndSettle();

    expect(inKey('plan-account', find.text(l.signInFailed)), findsOneWidget);
    expect(find.textContaining('invalid_grant'), findsNothing);
  });

  group('Pro, signed in', () {
    setUp(() => IAPManager.instance.setProForTesting(enabled: true));

    testWidgets('renewing: "Renews on", active on this device, signed in with Apple', (tester) async {
      final until = DateTime(2026, 11, 4);
      IAPManager.instance.setSubscriptionTermForTesting(
        SubscriptionTerm(
          renewal: SubscriptionRenewal.renews,
          until: until,
          period: SubscriptionPeriod.monthly,
          store: SubscriptionStore.appStore,
        ),
      );
      await signIn('apple');
      await pumpPage(tester);

      expect(inKey('plan-summary', find.text(l.proActiveOnThisDevice)), findsOneWidget);
      expect(inKey('plan-summary', find.text(l.subscriptionRenewsOn(formatPlanDate(until)))), findsOneWidget);
      expect(inKey('plan-summary', find.text(l.paywall_monthly)), findsOneWidget);
      expect(inKey('plan-account', find.text('anna.radler@example.com')), findsOneWidget);
      expect(inKey('plan-account', find.text(l.signedInWith('Apple'))), findsOneWidget);
      expect(inKey('plan-account', find.text(l.logout)), findsOneWidget);
      expect(find.byKey(EmailLoginForm.emailFieldKey), findsNothing);
    });

    testWidgets('not renewing: "Active until", never "Renews on"', (tester) async {
      final until = DateTime(2026, 11, 4);
      IAPManager.instance.setSubscriptionTermForTesting(
        SubscriptionTerm(renewal: SubscriptionRenewal.ends, until: until, store: SubscriptionStore.appStore),
      );
      await signIn('google');
      await pumpPage(tester);

      expect(find.text(l.subscriptionActiveUntil(formatPlanDate(until))), findsOneWidget);
      expect(find.text(l.subscriptionRenewsOn(formatPlanDate(until))), findsNothing);
    });

    testWidgets('a billing issue names the problem and the way to fix it', (tester) async {
      var managed = 0;
      IAPManager.instance.setSubscriptionTermForTesting(
        SubscriptionTerm(
          renewal: SubscriptionRenewal.billingIssue,
          until: DateTime(2026, 11, 4),
          store: SubscriptionStore.appStore,
        ),
      );
      await signIn('apple');
      await pumpPage(tester, manageSubscription: () async => managed++);

      expect(inKey('plan-summary', find.text(l.subscriptionBillingIssue)), findsOneWidget);
      expect(inKey('plan-summary', find.text(l.subscriptionBillingIssueBody)), findsOneWidget);
      await tester.tap(inKey('plan-summary', find.text(l.manageSubscription)));
      await tester.pumpAndSettle();
      expect(managed, 1);
    });

    testWidgets('devices inline: this one marked, the others removable after a confirmation', (tester) async {
      final removed = <String>[];
      await signIn('apple');
      await pumpPage(
        tester,
        loadDevices: () async => [
          _device('ios_this', 'ios', lastSeen: DateTime.now()),
          _device('macos_air', 'macos', name: 'MacBook Air'),
          _device('windows_pc', 'windows'),
        ],
        removeDevice: (d) async => removed.add(d.deviceId),
      );

      expect(inKey('plan-device-ios_this', find.text(l.thisDevice)), findsOneWidget);
      expect(inKey('plan-device-ios_this', find.text(l.removeDevice)), findsNothing);
      expect(inKey('plan-device-macos_air', find.text('MacBook Air')), findsOneWidget);
      expect(inKey('plan-device-windows_pc', find.text(l.removeDevice)), findsOneWidget);

      final remove = inKey('plan-device-macos_air', find.text(l.removeDevice));
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(find.text(l.removeDeviceTitle('MacBook Air')), findsOneWidget);

      await tester.tap(find.text(l.cancel));
      await tester.pumpAndSettle();
      expect(removed, isEmpty);

      await tester.tap(remove);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('plan-remove-confirm')));
      await tester.pumpAndSettle();
      expect(removed, ['macos_air']);
    });

    testWidgets('the sync row says when it last synced, in words', (tester) async {
      await signIn('apple');
      await pumpPage(tester);
      expect(inKey('plan-sync-row', find.text(l.lastSyncedAt(l.relativeMinutesAgo(5)))), findsOneWidget);
    });
  });

  group('Pro on the account, not on this device', () {
    setUp(() => IAPManager.instance.setProForTesting(enabled: true, registeredDevice: false));

    testWidgets('the plan card becomes the fix and registers this device', (tester) async {
      var registered = 0;
      await signIn('google');
      await pumpPage(tester, registerDevice: () async => registered++);

      expect(inKey('plan-unregistered', find.text(l.proUnregisteredTitle)), findsOneWidget);
      expect(inKey('plan-devices', find.text(l.deviceNotRegistered)), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('plan-register-device')));
      await tester.pumpAndSettle();
      expect(registered, 1);
    });

    testWidgets('at the device limit the list right below is the way out', (tester) async {
      await signIn('google');
      await pumpPage(
        tester,
        loadDevices: () async => [_device('ios_old', 'ios', name: 'iPhone 12')],
        registerDevice: () async =>
            throw const DeviceLimitReachedError(platform: 'ios', maxDevices: 1, devices: []),
      );

      await tester.tap(find.byKey(const ValueKey('plan-register-device')));
      await tester.pumpAndSettle();

      expect(inKey('plan-devices', find.text(l.deviceLimitRemoveOne('iOS'))), findsOneWidget);
      expect(inKey('plan-device-ios_old', find.text(l.removeDevice)), findsOneWidget);
    });
  });

  group('purchases', () {
    testWidgets('store builds offer Restore purchases', (tester) async {
      var restored = 0;
      await pumpPage(tester, restorePurchases: () async => restored++);

      final row = find.byKey(const ValueKey('plan-restore-purchases'));
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(restored, 1);
    });

    testWidgets('the Mac App Store subscription is managed from here too', (tester) async {
      IAPManager.instance.purchaseChannelForTesting = PurchaseChannel.macAppStore;
      IAPManager.instance.setProForTesting(enabled: true);
      IAPManager.instance.setSubscriptionTermForTesting(
        SubscriptionTerm(
          renewal: SubscriptionRenewal.renews,
          until: DateTime(2026, 11, 4),
          store: SubscriptionStore.macAppStore,
        ),
      );
      await pumpPage(tester);
      expect(inKey('plan-manage-subscription', find.text(l.manageInMacAppStore)), findsOneWidget);
    });

    testWidgets('the Windows download: no restore, and Konto above Go Pro', (tester) async {
      IAPManager.instance.purchaseChannelForTesting = PurchaseChannel.windowsDirect;
      IAPManager.instance.isPurchased.value = false;
      await pumpPage(tester);

      expect(find.byKey(const ValueKey('plan-restore-purchases')), findsNothing);
      expect(inKey('plan-account', find.text(l.windowsSubscriptionsRequireYouToBeLoggedIn)), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('plan-account'))).dy,
        lessThan(tester.getTopLeft(find.byKey(const ValueKey('plan-summary'))).dy),
      );
    });
  });

  testWidgets('a store Pro without an account is told what signing in brings', (tester) async {
    IAPManager.instance.setProForTesting(enabled: true);
    await pumpPage(tester);
    expect(inKey('plan-account', find.text(l.signInToBringProToOtherDevices)), findsOneWidget);
  });

  testWidgets('desktop: a centred column, Konto and Purchases side by side', (tester) async {
    IAPManager.instance.setProForTesting(enabled: true);
    IAPManager.instance.setSubscriptionTermForTesting(
      SubscriptionTerm(renewal: SubscriptionRenewal.renews, until: DateTime(2026, 11, 4), store: SubscriptionStore.appStore),
    );
    await signIn('apple');
    await pumpPage(tester, size: const Size(1280, 800));

    expectCentredPageColumn(tester, maxWidth: BkPageColumn.defaultMaxWidth);
    final account = tester.getRect(find.byKey(const ValueKey('plan-account')));
    final purchases = tester.getRect(find.byKey(const ValueKey('plan-purchases')));
    expect(account.top, moreOrLessEquals(purchases.top, epsilon: 1));
    expect(account.right, lessThan(purchases.left));
  });
}
