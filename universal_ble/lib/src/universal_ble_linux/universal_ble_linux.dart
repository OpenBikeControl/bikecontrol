import 'dart:async';

import 'package:bluez/bluez.dart';
import 'package:flutter/services.dart';
import 'package:universal_ble/src/models/model_exports.dart';
import 'package:universal_ble/src/universal_ble_filter_util.dart';
import 'package:universal_ble/src/universal_ble_platform_interface.dart';
import 'package:universal_ble/src/universal_logger.dart';

class UniversalBleLinux extends UniversalBlePlatform {
  UniversalBleLinux._();
  static UniversalBleLinux? _instance;
  static UniversalBleLinux get instance => _instance ??= UniversalBleLinux._();

  bool isInitialized = false;

  final BlueZClient _client = BlueZClient();
  late final UniversalBleFilterUtil _bleFilter = UniversalBleFilterUtil();
  BlueZAdapter? _activeAdapter;
  StreamSubscription? _deviceAdded;
  StreamSubscription? _deviceRemoved;
  Completer<void>? _initializationCompleter;
  final Map<String, BlueZDevice> _devices = {};
  final Map<String, StreamSubscription> _deviceUpdateStreamSubscriptions = {};
  final Map<String, StreamSubscription> _deviceAdvertisementSubscriptions = {};

  final Map<String, StreamSubscription> _characteristicPropertiesSubscriptions =
      {};

  @override
  Future<AvailabilityState> getBluetoothAvailabilityState() async {
    await _ensureInitialized();

    BlueZAdapter? adapter = _activeAdapter;
    if (adapter == null) {
      return AvailabilityState.unsupported;
    }
    return adapter.powered
        ? AvailabilityState.poweredOn
        : AvailabilityState.poweredOff;
  }

  @override
  Future<bool> enableBluetooth() async {
    await _ensureInitialized();
    if (_activeAdapter?.powered == true) return true;
    try {
      await _activeAdapter?.setPowered(true);
      return _activeAdapter?.powered ?? false;
    } catch (e) {
      UniversalLogger.logError('Error enabling bluetooth: $e');
      return false;
    }
  }

  @override
  Future<bool> disableBluetooth() async {
    await _ensureInitialized();
    var adapter = _activeAdapter;
    if (adapter == null) {
      throw "Adapter not available";
    }
    if (!adapter.powered) return true;
    try {
      await adapter.setPowered(false);
      return !adapter.powered;
    } catch (e) {
      UniversalLogger.logError('Error disabling bluetooth: $e');
      return false;
    }
  }

  @override
  Future<void> startScan({
    ScanFilter? scanFilter,
    PlatformConfig? platformConfig,
  }) async {
    await _ensureInitialized();
    var adapter = _activeAdapter;
    if (adapter == null) {
      throw "Adapter not available";
    }

    // Stop scan and clean all old advertisement listeners
    await stopScan();

    _bleFilter.scanFilter = scanFilter;

    // Setup listeners
    _deviceAdded ??= _client.deviceAdded.listen(_onDeviceAdd);
    _deviceRemoved ??= _client.deviceRemoved.listen(_onDeviceRemoved);

    await adapter.startDiscovery();

    for (var device in _client.devices) {
      _onDeviceAdd(device);
    }
  }

  @override
  Future<void> stopScan() async {
    await _ensureInitialized();
    try {
      // Dispose listeners
      _deviceAdded?.cancel();
      _deviceRemoved?.cancel();
      _deviceAdded = null;
      _deviceRemoved = null;

      // Stop Discovery
      if (_activeAdapter?.discovering == true) {
        await _activeAdapter?.stopDiscovery();
      }

      // Clean all advertisement listeners
      _deviceAdvertisementSubscriptions.removeWhere((e, value) {
        value.cancel();
        return true;
      });
    } catch (e) {
      UniversalLogger.logError("stopScan error: $e");
    }
  }

  @override
  Future<BleConnectionState> getConnectionState(String deviceId) async {
    BlueZDevice? device = _devices[deviceId] ??
        _client.devices.cast<BlueZDevice?>().firstWhere(
            (device) => device?.address == deviceId,
            orElse: () => null);
    bool connected = device?.connected ?? false;
    return connected
        ? BleConnectionState.connected
        : BleConnectionState.disconnected;
  }

  @override
  Future<void> connect(String deviceId, {Duration? connectionTimeout}) async {
    final device = _findDeviceById(deviceId);
    if (device.connected) {
      updateConnection(deviceId, true);
      return;
    }
    await device.connect();
  }

