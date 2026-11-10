import 'dart:async';
import 'dart:typed_data';

import 'package:prop/emulators/transporter/shared_peripheral.dart';
import 'package:universal_ble/universal_ble.dart';

/// Thin wrapper around [UniversalBlePeripheral]'s static API that lets
/// several PeripheralServer instances — and the trainer bridge — coexist
/// without clobbering each other's read/write handlers: universal_ble exposes
/// a single global read handler and write handler, so every role registers
/// with [SharedPeripheral]'s one router, which dispatches by characteristic
/// UUID.
class PeripheralServer {
  final Map<String, OnPeripheralReadRequest> _readHandlers = {};
  final Map<String, OnPeripheralWriteRequest> _writeHandlers = {};
  StreamSubscription<BlePeripheralConnectionStateChanged>? _connectionSub;
  StreamSubscription<BlePeripheralCharacteristicSubscriptionChanged>? _subscriptionSub;
  StreamSubscription<BlePeripheralAdvertisingStateChanged>? _advertisingSub;

  void onConnectionChanged(void Function(String deviceId, bool connected) callback) {
    _connectionSub?.cancel();
    _connectionSub = UniversalBlePeripheral.connectionStateStream.listen((e) {
      callback(e.deviceId, e.connected);
    });
  }

  void onSubscriptionChanged(void Function(String deviceId, String characteristicId, bool isSubscribed) callback) {
    _subscriptionSub?.cancel();
    _subscriptionSub = UniversalBlePeripheral.characteristicSubscriptionStream.listen((e) {
      callback(e.deviceId, e.characteristicId, e.isSubscribed);
    });
  }

  void onAdvertisingStateChanged(void Function(PeripheralAdvertisingState state, String? error) callback) {
    _advertisingSub?.cancel();
    _advertisingSub = UniversalBlePeripheral.advertisingStateStream.listen((e) {
      callback(e.state, e.error);
    });
  }

  void setReadHandler(String characteristicId, OnPeripheralReadRequest handler) {
    _readHandlers[characteristicId.toLowerCase()] = handler;
    SharedPeripheral.setReadHandler(characteristicId, handler);
  }

  void setWriteHandler(String characteristicId, OnPeripheralWriteRequest handler) {
    _writeHandlers[characteristicId.toLowerCase()] = handler;
    SharedPeripheral.setWriteHandler(characteristicId, handler);
  }

  Future<void> addService(BlePeripheralService service) => UniversalBlePeripheral.addService(service);

  Future<void> removeService(String serviceId) => UniversalBlePeripheral.removeService(serviceId);

  Future<void> clearServices() => UniversalBlePeripheral.clearServices();

  Future<void> startAdvertising({
    required List<String> services,
    String? localName,
    // Put service UUIDs in the Android scan response instead of the primary
    // advertisement. Needed when a 128-bit UUID + name would overflow the
    // 31-byte primary packet (e.g. the Rouvy Zwift emulator advertisement).
    bool servicesInScanResponse = false,
  }) => UniversalBlePeripheral.startAdvertising(
    services: services,
    localName: localName,
    platformConfig: PeripheralPlatformConfig(
      android: PeripheralAndroidOptions(
        addManufacturerDataInScanResponse: true,
        addServicesInScanResponse: servicesInScanResponse,
      ),
    ),
  );

  Future<void> stopAdvertising() => UniversalBlePeripheral.stopAdvertising();

  Future<void> notify({
    required String characteristicId,
    required Uint8List value,
    String? deviceId,
  }) => UniversalBlePeripheral.updateCharacteristicValue(
    characteristicId: characteristicId,
    value: value,
    deviceId: deviceId,
  );

  Future<PeripheralReadinessState> getAvailabilityState() => UniversalBlePeripheral.getAvailabilityState();

  Future<bool> get isReady async => (await getAvailabilityState()) == PeripheralReadinessState.ready;

  Future<void> dispose() async {
    await _connectionSub?.cancel();
    await _subscriptionSub?.cancel();
    await _advertisingSub?.cancel();
    _readHandlers.forEach(SharedPeripheral.removeReadHandler);
    _writeHandlers.forEach(SharedPeripheral.removeWriteHandler);
    _readHandlers.clear();
    _writeHandlers.clear();
  }
}
