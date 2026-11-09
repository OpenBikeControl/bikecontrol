import 'package:bike_control/utils/settings/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/prop.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('key round-trips per serial', () async {
    final s = Settings();
    s.prefs = await SharedPreferences.getInstance();
    await s.setSramKey('SRAM 42', 'ab7c706800759ce024498cb423e0adc9');
    expect(s.getSramKey('SRAM 42'), 'ab7c706800759ce024498cb423e0adc9');
    expect(s.getSramKey('SRAM 99'), isNull);

    // Null removes an existing key (not stored as the literal "null").
    await s.setSramKey('SRAM 42', 'abc');
    await s.setSramKey('SRAM 42', null);
    expect(s.getSramKey('SRAM 42'), isNull);
  });

  test('backup and disabled flag round-trip', () async {
    final s = Settings();
    s.prefs = await SharedPreferences.getInstance();
    await s.setSramBackup('SRAM 42', {
      'd9050028': const SramReactionTrigger([0], [3]),
    });
    expect(s.getSramBackup('SRAM 42')!['d9050028']!.buttonMasks, [3]);

    // Absent backup returns null (not an empty map).
    expect(s.getSramBackup('SRAM 99'), isNull);

    expect(s.getSramShiftingDisabled('SRAM 42'), isFalse);
    await s.setSramShiftingDisabled('SRAM 42', true);
    expect(s.getSramShiftingDisabled('SRAM 42'), isTrue);
  });

  test('discovered buttons dedupe', () async {
    final s = Settings();
    s.prefs = await SharedPreferences.getInstance();
    await s.addSramButton('SRAM 42', 100, 1);
    await s.addSramButton('SRAM 42', 100, 1); // duplicate
    await s.addSramButton('SRAM 42', 200, 1);
    expect(s.getSramButtons('SRAM 42').length, 2);

    // Degraded -1 serial/mask round-trips through the "serial:mask" encoding.
    await s.addSramButton('SRAM 42', -1, 5);
    expect(s.getSramButtons('SRAM 42'), contains((serial: -1, mask: 5, deviceType: null)));
  });

  test('device_type round-trips and upgrades a pre-side record in place', () async {
    final s = Settings();
    s.prefs = await SharedPreferences.getInstance();

    // Two serial-less paddle presses that only differ by side must NOT collapse.
    await s.addSramButton('SRAM 42', -1, 1, 0); // left paddle
    await s.addSramButton('SRAM 42', -1, 1, 1); // right paddle
    final both = s.getSramButtons('SRAM 42');
    expect(both.length, 2);
    expect(both, contains((serial: -1, mask: 1, deviceType: 0)));
    expect(both, contains((serial: -1, mask: 1, deviceType: 1)));

    // A legacy side-less record is upgraded in place (not duplicated) once the
    // device_type becomes known.
    await s.addSramButton('SRAM 99', 5, 2); // legacy: no device_type
    await s.addSramButton('SRAM 99', 5, 2, 1); // now with a side
    final upgraded = s.getSramButtons('SRAM 99');
    expect(upgraded.length, 1);
    expect(upgraded.single.deviceType, 1);
  });

  test('a side-less record is dropped once a sided record exists for its mask', () async {
    final s = Settings();
    s.prefs = await SharedPreferences.getInstance();
    // Left over from before presses carried a side (support 577bf96e): these
    // surfaced as "Shifter A – Paddle" / "Shifter A – Button 8" next to the
    // real Left/Right entries and survived every reconnect.
    SharedPreferences.setMockInitialValues({
      'sram_buttons_dev1': <String>['500:1:', '500:8', '600:1:0', '600:1:1', '600:8:0', '700:2:'],
    });
    s.prefs = await SharedPreferences.getInstance();

    final buttons = s.getSramButtons('dev1');
    expect(buttons, isNot(contains((serial: 500, mask: 1, deviceType: null))));
    expect(buttons, isNot(contains((serial: 500, mask: 8, deviceType: null))));
    expect(buttons, contains((serial: 600, mask: 1, deviceType: 0)));
    expect(buttons, contains((serial: 600, mask: 1, deviceType: 1)));
    expect(buttons, contains((serial: 600, mask: 8, deviceType: 0)));
    // No sided record for mask 2 → the side-less one is still the only source.
    expect(buttons, contains((serial: 700, mask: 2, deviceType: null)));
  });

  test('a sided press prunes stored side-less records of the same mask', () async {
    final s = Settings();
    s.prefs = await SharedPreferences.getInstance();
    await s.addSramButton('dev1', 500, 1); // side unknown
    await s.addSramButton('dev1', 600, 1, 0); // different serial, side known
    expect(s.prefs.getStringList('sram_buttons_dev1'), ['600:1:0']);
  });

  test('clearSramDevice forgets learned buttons and shifters, keeps the bond', () async {
    final s = Settings();
    s.prefs = await SharedPreferences.getInstance();
    await s.addSramButton('dev1', 600, 1, 0);
    s.setSramShifter('dev1', 600, 0, 1034);
    await s.setSramKey('dev1', 'abc');
    await s.addSramButton('dev2', 1, 1, 1);

    await s.clearSramDevice('dev1');

    expect(s.getSramButtons('dev1'), isEmpty);
    expect(s.getSramShifter('dev1', 600), isNull);
    expect(s.getSramKey('dev1'), 'abc');
    expect(s.getSramButtons('dev2'), hasLength(1));
  });
}
