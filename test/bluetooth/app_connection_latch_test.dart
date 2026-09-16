import 'package:bike_control/bluetooth/app_connection_latch.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// A world the latch can look at: which app is picked, and whether it is
/// connected over a real method (anything but Local).
class _World {
  String? app = 'MyWhoosh';
  bool connected = false;

  late final latch = AppConnectionLatch(pickedApp: () => app, connectedOverRealMethod: () => connected);

  void connect() {
    connected = true;
    latch.sync();
  }

  void drop() {
    connected = false;
    latch.sync();
  }
}

void main() {
  group('which app connected', () {
    test('nothing, before anything has connected', () {
      final world = _World();
      world.latch.sync();
      expect(world.latch.wasConnected('MyWhoosh'), isFalse);
    });

    test('the picked app, once it connects — and it stays latched after a drop', () {
      final world = _World()..connect();
      expect(world.latch.wasConnected('MyWhoosh'), isTrue);

      world.drop();
      expect(world.latch.wasConnected('MyWhoosh'), isTrue);
    });

    test('only that app: an app picked after the drop has connected to nothing', () {
      final world = _World()
        ..connect()
        ..drop();

      world.app = 'Rouvy';
      world.latch.sync();

      expect(world.latch.wasConnected('Rouvy'), isFalse);
      expect(world.latch.wasConnected('MyWhoosh'), isTrue);
    });

    // Its card showed it connected — the connection is still up — so when it
    // goes, that app is the one that disconnected.
    test('an app picked while the connection stays up takes it over', () {
      final world = _World()..connect();

      world.app = 'TrainingPeaks Virtual';
      world.latch.sync();

      expect(world.latch.wasConnected('TrainingPeaks Virtual'), isTrue);
      expect(world.latch.wasConnected('MyWhoosh'), isFalse);
    });

    test('nothing without an app picked, and never for "no app"', () {
      final world = _World()..app = null;
      world.connect();
      expect(world.latch.wasConnected(null), isFalse);

      world.app = 'MyWhoosh';
      world.drop();
      expect(world.latch.wasConnected('MyWhoosh'), isFalse);
    });

    test('everything is forgotten on reset', () {
      final world = _World()
        ..connect()
        ..drop();
      world.latch.reset();
      world.latch.sync();
      expect(world.latch.wasConnected('MyWhoosh'), isFalse);
      expect(world.latch.addressWarningAtConnect, isNull);
    });

    // The page that reads the latch is rebuilt on every tab swipe, so the
    // latch has to see a connection nobody is looking at.
    test('keeps itself current from the sources it watches', () {
      final world = _World();
      final method = ValueNotifier(false);
      addTearDown(method.dispose);
      world.latch.watch([method]);

      world.connected = true;
      method.value = true;
      world.connected = false;
      method.value = false;

      expect(world.latch.wasConnected('MyWhoosh'), isTrue);
    });
  });

  group('the address it connected through', () {
    test('is the first reading to land while it is connected', () {
      final world = _World()..connect();
      world.latch.noteAddressWarning('192.168.1.50');
      expect(world.latch.addressWarningAtConnect, '192.168.1.50');
    });

    // The usual order: a VPN comes up while the app is still connected over
    // the old path, and the app drops a little later.
    test('does not follow the address while the app stays connected', () {
      final world = _World()..connect();
      world.latch.noteAddressWarning(null);
      world.latch.noteAddressWarning('10.5.0.2');
      expect(world.latch.addressWarningAtConnect, isNull);
    });

    // The last reading before the connection may be stale — the network can
    // change without anything reading it again — so it only stands in.
    test('takes the last reading from before only until a new one lands', () {
      final world = _World();
      world.latch.noteAddressWarning(null);

      world.connect();
      expect(world.latch.addressWarningAtConnect, isNull);

      world.latch.noteAddressWarning('192.168.1.50');
      expect(world.latch.addressWarningAtConnect, '192.168.1.50');
    });

    test('keeps the stand-in when the app drops before a reading lands', () {
      final world = _World();
      world.latch.noteAddressWarning('192.168.1.50');
      world
        ..connect()
        ..drop();

      world.latch.noteAddressWarning('10.5.0.2');

      expect(world.latch.addressWarningAtConnect, '192.168.1.50');
    });

    test('is not moved by readings after the drop', () {
      final world = _World()..connect();
      world.latch.noteAddressWarning('192.168.1.50');
      world.drop();

      world.latch.noteAddressWarning('10.5.0.2');

      expect(world.latch.addressWarningAtConnect, '192.168.1.50');
    });

    test('is read afresh when the app connects again', () {
      final world = _World()..connect();
      world.latch.noteAddressWarning('192.168.1.50');
      world.drop();
      world.latch.noteAddressWarning('10.5.0.2');

      world.connect();
      // Until a reading lands, the last one stands in.
      expect(world.latch.addressWarningAtConnect, '10.5.0.2');
      world.latch.noteAddressWarning(null);
      expect(world.latch.addressWarningAtConnect, isNull);
    });

    // A reading can land before anything told the latch the app connected:
    // it looks for itself.
    test('counts a reading that lands before anyone synced the connection', () {
      final world = _World();
      world.latch.noteAddressWarning(null);
      world.connected = true;

      world.latch.noteAddressWarning('192.168.1.50');

      expect(world.latch.wasConnected('MyWhoosh'), isTrue);
      expect(world.latch.addressWarningAtConnect, '192.168.1.50');
    });
  });
}
