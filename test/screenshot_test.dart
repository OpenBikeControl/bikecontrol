import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/pages/button_simulator.dart';
import 'package:bike_control/pages/controller_settings.dart';
import 'package:bike_control/pages/proxy_device_details.dart';
import 'package:bike_control/pages/proxy_device_details/gear_ratios_editor_page.dart';
import 'package:bike_control/pages/trainer_connection_settings.dart';
import 'package:bike_control/utils/core.dart' show core;
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/bike_control.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:flutter/material.dart' as ma;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart' hide testGoldens;
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/emulators/dircon_emulator.dart';
import 'package:prop/emulators/transporter/network_transporter.dart';
import 'package:prop/protocol/zp.pbenum.dart';
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
    version: '5.4.0',
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

  testGoldens('Device', (WidgetTester tester) async {
    await shoot(
      tester,
      'device',
      () => BikeControlApp(),
      afterPump: (tester) async {
        core.connection.signalNotification(
          AlertNotification(LogLevel.LOGLEVEL_INFO, 'Connecting to: ${device.toString()}'),
        );
        core.connection.signalNotification(
          AlertNotification(LogLevel.LOGLEVEL_INFO, 'Connection finished: ${device.toString()}'),
        );
        await tester.pump();
      },
    );
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
}
