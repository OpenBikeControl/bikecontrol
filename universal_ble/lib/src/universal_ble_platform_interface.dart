import 'dart:async';
import 'dart:typed_data';
import 'package:universal_ble/universal_ble.dart';

abstract class UniversalBlePlatform {
  // Do not use these directly to push updates
  OnScanResult? onScanResult;
  OnConnectionChange? onConnectionChange;
  OnValueChange? onValueChange;
  OnAvailabilityChange? onAvailabilityChange;
  OnPairingStateChange? onPairingStateChange;
  final Map<String, bool> _pairStateMap = {};
  StreamController<BleConnectionUpdate>? _connectionStreamController;

  Future<AvailabilityState> getBluetoothAvailabilityState();

  Future<bool> enableBluetooth();

  Future<bool> disableBluetooth();

  Future<void> startScan({
    ScanFilter? scanFilter,
    PlatformConfig? platformConfig,
  });

  Future<void> stopScan();

  Future<void> connect(String deviceId, {Duration? connectionTimeout});

  Future<void> disconnect(String deviceId);

  Future<List<BleService>> discoverServices(String deviceId);

  Future<void> setNotifiable(String deviceId, String service,
      String characteristic, BleInputProperty bleInputProperty);

  Future<Uint8List> readValue(
    String deviceId,
    String service,
    String characteristic, {
    final Duration? timeout,
  });

  Future<void> writeValue(
      String deviceId,
      String service,
      String characteristic,
      Uint8List value,
      BleOutputProperty bleOutputProperty);

  Future<int> requestMtu(String deviceId, int expectedMtu);

  Future<bool> isPaired(String deviceId);

  Future<bool> pair(String deviceId);

  Future<void> unpair(String deviceId);

  Future<BleConnectionState> getConnectionState(String deviceId);

  Future<List<BleDevice>> getSystemDevices(
    List<String>? withServices,
  );

  bool receivesAdvertisements(String deviceId) => true;

  Stream<BleConnectionUpdate> connectionStream(String deviceId) {
    _setupConnectionStreamIfRequired();
    return _connectionStreamController!.stream;
  }

  void updateScanResult(BleDevice bleDevice) {
    try {
      onScanResult?.call(bleDevice);
    } catch (_) {}
  }

  void updateConnection(String deviceId, bool isConnected, [String? error]) {
    _connectionStreamController?.add(BleConnectionUpdate(
      deviceId: deviceId,
      isConnected: isConnected,
      error: error,
    ));

    try {
      onConnectionChange?.call(deviceId, isConnected, error);
    } catch (_) {}
  }

  void updateCharacteristicValue(
      String deviceId, String characteristicId, Uint8List value) {
    try {
      onValueChange?.call(
          deviceId, BleUuidParser.string(characteristicId), value);
    } catch (_) {}
  }

  void updateAvailability(AvailabilityState state) {
    try {
      onAvailabilityChange?.call(state);
    } catch (_) {}
  }

  void updatePairingState(String deviceId, bool isPaired) {
    if (_pairStateMap[deviceId] == isPaired) return;
    _pairStateMap[deviceId] = isPaired;

    try {
      onPairingStateChange?.call(deviceId, isPaired);
    } catch (_) {}
  }

  /// Creates an auto disposable streamController
  void _setupConnectionStreamIfRequired() {
    if (_connectionStreamController != null) return;

    _connectionStreamController = StreamController.broadcast();

    // Auto dispose if no more subscribers
    _connectionStreamController?.onCancel = () {
      // logInfo('Disposing Connection Stream');
      _connectionStreamController?.close();
      _connectionStreamController = null;
    };
  }
}

// Callback types
typedef OnConnectionChange = void Function(
    String deviceId, bool isConnected, String? error);

typedef OnValueChange = void Function(
    String deviceId, String characteristicId, Uint8List value);

typedef OnScanResult = void Function(BleDevice scanResult);

typedef OnAvailabilityChange = void Function(AvailabilityState state);

typedef OnPairingStateChange = void Function(String deviceId, bool isPaired);

typedef OnQueueUpdate = void Function(String id, int remainingQueueItems);
