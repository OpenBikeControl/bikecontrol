import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:universal_ble/universal_ble.dart';

/// A fake BLE peripheral served by [FakeUniversalBlePlatform]: what it
/// advertises, which services it exposes after connect, canned read values
/// and an [onWrite] hook to script device responses (handshakes etc.).
class FakePeripheral {
  FakePeripheral({
    required this.deviceId,
    required this.name,
    List<String> advertisedServices = const [],
    List<BleService> services = const [],
    this.manufacturerData,
    Map<String, Uint8List> serviceData = const {},
    this.rssi = -50,
  }) : advertisedServices = List.of(advertisedServices),
       services = List.of(services),
       serviceData = Map.of(serviceData);

  final String deviceId;
  final String? name;

  /// Service UUIDs included in the scan result (lowercase 128-bit form).
  final List<String> advertisedServices;

  /// Advertised service data (e.g. the SRAM 0xFE51 device record), keyed by
  /// service UUID — surfaced on the scan result for advert-based filtering.
  final Map<String, Uint8List> serviceData;

  /// GATT database returned by discoverServices once connected.
  final List<BleService> services;

  final ManufacturerData? manufacturerData;
  final int rssi;

  /// Canned read responses, keyed by lowercase characteristic UUID.
  final Map<String, Uint8List> readValues = {};

  /// Descriptor values, keyed by lowercase descriptor UUID. Reads return the
  /// stored value (empty when unset); writes replace it.
  final Map<String, Uint8List> descriptorValues = {};

  /// Writes received from the app, in order.
  final writes = <({String service, String characteristic, Uint8List value, bool withoutResponse})>[];

  /// Characteristic UUIDs (lowercase) the app subscribed to (notify or indicate).
  final subscriptions = <String>[];

  /// Invoked on every write so a test can script the peripheral's reaction
  /// (e.g. answer the Zwift RideOn handshake with a notification).
  void Function(String service, String characteristic, Uint8List value)? onWrite;

  bool isConnected = false;

  /// While non-null, every connect attempt fails with this error — the fake
  /// throws it AND (like Android) delivers a disconnected connection event a
  /// radio-roundtrip later. Set back to null to let connects succeed again.
  Object? connectError;

  /// Whether a failed connect (see [connectError]) is followed by the
  /// Android-style disconnected event. Set to false to mimic a connect that
  /// just times out (macOS/iOS CoreBluetooth): the call errors and the
  /// platform never says anything else about the link.
  bool connectErrorDeliversDisconnect = true;

  /// Connect attempts the app has made against this peripheral.
  int connectAttempts = 0;

  BleDevice get scanResult => BleDevice(
    deviceId: deviceId,
    name: name,
    rssi: rssi,
    services: advertisedServices,
    manufacturerDataList: [if (manufacturerData != null) manufacturerData!],
    serviceData: serviceData,
  );
}

/// In-memory implementation of universal_ble's central role. Install once per
/// test file via `UniversalBle.setInstance(fake)` BEFORE
/// `core.connection.initialize()` (the callbacks live on the instance).
class FakeUniversalBlePlatform extends UniversalBlePlatform {
  /// Registered peripherals, looked up case-insensitively: universal_ble 3
  /// canonicalises every id it emits to lower-case, so the app addresses a
  /// peripheral registered as `AA:BB:..` by `aa:bb:..` afterwards.
  final Map<String, FakePeripheral> peripherals = LinkedHashMap<String, FakePeripheral>(
    equals: (a, b) => a.toLowerCase() == b.toLowerCase(),
    hashCode: (key) => key.toLowerCase().hashCode,
  );

  /// The [ConnectionPlatformConfig] of the most recent connect call.
  ConnectionPlatformConfig? lastConnectPlatformConfig;

  /// Every connect call's [ConnectionPlatformConfig], in order.
  final connectPlatformConfigs = <ConnectionPlatformConfig?>[];
  bool scanning = false;
  AvailabilityState availability = AvailabilityState.poweredOn;

  /// Thrown by [startScan] when set: a machine without a usable adapter.
  Object? startScanError;

  /// Register a peripheral. When a scan is running it shows up immediately.
  void addPeripheral(FakePeripheral peripheral) {
    peripherals[peripheral.deviceId] = peripheral;
    if (scanning) updateScanResult(peripheral.scanResult);
  }

  /// Unregister a peripheral, dropping its connection first if needed.
  void removePeripheral(String deviceId) {
    final peripheral = peripherals.remove(deviceId);
    if (peripheral != null && peripheral.isConnected) {
      peripheral.isConnected = false;
      updateConnection(deviceId, false, 'peripheral removed');
    }
  }

