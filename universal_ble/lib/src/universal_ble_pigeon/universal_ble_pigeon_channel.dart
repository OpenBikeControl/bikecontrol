import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:universal_ble/src/universal_ble_pigeon/universal_ble.g.dart';
import 'package:universal_ble/universal_ble.dart';

class UniversalBlePigeonChannel extends UniversalBlePlatform {
  static UniversalBlePigeonChannel? _instance;
  static UniversalBlePigeonChannel get instance =>
      _instance ??= UniversalBlePigeonChannel._();

  UniversalBlePigeonChannel._() {
    _setupListeners();
  }

  final _channel = UniversalBlePlatformChannel();

  @override
  Future<AvailabilityState> getBluetoothAvailabilityState() async {
    int state = await _channel.getBluetoothAvailabilityState();
    return AvailabilityState.parse(state);
  }

  @override
  Future<bool> enableBluetooth() {
    if (!BleCapabilities.supportsBluetoothEnableApi) {
      throw UnsupportedError("Not supported");
    }
    return _channel.enableBluetooth();
  }

  @override
  Future<bool> disableBluetooth() {
    if (!BleCapabilities.supportsBluetoothEnableApi) {
      throw UnsupportedError("Not supported");
    }
    return _channel.disableBluetooth();
  }

  @override
  Future<void> startScan({
    ScanFilter? scanFilter,
    PlatformConfig? platformConfig,
  }) async {
    await _ensureInitialized();
    await _channel.startScan(
      scanFilter.toUniversalScanFilter(),
    );
  }

  @override
  Future<void> stopScan() => _channel.stopScan();

  @override
  Future<BleConnectionState> getConnectionState(String deviceId) async {
    int state = await _channel.getConnectionState(deviceId);
    return BleConnectionState.parse(state);
  }

  @override
  Future<void> connect(String deviceId, {Duration? connectionTimeout}) =>
      _channel.connect(deviceId);

  @override
  Future<void> disconnect(String deviceId) => _channel.disconnect(deviceId);

  @override
  Future<List<BleService>> discoverServices(String deviceId) async {
    List<UniversalBleService?> universalBleServices =
        await _channel.discoverServices(deviceId);
    return List<BleService>.from(universalBleServices
        .where((e) => e != null)
        .map((e) => e!.toBleService())
        .toList());
  }

  @override
  Future<void> setNotifiable(String deviceId, String service,
      String characteristic, BleInputProperty bleInputProperty) {
    return _channel.setNotifiable(
      deviceId,
      service,
      characteristic,
      bleInputProperty.index,
    );
  }

  @override
  Future<Uint8List> readValue(
    String deviceId,
    String service,
    String characteristic, {
    final Duration? timeout,
  }) {
    return _channel.readValue(deviceId, service, characteristic);
  }

  @override
  Future<void> writeValue(
      String deviceId,
      String service,
      String characteristic,
      Uint8List value,
      BleOutputProperty bleOutputProperty) {
    return _channel.writeValue(
      deviceId,
      service,
      characteristic,
      value,
      bleOutputProperty.index,
    );
  }

  @override
  Future<int> requestMtu(String deviceId, int expectedMtu) =>
      _channel.requestMtu(deviceId, expectedMtu);

  @override
  Future<bool> isPaired(String deviceId) => _channel.isPaired(deviceId);

  @override
  Future<bool> pair(String deviceId) => _channel.pair(deviceId);

  @override
  Future<void> unpair(String deviceId) => _channel.unPair(deviceId);

  @override
  Future<List<BleDevice>> getSystemDevices(
    List<String>? withServices,
  ) async {
    var devices = await _channel.getSystemDevices(withServices ?? []);
    return List<BleDevice>.from(
      devices.map((e) => e.toBleDevice(isSystemDevice: true)).toList(),
    );
  }

