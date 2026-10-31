// Kept apart from onboarding_methods_test.dart: a server started there stays
// mid-start inside the fake-async zone, and a running server is not started
// again.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate, screenshotMode;
import 'package:bike_control/pages/onboarding/onboarding_methods.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/host_platform.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/settings/settings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  testWidgets('without a Local Network permission the network method still comes up', (tester) async {
    // Regression (Linux, Windows, Android): there is no permission to ask
    // for, and the early return for that case skipped the start too — the
    // wizard said "Waiting for MyWhoosh…" while nothing was advertised until
    // the rider left it.
    screenshotMode = false;
    addTearDown(() => screenshotMode = true);
    debugHostPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugHostPlatformOverride = null);

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

    var updates = 0;
    await verifyEnabledNetworkMethod(ctx, app, onUpdate: () => updates++);
    await tester.pump(const Duration(milliseconds: 50));

    expect(mdns, isNotEmpty, reason: 'the enabled method must advertise over mDNS while the wizard is open');
    expect(updates, greaterThan(0), reason: 'the tile has to be told to redraw');
  });
}
