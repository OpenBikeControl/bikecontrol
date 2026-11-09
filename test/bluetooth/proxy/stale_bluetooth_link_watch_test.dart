import 'package:bike_control/bluetooth/devices/proxy/stale_bluetooth_link_watch.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

/// After BikeControl restarts on Windows, a phone that paired the Bluetooth
/// bridge keeps its old link and gets no data until the rider re-pairs it
/// (GH #451). The watch decides when to tell them.
void main() {
  late bool pairedBefore;
  late int pairedCalls;
  late StaleBluetoothLinkWatch watch;

  setUp(() {
    pairedBefore = true;
    pairedCalls = 0;
    watch = StaleBluetoothLinkWatch(pairedBefore: () => pairedBefore, onPaired: () => pairedCalls++);
  });

  tearDown(() => watch.dispose());

  test('a previously paired app that does not pick the bridge up within 20 s is suspected', () {
    fakeAsync((async) {
      watch.update(bridgeUp: true, appHolds: false);
      async.elapse(const Duration(seconds: 19));
      expect(watch.suspected.value, isFalse);
      async.elapse(const Duration(seconds: 1));
      expect(watch.suspected.value, isTrue);
    });
  });

  test('an app that picks the bridge up in time clears it, and is remembered as paired', () {
    fakeAsync((async) {
      watch.update(bridgeUp: true, appHolds: false);
      async.elapse(const Duration(seconds: 5));
      watch.update(bridgeUp: true, appHolds: true);
      async.elapse(const Duration(seconds: 30));
      expect(watch.suspected.value, isFalse);
      expect(pairedCalls, 1);
    });
  });

  test('the hint goes away once the rider has re-paired', () {
    fakeAsync((async) {
      watch.update(bridgeUp: true, appHolds: false);
      async.elapse(const Duration(seconds: 25));
      expect(watch.suspected.value, isTrue);
      watch.update(bridgeUp: true, appHolds: true);
      expect(watch.suspected.value, isFalse);
    });
  });

  test('a first-time rider who never paired is not told to re-pair', () {
    fakeAsync((async) {
      pairedBefore = false;
      watch.update(bridgeUp: true, appHolds: false);
      async.elapse(const Duration(minutes: 5));
      expect(watch.suspected.value, isFalse);
    });
  });

  test('an app that leaves mid-session is a real disconnect, not a stale link', () {
    fakeAsync((async) {
      watch.update(bridgeUp: true, appHolds: true);
      watch.update(bridgeUp: true, appHolds: false);
      async.elapse(const Duration(minutes: 5));
      expect(watch.suspected.value, isFalse);
    });
  });

  test('a bridge that stops cancels the window and clears the hint', () {
    fakeAsync((async) {
      watch.update(bridgeUp: true, appHolds: false);
      async.elapse(const Duration(seconds: 10));
      watch.update(bridgeUp: false, appHolds: false);
      async.elapse(const Duration(seconds: 30));
      expect(watch.suspected.value, isFalse);

      watch.update(bridgeUp: true, appHolds: false);
      async.elapse(const Duration(seconds: 25));
      expect(watch.suspected.value, isTrue);
      watch.update(bridgeUp: false, appHolds: false);
      expect(watch.suspected.value, isFalse);
    });
  });

  test('each bridge start is a new window, and repeated updates do not restart it', () {
    fakeAsync((async) {
      watch.update(bridgeUp: true, appHolds: true);
      watch.update(bridgeUp: false, appHolds: false);
      watch.update(bridgeUp: true, appHolds: false);
      async.elapse(const Duration(seconds: 15));
      // Unrelated rebuilds feed the same state again; the window keeps its start.
      watch.update(bridgeUp: true, appHolds: false);
      async.elapse(const Duration(seconds: 5));
      expect(watch.suspected.value, isTrue);
      expect(pairedCalls, 1);
    });
  });
}
