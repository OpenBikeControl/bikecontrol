// The trackResistance physics assume the rider's real chain sits in a middle
// gear. A chain left on a very big (or very small) gear makes virtual shifting
// feel wrong without anything on screen saying why, so the trainer page asks
// the rider to move it while the definition says so.
import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/proxy_device_details.dart';
import 'package:bike_control/pages/proxy_device_details/chain_position_hint_card.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/transports/trainer_transport.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

/// Keeps the definition's upstream writes off the real BLE stack.
class _SilentTransport implements TrainerTransport {
  @override
  String get id => 'silent';
  @override
  void Function()? onDisconnected;
  @override
  Future<void> connect() async {}
  @override
  Future<List<BleService>> discoverServices() async => const [];
  @override
  Future<Uint8List> read(String service, String characteristic) async => Uint8List(0);
  @override
  Future<void> write(String s, String c, Uint8List b, {bool withoutResponse = false}) async {}
  @override
  Future<void> subscribe(String s, String c, {required bool indicate}) async {}
  @override
  Stream<({String characteristic, Uint8List value})> get notifications => const Stream.empty();
  @override
  Future<void> disconnect() async {}
}

Future<void> main() async {
  await AppLocalizations.load(const Locale('en'));
  final l = AppLocalizations.current;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
  });

  tearDown(() => core.connection.devices.clear());

  ProxyDevice trainer({String name = 'Smart Trainer 1234'}) {
    final device = ProxyDevice(
      BleDevice(
        deviceId: 'smart-trainer',
        name: name,
        services: const [FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID],
      ),
    )..services = [
        BleService(FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID, [
          BleCharacteristic(FitnessBikeDefinition.FITNESS_MACHINE_CONTROL_POINT_UUID, [
            CharacteristicProperty.write,
            CharacteristicProperty.indicate,
          ], []),
        ]),
      ];
    final def = FitnessBikeDefinition(
      connectedDevice: device.scanResult,
      connectedDeviceServices: device.services!,
      data: ValueNotifier(''),
      transport: _SilentTransport(),
    );
    device.debugAttachFitnessBike(def);
    def.setVirtualShiftingMode(VirtualShiftingMode.trackResistance);
    def.trainerModeForTesting = TrainerMode.simModeVirtualShifting;
    return device;
  }

  var now = DateTime(2026, 10, 11, 8);

  /// [seconds] of Indoor Bike Data at 2 Hz, 64 rpm, on a real chain [ratio].
  void ride(FitnessBikeDefinition def, double ratio, {int seconds = 22}) {
    def.debugClock = () => now;
    final speed = (64 / 60 * ratio * 0.7 * 3.14159 * 360).round();
    for (var i = 0; i < seconds * 2; i++) {
      def.onNotification(
        FitnessBikeDefinition.INDOOR_BIKE_DATA_UUID,
        Uint8List.fromList([0x44, 0x00, speed & 0xFF, speed >> 8, 128, 0x00, 0x2C, 0x01]),
      );
      now = now.add(const Duration(milliseconds: 500));
    }
  }

  Future<void> pumpCard(WidgetTester tester, FitnessBikeDefinition def, {bool chainSet = false}) async {
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(
          child: SizedBox(width: 380, child: ChainPositionHintCard(definition: def, chainSet: chainSet)),
        ),
      ),
    );
    await tester.pump();
  }

  // With the real chain set, the band is around that chain, and the hint says
  // the chain is not where the rider set it rather than "middle gear".
  testWidgets('with a real chain set, says the chain is off the set one', (tester) async {
    final def = trainer().fitnessBike!;
    def.setRealChainRatio(53 / 12);
    await pumpCard(tester, def, chainSet: true);

    ride(def, 2.0);
    await tester.pump();
    expect(find.text(l.chainHintSetTitle), findsOneWidget);
    expect(find.text(l.chainHintSetBody('2.0', '4.4')), findsOneWidget);
    expect(find.text(l.chainHintTitle), findsNothing);
    await tester.pump(const Duration(seconds: 6));
  });

  // 36/18 is 2:1 like the default 34/17, but the rider set it.
  testWidgets('a real chain set to 2:1 still counts as set', (tester) async {
    final def = trainer().fitnessBike!;
    def.setRealChainRatio(36 / 18);
    await pumpCard(tester, def, chainSet: true);

    ride(def, 4.5);
    await tester.pump();
    expect(find.text(l.chainHintSetTitle), findsOneWidget);
    expect(find.text(l.chainHintTitle), findsNothing);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('appears while the chain sits on a very big gear, and goes when it moves', (tester) async {
    final def = trainer().fitnessBike!;
    await pumpCard(tester, def);
    expect(find.text(l.chainHintTitle), findsNothing);

    ride(def, 4.5);
    await tester.pump();
    expect(find.text(l.chainHintTitle), findsOneWidget);
    expect(find.text(l.chainHintVeryBigGear('4.5')), findsOneWidget);

    ride(def, 2.0, seconds: 5);
    await tester.pump();
    expect(find.text(l.chainHintTitle), findsNothing);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('names a very small gear on the low side', (tester) async {
    final def = trainer().fitnessBike!;
    await pumpCard(tester, def);
    ride(def, 1.1);
    await tester.pump();
    expect(find.text(l.chainHintVerySmallGear('1.1')), findsOneWidget);
    expect(find.text(l.chainHintVeryBigGear('1.1')), findsNothing);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('never appears on a smart bike, which has no real chain', (tester) async {
    final def = trainer(name: 'KICKR BIKE 1A2B').fitnessBike!;
    await pumpCard(tester, def);
    ride(def, 4.5, seconds: 60);
    await tester.pump();
    expect(find.text(l.chainHintTitle), findsNothing);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('goes away when virtual shifting stops using the grade physics', (tester) async {
    final def = trainer().fitnessBike!;
    await pumpCard(tester, def);
    ride(def, 4.5);
    await tester.pump();
    expect(find.text(l.chainHintTitle), findsOneWidget);

    def.setVirtualShiftingMode(VirtualShiftingMode.targetPower);
    await tester.pump();
    expect(find.text(l.chainHintTitle), findsNothing);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('the trainer page shows it next to the virtual shifting settings', (tester) async {
    final device = trainer();
    tester.view.physicalSize = const Size(430, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: ProxyDeviceDetailsPage(device: device),
      ),
    );
    await tester.pump();
    expect(find.text(l.chainHintTitle), findsNothing);

    ride(device.fitnessBike!, 4.5);
    await tester.pump();
    final hint = find.text(l.chainHintTitle);
    final link = find.byKey(const ValueKey('trainer-vs-settings'));
    expect(hint, findsOneWidget);
    expect(tester.getTopLeft(hint).dy, lessThan(tester.getTopLeft(link).dy));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 6));
  });

  test('the first time it shows is put in the activity log, once per connection', () async {
    final device = trainer();
    final def = device.fitnessBike!;
    final logs = <String>[];
    final sub = core.connection.actionStream.listen((n) {
      if (n is LogNotification && n.message.contains('chain')) logs.add(n.message);
    });

    // Re-seeding happens on every settings change; it must not stack listeners.
    device.applyTrainerSettings();
    device.applyTrainerSettings();
    def.setVirtualShiftingMode(VirtualShiftingMode.trackResistance);

    ride(def, 4.5);
    def.setVirtualShiftingMode(VirtualShiftingMode.targetPower);
    def.setVirtualShiftingMode(VirtualShiftingMode.trackResistance);
    ride(def, 2.0, seconds: 5);
    ride(def, 4.5);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();

    expect(logs, hasLength(1));
    expect(logs.single, contains('4.5'));
  });
}