  @override
  Future<void> disconnect(String deviceId) async {
    final device = _findDeviceById(deviceId);
    if (!device.connected) {
      updateConnection(deviceId, false);
      return;
    }
    await device.disconnect();
  }

  @override
  Future<List<BleService>> discoverServices(String deviceId) async {
    final device = _findDeviceById(deviceId);
    if (device.gattServices.isEmpty && !device.servicesResolved) {
      await device.propertiesChanged.firstWhere((element) {
        if (element.contains(BluezProperty.connected)) {
          if (!device.connected) {
            UniversalLogger.logInfo(
              "DiscoverServicesFailed: Device disconnected",
            );
            return true;
          }
        }
        return element.contains(BluezProperty.servicesResolved);
      }).timeout(const Duration(seconds: 10), onTimeout: () {
        UniversalLogger.logInfo(
          "DiscoverServicesFailed: Timeout",
        );
        return [];
      });
    }

    // Few ble devices requires delay to perform operations after discovering services
    await Future.delayed(const Duration(seconds: 1));

    if (device.gattServices.isEmpty && !device.servicesResolved) {
      throw "Failed to resolve services";
    }

    List<BleService> services = [];
    for (final service in device.gattServices) {
      final characteristics = service.characteristics.map((e) {
        final properties = List<CharacteristicProperty>.from(e.flags
            .map((e) => e.toCharacteristicProperty())
            .where((element) => element != null)
            .toList());
        return BleCharacteristic(e.uuid.toString(), properties);
      }).toList();
      services.add(BleService(service.uuid.toString(), characteristics));
    }
    return services;
  }

  BlueZGattCharacteristic _getCharacteristic(
      String deviceId, String service, String characteristic) {
    final device = _findDeviceById(deviceId);
    final s = device.gattServices
        .cast<BlueZGattService?>()
        .firstWhere((s) => s?.uuid.toString() == service, orElse: () => null);
    final c = s?.characteristics.cast<BlueZGattCharacteristic?>().firstWhere(
        (c) => c?.uuid.toString() == characteristic,
        orElse: () => null);

    if (c == null) {
      throw Exception('Unknown characteristic:$characteristic');
    }
    return c;
  }

  @override
  Future<void> setNotifiable(String deviceId, String service,
      String characteristic, BleInputProperty bleInputProperty) async {
    final char = _getCharacteristic(deviceId, service, characteristic);

    String characteristicKey = "${deviceId}_${service}_$characteristic";

    if (bleInputProperty != BleInputProperty.disabled) {
      if (char.notifying) {
        UniversalLogger.logInfo('$characteristic already notifying');
        return;
      }

      await char.startNotify();

      if (_characteristicPropertiesSubscriptions[characteristicKey] != null) {
        _characteristicPropertiesSubscriptions[characteristicKey]?.cancel();
      }

      _characteristicPropertiesSubscriptions[characteristicKey] =
          char.propertiesChanged.listen((List<String> properties) {
        for (String property in properties) {
          switch (property) {
            case BluezProperty.value:
              updateCharacteristicValue(
                deviceId,
                characteristic,
                Uint8List.fromList(char.value),
              );
              break;
            default:
              UniversalLogger.logInfo(
                "UnhandledCharValuePropertyChange: $property",
              );
          }
        }
      });
    } else {
      if (char.notifying) await char.stopNotify();
      _characteristicPropertiesSubscriptions
          .remove(characteristicKey)
          ?.cancel();
    }
  }

  @override
  Future<Uint8List> readValue(
    String deviceId,
    String service,
    String characteristic, {
    final Duration? timeout,
  }) async {
    try {
      final c = _getCharacteristic(deviceId, service, characteristic);
      final data = await c.readValue();
      return Uint8List.fromList(data);
    } on BlueZFailedException catch (e) {
      throw PlatformException(
        code: e.errorCode ?? "ReadFailed",
        message: e.message,
      );
    }
  }

  @override
  Future<void> writeValue(
      String deviceId,
      String service,
      String characteristic,
      Uint8List value,
      BleOutputProperty bleOutputProperty) async {
    try {
      final c = _getCharacteristic(deviceId, service, characteristic);
      if (bleOutputProperty == BleOutputProperty.withResponse) {
        await c.writeValue(
          value,
          type: BlueZGattCharacteristicWriteType.request,
        );
      } else {
        await c.writeValue(
          value,
          type: BlueZGattCharacteristicWriteType.command,
        );
      }
    } on BlueZFailedException catch (e) {
      throw PlatformException(
        code: e.errorCode ?? "WriteFailed",
        message: e.message,
      );
    }
  }

