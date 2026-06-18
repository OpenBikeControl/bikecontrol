import 'dart:async';
import 'dart:typed_data';

import 'package:universal_ble/universal_ble.dart';

/// Thin wrapper around [UniversalBlePeripheral]'s static API that lets
/// several PeripheralServer instances coexist without clobbering each
/// other's read/write handlers — universal_ble exposes a single global
/// read handler and write handler, so we install one router per process
/// and dispatch by characteristic UUID.
class PeripheralServer {
  static bool _routerInstalled = false;
  static final Map<String, OnPeripheralReadRequest> _readHandlers = {};
  static final Map<String, OnPeripheralWriteRequest> _writeHandlers = {};

  static void _installRouter() {
    if (_routerInstalled) return;
    _routerInstalled = true;
    UniversalBlePeripheral.setReadRequestHandlers((deviceId, charId, offset, value) {
      return _readHandlers[charId.toLowerCase()]?.call(deviceId, charId, offset, value);
    });
    UniversalBlePeripheral.setWriteRequestHandlers((deviceId, charId, offset, value) {
      return _writeHandlers[charId.toLowerCase()]?.call(deviceId, charId, offset, value);
    });
  }

  final List<String> _ownedCharacteristics = [];
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
    _installRouter();
    final key = characteristicId.toLowerCase();
    _readHandlers[key] = handler;
    _ownedCharacteristics.add(key);
  }

  void setWriteHandler(String characteristicId, OnPeripheralWriteRequest handler) {
    _installRouter();
    final key = characteristicId.toLowerCase();
    _writeHandlers[key] = handler;
    _ownedCharacteristics.add(key);
  }

  Future<void> addService(BlePeripheralService service) => UniversalBlePeripheral.addService(service);

  Future<void> clearServices() => UniversalBlePeripheral.clearServices();

  Future<void> startAdvertising({
    required List<String> services,
    String? localName,
  }) => UniversalBlePeripheral.startAdvertising(
    services: services,
    localName: localName,
    platformConfig: PeripheralPlatformConfig(
      android: PeripheralAndroidOptions(addManufacturerDataInScanResponse: true),
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
    for (final key in _ownedCharacteristics) {
      _readHandlers.remove(key);
      _writeHandlers.remove(key);
    }
    _ownedCharacteristics.clear();
  }
}