  /// To set listeners
  void _setupListeners() {
    UniversalBleCallbackChannel.setUp(_UniversalBleCallbackHandler(
      scanResult: updateScanResult,
      availabilityChange: updateAvailability,
      connectionChanged: updateConnection,
      valueChanged: updateCharacteristicValue,
      pairStateChange: updatePairingState,
    ));
  }

  Future<void> _ensureInitialized() async {
    // Check bluetooth availability on Apple
    // so that it will ask permission only when required, and throw error on failed
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      AvailabilityState state = await getBluetoothAvailabilityState();
      switch (state) {
        case AvailabilityState.unauthorized:
          throw PlatformException(
            code: "Unauthorized",
            message: "Not authorized to access Bluetooth",
          );
        case AvailabilityState.unsupported:
          throw PlatformException(
            code: "Unsupported",
            message: "Bluetooth is not supported",
          );
        default:
        // Ignore rest..
      }
    }
  }
}

extension _BleServiceExtension on UniversalBleService {
  BleService toBleService() {
    List<BleCharacteristic> bleCharacteristics = [];
    for (UniversalBleCharacteristic? characteristic in characteristics ?? []) {
      if (characteristic == null) continue;
      List<int?>? properties = List<int?>.from(characteristic.properties);
      bleCharacteristics.add(BleCharacteristic(
        characteristic.uuid,
        List<CharacteristicProperty>.from(
          properties.map((e) => CharacteristicProperty.parse(e ?? 1)),
        ),
      ));
    }
    return BleService(uuid, bleCharacteristics);
  }
}

class _UniversalBleCallbackHandler extends UniversalBleCallbackChannel {
  OnAvailabilityChange availabilityChange;
  OnScanResult scanResult;
  OnConnectionChange connectionChanged;
  OnValueChange valueChanged;
  OnPairingStateChange pairStateChange;

  _UniversalBleCallbackHandler({
    required this.availabilityChange,
    required this.scanResult,
    required this.connectionChanged,
    required this.valueChanged,
    required this.pairStateChange,
  });

  @override
  void onAvailabilityChanged(int state) =>
      availabilityChange(AvailabilityState.parse(state));

  @override
  void onConnectionChanged(String deviceId, bool connected, String? error) =>
      connectionChanged(deviceId, connected, error);

  @override
  void onScanResult(UniversalBleScanResult result) =>
      scanResult(result.toBleDevice());

  @override
  void onValueChanged(
          String deviceId, String characteristicId, Uint8List value) =>
      valueChanged(deviceId, characteristicId, value);

  @override
  void onPairStateChange(String deviceId, bool isPaired, String? error) =>
      pairStateChange(deviceId, isPaired);
}

extension _UniversalBleScanResultExtension on UniversalBleScanResult {
  BleDevice toBleDevice({bool? isSystemDevice}) {
    return BleDevice(
      name: name,
      deviceId: deviceId,
      rssi: rssi,
      isPaired: isPaired,
      isSystemDevice: isSystemDevice,
      services: services?.map(BleUuidParser.string).toList() ?? [],
      manufacturerDataList: manufacturerDataList
              ?.map((e) => ManufacturerData(e.companyIdentifier, e.data))
              .toList() ??
          [],
    );
  }
}

extension _ScanFilterExtension on ScanFilter? {
  UniversalScanFilter? toUniversalScanFilter() {
    List<UniversalManufacturerDataFilter>? manufacturerDataFilters = this
        ?.withManufacturerData
        .map((e) => UniversalManufacturerDataFilter(
              companyIdentifier: e.companyIdentifier,
              data: e.payloadPrefix,
              mask: e.payloadMask,
            ))
        .toList();

    // Windows crashes if it's null, so we need to pass empty scan filter in this case
    return UniversalScanFilter(
      withServices: this?.withServices.toValidUUIDList() ?? [],
      withNamePrefix: this?.withNamePrefix ?? [],
      withManufacturerData: manufacturerDataFilters ?? [],
    );
  }
}
