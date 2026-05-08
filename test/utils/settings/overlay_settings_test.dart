import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/utils/settings/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Settings settings;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = Settings();
    settings.prefs = await SharedPreferences.getInstance();
  });

  test('overlay enabled defaults to false and round-trips', () async {
    expect(settings.getOverlayEnabled(), isFalse);
    await settings.setOverlayEnabled(true);
    expect(settings.getOverlayEnabled(), isTrue);
  });

  test('overlay fields default to {power, cadence}', () {
    expect(settings.getOverlayFields(),
        {OverlayField.power, OverlayField.cadence});
  });

  test('overlay fields round-trip', () async {
    await settings.setOverlayFields(
        {OverlayField.power, OverlayField.gearRatio});
    expect(settings.getOverlayFields(),
        {OverlayField.power, OverlayField.gearRatio});
  });

  test('overlay position null when unset, round-trips when set', () async {
    expect(settings.getOverlayPosition(), isNull);
    await settings.setOverlayPosition(const Offset(120, 240));
    expect(settings.getOverlayPosition(), const Offset(120, 240));
  });
}
