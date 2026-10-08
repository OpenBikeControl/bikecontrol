import 'package:bike_control/pages/home/startup_settling.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StartupSettling', () {
    test('stays unsettled while the inputs flip during the window', () {
      fakeAsync((async) {
        final settling = StartupSettling();
        final seen = <bool>[];
        // Reconnecting, scanning, devices turning up and dropping again: the
        // banner keeps saying one thing.
        for (final (reconnecting, scanning) in [(true, false), (true, true), (false, true), (true, true)]) {
          seen.add(settling.observe(ready: false, reconnecting: reconnecting, scanning: scanning));
          async.elapse(const Duration(milliseconds: 500));
        }
        expect(seen, everyElement(isFalse));
        expect(settling.isSettled, isFalse);
        settling.dispose();
      });
    });

    test('settles once the reconnect is over and the scan has run for a while', () {
      fakeAsync((async) {
        final settling = StartupSettling();
        var notified = 0;
        settling.addListener(() => notified++);
        expect(settling.observe(ready: false, reconnecting: false, scanning: true), isFalse);
        async.elapse(StartupSettling.scanQuiet - const Duration(milliseconds: 1));
        expect(settling.isSettled, isFalse);
        async.elapse(const Duration(milliseconds: 1));
        expect(settling.isSettled, isTrue);
        expect(notified, 1, reason: 'the screen rebuilds to show the real steps');
        settling.dispose();
      });
    });

    test('waits for the remembered devices, but never past the maximum', () {
      fakeAsync((async) {
        final settling = StartupSettling();
        settling.observe(ready: false, reconnecting: true, scanning: true);
        async.elapse(StartupSettling.scanQuiet * 2);
        expect(settling.isSettled, isFalse, reason: 'a remembered device is still on its way back');
        async.elapse(StartupSettling.maximum - StartupSettling.scanQuiet * 2);
        expect(settling.isSettled, isTrue);
        settling.dispose();
      });
    });

    test('ends at the maximum even when no scan ever runs', () {
      fakeAsync((async) {
        final settling = StartupSettling();
        settling.observe(ready: false, reconnecting: false, scanning: false);
        async.elapse(StartupSettling.maximum - const Duration(milliseconds: 1));
        expect(settling.isSettled, isFalse);
        async.elapse(const Duration(milliseconds: 1));
        expect(settling.isSettled, isTrue);
        settling.dispose();
      });
    });

    test('a ready setup is shown at once, and settling never comes back', () {
      fakeAsync((async) {
        final settling = StartupSettling();
        expect(settling.observe(ready: false, reconnecting: true, scanning: false), isFalse);
        expect(settling.observe(ready: true, reconnecting: true, scanning: false), isTrue);
        expect(settling.observe(ready: false, reconnecting: true, scanning: false), isTrue);
        settling.dispose();
      });
    });

    test('the window is anchored on the first observation', () {
      fakeAsync((async) {
        final settling = StartupSettling();
        async.elapse(const Duration(minutes: 1));
        expect(settling.observe(ready: false, reconnecting: false, scanning: false), isFalse);
        async.elapse(StartupSettling.maximum);
        expect(settling.isSettled, isTrue);
        settling.dispose();
      });
    });

    test('settled() starts settled', () {
      expect(StartupSettling.settled().observe(ready: false, reconnecting: true, scanning: false), isTrue);
    });
  });
}
