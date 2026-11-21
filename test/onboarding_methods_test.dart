// The wizard's abstract Network/Bluetooth tiles must agree with the settings
// page's CoreLogic predicates for every registered app — TrainingPeaks
// (obpDirCon) and Rouvy (rouvyMdns) regressed exactly here.
import 'dart:async';
import 'dart:io';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate, screenshotMode;
import 'package:bike_control/pages/onboarding/onboarding_methods.dart';
import 'package:bike_control/services/local_network_access.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/settings/settings.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_network_permission/local_network_permission.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  testWidgets('network tile visibility matches CoreLogic for every app', (tester) async {
    for (final app in SupportedApp.supportedApps) {
      core.settings.setTrainerApp(app);
      final expected = core.logic.showObpMdnsEmulator || core.logic.showZwiftMsdnEmulator;
      expect(
        onboardingMethodVisible(OnboardingMethod.network, app),
        expected,
        reason: '${app.name}: network tile must match showObpMdnsEmulator/showZwiftMsdnEmulator',
      );
    }
  });

  testWidgets('local tile follows the target, like CoreLogic.showLocalControl', (tester) async {
    final app = SupportedApp.supportedApps.first;
    core.settings.setTrainerApp(app);
    await core.settings.setLastTarget(Target.otherDevice);
    expect(onboardingMethodVisible(OnboardingMethod.local, app), isFalse,
        reason: 'Local drives the app on THIS device — never offer it for another-device targets');
    await core.settings.setLastTarget(Target.thisDevice);
    expect(onboardingMethodVisible(OnboardingMethod.local, app), isTrue);
    expect(onboardingMethodVisible(OnboardingMethod.bluetooth, app), isFalse,
        reason: 'Bluetooth advertises to another device — pointless on the same one');
  });

  testWidgets('bluetooth tile visibility matches app support on other-device target', (tester) async {
    await core.settings.setLastTarget(Target.otherDevice);
    for (final app in SupportedApp.supportedApps) {
      core.settings.setTrainerApp(app);
      final expected =
          app.supports(AppConnectionMethod.obpBle) ||
          app.supports(AppConnectionMethod.cycplusBc2Ble) ||
          app.supports(AppConnectionMethod.zwiftBle);
      expect(
        onboardingMethodVisible(OnboardingMethod.bluetooth, app),
        expected,
        reason: '${app.name}: bluetooth tile must match obpBle/cycplusBc2Ble/zwiftBle support',
      );
    }
  });

  testWidgets('network method stays off while Local Network is denied', (tester) async {
    // getScanRequirements() is the Bluetooth-scan gate — every consumer reads a
    // non-empty result as "don't scan" — so Local Network is checked here, on
    // the method that actually needs it, exactly like OnboardingMethod.local.
    // ensureSnapshotHarness() sets screenshotMode, which suppresses every
    // permission requirement; this test is about one of them.
    screenshotMode = false;
    addTearDown(() => screenshotMode = true);
    LocalNetworkAccess.resetForTest();
    addTearDown(LocalNetworkAccess.resetForTest);
    // LocalNetworkPermission.isSupported reads defaultTargetPlatform, which the
    // test binding pins to android. Reset inside the body, not in a tearDown:
    // testWidgets asserts every foundation debug var is unset before those run.
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final probes = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      LocalNetworkPermission.channel,
      (call) async {
        probes.add(call.method);
        return call.method == 'check' ? 'denied' : null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(LocalNetworkPermission.channel, null),
    );

    final app = SupportedApp.supportedApps.firstWhere(
      (a) => onboardingMethodVisible(OnboardingMethod.network, a),
    );
    core.settings.setTrainerApp(app);
    core.settings.setObpMdnsEnabled(false);
    core.settings.setZwiftMdnsEmulatorEnabled(false);

    late BuildContext ctx;
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(child: Builder(builder: (c) {
          ctx = c;
          return const SizedBox.shrink();
        })),
      ),
    );

    try {
      // Not awaited: the gate opens the permission sheet and waits for the
      // rider to dismiss it, so the call only completes on a real interaction.
      unawaited(setOnboardingMethodEnabled(ctx, OnboardingMethod.network, app, true, onUpdate: () {}));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(probes, contains('check'), reason: 'the network method must consult Local Network before enabling');
      expect(
        core.settings.getObpMdnsEnabled() || core.settings.getZwiftMdnsEmulatorEnabled(),
        isFalse,
        reason: 'a denied Local Network permission must not leave the network method reporting enabled',
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
    // Local Network is an Apple-only permission; localNetworkRequirements()
    // is empty everywhere else, so there is nothing to assert.
  }, skip: !(Platform.isMacOS || Platform.isIOS));

  testWidgets('an already-enabled network method is re-verified on entering step 5', (tester) async {
    // setOnboardingMethodEnabled only checks on the way *on*. A rider arriving
    // at the connection step with the method already enabled — or who granted
    // Local Network once and revoked it since — never crosses that edge.
    screenshotMode = false;
    addTearDown(() => screenshotMode = true);
    LocalNetworkAccess.resetForTest();
    addTearDown(LocalNetworkAccess.resetForTest);
    final probes = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      LocalNetworkPermission.channel,
      (call) async {
        probes.add(call.method);
        return call.method == 'check' ? 'denied' : null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(LocalNetworkPermission.channel, null),
    );
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

    final app = SupportedApp.supportedApps.firstWhere(
      (a) => onboardingMethodVisible(OnboardingMethod.network, a),
    );
    core.settings.setTrainerApp(app);
    // Switch the method on directly, bypassing the toggle's own check — this is
    // the state a returning rider arrives in.
    core.settings.setObpMdnsEnabled(true);
    core.settings.setZwiftMdnsEmulatorEnabled(true);

    late BuildContext ctx;
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(child: Builder(builder: (c) {
          ctx = c;
          return const SizedBox.shrink();
        })),
      ),
    );

    try {
      expect(onboardingMethodEnabled(OnboardingMethod.network, app), isTrue,
          reason: 'precondition: the rider arrives with it already on');

      // Not awaited: the permission sheet waits for a real dismissal.
      unawaited(verifyEnabledNetworkMethod(ctx, app, onUpdate: () {}));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(probes, contains('check'),
          reason: 'entering the connection step must re-verify an enabled network method');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
    // Local Network is Apple-only; localNetworkRequirements() is empty elsewhere.
  }, skip: !(Platform.isMacOS || Platform.isIOS));

  testWidgets('granting Local Network brings the network method up', (tester) async {
    // Regression: the permission was granted and the method stayed enabled, but
    // nothing advertised — the launch-time start had been skipped while the
    // wizard held the screen, and the grant path never started it.
    screenshotMode = false;
    addTearDown(() => screenshotMode = true);
    LocalNetworkAccess.resetForTest();
    addTearDown(LocalNetworkAccess.resetForTest);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      LocalNetworkPermission.channel,
      (call) async => call.method == 'check' ? 'granted' : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(LocalNetworkPermission.channel, null),
    );
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

    // There is no nsd plugin under `flutter test`; record the advertise attempt
    // rather than let the emulator's catchError undo the setting.
    final mdns = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.haberey/nsd'),
      (call) async {
        mdns.add(call.method);
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('com.haberey/nsd'), null));

    // The wizard is still on screen, so the launch-time start is deferred.
    await core.settings.setOnboardingState(Settings.onboardingStatePending);
    addTearDown(() => core.settings.setOnboardingState(Settings.onboardingStateCompleted));

    final app = SupportedApp.supportedApps.firstWhere(
      (a) => onboardingMethodVisible(OnboardingMethod.network, a),
    );
    core.settings.setTrainerApp(app);
    core.settings.setObpMdnsEnabled(true);
    core.settings.setZwiftMdnsEmulatorEnabled(true);

    late BuildContext ctx;
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(child: Builder(builder: (c) {
          ctx = c;
          return const SizedBox.shrink();
        })),
      ),
    );

    try {
      var updates = 0;
      await verifyEnabledNetworkMethod(ctx, app, onUpdate: () => updates++);
      await tester.pump(const Duration(milliseconds: 50));

      expect(mdns, isNotEmpty,
          reason: 'granting the permission must bring the method up and advertise over mDNS');
      expect(updates, greaterThan(0), reason: 'the tile has to be told to redraw');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }, skip: !(Platform.isMacOS || Platform.isIOS));
}
