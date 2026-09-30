@Tags(['screenshots'])
library;

import 'dart:io';

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show screenshotMode;
import 'package:bike_control/pages/activity/activity_log.dart' show activityLogClock;
import 'package:bike_control/pages/activity/activity_section.dart';
import 'package:bike_control/pages/navigation.dart';
import 'package:bike_control/pages/proxy_device_details/gear_ratios_editor_page.dart';
import 'package:bike_control/pages/settings/virtual_shifting_settings_page.dart';
import 'package:bike_control/pages/shell/app_shell.dart';
import 'package:bike_control/services/blog_news.dart';
import 'package:bike_control/services/blog_service.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/host_platform.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:flutter/services.dart' show StandardMessageCodec;
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/emulators/transporter/network_transporter.dart';
import 'package:prop/prop.dart' show LogLevel;
import 'package:prop/utils/prefs.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../helpers/activity_log_seed.dart';
import '../helpers/shell_harness.dart';
import '../widget_snapshot.dart';

/// Renders the owner-feedback round: toasts above the tab bar, Ride's banner
/// listing the outstanding steps, Activity's News segment, Settings without
/// the Blog row and Virtual shifting's Gears without the gear-count warning.
/// German unless named `-en`. Run:
/// `OF_SHOTS=.impeccable/review flutter test --run-skipped test/pages/owner_feedback_snapshot_test.dart`
Future<void> main() async {
  await ensureSnapshotHarness();
  quietShellEnvironment();
  final outDir = Platform.environment['OF_SHOTS'] ?? 'build/snapshots';

  final controller = ZwiftClickV2(BleDevice(name: 'Zwift Click', deviceId: 'of-shot-click'))
    ..firmwareVersion = '1.2.0'
    ..isConnected = true
    ..rssi = -51
    ..batteryLevel = 81;
  final proxy =
      ProxyDevice(
          BleDevice(
            name: 'KICKR CORE',
            deviceId: 'of-shot-kickr',
            services: [FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID],
          ),
        )
        ..services = [BleService(FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID, [])]
        ..isConnected = true;
  final definition = FitnessBikeDefinition(
    connectedDevice: proxy.scanResult,
    connectedDeviceServices: proxy.services!,
    data: ValueNotifier(''),
  )..setDebugValues();
  proxy.emulator.debugSetTransporter(NetworkTransporter(definition: definition));

  final now = DateTime.now();
  final posts = [
    BlogPost(
      date: now.subtract(const Duration(days: 1)),
      title: '7.1 - A Calmer Home Screen',
      slug: 'bikecontrol-7-1',
      excerpt: 'Ride, Devices, Activity and Settings: everything in its place, and the gear front and centre.',
      translations: {
        'de': const BlogTranslation(
          slug: 'bikecontrol-7-1',
          title: '7.1 – Ein ruhigerer Startbildschirm',
          url: '/de/blog/bikecontrol-7-1/',
          excerpt: 'Fahren, Geräte, Aktivität und Einstellungen: alles an seinem Platz, der Gang im Mittelpunkt.',
        ),
      },
    ),
    BlogPost(
      date: DateTime(2026, 9, 18),
      title: '7.0 - One Connection for Everything',
      slug: 'bikecontrol-7-0-one-connection-for-everything',
      excerpt: 'One bridge carries your trainer and your controller to the app.',
    ),
    BlogPost(
      date: DateTime(2026, 8, 21),
      title: 'Configure Your Controller: Single Click, Double Click, Long Press',
      slug: 'configure-your-controller',
      translations: {
        'de': const BlogTranslation(
          slug: 'controller-einrichten',
          title: 'Controller einrichten: Einfacher Klick, Doppelklick, langes Drücken',
          url: '/de/blog/controller-einrichten/',
        ),
      },
    ),
    BlogPost(
      date: DateTime(2026, 7, 31),
      title: 'Virtual Shifting with BikeControl — and Without',
      slug: 'virtual-shifting',
      translations: {
        'de': const BlogTranslation(
          slug: 'virtuelles-schalten',
          title: 'Virtuelles Schalten mit BikeControl — und ohne',
          url: '/de/blog/virtuelles-schalten/',
        ),
      },
    ),
  ];

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
    'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
    (_) async => const StandardMessageCodec().encodeMessage(<Object?>[null]),
  );

  /// Mid-ride: everything connected, MyWhoosh receiving.
  Future<void> ready() async {
    core.connection.devices
      ..clear()
      ..addAll([controller, proxy]);
    core.connection.hasDevices.value = true;
    core.settings.setTrainerApp(MyWhoosh());
    core.settings.setKeyMap(MyWhoosh());
    await core.settings.setLastTarget(Target.thisDevice);
    core.actionHandler.init(MyWhoosh());
    await core.settings.setClickV2OnboardingDone(true);
    propPrefs.setZwiftClickV2LastUnlock(controller.scanResult.deviceId, DateTime.now());
    core.settings.setObpMdnsEnabled(true);
    core.obpMdnsEmulator.isStarted.value = true;
    core.obpMdnsEmulator.isConnected.value = true;
    proxy.debugSetTrainerAppConnected(true);
    proxy.debugAttachFitnessBike(definition);
    await core.settings.setSeenBlogPosts(const []);
    BlogNewsController.debugFetchOverride = () async => posts;
  }

  setUp(ready);
  tearDown(() {
    BlogNewsController.debugFetchOverride = null;
    debugHostPlatformOverride = null;
    activityLogClock = DateTime.now;
    screenshotMode = true;
  });

  Future<void> shoot(
    WidgetTester tester, {
    required String name,
    required Size size,
    required Brightness brightness,
    required Widget Function(BuildContext) build,
    String locale = 'de',
    Future<void> Function(WidgetTester tester)? beforeCapture,
  }) async {
    await captureWidget(
      tester,
      name: name,
      width: size.width,
      height: size.height,
      padding: EdgeInsets.zero,
      pixelRatio: 2,
      brightness: brightness,
      settle: false,
      outputDir: outDir,
      locales: [locale],
      beforeCapture: beforeCapture,
      builder: build,
    );
    await disposeShell(tester);
  }

  const phone = Size(390, 844);
  const desktop = Size(1280, 800);

  testWidgets('warm-up', (tester) async {
    await shoot(tester, name: 'warm-up', size: phone, brightness: Brightness.dark, build: (_) => const Navigation());
  });

  // ── 1. Toasts ─────────────────────────────────────────────────────────
  // The harness's own toast layer sits outside the captured boundary, so the
  // shell gets one inside it, placed the way the app places them.
  BuildContext? toastContext;
  Widget withToasts(Widget child) => BkToastTheme(
    child: ToastLayer(
      child: Builder(
        builder: (context) {
          toastContext = context;
          return child;
        },
      ),
    ),
  );
  Future<void> showToasts(WidgetTester tester) async {
    final l = AppLocalizations.current;
    showBkToast(
      toastContext!,
      title: l.chainForgotten('Zwift Click'),
      closeTitle: l.chainUndo,
      onClose: () {},
      duration: const Duration(minutes: 1),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  for (final brightness in Brightness.values) {
    testWidgets('toast-390x844-${brightness.name}-de', (tester) async {
      await shoot(
        tester,
        name: 'toast-390x844-${brightness.name}-de',
        size: phone,
        brightness: brightness,
        build: (_) => withToasts(const Navigation()),
        beforeCapture: showToasts,
      );
    });
  }

  testWidgets('toast-1280x800-dark-de', (tester) async {
    await shoot(
      tester,
      name: 'toast-1280x800-dark-de',
      size: desktop,
      brightness: Brightness.dark,
      build: (_) => withToasts(const Navigation()),
      beforeCapture: (tester) async {
        final l = AppLocalizations.current;
        showBkToast(
          toastContext!,
          level: LogLevel.LOGLEVEL_WARNING,
          title: l.sensorConnectFailed,
          duration: const Duration(minutes: 1),
        );
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      },
    );
  });

  // ── 2. Ride, not ready: four steps ────────────────────────────────────
  // The Click V2 has not been unlocked, no connection method is on for
  // MyWhoosh, and the trainer is connected but not picked up by the app.
  Future<void> notReady() async {
    propPrefs.setZwiftClickV2LastUnlock(controller.scanResult.deviceId, DateTime(2020));
    core.settings.setObpMdnsEnabled(false);
    core.obpMdnsEmulator.isStarted.value = false;
    core.obpMdnsEmulator.isConnected.value = false;
    core.settings.setMyWhooshLinkEnabled(false);
    proxy.debugSetTrainerAppConnected(false);
    proxy.emulator.isStarted.value = true;
  }

  for (final (brightness, locale) in [
    (Brightness.dark, 'de'),
    (Brightness.light, 'de'),
    (Brightness.dark, 'en'),
  ]) {
    final name = 'ride-steps-390x844-${brightness.name}-$locale';
    testWidgets(name, (tester) async {
      await notReady();
      await shoot(
        tester,
        name: name,
        size: phone,
        brightness: brightness,
        locale: locale,
        build: (_) => const Navigation(),
      );
    });
  }

  // ── 3. Activity: News and the log ─────────────────────────────────────
  for (final brightness in Brightness.values) {
    testWidgets('activity-news-390x844-${brightness.name}-de', (tester) async {
      await shoot(
        tester,
        name: 'activity-news-390x844-${brightness.name}-de',
        size: phone,
        brightness: brightness,
        build: (_) => const Navigation(initialSection: AppSection.activity),
        beforeCapture: (tester) async {
          await tester.tap(find.descendant(of: find.byType(ActivitySegments), matching: find.text('Neuigkeiten')));
          for (var i = 0; i < 4; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
        },
      );
    });
  }

  testWidgets('activity-news-1280x800-dark-de', (tester) async {
    await shoot(
      tester,
      name: 'activity-news-1280x800-dark-de',
      size: desktop,
      brightness: Brightness.dark,
      build: (_) => const Navigation(initialSection: AppSection.activity),
      beforeCapture: (tester) async {
        await tester.tap(find.descendant(of: find.byType(ActivitySegments), matching: find.text('Neuigkeiten')));
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      },
    );
  });

  testWidgets('activity-log-390x844-dark-de', (tester) async {
    await shoot(
      tester,
      name: 'activity-log-390x844-dark-de',
      size: phone,
      brightness: Brightness.dark,
      build: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) => seedRideActivityLog(controller));
            return const Navigation(initialSection: AppSection.activity);
          },
        ),
      ),
    );
  });

  // ── 4. Settings without the Blog row ──────────────────────────────────
  testWidgets('settings-390x844-dark-de', (tester) async {
    debugHostPlatformOverride = TargetPlatform.iOS;
    await shoot(
      tester,
      name: 'settings-390x844-dark-de',
      size: phone,
      brightness: Brightness.dark,
      build: (_) => const Navigation(initialSection: AppSection.settings),
      beforeCapture: (tester) async {
        await tester.ensureVisible(find.byKey(const ValueKey('settings-app')));
        await tester.pump(const Duration(milliseconds: 100));
      },
    );
  });

  // ── 5. Virtual shifting → Gears, no gear-count warning ────────────────
  testWidgets('vs-gears-390x844-dark-de', (tester) async {
    // MyWhoosh counts 30 gears; this config 24 — the old warning's case.
    definition.setMaxGear(24);
    await shoot(
      tester,
      name: 'vs-gears-390x844-dark-de',
      size: phone,
      brightness: Brightness.dark,
      build: (_) => VirtualShiftingSettingsPage(definition: definition, device: proxy),
      beforeCapture: (tester) async {
        await tester.ensureVisible(find.byType(GearCountRow));
        await tester.pump(const Duration(milliseconds: 100));
      },
    );
  });
}
