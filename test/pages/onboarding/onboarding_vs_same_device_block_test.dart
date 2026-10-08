// Same-device setups where the trainer app can never pick up BikeControl's
// bridge: it only takes trainers over Bluetooth (which never reaches an app on
// the same device), or it is a Microsoft Store app that Windows walls off from
// network services on the same PC. Riders there need the honest "needs a
// second device" explanation, not a Wi-Fi option that can't work.
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/onboarding/onboarding_methods.dart';
import 'package:bike_control/pages/onboarding/steps/step_trainer.dart';
import 'package:bike_control/pages/proxy_device_details/connection_card.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/host_platform.dart';
import 'package:bike_control/utils/keymap/apps/fulgaz.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/apps/tacx.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/emulators/dircon_emulator.dart' show RetrofitMode;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../widget_snapshot.dart';

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(ensureSnapshotAppState);

  tearDown(() {
    debugHostPlatformOverride = null;
    core.actionHandler = StubActions();
  });

  Future<void> on(TargetPlatform platform, SupportedApp app, Target target) async {
    // The target first, on the real host: setting it re-initialises the
    // platform's actions, and staged Android ones would call a plugin.
    debugHostPlatformOverride = null;
    core.settings.setTrainerApp(app);
    await core.settings.setLastTarget(target);
    debugHostPlatformOverride = platform;
  }

  group('which same-device setups are blocked', () {
    test('MyWhoosh on Android: Bluetooth only there', () async {
      await on(TargetPlatform.android, MyWhoosh(), Target.thisDevice);
      expect(onboardingVirtualShiftingBlocked(MyWhoosh()), isTrue);
      expect(vsSameDeviceBlock(MyWhoosh()), VsSameDeviceBlock.bluetoothOnly);
    });

    test('MyWhoosh on a Mac or iPad finds the bridge over Wi-Fi', () async {
      for (final p in [TargetPlatform.macOS, TargetPlatform.iOS, TargetPlatform.windows]) {
        await on(p, MyWhoosh(), Target.thisDevice);
        expect(onboardingVirtualShiftingBlocked(MyWhoosh()), isFalse, reason: '$p');
      }
    });

    test('FulGaz on the same iPad: Bluetooth only everywhere', () async {
      await on(TargetPlatform.iOS, FulGaz(), Target.thisDevice);
      expect(onboardingVirtualShiftingBlocked(FulGaz()), isTrue);
      expect(vsSameDeviceBlock(FulGaz()), VsSameDeviceBlock.bluetoothOnly);
    });

    test('Tacx Training on the same Windows PC: a Store app walled off from it', () async {
      await on(TargetPlatform.windows, Tacx(), Target.thisDevice);
      expect(onboardingVirtualShiftingBlocked(Tacx()), isTrue);
      expect(vsSameDeviceBlock(Tacx()), VsSameDeviceBlock.storeAppIsolation);
    });

    test('Tacx Training on the same Mac works', () async {
      await on(TargetPlatform.macOS, Tacx(), Target.thisDevice);
      expect(onboardingVirtualShiftingBlocked(Tacx()), isFalse);
    });

    test('Zwift and Rouvy on the same Windows PC work', () async {
      for (final app in [Zwift(), Rouvy()]) {
        await on(TargetPlatform.windows, app, Target.thisDevice);
        expect(onboardingVirtualShiftingBlocked(app), isFalse, reason: app.name);
      }
    });

    test('never blocked with the trainer app on another device', () async {
      for (final (p, app) in [
        (TargetPlatform.android, MyWhoosh()),
        (TargetPlatform.windows, Tacx()),
        (TargetPlatform.iOS, FulGaz()),
      ]) {
        await on(p, app, Target.otherDevice);
        expect(onboardingVirtualShiftingBlocked(app), isFalse, reason: '${app.name} on $p');
      }
    });
  });

  // FulGaz never gets asked "this or another device" — it takes no buttons, so
  // the answer is filled in as "another device". Riders still put it on the
  // same iPad, so the trainer step says up front that it has to run elsewhere.
  group('apps that can only ever run on a second device', () {
    test('FulGaz: the trainer step says it must run on another device', () async {
      await on(TargetPlatform.iOS, FulGaz(), Target.otherDevice);
      expect(onboardingVsNeedsSecondDevice(FulGaz()), isTrue);
    });

    test('apps the rider placed themselves: no extra note', () async {
      for (final app in [MyWhoosh(), Tacx(), Zwift()]) {
        await on(TargetPlatform.android, app, Target.otherDevice);
        expect(onboardingVsNeedsSecondDevice(app), isFalse, reason: app.name);
      }
    });
  });

  group('shown to the rider', () {
    late AppLocalizations l;
    setUp(() async => l = await AppLocalizations.load(const Locale('en')));

    Future<void> pump(WidgetTester tester, Widget child) async {
      tester.view.physicalSize = const Size(430, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ShadcnApp(
          localizationsDelegates: const [AppLocalizations.delegate],
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          home: Scaffold(child: SingleChildScrollView(child: SizedBox(width: 400, child: child))),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
    }

    testWidgets('onboarding: Tacx on the same Windows PC gets the Store-app explanation', (tester) async {
      await on(TargetPlatform.windows, Tacx(), Target.thisDevice);
      await pump(
        tester,
        Builder(
          builder: (context) => onboardingTrainerBody(
            context,
            app: Tacx(),
            trainers: const [],
            onPick: (_) {},
            virtualShiftingBlocked: onboardingVirtualShiftingBlocked(Tacx()),
          ),
        ),
      );

      expect(find.text(l.onboardingVsBlockedTitle.toUpperCase()), findsOneWidget);
      expect(find.text(l.onboardingVsBlockedExplainerStoreApp('Tacx Training')), findsOneWidget);
      expect(find.text(l.onboardingVsBlockedExplainer('Tacx Training')), findsNothing);
    });

    testWidgets('onboarding: FulGaz shows the second-device note above the trainer list', (tester) async {
      await on(TargetPlatform.iOS, FulGaz(), Target.otherDevice);
      await pump(
        tester,
        Builder(
          builder: (context) => onboardingTrainerBody(
            context,
            app: FulGaz(),
            trainers: const [],
            onPick: (_) {},
            needsSecondDevice: onboardingVsNeedsSecondDevice(FulGaz()),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('onboarding-vs-second-device-note')), findsOneWidget);
    });

    ProxyDevice smartTrainer() => ProxyDevice(
      BleDevice(
        deviceId: 'block-test',
        name: 'NEO 2T',
        services: const [FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID],
      ),
    )..setRetrofitMode(RetrofitMode.wifi)..isConnected = true;

    testWidgets('trainer page: a blocked same-device setup explains itself instead of offering Wi-Fi', (tester) async {
      await on(TargetPlatform.windows, Tacx(), Target.thisDevice);
      await pump(tester, ConnectionCard(device: smartTrainer()));

      expect(find.byKey(const ValueKey('vs-same-device-blocked')), findsOneWidget);
      expect(find.text('WiFi'), findsNothing, reason: 'no transport to pick that cannot work');
    });

    testWidgets('trainer page: a working same-device setup has no such note', (tester) async {
      await on(TargetPlatform.windows, Zwift(), Target.thisDevice);
      await pump(tester, ConnectionCard(device: smartTrainer()));

      expect(find.byKey(const ValueKey('vs-same-device-blocked')), findsNothing);
      expect(find.text('WiFi'), findsOneWidget);
    });
  });
}
