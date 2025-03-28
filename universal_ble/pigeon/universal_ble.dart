import 'package:pigeon/pigeon.dart';

// dart run pigeon --input pigeon/universal_ble.dart
@ConfigurePigeon(
  PigeonOptions(
    dartPackageName: 'universal_ble',
    dartOut: 'lib/src/universal_ble_pigeon/universal_ble.g.dart',
    dartOptions: DartOptions(),
    kotlinOut:
        'android/src/main/kotlin/com/navideck/universal_ble/UniversalBle.g.kt',
    swiftOut: 'darwin/Classes/UniversalBle.g.swift',
    kotlinOptions: KotlinOptions(package: 'com.navideck.universal_ble'),
    swiftOptions: SwiftOptions(),
    cppOptions: CppOptions(namespace: 'universal_ble'),
    cppHeaderOut: 'windows/src/generated/universal_ble.g.h',
    cppSourceOut: 'windows/src/generated/universal_ble.g.cpp',
    debugGenerators: true,
  ),
)

/// Flutter -> Native
@HostApi()
abstract class UniversalBlePlatformChannel {
  @async
  int getBluetoothAvailabilityState();

  @async
  bool enableBluetooth();

  @async
  bool disableBluetooth();

  void startScan(UniversalScanFilter? filter);

  void stopScan();

  void connect(String deviceId);

  void disconnect(String deviceId);

  @async
  void setNotifiable(
    String deviceId,
    String service,
    String characteristic,
    int bleInputProperty,
  );

  @async
  List<UniversalBleService> discoverServices(String deviceId);

  @async
  Uint8List readValue(
    String deviceId,
    String service,
    String characteristic,
  );

  @async
  int requestMtu(String deviceId, int expectedMtu);

  @async
  void writeValue(
    String deviceId,
    String service,
    String characteristic,
    Uint8List value,
    int bleOutputProperty,
  );

  @async
  bool isPaired(String deviceId);

  @async
  bool pair(String deviceId);

  void unPair(String deviceId);

  @async
  List<UniversalBleScanResult> getSystemDevices(
    List<String> withServices,
  );

  int getConnectionState(String deviceId);
}

/// Native -> Flutter
@FlutterApi()
abstract class UniversalBleCallbackChannel {
  void onAvailabilityChanged(int state);

  void onPairStateChange(String deviceId, bool isPaired, String? error);

  void onScanResult(UniversalBleScanResult result);

  void onValueChanged(
    String deviceId,
    String characteristicId,
    Uint8List value,
  );

  void onConnectionChanged(
    String deviceId,
    bool connected,
    String? error,
  );
}

class UniversalBleScanResult {
  final String deviceId;
  final String? name;
  final bool? isPaired;
  final int? rssi;
  final List<UniversalManufacturerData>? manufacturerDataList;
  final List<String>? services;

  UniversalBleScanResult({
    required this.name,
    required this.deviceId,
    required this.isPaired,
    required this.rssi,
    required this.manufacturerDataList,
    required this.services,
  });
}

class UniversalBleService {
  String uuid;
  List<UniversalBleCharacteristic>? characteristics;
  UniversalBleService(this.uuid, this.characteristics);
}

class UniversalBleCharacteristic {
  String uuid;
  List<int> properties;
  UniversalBleCharacteristic(this.uuid, this.properties);
}

/// Scan Filters
class UniversalScanFilter {
  final List<String> withServices;
  final List<String> withNamePrefix;
  final List<UniversalManufacturerDataFilter> withManufacturerData;

  UniversalScanFilter(
    this.withServices,
    this.withNamePrefix,
    this.withManufacturerData,
  );
}

class UniversalManufacturerDataFilter {
  int companyIdentifier;
  Uint8List? data;
  Uint8List? mask;
  UniversalManufacturerDataFilter({
    required this.companyIdentifier,
    this.data,
    this.mask,
  });
}

class UniversalManufacturerData {
  final int companyIdentifier;
  final Uint8List data;

  UniversalManufacturerData({
    required this.companyIdentifier,
    required this.data,
  });
}
