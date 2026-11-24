// ignore_for_file: deprecated_member_use
import 'package:bike_control/utils/actions/desktop.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:keypress_simulator_platform_interface/keypress_simulator_platform_interface.dart';

/// Records each simulated key event together with the fake-clock time it was
/// sent at, so a test can measure how long a click held the key down.
class _TimedKeyPresses extends KeyPressSimulatorPlatform {
  _TimedKeyPresses(this.clock);

  final Duration Function() clock;
  final events = <({bool keyDown, KeyboardKey? key, List<ModifierKey> modifiers, String? targetApp, Duration at})>[];

  @override
  Future<void> simulateKeyPress({
    KeyboardKey? key,
    List<ModifierKey> modifiers = const [],
    bool keyDown = true,
    String? targetApp,
  }) async {
    events.add((keyDown: keyDown, key: key, modifiers: modifiers, targetApp: targetApp, at: clock()));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a key click holds the key down before releasing it', () {
    fakeAsync((async) {
      final platform = _TimedKeyPresses(() => async.elapsed);
      KeyPressSimulatorPlatform.instance = platform;

      var done = false;
      simulateKeyClick(
        PhysicalKeyboardKey.enter,
        const [ModifierKey.shiftModifier],
        'com.example.app',
      ).then((_) => done = true);
      async.flushMicrotasks();

      // Key-down goes out immediately, key-up must wait for the hold time:
      // games that poll key state once per frame miss a zero-length press.
      expect(platform.events, hasLength(1));
      expect(platform.events.single.keyDown, isTrue);
      expect(done, isFalse);

      async.elapse(keyClickHoldDuration);
      async.flushMicrotasks();

      expect(done, isTrue);
      expect(platform.events, hasLength(2));
      final down = platform.events[0];
      final up = platform.events[1];
      expect(up.keyDown, isFalse);
      expect(up.at - down.at, greaterThanOrEqualTo(const Duration(milliseconds: 50)));
      for (final e in platform.events) {
        expect(e.key, PhysicalKeyboardKey.enter);
        expect(e.modifiers, const [ModifierKey.shiftModifier]);
        expect(e.targetApp, 'com.example.app');
      }
    });
  });

  test('hold duration is long enough to span a frame at 30 fps', () {
    expect(keyClickHoldDuration, greaterThanOrEqualTo(const Duration(milliseconds: 34)));
  });
}