  @override
  Future<int> requestMtu(String deviceId, int expectedMtu) async {
    final device = _findDeviceById(deviceId);
    if (!device.connected) throw Exception('Device not connected');
    for (BlueZGattService service in device.gattServices) {
      for (BlueZGattCharacteristic characteristic in service.characteristics) {
        int? mtu = characteristic.mtu;
        // The value provided by Bluez includes an extra 3 bytes from the GATT header, which needs to be removed.
        if (mtu != null) return mtu - 3;
      }
    }
    throw Exception('MTU not available');
  }

  @override
  Future<bool> pair(String deviceId) async {
    BlueZDevice device = _findDeviceById(deviceId);
    try {
      if (device.paired) return true;
      await device.pair();
      return true;
    } catch (error) {
      updatePairingState(deviceId, false);
      return false;
    }
  }

  @override
  Future<void> unpair(String deviceId) async {
    BlueZDevice device = _findDeviceById(deviceId);
    if (device.paired) {
      // await device.cancelPairing();
      await _activeAdapter?.removeDevice(device);
    }
  }

  @override
  Future<bool> isPaired(String deviceId) async {
    return _findDeviceById(deviceId).paired;
  }

  @override
  Future<List<BleDevice>> getSystemDevices(
    List<String>? withServices,
  ) async {
    List<BlueZDevice> devices =
        _client.devices.where((device) => device.connected).toList();
    if (withServices != null && withServices.isNotEmpty) {
      devices = devices.where((device) {
        if (device.servicesResolved) {
          return device.gattServices
              .map((e) => e.uuid.toString())
              .any((service) => withServices.contains(service));
        } else {
          UniversalLogger.logInfo(
            'Skipping: ${device.address}: Services not resolved yet.',
          );
          return false;
        }
      }).toList();
    }
    return devices
        .map((device) => device.toBleDevice(isSystemDevice: true))
        .toList();
  }

  AvailabilityState get _availabilityState {
    return _activeAdapter?.powered == true
        ? AvailabilityState.poweredOn
        : AvailabilityState.poweredOff;
  }

  BlueZDevice _findDeviceById(String deviceId) {
    final device = _devices[deviceId] ??
        _client.devices.cast<BlueZDevice?>().firstWhere(
            (device) => device?.address == deviceId,
            orElse: () => null);
    if (device == null) {
      throw Exception('Unknown deviceId:$deviceId');
    }
    return device;
  }

  Future<void> _ensureInitialized() async {
    if (isInitialized) return;

    if (_initializationCompleter != null) {
      await _initializationCompleter?.future;
      return;
    }

    _initializationCompleter = Completer<void>();
    try {
      await _client.connect();
      await _waitForAdapter(_client);

      _activeAdapter ??= _client.adapters.first;

      UniversalLogger.logInfo(
        'BleAdapter: ${_activeAdapter?.name} - ${_activeAdapter?.address}',
      );

      _activeAdapter?.propertiesChanged.listen((List<String> properties) {
        // Handle pairing state change
        for (final property in properties) {
          switch (property) {
            case BluezProperty.powered:
              updateAvailability(_availabilityState);
              break;
            case BluezProperty.discoverable:
            case BluezProperty.discovering:
              //  print("Adapter Discovering: ${_activeAdapter?.discovering}");
              break;
            case BluezProperty.propertyClass:
            default:
              UniversalLogger.logInfo(
                "UnhandledPropertyChanged: $property",
              );
          }
        }
      });

      updateAvailability(_availabilityState);
      isInitialized = true;
      _initializationCompleter?.complete();
      _initializationCompleter = null;
    } catch (e) {
      UniversalLogger.logError('Error initializing: $e');
      _initializationCompleter?.completeError(e);
      await _client.close();
      rethrow;
    }
  }

