import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:bike_control/bluetooth/devices/cycplus/cycplus_bc2.dart';
import 'package:bike_control/bluetooth/devices/elite/elite_sterzo.dart';
import 'package:bike_control/bluetooth/devices/gyroscope/gyroscope_steering.dart';
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/devices/thinkrider/thinkrider_vs200.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_click.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_play.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/pages/button_simulator.dart';
import 'package:bike_control/pages/configuration.dart';
import 'package:bike_control/pages/controller_settings.dart';
import 'package:bike_control/pages/proxy_device_details.dart';
import 'package:bike_control/pages/proxy_device_details/front_shift_card.dart';
import 'package:bike_control/pages/proxy_device_details/gear_ratios_editor_page.dart';
import 'package:bike_control/pages/trainer_connection_settings.dart';
import 'package:bike_control/utils/core.dart' show core;
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/bike_control.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:bike_control/widgets/apps/openbikecontrol_mdns_tile.dart';
import 'package:bike_control/widgets/controller/controller_canvas.dart';
import 'package:bike_control/widgets/overlay/trainer_overlay_view.dart';
import 'package:bike_control/widgets/ui/animated_button_widget.dart';
import 'package:flutter/material.dart' as ma;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart' hide testGoldens;
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/emulators/dircon_emulator.dart';
import 'package:prop/emulators/transporter/network_transporter.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

import 'custom_frame.dart';

enum DeviceType {
  android,
  androidTablet,
  iPhone,
  iPad,
  desktop,
  noFrame,
}

/// Drop-in for golden_screenshot's [testGoldens] that leaves
/// [debugDisableShadows] = false at teardown.
///
/// These screenshot tests run under the live
/// [IntegrationTestWidgetsFlutterBinding] (needed for the real-async Supabase /
/// settings bootstrap in [main]), whose painting-vars invariant requires
/// debugDisableShadows == false. golden_screenshot's own testGoldens resets it
/// to true — correct only for the automated binding — which trips that
/// invariant. Shadows stay enabled during capture, so the goldens are identical.
void testGoldens(
  String description,
  WidgetTesterCallback callback, {
  // Mirrors golden_screenshot's internal kAllowedDiffPercent default.
  double allowedDiffPercent = 0.1,
}) {
  testWidgets(description, (tester) async {
    debugDisableShadows = false;
    tester.useFuzzyComparator(allowedDiffPercent: allowedDiffPercent);
    try {
      await callback(tester);
    } finally {
      debugDisableShadows = false;
    }
  });
}

