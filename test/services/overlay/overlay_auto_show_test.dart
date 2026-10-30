import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/services/overlay/trainer_overlay_service.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/requirements/multi.dart' show Target;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

/// When BikeControl starts with the overlay switched on, the overlay opens by
/// itself once the trainer is connected and shifting. That must hold for every
/// trainer the switch is offered for — a Van Rysel D100 is found by its name
/// with no services in the advert, and the overlay stayed shut on every launch
/// (support fccde7cf) although the switch still read "on".
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    await core.settings.setLastTarget(Target.thisDevice);
    TrainerOverlayService.debugSupportedPlatform = true;
  });

  tearDown(() => TrainerOverlayService.debugSupportedPlatform = null);

  ProxyDevice makeTrainer({List<String> advertised = const [], bool shifting = true, bool connected = true}) {
    final device = ProxyDevice(BleDevice(deviceId: 'd100', name: 'VANRYSEL-HT-d8ef', services: advertised))
      ..services = [BleService(FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID, [])]
      ..isConnected = connected;
    if (shifting) {
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

  test('a trainer found by name alone gets the overlay once it shifts', () {
    final device = makeTrainer();
    expect(trainerOverlayOffered(device), isTrue);
    expect(trainerOverlayAutoShowReady(device), isTrue);
  });

  test('a trainer advertising FTMS gets it too', () {
    expect(trainerOverlayAutoShowReady(makeTrainer(advertised: [FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID])), isTrue);
  });

  test('not before the trainer is connected and shifting', () {
    expect(trainerOverlayAutoShowReady(makeTrainer(connected: false)), isFalse);
    expect(trainerOverlayAutoShowReady(makeTrainer(shifting: false)), isFalse);
  });

  test('not while the trainer app runs on another device', () async {
    await core.settings.setLastTarget(Target.otherDevice);
    expect(trainerOverlayAutoShowReady(makeTrainer()), isFalse);
  });
}
