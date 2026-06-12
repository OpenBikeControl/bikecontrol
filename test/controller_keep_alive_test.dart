import 'package:bike_control/bluetooth/devices/zwift/controller_keep_alive.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ControllerKeepAlive', () {
    test('invokes onTick once per interval while running', () {
      fakeAsync((async) {
        var ticks = 0;
        final keepAlive = ControllerKeepAlive(onTick: () => ticks++, interval: const Duration(seconds: 5));

        keepAlive.start();
        async.elapse(const Duration(seconds: 15));

        expect(ticks, 3);
        keepAlive.stop();
      });
    });

    test('stop() halts further ticks', () {
      fakeAsync((async) {
        var ticks = 0;
        final keepAlive = ControllerKeepAlive(onTick: () => ticks++, interval: const Duration(seconds: 5));

        keepAlive.start();
        async.elapse(const Duration(seconds: 5));
        expect(ticks, 1);

        keepAlive.stop();
        async.elapse(const Duration(seconds: 30));
        expect(ticks, 1, reason: 'no ticks must fire after stop()');
        expect(keepAlive.isRunning, isFalse);
      });
    });

    test('start() while already running does not stack timers', () {
      fakeAsync((async) {
        var ticks = 0;
        final keepAlive = ControllerKeepAlive(onTick: () => ticks++, interval: const Duration(seconds: 5));

        keepAlive.start();
        keepAlive.start();
        async.elapse(const Duration(seconds: 5));

        expect(ticks, 1, reason: 'restarting must leave exactly one active timer');
        keepAlive.stop();
      });
    });

    test('default interval stays well under the 30s inactivity window', () {
      expect(
        ControllerKeepAlive(onTick: () {}).interval,
        lessThan(const Duration(seconds: 30)),
      );
    });

    test('the released state frame presses no buttons', () {
      // Every button bit set to 1 == "nothing pressed"; this is exactly what a
      // key-up emits, so re-sending it can never register a phantom press.
      expect(kZwiftControllerReleasedState, [0x08, 0xFF, 0xFF, 0xFF, 0xFF, 0x0F]);
    });
  });
}
