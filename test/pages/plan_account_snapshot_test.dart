@Tags(['screenshots'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:bike_control/main.dart' show screenshotMode;
import 'package:bike_control/models/subscription_term.dart';
import 'package:bike_control/models/user_device.dart';
import 'package:bike_control/pages/plan/plan_account_page.dart';
import 'package:bike_control/pages/shell/app_shell.dart';
import 'package:bike_control/pages/subscriptions/email_login_form.dart';
import 'package:bike_control/services/email_otp_auth_service.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widget_snapshot.dart';

/// Renders Plan & account in the mock's states (German): signed out Base,
/// code sent, Pro signed in, Pro not on this device, a wrong code, and the
/// desktop window beside the sidebar. Run:
/// `PLAN_SHOTS=/tmp/plan flutter test --run-skipped test/pages/plan_account_snapshot_test.dart`
class _Otp implements EmailOtpAuth {
  bool failVerify = false;

  @override
  Future<void> sendCode(String email) async {}

  @override
  Future<void> verifyCode({required String email, required String code}) async {
    if (failVerify) throw const AuthException('Token has expired or is invalid', statusCode: '403');
  }
}

class _NoHttp extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(Stream.value(utf8.encode('{}')), 404, headers: const {'content-type': 'application/json'});
}

class _Storage extends GotrueAsyncStorage {
  final _store = <String, String>{};

  @override
  Future<String?> getItem({required String key}) async => _store[key];

  @override
  Future<void> setItem({required String key, required String value}) async => _store[key] = value;

  @override
  Future<void> removeItem({required String key}) async => _store.remove(key);
}

Future<SupabaseClient> _client({String? provider}) async {
  final client = SupabaseClient(
    'https://example.test',
    'anon',
    httpClient: _NoHttp(),
    authOptions: AuthClientOptions(autoRefreshToken: false, pkceAsyncStorage: _Storage()),
  );
  if (provider != null) {
    await client.auth.recoverSession(
      jsonEncode({
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
          'email': 'anna.radler@example.com',
          'identities': <Object>[],
        },
      }),
    );
  }
  return client;
}

UserDevice _device(String id, String platform, String? name, DateTime seen) => UserDevice(
  id: 'row-$id',
  userId: 'user-id',
  platform: platform,
  deviceId: id,
  deviceName: name,
  appVersion: '7.1.0',
  lastSeenAt: seen,
  createdAt: DateTime(2026, 1, 1),
  revokedAt: null,
);