Future<void> main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  PackageInfo.setMockInitialValues(
    appName: 'BikeControl',
    packageName: 'de.jonasbark.swiftcontrol',
    version: '6.1.0',
    buildNumber: '1',
    buildSignature: '',
  );
  FlutterSecureStorage.setMockInitialValues({});
  SharedPreferences.setMockInitialValues({});
  IAPManager.instance.isPurchased.value = true;

  screenshotMode = true;

  // Some setup (e.g. core.whooshLink) reads AppLocalizations.current before any
  // app widget has loaded the delegate, so load it up front. Without this, a
  // single test run in isolation throws "No instance of AppLocalizations".
  await AppLocalizations.load(const Locale('en'));

  await core.settings.init();
  await core.settings.reset();

  final keymap = MyWhoosh();

  final device =
      ZwiftClickV2(
          BleDevice(
            name: 'Controller',
            deviceId: '00:11:22:33:44:55',
          ),
        )
        ..firmwareVersion = '1.2.0'
        ..isConnected = true
        ..rssi = -51
        ..batteryLevel = 81;

  final proxy =
      ProxyDevice(
          BleDevice(
            name: 'Smart Trainer',
            deviceId: '00:11:22:33:44:55',
            services: [
              FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID,
            ],
          ),
        )
        ..services = [
          BleService(FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID, []),
        ]
        ..firmwareVersion = '1.2.0'
        ..isConnected = true
        ..rssi = -51;

  final fbd = FitnessBikeDefinition(
    connectedDevice: proxy.scanResult,
    connectedDeviceServices: proxy.services!,
    data: ValueNotifier(''),
  )..setDebugValues();
  proxy.emulator.debugSetTransporter(NetworkTransporter(definition: fbd));

  core.connection.addDevices([device, proxy]);

  // Connected instances of every controller we shoot a full connection-card
  // golden for. Each is given a real advertised name (so the card header shows
  // the actual product name) and the connected meta (battery/rssi/firmware) the
  // overview list would display. `device` above is the Zwift Click v2 instance.
  BleDevice scan(String name) => BleDevice(name: name, deviceId: '00:11:22:33:44:55');
  // BLE controllers carry battery / rssi / firmware meta (defined on
  // BluetoothDevice); set it so the card header shows the connected status line.
  T connectedBle<T extends BluetoothDevice>(T d) {
    d
      ..firmwareVersion = '1.2.0'
      ..isConnected = true
      ..rssi = -51
      ..batteryLevel = 81;
    return d;
  }

  final zwiftClick = connectedBle(ZwiftClick(scan('Zwift Click')));
  final zwiftRide = connectedBle(ZwiftRide(scan('Zwift Ride')));
  final zwiftPlay = connectedBle(
    ZwiftPlay(scan('Zwift Play'), deviceType: ZwiftDeviceType.playLeft),
  );
  final cycplusBc2 = connectedBle(CycplusBc2(scan('CYCPLUS BC2')));
  final thinkriderVs200 = connectedBle(ThinkRiderVs200(scan('THINK VS200')));
  final eliteSterzo = connectedBle(EliteSterzo(scan('STERZO')));
  // GyroscopeSteering extends BaseDevice directly (no BLE), so it has no
  // battery/rssi/firmware — just mark it connected.
  final gyroSteering = GyroscopeSteering()..isConnected = true;

  // All controllers must live in core.connection.devices so the MyWhoosh
  // action handler (initialized below) seeds each button's default in-game
  // action into the keymap — that's what renders the action badges.
  core.connection.addDevices([
    zwiftClick,
    zwiftRide,
    zwiftPlay,
    cycplusBc2,
    thinkriderVs200,
    eliteSterzo,
    gyroSteering,
  ]);

  // core.actionHandler is `late` (assigned in the app's main(), which the test
  // harness never runs). Provide a StubActions and init it with MyWhoosh so
  // core.actionHandler.supportedApp?.keymap is the populated MyWhoosh keymap the
  // connected-Controllers footer passes to AnimatedButtonWidget.
  core.actionHandler = StubActions();
  core.actionHandler.init(MyWhoosh());

  final firstButton = ZwiftButtons.b.copyWith(sourceDeviceId: device.uniqueId);
  final keyEntry = keymap.keymap.getOrCreateKeyPair(firstButton, trigger: ButtonTrigger.longPress);
  keyEntry.inGameAction = InGameAction.steerRight;

  core.settings.setRetrofitMode(proxy.trainerKey, RetrofitMode.wifi);
  core.settings.setTrainerApp(keymap);
  core.settings.setKeyMap(keymap);
  core.settings.setLastTarget(Target.thisDevice);

  final List<({DeviceType type, TargetPlatform platform, Size size})> sizes = [
    (type: DeviceType.android, platform: TargetPlatform.android, size: Size(1320, 2868)),
    (type: DeviceType.androidTablet, platform: TargetPlatform.android, size: Size(3840, 2400)),
    (type: DeviceType.iPhone, platform: TargetPlatform.iOS, size: Size(1242, 2688)),
    (type: DeviceType.iPad, platform: TargetPlatform.iOS, size: Size(2752, 2064)),
    (type: DeviceType.desktop, platform: TargetPlatform.windows, size: Size(2560, 1600)),
    (type: DeviceType.noFrame, platform: TargetPlatform.windows, size: Size(1320, 2868) / 1.2),
    /*('iPhone', Size(1242, 2688)),
    ('macOS', Size(1280, 800)),
    ('GitHub', Size(600, 900)),*/
  ];

  debugDisableShadows = true;

  // Locales to render — one screenshot folder per language so the store
  // listings get genuinely localized screenshots (instead of the English ones
  // copied to every locale).
  const screenshotLocales = ['en', 'de', 'es', 'fr', 'it', 'pl'];

  // Marketing headline per scene, per locale. English is the source of truth;
  // the other languages are drafts — review/adjust the copy as needed.
  const titles = <String, Map<String, String>>{
    'device': {
      'en': 'Control any trainer with ANY controller',
      'de': 'Steuere jeden Trainer mit JEDEM Controller',
      'es': 'Controla cualquier rodillo con CUALQUIER mando',
      'fr': 'Contrôlez n’importe quel home-trainer avec N’IMPORTE QUEL contrôleur',
      'it': 'Controlla qualsiasi rullo con QUALSIASI controller',
      'pl': 'Steruj każdym trenażerem DOWOLNYM kontrolerem',
    },
    'trainer': {
      'en': 'Connect BikeControl to your trainer',
      'de': 'Verbinde BikeControl mit deinem Trainer',
      'es': 'Conecta BikeControl a tu rodillo',
      'fr': 'Connectez BikeControl à votre home-trainer',
      'it': 'Collega BikeControl al tuo rullo',
      'pl': 'Połącz BikeControl ze swoim trenażerem',
    },
    'customization': {
      'en': 'Customize every controller button',
      'de': 'Passe jede Controller-Taste an',
      'es': 'Personaliza cada botón del mando',
      'fr': 'Personnalisez chaque bouton du contrôleur',
      'it': 'Personalizza ogni pulsante del controller',
      'pl': 'Dostosuj każdy przycisk kontrolera',
    },
    'companion': {
      'en': 'Companion App mode with custom hotkeys',
      'de': 'Companion-App-Modus mit eigenen Tastenkürzeln',
      'es': 'Modo app complementaria con atajos personalizados',
      'fr': 'Mode application compagnon avec raccourcis personnalisés',
      'it': 'Modalità app companion con scorciatoie personalizzate',
      'pl': 'Tryb aplikacji towarzyszącej z własnymi skrótami',
    },
    'virtualshifting': {
      'en': 'Add or adjust Virtual Shifting functionality',
      'de': 'Virtuelles Schalten hinzufügen oder anpassen',
      'es': 'Añade o ajusta el cambio virtual',
      'fr': 'Ajoutez ou réglez le passage de vitesses virtuel',
      'it': 'Aggiungi o regola il cambio virtuale',
      'pl': 'Dodaj lub dostosuj wirtualną zmianę biegów',
    },
    'virtualshifting-settings': {
      'en': 'Full Control of Virtual Shifting',
      'de': 'Volle Kontrolle über das virtuelle Schalten',
      'es': 'Control total del cambio virtual',
      'fr': 'Contrôle total du passage de vitesses virtuel',
      'it': 'Controllo totale del cambio virtuale',
      'pl': 'Pełna kontrola nad wirtualną zmianą biegów',
    },
  };

  // Renders [scene] for every locale × device size and writes
  // ../screenshots/<locale>/<scene>-<device>-<WxH>.png.
  Future<void> shoot(
    WidgetTester tester,
    String scene,
    Widget Function() homeBuilder, {
    Future<void> Function(WidgetTester tester)? afterPump,
  }) async {
    final sceneTitles = titles[scene]!;
    // core.settings.reset() (in main) clears this, so re-assert the Base version
    // is active — otherwise the overview shows the "N day trial available" banner.
    IAPManager.instance.isPurchased.value = true;
    for (final loc in screenshotLocales) {
      await AppLocalizations.load(Locale(loc));
      screenshotLocale = Locale(loc);
      for (final size in sizes) {
        await tester.pumpWidget(
          ScreenshotApp(
            locale: Locale(loc),
            device: ScreenshotDevice(
              platform: size.platform,
              resolution: size.size,
              pixelRatio: 3,
              goldenSubFolder: 'iphoneScreenshots/',
              frameBuilder:
                  ({
                    required ScreenshotDevice device,
                    required ScreenshotFrameColors? frameColors,
                    required Widget child,
                  }) => CustomFrame(
                    platform: size.type,
                    title: sceneTitles[loc] ?? sceneTitles['en']!,
                    device: device,
                    child: child,
                  ),
            ),
            home: homeBuilder(),
          ),
        );

        await tester.pump();
        if (afterPump != null) await afterPump(tester);
        // golden_screenshot v9+ only loads fonts found in the rendered widget
        // tree, so load after the first pump (then re-render with them).
        await tester.loadAssets();
        await tester.pump();
        await expectLater(
          find.byType(ma.Scaffold),
          matchesGoldenFile(
            '../screenshots/$loc/$scene-${size.type.name}-${size.size.width.toInt()}x${size.size.height.toInt()}.png',
          ),
        );
      }
    }
  }

  // Blog screenshot: a single clean frameless (noFrame) English shot written to
  // ../screenshots/en/<scene>-noFrame-1100x2390.png — used for the website blog,
  // not the localized App Store matrix that [shoot] produces.
  Future<void> shootOne(
    WidgetTester tester,
    String scene,
    Widget Function() home, {
    Finder Function()? capture,
    Future<void> Function(WidgetTester tester)? afterPump,
    TargetPlatform platform = TargetPlatform.android,
  }) async {
    final nf = sizes.firstWhere((s) => s.type == DeviceType.noFrame);
    await AppLocalizations.load(const Locale('en'));
    screenshotLocale = const Locale('en');
    await tester.pumpWidget(
      ScreenshotApp(
        locale: const Locale('en'),
        device: ScreenshotDevice(
          // Default Android, never the entry's Windows platform: shadcn's theme
          // queries the Windows accent colour via advapi32.dll, which can't load
          // on a macOS test host.
          platform: platform,
          resolution: nf.size,
          pixelRatio: 3,
          goldenSubFolder: 'iphoneScreenshots/',
          frameBuilder:
              ({
                required ScreenshotDevice device,
                required ScreenshotFrameColors? frameColors,
                required Widget child,
              }) => CustomFrame(platform: DeviceType.noFrame, title: '', device: device, child: child),
        ),
        home: home(),
      ),
    );
    await tester.pump();
    if (afterPump != null) await afterPump(tester);
    await tester.loadAssets();
    await tester.pump();
    await expectLater(
      capture?.call() ?? find.byType(ma.Scaffold),
      matchesGoldenFile('../screenshots/en/$scene.png'),
    );
  }

  // Localized widget snapshot: like [shootOne], but renders the (frameless,
  // noFrame) widget once per locale and writes ../screenshots/<loc>/<scene>.png.
  // Used for the website setup guides, which show the matching-language widget
  // screenshots. The website uses the en/de/es/fr/it intersection of the app's
  // and the site's supported locales; Czech falls back to en on the website.
  Future<void> shootLocalized(
    WidgetTester tester,
    String scene,
    Widget Function() home, {
    Finder Function()? capture,
    Future<void> Function(WidgetTester tester)? afterPump,
    TargetPlatform platform = TargetPlatform.android,
  }) async {
    const widgetLocales = ['en', 'de', 'es', 'fr', 'it'];
    final nf = sizes.firstWhere((s) => s.type == DeviceType.noFrame);
    for (final loc in widgetLocales) {
      await AppLocalizations.load(Locale(loc));
      screenshotLocale = Locale(loc);
      await tester.pumpWidget(
        ScreenshotApp(
          locale: Locale(loc),
          device: ScreenshotDevice(
            // Default Android, never the entry's Windows platform: shadcn's theme
            // queries the Windows accent colour via advapi32.dll, which can't load
            // on a macOS test host.
            platform: platform,
            resolution: nf.size,
            pixelRatio: 3,
            goldenSubFolder: 'iphoneScreenshots/',
            frameBuilder:
                ({
                  required ScreenshotDevice device,
                  required ScreenshotFrameColors? frameColors,
                  required Widget child,
                }) => CustomFrame(platform: DeviceType.noFrame, title: '', device: device, child: child),
          ),
          home: home(),
        ),
      );
      await tester.pump();
      if (afterPump != null) await afterPump(tester);
      await tester.loadAssets();
      await tester.pump();
      await expectLater(
        capture?.call() ?? find.byType(ma.Scaffold),
        matchesGoldenFile('../screenshots/$loc/$scene.png'),
      );
    }
  }

  testGoldens('Device', (WidgetTester tester) async {
    await shoot(tester, 'device', () => BikeControlApp());
  });

  testGoldens('Trainer', (WidgetTester tester) async {
    core.settings.setTrainerApp(BikeControl());
    core.settings.setKeyMap(BikeControl());
    await shoot(
      tester,
      'trainer',
      () => BikeControlApp(customChild: TrainerConnectionSettingsPage()),
    );
  });

  testGoldens('Customization', (WidgetTester tester) async {
    core.settings.setTrainerApp(keymap);
    core.settings.setKeyMap(keymap);
    await shoot(
      tester,
      'customization',
      () => BikeControlApp(customChild: ControllerSettingsPage(device: device)),
    );
  });

  testGoldens('Trainer Controls', (WidgetTester tester) async {
    core.settings.setTrainerApp(keymap);
    core.settings.setKeyMap(keymap);
    core.settings.setMyWhooshLinkEnabled(true);
    core.whooshLink.isConnected.value = true;
    await shoot(
      tester,
      'companion',
      () => BikeControlApp(customChild: ButtonSimulator()),
    );
  });

  testGoldens('Virtual Shifting', (WidgetTester tester) async {
    core.settings.setTrainerApp(keymap);
    core.settings.setKeyMap(keymap);
    core.settings.setMyWhooshLinkEnabled(true);
    core.whooshLink.isConnected.value = true;
    // Put the proxy into virtual-shifting mode so the page shows the gear UI
    // instead of the "trainer doesn't advertise FTMS" warning.
    proxy.debugAttachFitnessBike(fbd);
    await shoot(
      tester,
      'virtualshifting',
      () => BikeControlApp(customChild: ProxyDeviceDetailsPage(device: proxy)),
    );
  });

  testGoldens('Virtual Shifting Settings', (WidgetTester tester) async {
    core.settings.setTrainerApp(Zwift());
    core.settings.setKeyMap(Zwift());
    core.settings.setMyWhooshLinkEnabled(true);
    core.whooshLink.isConnected.value = true;
    await shoot(
      tester,
      'virtualshifting-settings',
      () => BikeControlApp(
        customChild: GearRatiosEditorPage(
          device: proxy,
          definition: fbd,
        ),
      ),
    );
  });

  // --- 6.2 Virtual front derailleur (blog widget snapshots) ---
  // Each widget is rendered standalone inside a keyed RepaintBoundary so the
  // golden captures ONLY that widget (no page chrome).

  // The second-window / desktop gear overlay (TrainerOverlayView), as shown on
  // Windows & macOS. Large ring → the primary readout uses the 2×N position
  // notation (here 2×14). Mirrors desktop_overlay_window: bare overlay on white.
  testGoldens('Front Derailleur Gear', (WidgetTester tester) async {
    const k = ValueKey('shot');
    final state = ValueNotifier<TrainerOverlayState>(
      const TrainerOverlayState(
        gear: 14,
        maxGear: 24,
        gearRatio: 3.53,
        mode: TrainerMode.simMode,
        powerW: 250,
        cadenceRpm: 90,
        ergTargetW: null,
        fields: {OverlayField.power, OverlayField.cadence},
        frontShiftEnabled: true,
        frontRingLarge: true,
      ),
    );
    await shootOne(
      tester,
      'frontderailleur-gear',
      () => BikeControlApp(
        customChild: Center(
          child: RepaintBoundary(
            key: k,
            child: ColoredBox(
              color: const Color(0xFFFFFFFF),
              child: SizedBox(
                width: 240,
                child: TrainerOverlayView(state: state, onModeToggle: null),
              ),
            ),
          ),
        ),
      ),
      capture: () => find.byKey(k),
      platform: TargetPlatform.macOS,
    );
  });

  // The front-derailleur setting card, enabled so the chainring steppers show.
  testGoldens('Front Derailleur Setting', (WidgetTester tester) async {
    await core.shiftingConfigs.upsert(
      core.shiftingConfigs.activeFor(proxy.trainerKey).copyWith(
            frontShiftEnabled: true,
            smallChainringTeeth: 34,
            largeChainringTeeth: 50,
          ),
    );
    const k = ValueKey('shot');
    await shootOne(
      tester,
      'frontderailleur-setting',
      () => BikeControlApp(
        customChild: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: RepaintBoundary(key: k, child: FrontShiftCard(device: proxy)),
          ),
        ),
      ),
      capture: () => find.byKey(k),
    );
  });

  // --- MyWhoosh setup-guide widget snapshots (website setup guide) ---
  // Tight single-widget captures of the two BikeControl controls the MyWhoosh
  // setup guide walks through: the trainer-app picker (showing MyWhoosh) and the
  // "Connect directly over Network" connection method. Rendered standalone inside
  // a keyed RepaintBoundary so the golden captures ONLY the widget.

  // The trainer-app picker with MyWhoosh selected. screenshotMode stays on (it
  // suppresses the real BLE bootstrap) and TrainerAppSelect.showRealName forces
  // the closed Select to show the real "MyWhoosh" name + logo instead of the
  // generic "Trainer app" placeholder the marketing screenshots use.
  testGoldens('mywhoosh-trainer-select', (WidgetTester tester) async {
    core.settings.setTrainerApp(MyWhoosh());
    core.settings.setKeyMap(MyWhoosh());
    const k = ValueKey('shot');
    await shootLocalized(
      tester,
      'mywhoosh-trainer-select',
      () => BikeControlApp(
        customChild: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: RepaintBoundary(
              key: k,
              child: TrainerAppSelect(onUpdate: () {}, showRealName: true),
            ),
          ),
        ),
      ),
      capture: () => find.byKey(k),
    );
  });

  // The Network connection method (OpenBikeControl over mDNS), as shown for
  // MyWhoosh, in its disabled/off state. The tile passes no requirements, so no
  // real BLE is touched even though screenshotMode hides the "Recommended" badge.
  testGoldens('mywhoosh-network-connection', (WidgetTester tester) async {
    core.settings.setTrainerApp(MyWhoosh());
    core.settings.setKeyMap(MyWhoosh());
    core.settings.setObpMdnsEnabled(false);
    // Force the off / not-yet-connected state so the captured card is identical
    // regardless of any emulator state a prior scene left behind (the shown
    // description and height depend on isStarted/connectedApp).
    core.obpMdnsEmulator.isStarted.value = false;
    core.obpMdnsEmulator.connectedApp.value = null;
    const k = ValueKey('shot');
    await shootLocalized(
      tester,
      'mywhoosh-network-connection',
      () => BikeControlApp(
        customChild: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: RepaintBoundary(
              key: k,
              child: OpenBikeControlMdnsTile(small: false),
            ),
          ),
        ),
      ),
      capture: () => find.byKey(k),
    );
  });

  // --- Full connection card (connected-controller list entry) ---
  // The complete card the overview's Controllers list renders for a connected
  // controller: `device.showInformation` draws the header Row (StatusIcon +
  // name + Beta pill + status meta) and, below it, the footer — the
  // `ControllerCanvas` contour with its buttons. Two deviations from the live
  // app, both deliberate so the image is chrome-free:
  //   * `showSettingsIcon: false` hides the small header gear (settings live on
  //     a separate page, not in this card).
  //   * `showAdditionalInfo: false` drops the device's own state chrome (e.g.
  //     the Zwift Click unlock warning) so the card is state-agnostic.
  // The footer's buttons DO carry the MyWhoosh keymap (via
  // `core.actionHandler.supportedApp?.keymap`), so each button that maps to an
  // in-game action renders its supported-action badge — exactly like the
  // connected-Controllers list. Buttons with no action (e.g. pure steering on
  // the Sterzo / phone) render as bare buttons.
  //
  // `ZwiftClickV2.toString()` anonymizes its name to "Controller" while the
  // marketing `screenshotMode` is on; we flip it off *synchronously* around just
  // the `showInformation` build so the header shows the real product name — and
  // restore it immediately, before any async (the app's connection-init scan
  // reads `screenshotMode` on a later microtask, by which point it is true
  // again, so no BLE scan fires). Only ClickV2 needs this, but doing it
  // uniformly is harmless for the other devices.
  //
  // Rendered inside `BikeControlApp` so the card has the real theme and an
  // `i18n` context, standalone in a keyed RepaintBoundary (captured tight) at a
  // fixed list-card width.
  Future<void> shootCard(WidgetTester tester, String scene, BaseDevice cardDevice) async {
    const k = ValueKey('shot');
    final savedScreenshotMode = screenshotMode;
    try {
      await shootOne(
        tester,
        scene,
        () => BikeControlApp(
          customChild: SingleChildScrollView(
            child: Center(
              child: SizedBox(
                width: 340,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Builder(
                    builder: (context) {
                      // Footer mirrors overview.dart's footerBuilder: the
                      // active app's keymap drives the per-button action badges.
                      final keymap = core.actionHandler.supportedApp?.keymap;
                      final size = 56 / Theme.of(context).scaling;
                      Widget btnFor(ControllerButton btn) => AnimatedButtonWidget(
                            key: ValueKey(btn.name),
                            button: btn,
                            pressGeneration: 0,
                            keymap: keymap,
                            device: cardDevice,
                            size: size,
                            onUpdate: () {},
                          );
                      final footer = ControllerCanvas(
                        layout: cardDevice.controllerLayout!,
                        availableButtons: cardDevice.availableButtons,
                        buttonBuilder: btnFor,
                        buttonSize: size,
                      );
                      // Flip screenshotMode off only for this synchronous build
                      // so the header shows the real product name, then restore
                      // it before control returns to the framework.
                      final saved = screenshotMode;
                      screenshotMode = false;
                      final card = cardDevice.showInformation(
                        context,
                        showFull: false,
                        showSettingsIcon: false,
                        showAdditionalInfo: false,
                        footer: footer,
                      );
                      screenshotMode = saved;
                      return RepaintBoundary(key: k, child: card);
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        capture: () => find.byKey(k),
      );
    } finally {
      screenshotMode = savedScreenshotMode;
    }
  }

  testGoldens('controller-zwift-click', (WidgetTester tester) async {
    await shootCard(tester, 'controller-zwift-click', zwiftClick);
  });

  testGoldens('controller-zwift-click-v2', (WidgetTester tester) async {
    await shootCard(tester, 'controller-zwift-click-v2', device);
  });

  testGoldens('controller-zwift-ride', (WidgetTester tester) async {
    await shootCard(tester, 'controller-zwift-ride', zwiftRide);
  });

  testGoldens('controller-zwift-play', (WidgetTester tester) async {
    await shootCard(tester, 'controller-zwift-play', zwiftPlay);
  });

  testGoldens('controller-cycplus-bc2', (WidgetTester tester) async {
    await shootCard(tester, 'controller-cycplus-bc2', cycplusBc2);
  });

  testGoldens('controller-thinkrider-vs200', (WidgetTester tester) async {
    await shootCard(tester, 'controller-thinkrider-vs200', thinkriderVs200);
  });

  testGoldens('controller-elite-sterzo', (WidgetTester tester) async {
    await shootCard(tester, 'controller-elite-sterzo', eliteSterzo);
  });

  testGoldens('controller-phone-steering', (WidgetTester tester) async {
    await shootCard(tester, 'controller-phone-steering', gyroSteering);
  });
}
