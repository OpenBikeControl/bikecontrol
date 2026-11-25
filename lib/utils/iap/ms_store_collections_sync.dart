import 'package:bike_control/main.dart' show recordError;

/// Records a Base bought in the Microsoft Store on the signed-in account,
/// dated by the Store, so cross-platform promotions can apply to it (see
/// `ms-store-sync` in the backend):
///
/// 1. the backend issues a service ticket for this account,
/// 2. the Store turns it into a collections ID key
///    (`StoreContext.GetCustomerCollectionsIdAsync`),
/// 3. the backend reads the Store's record with that key and writes the
///    entitlement, then the app re-reads its entitlements.
///
/// Every step is injected; WindowsIAPService wires the real ones.
class MsStoreCollectionsSync {
  MsStoreCollectionsSync({
    required this.currentUserId,
    required this.requestTicket,
    required this.collectionsIdKey,
    required this.submitKey,
    required this.refreshEntitlements,
    required this.readFlag,
    required this.writeFlag,
    void Function(Object error, StackTrace stack)? onError,
  }) : _onError = onError ?? ((e, s) => recordError(e, s, context: 'Microsoft Store collections sync'));

  final String? Function() currentUserId;
  final Future<({String serviceTicket, String publisherUserId})> Function() requestTicket;
  final Future<String> Function({required String serviceTicket, required String publisherUserId}) collectionsIdKey;

  /// Returns the backend's verdict: "active", "expired" or "none".
  final Future<String> Function(String collectionsIdKey) submitKey;
  final Future<void> Function() refreshEntitlements;
  final Future<String?> Function(String key) readFlag;
  final Future<void> Function(String key, String value) writeFlag;
  final void Function(Object error, StackTrace stack) _onError;

  static String _flagFor(String userId) => 'ms_store_base_synced_$userId';

  /// After a Store purchase: always asks the Store.
  Future<void> sync() async {
    final userId = currentUserId();
    if (userId == null) return;
    try {
      final ticket = await requestTicket();
      final key = await collectionsIdKey(
        serviceTicket: ticket.serviceTicket,
        publisherUserId: ticket.publisherUserId,
      );
      final base = await submitKey(key);
      if (base != 'none') await writeFlag(_flagFor(userId), base);
      await refreshEntitlements();
    } catch (e, s) {
      _onError(e, s);
    }
  }

  /// At launch and sign-in: only until the account has the Store purchase.
  Future<void> syncOnce() async {
    final userId = currentUserId();
    if (userId == null) return;
    if (await readFlag(_flagFor(userId)) != null) return;
    await sync();
  }
}
