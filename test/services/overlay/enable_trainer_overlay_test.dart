import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/services/overlay/trainer_overlay_controller.dart';
import 'package:bike_control/services/overlay/trainer_overlay_service.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

/// [enableTrainerOverlay] — the one path that turns the gear overlay on, run by
/// both the Overlay section's switch and the home screen's gear-overlay step.
///
/// The rule worth pinning down is that the persisted flag follows the platform
/// rather than the intent: a rider who declines Android's draw-over prompt must
/// not be left with a setting claiming an overlay they cannot see.
class _FakeOverlayController implements TrainerOverlayController {
  _FakeOverlayController(this.result);

  final OverlayShowResult result;
  int shows = 0;
  Set<OverlayField>? shownFields;
  FitnessBikeDefinition? shownDefinition;

  final ValueNotifier<bool> _showing = ValueNotifier(false);

  @override
  ValueListenable<bool> get isShowing => _showing;

  @override
  Future<OverlayShowResult> show(
    FitnessBikeDefinition def,
    Set<OverlayField> fields, {
    LiveDefinitionLookup? liveDef,
  }) async {
    shows++;
    shownFields = fields;
    shownDefinition = def;
    _showing.value = result.ok;
    return result;
  }

  @override
  Future<void> hide() async => _showing.value = false;

  @override
  void updateFields(Set<OverlayField> fields) {}

  @override
  void updateOpacity(double opacity) {}

  @override
  Future<void> reassert() async {}
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
    TrainerOverlayService.resetForTest();
  });

  tearDown(TrainerOverlayService.resetForTest);

  ProxyDevice makeDevice({required bool virtualShifting}) {
    final device = ProxyDevice(
      BleDevice(
        deviceId: 'kickr',
        name: 'KICKR CORE',
        services: const [FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID],
      ),
    )..services = [BleService(FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID, [])];
    if (virtualShifting) {
      device.debugAttachFitnessBike(
        FitnessBikeDefinition(
          connectedDevice: device.scanResult,
          connectedDeviceServices: device.services!,
          data: ValueNotifier(''),
        ),
      );
    }
    return device;
  }

  test('puts the overlay on screen and persists the choice', () async {
    final controller = _FakeOverlayController(const OverlayShowResult.ok());
    TrainerOverlayService.setForTest(controller);

    final result = await enableTrainerOverlay(makeDevice(virtualShifting: true));

    expect(result.ok, isTrue);
    expect(controller.shows, 1);
    expect(controller.shownFields, core.settings.getOverlayFields());
    expect(core.settings.getOverlayEnabled(), isTrue);
  });

  // The Android draw-over prompt lives inside show(). Declining it has to leave
  // the setting alone, or the app spends the rest of the ride insisting an
  // invisible overlay is on.
  test('a refused overlay is not recorded as enabled', () async {
    TrainerOverlayService.setForTest(
      _FakeOverlayController(const OverlayShowResult.fail(OverlayShowFailure.permissionDenied)),
    );

    final result = await enableTrainerOverlay(makeDevice(virtualShifting: true));

    expect(result.ok, isFalse);
    expect(result.failure, OverlayShowFailure.permissionDenied);
    expect(core.settings.getOverlayEnabled(), isFalse);
  });

  test('a trainer with no Virtual Shifting session has no gear to draw', () async {
    final controller = _FakeOverlayController(const OverlayShowResult.ok());
    TrainerOverlayService.setForTest(controller);

    final result = await enableTrainerOverlay(makeDevice(virtualShifting: false));

    expect(result.ok, isFalse);
    expect(controller.shows, 0);
    expect(core.settings.getOverlayEnabled(), isFalse);
  });
}
