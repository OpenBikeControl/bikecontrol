import 'package:bike_control/services/network_recovery.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/utils/suspension_watch.dart';

void main() {
  late DateTime now;
  late SuspensionWatch watch;
  late List<String> calls;

  NetworkRecovery recovery(TargetPlatform platform) => NetworkRecovery(
    watch: watch,
    platform: platform,
    now: () => now,
    rebindListeners: () async => calls.add('rebind'),
    recoverAdvertiser: ({bool force = false}) async => calls.add(force ? 'recover(force)' : 'recover'),
    refreshKeepAlive: () => calls.add('keepAlive'),
  );

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() {
    now = DateTime(2026, 11, 24, 10);
    watch = SuspensionWatch(now: () => now);
    calls = [];
  });

  tearDown(() => watch.reset());

  test('iOS: coming back from a suspension binds the listeners and publishes again', () async {
    final r = recovery(TargetPlatform.iOS)..start();
    r.onLifecycleState(AppLifecycleState.paused);
    calls.clear();

    now = now.add(const Duration(minutes: 6));
    r.onLifecycleState(AppLifecycleState.resumed);
    await settle();

    expect(calls, containsAllInOrder(['rebind', 'recover(force)']));
    expect(calls, contains('keepAlive'));
    expect(r.diagnosticLines().join('\n'), contains('1 standstill(s), last 360 s'));
  });

  test('iOS: a resume without a standstill only re-checks the advertisement', () async {
    final r = recovery(TargetPlatform.iOS)..start();
    r.onLifecycleState(AppLifecycleState.paused);
    calls.clear();

    now = now.add(const Duration(seconds: 4));
    r.onLifecycleState(AppLifecycleState.resumed);
    await settle();

    expect(calls, ['keepAlive', 'recover']);
  });

  test('iOS: leaving the app starts the keep-alive waiting limit over', () {
    final r = recovery(TargetPlatform.iOS)..start();

    r.onLifecycleState(AppLifecycleState.inactive);
    r.onLifecycleState(AppLifecycleState.paused);

    expect(calls, ['keepAlive', 'keepAlive']);
    expect(r.lastBackgroundAt, now);
  });

  test('macOS: waking from sleep publishes again but leaves the listeners alone', () async {
    recovery(TargetPlatform.macOS).start();

    now = now.add(const Duration(hours: 2));
    watch.check();
    await settle();

    expect(calls, ['recover(force)']);
  });

  group('ensureAdvertisementVisible', () {
    test('a visible advertisement is left alone', () async {
      final r = recovery(TargetPlatform.iOS);

      final visible = await r.ensureAdvertisementVisible(
        advertising: () => true,
        ownAdvertisementSeen: () async => true,
        settle: Duration.zero,
      );

      expect(visible, isTrue);
      expect(calls, isEmpty);
    });

    test('a missing advertisement is repaired and looked for again', () async {
      final r = recovery(TargetPlatform.iOS);
      var looks = 0;

      final visible = await r.ensureAdvertisementVisible(
        advertising: () => true,
        // Gone on the first look, back once it was published again.
        ownAdvertisementSeen: () async => ++looks > 1,
        settle: Duration.zero,
      );

      expect(visible, isTrue);
      expect(calls, ['rebind', 'recover(force)']);
      expect(r.lastInvisibleAt, isNull);
    });

    test('reports an advertisement that stays missing after the repair', () async {
      final r = recovery(TargetPlatform.macOS);

      final visible = await r.ensureAdvertisementVisible(
        advertising: () => true,
        ownAdvertisementSeen: () async => false,
        settle: Duration.zero,
      );

      expect(visible, isFalse);
      expect(calls, ['recover(force)'], reason: 'a Mac keeps its listeners through sleep');
      expect(r.diagnosticLines().join('\n'), contains('own advertisement not found after a repair'));
    });

    test('a miss soon after a forced repair only looks again, it does not republish again', () async {
      final r = recovery(TargetPlatform.macOS);
      Future<bool> look() => r.ensureAdvertisementVisible(
        advertising: () => true,
        ownAdvertisementSeen: () async => false,
        settle: Duration.zero,
      );

      await look();
      expect(calls, ['recover(force)']);

      // The home page looks again every 20 s while it is flagged missing.
      now = now.add(const Duration(seconds: 20));
      expect(await look(), isFalse);
      now = now.add(const Duration(minutes: 5));
      expect(await look(), isFalse);
      expect(calls, ['recover(force)'], reason: 'unregistering and publishing again every look churns the records a trainer app is resolving');

      now = now.add(const Duration(minutes: 6));
      await look();
      expect(calls, ['recover(force)', 'recover(force)'], reason: 'after the pause it is repaired again');
    });

    test('nothing advertised means nothing to look for', () async {
      final r = recovery(TargetPlatform.iOS);
      var looked = false;

      final visible = await r.ensureAdvertisementVisible(
        advertising: () => false,
        ownAdvertisementSeen: () async => looked = true,
        settle: Duration.zero,
      );

      expect(visible, isTrue);
      expect(looked, isFalse);
    });
  });

  test('other platforms are left as they were', () async {
    final r = recovery(TargetPlatform.windows)..start();

    now = now.add(const Duration(hours: 2));
    watch.check();
    r.onLifecycleState(AppLifecycleState.resumed);
    await settle();

    expect(calls, isEmpty);
    expect(watch.isRunning, isFalse);
    expect(r.diagnosticLines(), isEmpty);
  });
}