  /// Push a characteristic notification from [deviceId] to the app.
  void notify(String deviceId, String characteristicUuid, List<int> value) {
    updateCharacteristicValue(
      deviceId,
      characteristicUuid,
      Uint8List.fromList(value),
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Drop the connection from the peripheral side (e.g. battery died).
  void dropConnection(String deviceId) {
    final peripheral = peripherals[deviceId];
    if (peripheral != null) peripheral.isConnected = false;
    updateConnection(deviceId, false, 'connection dropped by peripheral');
  }

  /// Clear per-test state but keep the instance installed.
  void reset() {
    peripherals.clear();
    scanning = false;
    availability = AvailabilityState.poweredOn;
    startScanError = null;
  }

  FakePeripheral _require(String deviceId) {
    final peripheral = peripherals[deviceId];
    if (peripheral == null) {
      throw StateError('FakePeripheral $deviceId is not registered');
    }
    return peripheral;
  }

  @override
  Future<AvailabilityState> getBluetoothAvailabilityState() async => availability;

  @override
  Future<bool> enableBluetooth() async => true;

  @override
  Future<bool> disableBluetooth() async => true;

  @override
  Future<void> startScan({ScanFilter? scanFilter, PlatformConfig? platformConfig}) async {
    final error = startScanError;
    if (error != null) throw error;
    scanning = true;
    for (final peripheral in peripherals.values) {
      updateScanResult(peripheral.scanResult);
    }
  }

  @override
  Future<void> stopScan() async {
    scanning = false;
  }

  @override
  Future<bool> isScanning() async => scanning;

  @override
  Future<void> connect(
    String deviceId, {
    Duration? connectionTimeout,
    bool autoConnect = false,
    ConnectionPlatformConfig? platformConfig,
  }) async {
    lastConnectPlatformConfig = platformConfig;
    connectPlatformConfigs.add(platformConfig);
    final peripheral = _require(deviceId);
    peripheral.connectAttempts++;
    final error = peripheral.connectError;
    if (error != null) {
      // Android delivers a failed connect twice: the connect call errors AND
      // onConnectionStateChange reports disconnected (e.g. GATT 133/147).
      if (peripheral.connectErrorDeliversDisconnect) {
        Future<void>.delayed(const Duration(milliseconds: 50)).then((_) {
          updateConnection(deviceId, false, error.toString());
        });
      }
      throw error;
    }
    peripheral.isConnected = true;
    updateConnection(deviceId, true);
  }

  @override
  Future<void> disconnect(String deviceId) async {
    final peripheral = peripherals[deviceId];
    if (peripheral != null && peripheral.isConnected) {
      peripheral.isConnected = false;
      // Real platforms deliver the disconnect event a radio-roundtrip later —
      // always after Connection.disconnect() has finished its synchronous
      // teardown tail and cancelled its listeners. Delivering it earlier
      // re-enters Connection.disconnect through the still-attached
      // connectionStream listener and defeats keepInList. The delay must
      // outlast a ProxyDevice teardown (emulator restart + mDNS unregister).
      Future<void>.delayed(const Duration(milliseconds: 400)).then((_) {
        updateConnection(deviceId, false);
      });
    }
  }

  @override
  Future<List<BleService>> discoverServices(
    String deviceId,
    bool withDescriptors, {
    DiscoverServicesPlatformConfig? platformConfig,
  }) async =>
      // Defensive copy: BluetoothDevice.disconnect() clears the list it was
      // handed, which must not wipe the peripheral's GATT database.
      List.of(_require(deviceId).services);

  @override
  Future<void> setNotifiable(
    String deviceId,
    String service,
    String characteristic,
    BleInputProperty bleInputProperty,
  ) async {
    final peripheral = _require(deviceId);
    final uuid = characteristic.toLowerCase();
    if (bleInputProperty == BleInputProperty.disabled) {
      peripheral.subscriptions.remove(uuid);
    } else {
      peripheral.subscriptions.add(uuid);
    }
  }

  @override
  Future<Uint8List> readValue(String deviceId, String service, String characteristic, {Duration? timeout}) async =>
      _require(deviceId).readValues[characteristic.toLowerCase()] ?? Uint8List(0);

  @override
  Future<void> writeValue(
    String deviceId,
    String service,
    String characteristic,
    Uint8List value,
    BleOutputProperty bleOutputProperty,
  ) async {
    final peripheral = _require(deviceId);
    peripheral.writes.add((
      service: service,
      characteristic: characteristic,
      value: value,
      withoutResponse: bleOutputProperty == BleOutputProperty.withoutResponse,
    ));
    peripheral.onWrite?.call(service, characteristic, value);
  }

  @override
  Future<Uint8List> readDescriptorValue(
    String deviceId,
    String service,
    String characteristic,
    String descriptor, {
    Duration? timeout,
  }) async => _require(deviceId).descriptorValues[descriptor.toLowerCase()] ?? Uint8List(0);

  @override
  Future<void> writeDescriptorValue(
    String deviceId,
    String service,
    String characteristic,
    String descriptor,
    Uint8List value,
  ) async {
    _require(deviceId).descriptorValues[descriptor.toLowerCase()] = value;
  }

  @override
  Future<int> requestMtu(String deviceId, int expectedMtu) async => expectedMtu;

  @override
  Future<int> readRssi(String deviceId) async => _require(deviceId).rssi;

  @override
  Future<void> requestConnectionPriority(String deviceId, BleConnectionPriority priority) async {}

  @override
  Future<bool> isPaired(String deviceId) async => true;

  @override
  Future<bool> pair(String deviceId) async => true;

  @override
  Future<void> unpair(String deviceId) async {}

  @override
  Future<BleConnectionState> getConnectionState(String deviceId) async =>
      (peripherals[deviceId]?.isConnected ?? false) ? BleConnectionState.connected : BleConnectionState.disconnected;

  @override
  Future<List<BleDevice>> getSystemDevices(List<String>? withServices) async => [];
}
