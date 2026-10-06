// A Zwift-made controller in the onboarding list gets a note that sets
// expectations for the selected trainer app. Which note is a pure decision
// over (devices, app) — pinned here without rendering anything.
import 'package:bike_control/bluetooth/devices/sram/sram_axs.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_click.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/pages/onboarding/zwift_controller_expectation.dart';
import 'package:bike_control/utils/keymap/apps/bike_control.dart';
import 'package:bike_control/utils/keymap/apps/biketerra.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/apps/fulgaz.dart';
import 'package:bike_control/utils/keymap/apps/openbikecontrol.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/apps/tacx.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../widget_snapshot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Devices read `core` when constructed, so build them after the app state.
  late ZwiftClick click;
  late SramAxs sram;
  setUpAll(() async {
    await ensureSnapshotAppState();
    click = ZwiftClick(BleDevice(deviceId: 'click', name: 'Zwift Click'));
    sram = SramAxs(BleDevice(deviceId: 'sram', name: 'SRAM Rival AXS'));
  });

  test('no note without a trainer app', () {
    expect(zwiftControllerExpectation(devices: [click], app: null), isNull);
  });

  test('no note without a Zwift-made controller', () {
    expect(zwiftControllerExpectation(devices: [sram], app: Tacx()), isNull);
    expect(zwiftControllerExpectation(devices: const [], app: Tacx()), isNull);
  });

  test('no note when riding in BikeControl itself', () {
    expect(zwiftControllerExpectation(devices: [click], app: BikeControl()), isNull);
  });

  test('Zwift selected -> zwift variant', () {
    final e = zwiftControllerExpectation(devices: [sram, click], app: Zwift())!;
    expect(e.variant, ZwiftExpectationVariant.zwift);
    expect(e.device, same(click));
  });

  test('every officially integrated app (except BikeControl) -> official variant', () {
    final official = SupportedApp.supportedApps.where((a) => a.officialIntegration && a is! BikeControl);
    expect(official, isNotEmpty);
    for (final app in official) {
      expect(
        zwiftControllerExpectation(devices: [click], app: app)!.variant,
        ZwiftExpectationVariant.officialApp,
        reason: app.name,
      );
    }
  });

  test('Rouvy is official via its flag', () {
    expect(Rouvy().officialIntegration, isTrue);
    expect(zwiftControllerExpectation(devices: [click], app: Rouvy())!.variant, ZwiftExpectationVariant.officialApp);
  });

  test('an app with a keymap lists the distinct actions BikeControl can trigger', () {
    final e = zwiftControllerExpectation(devices: [click], app: Tacx())!;
    expect(e.variant, ZwiftExpectationVariant.appActions);
    expect(e.actions, containsAll([InGameAction.pause, InGameAction.back, InGameAction.skipInterval]));
    expect(e.actions.toSet().length, e.actions.length, reason: 'distinct');
    expect(e.actions.where((a) => a.isOutsideTrainerApp), isEmpty);
  });

  test('actions are read from the buttons when a key pair carries none (Biketerra)', () {
    final e = zwiftControllerExpectation(devices: [click], app: Biketerra())!;
    expect(e.variant, ZwiftExpectationVariant.appActions);
    expect(e.actions, containsAll([InGameAction.shiftUp, InGameAction.shiftDown, InGameAction.toggleUi]));
  });

  test('FulGaz reads no button input -> noInput variant', () {
    expect(zwiftControllerExpectation(devices: [click], app: FulGaz())!.variant, ZwiftExpectationVariant.noInput);
  });

  test('OpenBikeControl-compatible apps decide their own controls -> appDefined', () {
    expect(
      zwiftControllerExpectation(devices: [click], app: OpenBikeControl())!.variant,
      ZwiftExpectationVariant.appDefined,
    );
  });

  test('a custom app without a preset -> customApp', () {
    final e = zwiftControllerExpectation(devices: [click], app: CustomApp())!;
    expect(e.variant, ZwiftExpectationVariant.customApp);
    expect(e.actions, isEmpty);
  });

  test('a connected Zwift device is preferred over one still connecting', () {
    final other = ZwiftClick(BleDevice(deviceId: 'other', name: 'Zwift Click'));
    final ride = ZwiftRide(BleDevice(deviceId: 'ride', name: 'Zwift Ride'))..isConnected = true;
    final e = zwiftControllerExpectation(devices: [other, ride], app: Tacx())!;
    expect(e.device, same(ride));
  });
}
