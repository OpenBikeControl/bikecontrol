import 'package:bike_control/utils/iap/revenuecat_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RevenueCatService.isPurchasedBuild', () {
    group('iOS (isMacOS: false)', () {
      test('old paid era (< 58) is purchased', () {
        expect(RevenueCatService.isPurchasedBuild(0, isMacOS: false), isTrue);
        expect(RevenueCatService.isPurchasedBuild(57, isMacOS: false), isTrue);
      });

      test('legacy free window (58..76) is not purchased', () {
        expect(RevenueCatService.isPurchasedBuild(58, isMacOS: false), isFalse);
        expect(RevenueCatService.isPurchasedBuild(76, isMacOS: false), isFalse);
      });

      test('current paid era (77..137) is purchased', () {
        expect(RevenueCatService.isPurchasedBuild(77, isMacOS: false), isTrue);
        expect(RevenueCatService.isPurchasedBuild(114, isMacOS: false), isTrue);
        expect(RevenueCatService.isPurchasedBuild(137, isMacOS: false), isTrue);
      });

      test('first free build (138) and later are not purchased', () {
        expect(RevenueCatService.isPurchasedBuild(138, isMacOS: false), isFalse);
        expect(RevenueCatService.isPurchasedBuild(200, isMacOS: false), isFalse);
      });
    });

    group('macOS (isMacOS: true) uses 61 as the lower paid edge', () {
      test('60 is purchased, 61 is not', () {
        expect(RevenueCatService.isPurchasedBuild(60, isMacOS: true), isTrue);
        expect(RevenueCatService.isPurchasedBuild(61, isMacOS: true), isFalse);
      });

      test('current paid era (77..137) is purchased', () {
        expect(RevenueCatService.isPurchasedBuild(77, isMacOS: true), isTrue);
        expect(RevenueCatService.isPurchasedBuild(137, isMacOS: true), isTrue);
      });

      test('first free build (138) and later are not purchased', () {
        expect(RevenueCatService.isPurchasedBuild(138, isMacOS: true), isFalse);
      });
    });

    test('freeAgainFromBuild is 138', () {
      expect(RevenueCatService.freeAgainFromBuild, 138);
    });
  });

  group('RevenueCatService.isPurchasedVersion (macOS version strings)', () {
    test('old paid era (< 4.2.0) is purchased', () {
      expect(RevenueCatService.isPurchasedVersion('1.0'), isTrue);
      expect(RevenueCatService.isPurchasedVersion('4.1.9'), isTrue);
    });

    test('legacy free window (4.2.0..4.3.x) is not purchased', () {
      expect(RevenueCatService.isPurchasedVersion('4.2.0'), isFalse);
      expect(RevenueCatService.isPurchasedVersion('4.3.5'), isFalse);
    });

    test('paid era (4.4.0..6.0.x) is purchased', () {
      expect(RevenueCatService.isPurchasedVersion('4.4.0'), isTrue);
      expect(RevenueCatService.isPurchasedVersion('5.0.0'), isTrue);
      expect(RevenueCatService.isPurchasedVersion('6.0.1'), isTrue);
    });

    test('first free version (6.1.0, build 138) and later are not purchased', () {
      expect(RevenueCatService.isPurchasedVersion('6.1.0'), isFalse);
      expect(RevenueCatService.isPurchasedVersion('7.4.0'), isFalse);
    });
  });

  group('RevenueCatService.needsSubscriptionSync', () {
    test('only when signed in, Pro in the store, and missing on the backend', () {
      expect(RevenueCatService.needsSubscriptionSync(signedIn: true, storePro: true, backendPro: false), isTrue);
      expect(RevenueCatService.needsSubscriptionSync(signedIn: true, storePro: true, backendPro: true), isFalse);
      expect(RevenueCatService.needsSubscriptionSync(signedIn: true, storePro: false, backendPro: false), isFalse);
      expect(RevenueCatService.needsSubscriptionSync(signedIn: false, storePro: true, backendPro: false), isFalse);
    });
  });

  group('RevenueCatService.syncSubscriptionsBody', () {
    test('asks the backend to wait for the subscription only when the store says Pro', () {
      expect(RevenueCatService.syncSubscriptionsBody(expectActive: true), {'expectActive': true});
      expect(RevenueCatService.syncSubscriptionsBody(expectActive: false), isNull);
    });
  });

  // Pro bought while signed out lands on an anonymous RevenueCat id, so the
  // backend never hears of it; the sign-in sync can run before RevenueCat's
  // API shows the subscription under the account. Refreshing must heal that
  // by syncing again, instead of only re-reading empty entitlements.
  group('RevenueCatService.refreshUntilBackendPro', () {
    test('backend already Pro: one read, no sync', () async {
      final backend = _FakeBackend(backendPro: true);

      expect(await backend.run(signedIn: true, storePro: true), isTrue);
      expect(backend.refreshes, 1);
      expect(backend.syncs, 0);
      expect(backend.waits, isEmpty);
    });

    test('store says Pro, backend not: syncs subscriptions and picks up Pro', () async {
      final backend = _FakeBackend(syncsUntilPro: 1);

      expect(await backend.run(signedIn: true, storePro: true), isTrue);
      expect(backend.syncs, 1);
      expect(backend.refreshes, 2);
    });

    test('RevenueCat lagging: keeps syncing with backoff until the backend has Pro', () async {
      final backend = _FakeBackend(syncsUntilPro: 3);

      expect(await backend.run(signedIn: true, storePro: true), isTrue);
      expect(backend.syncs, 3);
      expect(backend.waits, const [Duration(seconds: 1), Duration(seconds: 2), Duration(seconds: 4)]);
    });

    test('gives up after the retries when the backend never gets Pro', () async {
      final backend = _FakeBackend();

      expect(await backend.run(signedIn: true, storePro: true), isFalse);
      expect(backend.syncs, 3);
      expect(backend.refreshes, 4);
    });

    test('no Pro in the store: never syncs, only re-reads entitlements', () async {
      final backend = _FakeBackend(syncsUntilPro: 1);

      expect(await backend.run(signedIn: true, storePro: false), isFalse);
      expect(backend.syncs, 0);
      expect(backend.refreshes, 4);
    });

    test('signed out (or anonymous support session): never syncs', () async {
      final backend = _FakeBackend(syncsUntilPro: 1);

      expect(await backend.run(signedIn: false, storePro: true), isFalse);
      expect(backend.syncs, 0);
    });
  });
}

/// A backend whose entitlements only show Pro once `sync-subscriptions` has
/// pulled the store subscription onto the account, after [syncsUntilPro]
/// syncs (RevenueCat's API can lag a few seconds after a logIn or purchase).
class _FakeBackend {
  _FakeBackend({this.backendPro = false, this.syncsUntilPro});

  bool backendPro;
  final int? syncsUntilPro;
  int refreshes = 0;
  int syncs = 0;
  final waits = <Duration>[];

  Future<void> refresh() async => refreshes++;

  Future<void> sync() async {
    syncs++;
    if (syncsUntilPro != null && syncs >= syncsUntilPro!) backendPro = true;
  }

  Future<void> wait(Duration d) async => waits.add(d);

  Future<bool> run({required bool signedIn, required bool storePro}) => RevenueCatService.refreshUntilBackendPro(
    refresh: refresh,
    backendPro: () => backendPro,
    needsSync: () => RevenueCatService.needsSubscriptionSync(
      signedIn: signedIn,
      storePro: storePro,
      backendPro: backendPro,
    ),
    syncSubscriptions: sync,
    wait: wait,
  );
}