  Future<void> _waitForAdapter(BlueZClient client) async {
    if (client.adapters.isNotEmpty) return;

    int attempts = 0;
    while (attempts < 10 && client.adapters.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    if (client.adapters.isEmpty) {
      throw Exception('Bluetooth adapter unavailable');
    }
  }

  void _onDeviceAdd(BlueZDevice device) {
    BleDevice bleDevice = device.toBleDevice();
    if (!_bleFilter.matchesDevice(bleDevice)) {
      return;
    }

    // Update scan results only if rssi is available
    if (device.rssi != 0) {
      updateScanResult(bleDevice);
    }

    // Setup Cache
    _devices[device.address] = device;

    // Setup advertisements Listener
    _deviceAdvertisementSubscriptions[device.address] ??= device
        .propertiesChanged
        .where((e) =>
            e.contains(BluezProperty.rssi) ||
            e.contains(BluezProperty.manufacturerData) ||
            e.contains(BluezProperty.uuids))
        .listen((_) {
      if (_bleFilter.matchesDevice(bleDevice)) {
        updateScanResult(device.toBleDevice());
      }
    });

    // Setup update listener
    _deviceUpdateStreamSubscriptions[device.address] ??=
        device.propertiesChanged.listen((properties) {
      for (final property in properties) {
        switch (property) {
          // Connection/Pair updates
          case BluezProperty.connected:
            updateConnection(device.address, device.connected);
            break;
          case BluezProperty.paired:
            updatePairingState(device.address, device.paired);
            break;
          // Ignored these properties updates
          case BluezProperty.bonded:
          case BluezProperty.legacyPairing:
          case BluezProperty.servicesResolved:
          case BluezProperty.uuids:
          case BluezProperty.txPower:
          case BluezProperty.address:
          case BluezProperty.addressType:
          case BluezProperty.rssi:
          case BluezProperty.manufacturerData:
            break;
          default:
            UniversalLogger.logInfo(
              "UnhandledDevicePropertyChanged ${device.name} ${device.address}: $property",
            );
            break;
        }
      }
    });
  }

  void _onDeviceRemoved(BlueZDevice device) {
    _devices.remove(device.address);
    // Clean Update listeners
    _deviceUpdateStreamSubscriptions.removeWhere((key, value) {
      if (key == device.address) {
        value.cancel();
        return true;
      }
      return false;
    });
    // Clean Advertisement listeners
    _deviceAdvertisementSubscriptions.removeWhere((key, value) {
      if (key == device.address) {
        value.cancel();
        return true;
      }
      return false;
    });
  }
}

class BluezProperty {
  static const String rssi = 'RSSI';
  static const String connected = 'Connected';
  static const String txPower = 'TxPower';
  static const String bonded = 'Bonded';
  static const String manufacturerData = 'ManufacturerData';
  static const String legacyPairing = 'LegacyPairing';
  static const String servicesResolved = 'ServicesResolved';
  static const String paired = 'Paired';
  static const String address = 'Address';
  static const String addressType = 'AddressType';
  static const String modalias = 'Modalias';
  static const String uuids = 'UUIDs';
  static const String value = 'Value';
  static const String powered = 'Powered';
  static const String discoverable = 'Discoverable';
  static const String discovering = 'Discovering';
  static const String propertyClass = 'Class';
}

extension on BlueZGattCharacteristicFlag {
  CharacteristicProperty? toCharacteristicProperty() {
    return switch (this) {
      BlueZGattCharacteristicFlag.broadcast => CharacteristicProperty.broadcast,
      BlueZGattCharacteristicFlag.read => CharacteristicProperty.read,
      BlueZGattCharacteristicFlag.writeWithoutResponse =>
        CharacteristicProperty.writeWithoutResponse,
      BlueZGattCharacteristicFlag.write => CharacteristicProperty.write,
      BlueZGattCharacteristicFlag.notify => CharacteristicProperty.notify,
      BlueZGattCharacteristicFlag.indicate => CharacteristicProperty.indicate,
      BlueZGattCharacteristicFlag.authenticatedSignedWrites =>
        CharacteristicProperty.authenticatedSignedWrites,
      BlueZGattCharacteristicFlag.extendedProperties =>
        CharacteristicProperty.extendedProperties,
      _ => null,
    };
  }
}

extension on BlueZFailedException {
  /// Extract error code from message and parse into decimal
  /// example: 'Operation failed with ATT error: 0x90' => 144
  String? get errorCode {
    try {
      RegExp regExp = RegExp(r'0x\w+');
      Match? match = regExp.firstMatch(message);
      String? code = match?.group(0);
      if (code == null) return null;
      int? decimalValue = int.tryParse(
        code.replaceFirst('0x', ''),
        radix: 16,
      );
      return decimalValue?.toString() ?? code;
    } catch (e) {
      return null;
    }
  }
}

extension BlueZDeviceExtension on BlueZDevice {
  List<ManufacturerData> get manufacturerDataList => manufacturerData.entries
      .map((MapEntry<BlueZManufacturerId, List<int>> data) =>
          ManufacturerData(data.key.id, Uint8List.fromList(data.value)))
      .toList();

  BleDevice toBleDevice({bool? isSystemDevice}) {
    return BleDevice(
      name: name,
      deviceId: address,
      isPaired: paired,
      rssi: rssi,
      isSystemDevice: isSystemDevice,
      services: uuids.map((e) => e.toString()).toList(),
      manufacturerDataList: manufacturerDataList,
    );
  }
}
