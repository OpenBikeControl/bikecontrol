// The same physical trainer is regularly discovered twice — once over BLE and
// once over mDNS/DirCon — and the two entries used to be indistinguishable:
// same name, same "Supports virtual shifting" subtitle, same bike icon. These
// tests pin the four places that now name the upstream transport.
import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/home/home_page.dart';
import 'package:bike_control/pages/onboarding/steps/step_trainer.dart';
import 'package:bike_control/services/trainer_self_test/self_test_result.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/widgets/menu.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/emulators/dircon_emulator.dart' show RetrofitMode;
import 'package:prop/utils/constants.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

Future<void> main() async {
  await AppLocalizations.load(const Locale('en'));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
    core.connection.devices.clear();
  });

  tearDown(() => core.connection.devices.clear());

  BleDevice scan(String id, {String name = 'KICKR CORE 1EB7'}) => BleDevice(
    deviceId: id,
    name: name,
    services: const [FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID],
  );

  ProxyDevice bleTrainer({String id = 'AA:BB:CC:DD:EE:FF'}) => ProxyDevice(scan(id));

  ProxyDevice wifiTrainer({String id = 'dircon://KICKR CORE 1EB7'}) =>
      ProxyDevice.wifi(scan(id), host: '192.168.1.20', port: 36866);

  // Mirrors reveal_overlay_section_test.dart's makeVsDevice(): a trainer with
  // an attached (unprobed) FitnessBikeDefinition, which is what makes the
  // proto=/vsMode=/ftms= diagnostics fields appear in describeProxyDevice at
  // all. Named 'KICKR CORE' by default so device.trainerKey lines up with the
  // 'self_test_KICKR CORE' settings key the self-test group below seeds.
  ProxyDevice trainerWithFitnessBike({
    String id = 'kickr',
    String name = 'KICKR CORE',
    List<BleService>? services,
  }) {
    final device = ProxyDevice(scan(id, name: name))
      ..services = services ?? [BleService(FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID, [])];
    device.debugAttachFitnessBike(
      FitnessBikeDefinition(
        connectedDevice: device.scanResult,
        connectedDeviceServices: device.services!,
        data: ValueNotifier(''),
      ),
    );
    return device;
  }

  /// Mirrors prop's `makeDualProtocol()`: FTMS *with* its Control Point (the
  /// ftms entry in supportedControlProtocols is Control-Point-gated) plus the
  /// Zwift custom service — the only shape where `protoAvail=` has anything to
  /// say.
  List<BleService> dualProtocolServices() => [
    BleService(FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID, [
      BleCharacteristic(FitnessBikeDefinition.FITNESS_MACHINE_CONTROL_POINT_UUID, [
        CharacteristicProperty.write,
        CharacteristicProperty.indicate,
      ], []),
    ]),
    BleService(FtmsMdnsConstants.ZWIFT_PLAY_SERVICE_UUID, [
      BleCharacteristic(FtmsMdnsConstants.ZWIFT_SYNC_RX_CHARACTERISTIC_UUID, [
        CharacteristicProperty.write,
      ], []),
    ]),
  ];

  Future<void> pump(WidgetTester tester, Widget Function(BuildContext) builder) async {
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(child: SizedBox(width: 380, child: Builder(builder: builder))),
      ),
    );
    await tester.pump();
  }

  group('trainer picker names its transport', () {
    // The stage and the radar animate forever, so pump() — never
    // pumpAndSettle() — is the only way through these builds.
    Future<void> pumpPicker(WidgetTester tester, List<ProxyDevice> trainers) => pump(
      tester,
      (c) => SingleChildScrollView(
        child: onboardingTrainerBody(
          c,
          app: SupportedApp.supportedApps.first,
          trainers: trainers,
          onPick: (_) {},
        ),
      ),
    );

    testWidgets('a WiFi trainer reads "WiFi · Supports virtual shifting"', (tester) async {
      await pumpPicker(tester, [wifiTrainer()]);

      expect(find.text('WiFi · Supports virtual shifting'), findsOneWidget);
      expect(find.text('Bluetooth · Supports virtual shifting'), findsNothing);
      // …and the bare meta line, which both duplicates used to show, is gone.
      expect(find.text('Supports virtual shifting'), findsNothing);
    });

    testWidgets('a Bluetooth trainer reads "Bluetooth · Supports virtual shifting"', (tester) async {
      await pumpPicker(tester, [bleTrainer()]);

      expect(find.text('Bluetooth · Supports virtual shifting'), findsOneWidget);
      expect(find.text('WiFi · Supports virtual shifting'), findsNothing);
    });

    testWidgets('two entries for one trainer are told apart by subtitle and icon', (tester) async {
      await pumpPicker(tester, [bleTrainer(), wifiTrainer()]);

      // Same name twice — that is the support case — but two distinct rows.
      expect(find.text('KICKR CORE 1EB7'), findsNWidgets(2));
      expect(find.text('WiFi · Supports virtual shifting'), findsOneWidget);
      expect(find.text('Bluetooth · Supports virtual shifting'), findsOneWidget);

      // The leading mark carries the transport too; the generic bike icon that
      // said nothing about either row is no longer used for trainers.
      expect(find.byIcon(LucideIcons.bike), findsNothing);
      expect(find.byIcon(LucideIcons.wifi), findsOneWidget);
      // One in each row's leading slot… plus the scan card's own radar mark.
      expect(find.byIcon(LucideIcons.bluetooth), findsNWidgets(2));
    });

    testWidgets('the connected variant names the transport as well', (tester) async {
      final trainer = wifiTrainer()..debugSetTrainerAppConnected(true);
      expect(trainer.isBridged, isTrue);

      await pumpPicker(tester, [trainer]);

      expect(find.text('WiFi · Supports virtual shifting'), findsOneWidget);
      expect(find.byIcon(LucideIcons.wifi), findsOneWidget);
      expect(find.byIcon(LucideIcons.bike), findsNothing);
    });

    testWidgets('picker icons come straight from the helper', (tester) async {
      expect(onboardingTrainerIcon(wifiTrainer()), LucideIcons.wifi);
      expect(onboardingTrainerIcon(bleTrainer()), LucideIcons.bluetooth);
    });
  });

  group('nameBadge', () {
    Future<Widget?> badgeOf(WidgetTester tester, ProxyDevice device) async {
      Widget? badge;
      await pump(tester, (c) {
        badge = device.nameBadge(c);
        return badge ?? const SizedBox.shrink();
      });
      return badge;
    }

    testWidgets('a lone WiFi trainer still gets a WiFi badge', (tester) async {
      // No duplicate registered anywhere — the old exact-name gate returned
      // null here, which is precisely the case support kept hitting: the two
      // entries differ slightly (BLE advertisement vs DirCon service name).
      final badge = await badgeOf(tester, wifiTrainer());
      expect(badge, isA<Icon>());
      expect((badge as Icon).icon, LucideIcons.wifi);
    });

    testWidgets('a lone BLE trainer gets a Bluetooth badge', (tester) async {
      final badge = await badgeOf(tester, bleTrainer());
      expect((badge as Icon?)?.icon, LucideIcons.bluetooth);
    });

    testWidgets('non-trainers stay unbadged', (tester) async {
      final hrStrap = ProxyDevice(BleDevice(
        deviceId: 'hr',
        name: 'TICKR',
        services: const [FitnessBikeDefinition.HEART_RATE_MEASUREMENT_UUID],
      ));
      expect(hrStrap.isSmartTrainer, isFalse);
      expect(await badgeOf(tester, hrStrap), isNull);
    });
  });

  group('diagnostics bundle', () {
    test('records the upstream transport next to the downstream mode', () {
      expect(describeProxyDevice(wifiTrainer()), contains('upstream=wifi'));
      expect(describeProxyDevice(bleTrainer()), contains('upstream=ble'));
    });

    test('upstream is not the retrofit mode', () {
      // A BLE-discovered trainer bridged in wifi retrofit mode: `mode=` and
      // `upstream=` disagree on purpose, and that is the whole point of the
      // new field.
      final device = bleTrainer();
      device.setRetrofitMode(RetrofitMode.wifi);
      final line = describeProxyDevice(device);
      expect(line, contains('upstream=ble'));
      expect(line, contains('mode=wifi'));
    });

    test('trainer line carries proto, vsMode, ftms capability and selfTest', () async {
      SharedPreferences.setMockInitialValues({
        'self_test_KICKR CORE': SelfTestResult(
          at: DateTime(2026, 8, 20),
          verdict: SelfTestVerdict.pass,
          ergStepsPassed: 3,
          ergStepsTotal: 3,
          shiftStepsPassed: 3,
          shiftStepsTotal: 3,
          vsMode: 'targetPower',
          protocol: 'ftms',
        ).toJsonString(),
      });
      core.settings.prefs = await SharedPreferences.getInstance();

      final device = trainerWithFitnessBike();

      final line = describeProxyDevice(device);
      expect(line, contains('proto=ftms'));
      expect(line, contains('vsMode=targetPower'));
      expect(line, contains('ftms=unknown')); // unprobed definition
      expect(line, contains('selfTest=PASS,2026-08-20,a:3/3,b:3/3,targetPower'));
      expect(line, isNot(contains('lastCtl='))); // no control write happened
    });

    test('a stored self-test log is printed as its own indented block', () async {
      // The one-line summary keeps the verdict; the per-step lines carry the
      // per-gear plateau numbers support actually needs, so they get their own
      // block under the proxy entry.
      SharedPreferences.setMockInitialValues({
        'self_test_KICKR CORE': SelfTestResult(
          at: DateTime(2026, 8, 20),
          verdict: SelfTestVerdict.pass,
          ergStepsPassed: 3,
          ergStepsTotal: 3,
          shiftStepsPassed: 3,
          shiftStepsTotal: 3,
          vsMode: 'targetPower',
          protocol: 'ftms',
          stepLog: const [
            'start: vs=targetPower protocol=ftms gear=12 erg=false',
            'shift: gear 22 145W vs 142W harder',
          ],
        ).toJsonString(),
      });
      core.settings.prefs = await SharedPreferences.getInstance();

      final line = describeProxyDevice(trainerWithFitnessBike());
      // Inline summary stays put, and the block joins it.
      expect(line, contains('selfTest=PASS,2026-08-20,a:3/3,b:3/3,targetPower'));
      expect(line, contains('Self-test log:'));
      expect(line, contains('shift: gear 22 145W vs 142W harder'));
    });

    test('a self-test with an empty step log prints no log block', () async {
      // Every result stored before this feature has no step log; those bundles
      // must read exactly as before.
      SharedPreferences.setMockInitialValues({
        'self_test_KICKR CORE': SelfTestResult(
          at: DateTime(2026, 8, 20),
          verdict: SelfTestVerdict.pass,
          ergStepsPassed: 3,
          ergStepsTotal: 3,
          shiftStepsPassed: 3,
          shiftStepsTotal: 3,
          vsMode: 'targetPower',
          protocol: 'ftms',
        ).toJsonString(),
      });
      core.settings.prefs = await SharedPreferences.getInstance();

      expect(describeProxyDevice(trainerWithFitnessBike()), isNot(contains('Self-test log:')));
    });

    test('vsMode names the cadence-less fallback that actually drove the trainer', () {
      // A trainer whose telemetry carries no cadence is driven over
      // trackResistance whatever the rider's saved mode says, because the
      // cadence-driven modes would write nothing at all. Showing only the saved
      // mode hides what the trainer was really given — the one thing a "gears
      // change but nothing happens" bundle is read for.
      final device = trainerWithFitnessBike();
      // Power-only IBD (flags 0x41: More Data + power): power lands, cadence
      // never does.
      device.fitnessBike!.onNotification(
        FitnessBikeDefinition.INDOOR_BIKE_DATA_UUID,
        Uint8List.fromList([0x41, 0x00, 0xFA, 0x00]),
      );

      expect(describeProxyDevice(device), contains('vsMode=targetPower\u2192trackResistance'));
    });

    test('trainer line carries the live cadence/power/speed readout', () {
      // A "no resistance" report is settled by whether BikeControl is reading
      // cadence: the VS resistance calc is entirely cadence-driven, so the
      // bundle surfaces raw/filtered cadence plus power and speed.
      final line = describeProxyDevice(trainerWithFitnessBike());
      expect(line, contains('read=cad:'));
      expect(line, contains('pwr:'));
      expect(line, contains('spd:'));
    });

    test('a forced protocol is marked manual and lists what else was available', () {
      // Support's first question on a "my trainer ignores BikeControl" report
      // is whether the rider forced a delivery — auto-picked and rider-picked
      // read identically without the marker.
      final device = trainerWithFitnessBike(services: dualProtocolServices());
      device.fitnessBike!.setControlProtocolOverride(TrainerControlProtocol.zwiftHub);

      final line = describeProxyDevice(device);
      expect(line, contains('proto=zwiftHub(manual)'));
      expect(line, contains('protoAvail=ftms+zwiftHub'));
    });

    test('a Zwift-Sync trainer reports its RideOn handshake state', () {
      // `lastCtl=ok` says the BLE write was accepted, not that the trainer
      // acted on it. Without this field a trainer that never opened its
      // command interface is indistinguishable from one that ignores us.
      final device = trainerWithFitnessBike(services: dualProtocolServices());

      final line = describeProxyDevice(device);
      expect(line, contains('zwiftHandshake=not-started'));
    });

    test('a plain FTMS trainer carries no handshake field', () {
      // Noise on every bundle from a trainer that has no Zwift service.
      expect(describeProxyDevice(trainerWithFitnessBike()), isNot(contains('zwiftHandshake=')));
    });

    test('an auto-picked single-protocol trainer carries neither marker', () {
      final line = describeProxyDevice(trainerWithFitnessBike());

      expect(line, contains('proto=ftms'));
      expect(line, isNot(contains('(manual)')));
      // Nothing to switch to — the field would be noise on every plain FTMS
      // trainer in every bundle.
      expect(line, isNot(contains('protoAvail=')));
    });
  });

  group('describeControllers', () {
    test('renders firmware when known, plain toString otherwise', () {
      final withFw = bleTrainer(id: 'ctrl-with-fw')..firmwareVersion = '1.5.0';
      final withoutFw = bleTrainer(id: 'ctrl-without-fw');

      final s = describeControllers([withFw, withoutFw]);

      expect(s, contains('(fw 1.5.0)'));
      expect(s.split(', ').last, isNot(contains('fw')));
    });
  });

  group('twin subtitle in the trainer list', () {
    // The list entry is BaseDevice.showInformation (ProxyPage renders exactly
    // that), whose meta line comes from ProxyDevice.showMetaInformation.
    Future<void> pumpEntry(WidgetTester tester, ProxyDevice device) =>
        pump(tester, (c) => device.showInformation(c, showFull: false));

    testWidgets('the idle entry says the trainer is held over the other transport', (tester) async {
      final ble = bleTrainer()..isConnected = true;
      final wifi = wifiTrainer();
      core.connection.devices.addAll([ble, wifi]);

      await pumpEntry(tester, wifi);

      expect(find.text('Same trainer over Bluetooth — connecting switches to this path'), findsOneWidget);
      // …in place of the "Connect for:" feature pitch, which the live sibling
      // is already delivering.
      expect(find.textContaining('Connect'), findsNothing);
    });

    testWidgets('the transport named is the one currently in use', (tester) async {
      final ble = bleTrainer();
      final wifi = wifiTrainer()..debugSetTrainerAppConnected(true);
      core.connection.devices.addAll([ble, wifi]);

      await pumpEntry(tester, ble);

      expect(find.text('Same trainer over WiFi — connecting switches to this path'), findsOneWidget);
    });

    testWidgets('no subtitle while the twin is idle, or for a lone entry', (tester) async {
      final ble = bleTrainer();
      final wifi = wifiTrainer();
      core.connection.devices.addAll([ble, wifi]);

      await pumpEntry(tester, wifi);
      expect(find.textContaining('Same trainer over'), findsNothing);

      core.connection.devices.remove(ble);
      await pumpEntry(tester, wifi);
      expect(find.textContaining('Same trainer over'), findsNothing);
    });
  });

  group('chain card picks the live trainer', () {
    test('a bridged duplicate beats an idle one whatever the discovery order', () {
      final idle = wifiTrainer();
      final live = bleTrainer()..debugSetTrainerAppConnected(true);
      core.connection.devices.addAll([idle, live]);

      expect(chainProxy(), same(live));
    });

    test('a connected duplicate beats a merely discovered one', () {
      final discovered = wifiTrainer();
      final connected = bleTrainer()..isConnected = true;
      core.connection.devices.addAll([discovered, connected]);

      expect(chainProxy(), same(connected));
    });

    test('a connecting duplicate beats an idle one', () {
      final idle = wifiTrainer();
      final starting = bleTrainer()..isStarting.value = true;
      core.connection.devices.addAll([idle, starting]);

      expect(chainProxy(), same(starting));
    });

    test('rank order: bridged < connected < starting < idle', () {
      expect(proxyChainRank(bleTrainer()..debugSetTrainerAppConnected(true)), 0);
      expect(proxyChainRank(bleTrainer()..isConnected = true), 1);
      expect(proxyChainRank(bleTrainer()..isStarting.value = true), 2);
      expect(proxyChainRank(bleTrainer()), 3);
    });
  });
}
