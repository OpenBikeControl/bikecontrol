import 'package:bike_control/bluetooth/peripheral_server.dart';

/// Shared recovery for BLE peripheral emulators that advertise via a
/// [PeripheralServer]. The shared CoreBluetooth manager (or a stale
/// advertisement from a prior session) can already be advertising, making
/// CoreBluetooth reject `startAdvertising` with "Advertising has already
/// started." Mixing this in gives an emulator a one-shot stop+restart recovery
/// and a pre-emptive restart helper, without each emulator duplicating the guard.
///
/// Implementers provide the server and their own service-advertising call
/// (which carries that emulator's services / localName / scan-response config).
mixin PeripheralAdvertisingRecovery {
  PeripheralServer get advertisingServer;

  /// Start advertising THIS emulator's service(s) with its own config.
  Future<void> startServiceAdvertising();

  bool _recoveringAdvertising = false;

  /// Drop any stale/foreign advertisement, then (re)start ours. `stopAdvertising`
  /// is idempotent on Darwin, so this is safe to call when idle.
  Future<void> restartAdvertising() async {
    await advertisingServer.stopAdvertising();
    await startServiceAdvertising();
  }

  /// Recover from an "Advertising has already started" error by stopping and
  /// restarting our service once. Guarded so a persistent error cannot loop.
  /// Returns true if it handled the error (caller should then NOT also warn).
  Future<bool> recoverIfAlreadyAdvertising(String? error) async {
    final alreadyStarted = error?.toLowerCase().contains('already') ?? false;
    if (!alreadyStarted || _recoveringAdvertising) return false;
    _recoveringAdvertising = true;
    try {
      await advertisingServer.stopAdvertising();
      await startServiceAdvertising();
    } finally {
      _recoveringAdvertising = false;
    }
    return true;
  }
}
