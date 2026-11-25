import 'package:bike_control/utils/iap/ms_store_collections_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<String> calls;
  late Map<String, String> stored;

  MsStoreCollectionsSync build({String? userId = 'user-1', String base = 'active', Object? keyError}) {
    return MsStoreCollectionsSync(
      currentUserId: () => userId,
      requestTicket: () async {
        calls.add('ticket');
        return (serviceTicket: 'TICKET', publisherUserId: 'user-1');
      },
      collectionsIdKey: ({required serviceTicket, required publisherUserId}) async {
        calls.add('key $serviceTicket $publisherUserId');
        if (keyError != null) throw keyError;
        return 'KEY';
      },
      submitKey: (key) async {
        calls.add('sync $key');
        return base;
      },
      refreshEntitlements: () async => calls.add('refresh'),
      readFlag: (k) async => stored[k],
      writeFlag: (k, v) async => stored[k] = v,
    );
  }

  setUp(() {
    calls = [];
    stored = {};
  });

  test('ticket, Store key, backend sync, then the entitlements are re-read', () async {
    await build().sync();
    expect(calls, ['ticket', 'key TICKET user-1', 'sync KEY', 'refresh']);
  });

  test('signed out: nothing to record the purchase on', () async {
    await build(userId: null).sync();
    expect(calls, isEmpty);
  });

  test('once recorded for an account, the launch sync is skipped; after a purchase it runs again', () async {
    await build().syncOnce();
    calls.clear();
    await build().syncOnce();
    expect(calls, isEmpty);

    await build().sync();
    expect(calls, contains('sync KEY'));
  });

  test('a Store without a Base purchase is checked again next time', () async {
    await build(base: 'none').syncOnce();
    calls.clear();
    await build(base: 'none').syncOnce();
    expect(calls, contains('ticket'));
  });

  test('a failing Store key is reported, not thrown', () async {
    final errors = <Object>[];
    final sync = MsStoreCollectionsSync(
      currentUserId: () => 'user-1',
      requestTicket: () async => (serviceTicket: 'T', publisherUserId: 'user-1'),
      collectionsIdKey: ({required serviceTicket, required publisherUserId}) async => throw StateError('store'),
      submitKey: (_) async => 'active',
      refreshEntitlements: () async {},
      readFlag: (_) async => null,
      writeFlag: (_, _) async {},
      onError: (e, s) => errors.add(e),
    );
    await sync.sync();
    expect(errors.single, isA<StateError>());
  });

  test('an empty Store key (unpackaged build, Store unavailable) is never sent', () async {
    final errors = <Object>[];
    final sync = MsStoreCollectionsSync(
      currentUserId: () => 'user-1',
      requestTicket: () async => (serviceTicket: 'T', publisherUserId: 'user-1'),
      collectionsIdKey: ({required serviceTicket, required publisherUserId}) async => '',
      submitKey: (_) async {
        calls.add('sync');
        return 'active';
      },
      refreshEntitlements: () async {},
      readFlag: (_) async => null,
      writeFlag: (_, _) async {},
      onError: (e, s) => errors.add(e),
    );
    await sync.sync();
    expect(calls, isEmpty);
    expect(errors.single, isA<StateError>());
  });
}
