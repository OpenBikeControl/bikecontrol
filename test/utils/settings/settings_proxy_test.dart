import 'package:bike_control/utils/settings/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Settings settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = Settings();
    settings.prefs = await SharedPreferences.getInstance();
  });

  test('bike weight defaults to 10.0 kg', () {
    expect(settings.getProxyBikeWeightKg(), 10.0);
  });

  test('rider weight defaults to 75.0 kg', () {
    expect(settings.getProxyRiderWeightKg(), 75.0);
  });

  test('grade smoothing defaults to true', () {
    expect(settings.getProxyGradeSmoothing(), true);
  });

  test('virtual shifting mode defaults to targetPower', () {
    expect(settings.getProxyVirtualShiftingMode(), VirtualShiftingMode.targetPower);
  });

  test('setters persist values', () async {
    await settings.setProxyBikeWeightKg(8.5);
    await settings.setProxyRiderWeightKg(72.0);
    await settings.setProxyGradeSmoothing(false);
    await settings.setProxyVirtualShiftingMode(VirtualShiftingMode.trackResistance);

    expect(settings.getProxyBikeWeightKg(), closeTo(8.5, 0.01));
    expect(settings.getProxyRiderWeightKg(), closeTo(72.0, 0.01));
    expect(settings.getProxyGradeSmoothing(), isFalse);
    expect(settings.getProxyVirtualShiftingMode(), VirtualShiftingMode.trackResistance);
  });

  test('setter clamps bike weight to max', () async {
    await settings.setProxyBikeWeightKg(100.0);
    expect(settings.getProxyBikeWeightKg(), 50.0);
  });

  test('setter clamps rider weight to min', () async {
    await settings.setProxyRiderWeightKg(-5.0);
    expect(settings.getProxyRiderWeightKg(), 20.0);
  });

  test('getter clamps out-of-range stored bike weight', () async {
    SharedPreferences.setMockInitialValues({'proxy_bike_weight_kg': 999.0});
    final s = Settings();
    s.prefs = await SharedPreferences.getInstance();
    expect(s.getProxyBikeWeightKg(), 50.0);
  });

  test('unknown VS mode string falls back to targetPower', () async {
    SharedPreferences.setMockInitialValues({'proxy_vs_mode': 'garbage'});
    final s = Settings();
    s.prefs = await SharedPreferences.getInstance();
    expect(s.getProxyVirtualShiftingMode(), VirtualShiftingMode.targetPower);
  });

  test('gear ratios default to null (signals "use factory table")', () {
    expect(settings.getProxyGearRatios(), isNull);
  });

  test('gear ratios roundtrip persists 24 entries', () async {
    final custom = List<double>.generate(
      FitnessBikeDefinition.maxGear,
      (i) => (i + 1) * 0.25,
    );
    await settings.setProxyGearRatios(custom);
    final loaded = settings.getProxyGearRatios();
    expect(loaded, isNotNull);
    expect(loaded!.length, FitnessBikeDefinition.maxGear);
    for (int i = 0; i < custom.length; i++) {
      expect(loaded[i], closeTo(custom[i], 0.0001));
    }
  });

  test('gear ratios rejects wrong-length list', () {
    expect(() => settings.setProxyGearRatios([1.0, 2.0]), throwsArgumentError);
  });

  test('gear ratios returns null when stored list is wrong length', () async {
    SharedPreferences.setMockInitialValues({
      'proxy_gear_ratios': ['1.0', '2.0', '3.0'],
    });
    final s = Settings();
    s.prefs = await SharedPreferences.getInstance();
    expect(s.getProxyGearRatios(), isNull);
  });

  test('clearProxyGearRatios removes the entry', () async {
    final custom = List<double>.filled(FitnessBikeDefinition.maxGear, 2.0);
    await settings.setProxyGearRatios(custom);
    expect(settings.getProxyGearRatios(), isNotNull);
    await settings.clearProxyGearRatios();
    expect(settings.getProxyGearRatios(), isNull);
  });
}
