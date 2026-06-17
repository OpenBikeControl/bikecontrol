import 'package:bike_control/bluetooth/inactivity_disconnector.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InactivityDisconnector', () {
    // Mutable stand-ins for the live queries Connection injects.
    late bool trainerAppConnected;
    late bool onlyLocalActive;
    late bool hasControllers;
    late List<Duration> firedTimeouts;

    InactivityDisconnector build() => InactivityDisconnector(
          isTrainerAppConnected: () => trainerAppConnected,
          isOnlyLocalActive: () => onlyLocalActive,
          hasEligibleControllers: () => hasControllers,
          onTimeout: (d) => firedTimeouts.add(d),
          graceTimeout: const Duration(minutes: 5),
          localTimeout: const Duration(minutes: 30),
        );

    setUp(() {
      trainerAppConnected = false;
      onlyLocalActive = false;
      hasControllers = true;
      firedTimeouts = [];
    });

    test('no timer while a trainer app is connected', () {
      fakeAsync((async) {
        trainerAppConnected = true;
        final d = build();
        d.onTrainerConnectionChanged();
        async.elapse(const Duration(minutes: 10));
        expect(firedTimeouts, isEmpty);
        d.dispose();
      });
    });

    test('trainer-app disconnect arms a 5-minute grace that fires', () {
      fakeAsync((async) {
        final d = build();
        trainerAppConnected = true;
        d.onTrainerConnectionChanged(); // app connected
        trainerAppConnected = false;
        d.onTrainerConnectionChanged(); // app left -> grace
        async.elapse(const Duration(minutes: 5));
        expect(firedTimeouts, [const Duration(minutes: 5)]);
        d.dispose();
      });
    });

    test('button activity slides the 5-minute grace', () {
      fakeAsync((async) {
        final d = build();
        trainerAppConnected = true;
        d.onTrainerConnectionChanged();
        trainerAppConnected = false;
        d.onTrainerConnectionChanged();
        async.elapse(const Duration(minutes: 4));
        d.onButtonActivity(); // reset
        async.elapse(const Duration(minutes: 4));
        expect(firedTimeouts, isEmpty, reason: 'only 4 min since reset');
        async.elapse(const Duration(minutes: 1));
        expect(firedTimeouts, [const Duration(minutes: 5)]);
        d.dispose();
      });
    });

    test('trainer app reconnecting cancels the grace', () {
      fakeAsync((async) {
        final d = build();
        trainerAppConnected = true;
        d.onTrainerConnectionChanged();
        trainerAppConnected = false;
        d.onTrainerConnectionChanged(); // grace armed
        trainerAppConnected = true;
        d.onTrainerConnectionChanged(); // reconnected
        async.elapse(const Duration(minutes: 10));
        expect(firedTimeouts, isEmpty);
        d.dispose();
      });
    });

    test('grace does NOT arm during initial waiting (no prior connect)', () {
      fakeAsync((async) {
        onlyLocalActive = false; // a non-local method is enabled but never connected
        final d = build();
        d.onDeviceConnectionChanged(); // controller connects, no app yet
        async.elapse(const Duration(minutes: 10));
        expect(firedTimeouts, isEmpty);
        d.dispose();
      });
    });

    test('only Local active arms a 30-minute timer that fires', () {
      fakeAsync((async) {
        onlyLocalActive = true;
        final d = build();
        d.onDeviceConnectionChanged();
        async.elapse(const Duration(minutes: 30));
        expect(firedTimeouts, [const Duration(minutes: 30)]);
        d.dispose();
      });
    });

    test('button activity slides the 30-minute Local timer', () {
      fakeAsync((async) {
        onlyLocalActive = true;
        final d = build();
        d.onDeviceConnectionChanged();
        async.elapse(const Duration(minutes: 29));
        d.onButtonActivity();
        async.elapse(const Duration(minutes: 29));
        expect(firedTimeouts, isEmpty);
        async.elapse(const Duration(minutes: 1));
        expect(firedTimeouts, [const Duration(minutes: 30)]);
        d.dispose();
      });
    });

    test('5-minute grace takes precedence when Local is also active', () {
      fakeAsync((async) {
        final d = build();
        // App connected and a non-local method enabled => onlyLocalActive false.
        trainerAppConnected = true;
        onlyLocalActive = false;
        d.onTrainerConnectionChanged();
        // App leaves; Local stays on, but spec says 5-min grace wins.
        trainerAppConnected = false;
        d.onTrainerConnectionChanged();
        async.elapse(const Duration(minutes: 5));
        expect(firedTimeouts, [const Duration(minutes: 5)]);
        d.dispose();
      });
    });

    test('no eligible controllers => never fires', () {
      fakeAsync((async) {
        hasControllers = false;
        final d = build();
        trainerAppConnected = true;
        d.onTrainerConnectionChanged();
        trainerAppConnected = false;
        d.onTrainerConnectionChanged();
        async.elapse(const Duration(minutes: 30));
        expect(firedTimeouts, isEmpty);
        d.dispose();
      });
    });

    test('dispose cancels a pending timer', () {
      fakeAsync((async) {
        onlyLocalActive = true;
        final d = build();
        d.onDeviceConnectionChanged();
        async.elapse(const Duration(minutes: 10));
        d.dispose();
        async.elapse(const Duration(minutes: 30));
        expect(firedTimeouts, isEmpty);
      });
    });
  });
}
