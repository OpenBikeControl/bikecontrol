import 'package:bike_control/services/network_self_test/network_check.dart';
import 'package:bike_control/services/network_self_test/network_self_test_result.dart';
import 'package:bike_control/services/network_self_test/network_self_test_store.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

NetworkSelfTestResult _result({bool completed = true, List<NetworkCheck> checks = const []}) => NetworkSelfTestResult(
  at: DateTime(2026, 8, 21, 10, 30),
  platform: 'macos',
  obcBackend: 'platformDefault',
  hostname: 'BikeControl.local',
  checks: checks.isEmpty ? const [NetworkCheck(id: NetworkCheckId.methodListening, verdict: NetworkVerdict.pass)] : checks,
  completed: completed,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
  });

  test('save then load round-trips a completed result', () async {
    final result = _result();
    await NetworkSelfTestStore.save(result);
    final loaded = NetworkSelfTestStore.load();

    expect(loaded, isNotNull);
    expect(loaded!.platform, 'macos');
    expect(loaded.obcBackend, 'platformDefault');
    expect(loaded.hostname, 'BikeControl.local');
    expect(loaded.completed, isTrue);
    expect(loaded.checks.single.id, NetworkCheckId.methodListening);
  });

  test('load returns null when nothing is stored', () {
    expect(NetworkSelfTestStore.load(), isNull);
  });

  test('save persists a cancelled run that still has at least one active probe', () async {
    final result = _result(
      completed: false,
      checks: const [
        NetworkCheck(id: NetworkCheckId.methodListening, verdict: NetworkVerdict.pass),
        NetworkCheck(id: NetworkCheckId.advertisedAddress, verdict: NetworkVerdict.skipped),
      ],
    );
    await NetworkSelfTestStore.save(result);
    final loaded = NetworkSelfTestStore.load();

    expect(loaded, isNotNull);
    expect(loaded!.completed, isFalse);
  });

  test('save drops a cancelled run with no active probe at all', () async {
    final result = _result(
      completed: false,
      checks: const [
        NetworkCheck(id: NetworkCheckId.methodListening, verdict: NetworkVerdict.skipped),
        NetworkCheck(id: NetworkCheckId.advertisedAddress, verdict: NetworkVerdict.skipped),
      ],
    );
    await NetworkSelfTestStore.save(result);

    expect(NetworkSelfTestStore.load(), isNull);
  });

  test('bundleSection is empty when nothing is stored', () {
    expect(NetworkSelfTestStore.bundleSection(), '');
  });

  test('bundleSection contains the header and the bundle string once a result is stored', () async {
    await NetworkSelfTestStore.save(_result());
    final section = NetworkSelfTestStore.bundleSection();

    expect(section, contains('Network self-test:'));
    expect(section, contains(NetworkSelfTestStore.load()!.toBundleString()));
  });

  group('age line', () {
    final at = DateTime.utc(2026, 10, 5, 9, 30);

    test('a result from minutes ago is given its age and nothing more', () {
      expect(NetworkSelfTestStore.ageLine(at, at.add(const Duration(minutes: 12))), 'age=12min');
      expect(NetworkSelfTestStore.ageLine(at, at.add(const Duration(hours: 5, minutes: 7))), 'age=5h 7min');
    });

    test('a result older than a day is marked stale', () {
      // A result from weeks ago says nothing about the device today.
      final line = NetworkSelfTestStore.ageLine(at, DateTime.utc(2026, 11, 3, 13, 30));
      expect(line, startsWith('age=29d 4h STALE'));
    });

    test('a clock that moved backwards does not print a negative age', () {
      expect(NetworkSelfTestStore.ageLine(at, at.subtract(const Duration(hours: 1))), 'age=0min');
    });

    test('bundleSection puts the age between the heading and the result', () async {
      await NetworkSelfTestStore.save(_result());
      final stored = NetworkSelfTestStore.load()!;
      final section = NetworkSelfTestStore.bundleSection(now: () => stored.at.add(const Duration(days: 3)));

      final lines = section.split('\n');
      expect(lines[0], 'Network self-test:');
      expect(lines[1], startsWith('age=3d 0h STALE'));
      expect(lines[2], startsWith('NETWORK '));
    });
  });

  test(
    'menu.dart interpolation helper avoids a double blank line: '
    'empty section adds nothing, non-empty section adds exactly one trailing newline',
    () {
      String prefixed(String networkTest) => '${networkTest.isEmpty ? '' : '$networkTest\n'}Logs:';

      expect(prefixed(''), 'Logs:');
      expect(prefixed('Network self-test:\nNETWORK PASS,2026-08-21,macos,platformDefault'), '''
Network self-test:
NETWORK PASS,2026-08-21,macos,platformDefault
Logs:''');
    },
  );
}