Future<void> main() async {
  await ensureSnapshotHarness();
  final outDir = Platform.environment['PLAN_SHOTS'] ?? 'build/snapshots';
  final now = DateTime.now();

  setUp(() {
    screenshotMode = false;
    IAPManager.instance.purchaseChannelForTesting = PurchaseChannel.appStore;
    IAPManager.instance.isPurchased.value = true;
    IAPManager.instance.setProForTesting(enabled: false);
    IAPManager.instance.setSubscriptionTermForTesting(null);
  });
  tearDown(() {
    screenshotMode = true;
    IAPManager.instance.purchaseChannelForTesting = null;
    IAPManager.instance.setProForTesting(enabled: false);
    IAPManager.instance.setSubscriptionTermForTesting(null);
  });

  PlanAccountPage page(SupabaseClient client, {EmailOtpAuth? otp, List<UserDevice> devices = const []}) =>
      PlanAccountPage(
        client: client,
        emailAuth: otp ?? _Otp(),
        socialSignIn: (_) async {},
        loadDevices: () async => devices,
        currentDeviceId: () async => 'ios_this',
        currentPlatform: () async => 'ios',
        removeDevice: (_) async {},
        registerDevice: () async {},
        restorePurchases: () async {},
        manageSubscription: () async {},
        loadLastSynced: () async => now.subtract(const Duration(minutes: 5)),
        hasBillingPortal: () async => false,
      );

  Future<void> shoot(
    WidgetTester tester,
    String name,
    Widget Function() build, {
    Brightness brightness = Brightness.dark,
    Size size = const Size(390, 844),
    Future<void> Function(WidgetTester tester)? before,
  }) => captureWidget(
    tester,
    name: name,
    locales: const ['de'],
    width: size.width,
    height: size.height,
    padding: EdgeInsets.zero,
    brightness: brightness,
    pixelRatio: 2,
    outputDir: outDir,
    settle: false,
    builder: (_) => build(),
    beforeCapture: (tester) async {
      await tester.pump(const Duration(milliseconds: 300));
      if (before != null) await before(tester);
      await tester.pump(const Duration(milliseconds: 300));
    },
  );

  void stagePro({bool registered = true}) {
    IAPManager.instance.setProForTesting(enabled: true, registeredDevice: registered);
    IAPManager.instance.setSubscriptionTermForTesting(
      SubscriptionTerm(
        renewal: SubscriptionRenewal.renews,
        until: DateTime(2026, 11, 4),
        period: SubscriptionPeriod.monthly,
        store: SubscriptionStore.appStore,
      ),
    );
  }

  final proDevices = [
    _device('ios_this', 'ios', 'iPhone von Anna', now),
    _device('macos_air', 'macos', 'MacBook Air', DateTime(2026, 10, 2)),
    _device('windows_pc', 'windows', 'DESKTOP-7Q2K', DateTime(2026, 9, 28)),
  ];

  Future<void> sendCode(WidgetTester tester) async {
    await tester.enterText(find.byKey(EmailLoginForm.emailFieldKey), 'anna.radler@example.com');
    await tester.tap(find.byKey(EmailLoginForm.sendButtonKey));
    await tester.pump(const Duration(milliseconds: 300));
  }

  for (final brightness in Brightness.values) {
    testWidgets('01 base signed out ${brightness.name}', (tester) async {
      // A picked trainer app, named on the shifting line.
      addTearDown(() => core.settings.setTrainerApp(CustomApp()));
      core.settings.setTrainerApp(MyWhoosh());
      final client = await _client();
      await shoot(tester, 'pro-new-01-base-${brightness.name}', () => page(client), brightness: brightness);
    });

    testWidgets('03 pro signed in ${brightness.name}', (tester) async {
      stagePro();
      final client = await _client(provider: 'apple');
      await shoot(
        tester,
        'pro-new-03-pro-${brightness.name}',
        () => page(client, devices: proDevices),
        brightness: brightness,
      );
    });
  }

  testWidgets('02 code sent', (tester) async {
    final client = await _client();
    await shoot(tester, 'pro-new-02-code-sent-dark', () => page(client), before: sendCode);
  });

  testWidgets('04 pro not on this device', (tester) async {
    stagePro(registered: false);
    final client = await _client(provider: 'google');
    await shoot(
      tester,
      'pro-new-04-unregistered-dark',
      () => page(
        client,
        devices: [
          _device('macos_air', 'macos', 'MacBook Air', DateTime(2026, 10, 2)),
          _device('ios_12', 'ios', 'iPhone 12', DateTime(2026, 6, 14)),
        ],
      ),
    );
  });

  testWidgets('05 wrong code', (tester) async {
    final client = await _client();
    final otp = _Otp()..failVerify = true;
    await shoot(
      tester,
      'pro-new-05-error-dark',
      () => page(client, otp: otp),
      before: (tester) async {
        await sendCode(tester);
        final boxes = find.descendant(of: find.byKey(EmailLoginForm.codeFieldKey), matching: find.byType(TextField));
        for (var i = 0; i < 6; i++) {
          await tester.enterText(boxes.at(i), '${[4, 8, 1, 9, 0, 2][i]}');
          await tester.pump();
        }
        await tester.pump(const Duration(milliseconds: 300));
      },
    );
  });

  testWidgets('06 desktop pro signed in', (tester) async {
    stagePro();
    final client = await _client(provider: 'apple');
    final shell = ShellController();
    addTearDown(shell.dispose);
    await shoot(
      tester,
      'pro-new-06-desktop-dark',
      () => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShellSidebar(controller: shell, planSelected: true),
          Expanded(child: page(client, devices: proDevices)),
        ],
      ),
      size: const Size(1280, 800),
    );
  });
}
