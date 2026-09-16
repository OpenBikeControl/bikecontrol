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

  test('overlay declined defaults to false and round-trips', () async {
    expect(settings.getOverlayDeclined(), isFalse);
    await settings.setOverlayDeclined(true);
    expect(settings.getOverlayDeclined(), isTrue);
  });

  // "Not now" on the home screen's step must not outlive the rider changing
  // their mind: turning the overlay on anywhere — the step's own button or the
  // trainer page's switch — is that change of mind, so the setter clears it
  // rather than leaving every call site to remember.
  test('turning the overlay on clears a decline', () async {
    await settings.setOverlayDeclined(true);
    await settings.setOverlayEnabled(true);
    expect(settings.getOverlayDeclined(), isFalse);
  });

  test('turning the overlay off leaves a decline alone', () async {
    await settings.setOverlayDeclined(true);
    await settings.setOverlayEnabled(false);
    expect(settings.getOverlayDeclined(), isTrue);
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

  test('overlay opacity defaults to 1.0 (fully opaque)', () {
    expect(settings.getOverlayOpacity(), 1.0);
  });

  test('overlay opacity round-trips within range', () async {
    await settings.setOverlayOpacity(0.5);
    expect(settings.getOverlayOpacity(), 0.5);
  });

  test('overlay opacity clamps to [0.2, 1.0] on write', () async {
    await settings.setOverlayOpacity(0.0);
    expect(settings.getOverlayOpacity(), 0.2);
    await settings.setOverlayOpacity(1.5);
    expect(settings.getOverlayOpacity(), 1.0);
  });

  test('overlay opacity clamps a stale out-of-range stored value on read',
      () async {
    // A value written by an older/other build could sit outside the range;
    // the getter must never hand back something setOpacity would reject.
    await settings.prefs.setDouble('overlay_opacity', 0.05);
    expect(settings.getOverlayOpacity(), 0.2);
  });
}
