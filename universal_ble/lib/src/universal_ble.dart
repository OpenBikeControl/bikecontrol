import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:universal_ble/src/ble_command_queue.dart';
import 'package:universal_ble/src/universal_ble_linux/universal_ble_linux.dart';
import 'package:universal_ble/src/universal_ble_pigeon/universal_ble_pigeon_channel.dart';
import 'package:universal_ble/src/universal_ble_web/universal_ble_web.dart';
import 'package:universal_ble/src/universal_logger.dart';
import 'package:universal_ble/universal_ble.dart';

class UniversalBle {
  /// Get platform specific implementation.
  static UniversalBlePlatform _platform = _defaultPlatform();
  static final BleCommandQueue _bleCommandQueue = BleCommandQueue();

  /// Set custom platform specific implementation (e.g. for testing).
  static void setInstance(UniversalBlePlatform instance) =>
      _platform = instance;

  /// Set global timeout for all commands.
  /// Default timeout is 10 seconds.
  /// Set to null to disable.
  static set timeout(Duration? duration) {
    _bleCommandQueue.timeout = duration;
  }

  /// Set how commands will be executed. By default, all commands are executed in a global queue (`QueueType.global`),
  /// with each command waiting for the previous one to finish.
  ///
  /// [QueueType.global] will execute commands of all devices in a single queue.
  /// [QueueType.perDevice] will execute command of each device in separate queues.
  /// [QueueType.none] will execute all commands in parallel.
  static set queueType(QueueType queueType) {
    _bleCommandQueue.queueType = queueType;
    UniversalLogger.logInfo('Queue ${queueType.name}');
  }

  /// Get Bluetooth availability state.
  /// To be notified of updates, set [onAvailabilityChange] listener.
  static Future<AvailabilityState> getBluetoothAvailabilityState() async {
    return await _bleCommandQueue.queueCommand(
      () => _platform.getBluetoothAvailabilityState(),
    );
  }

  /// Start scan.
  /// Scan results will arrive in [onScanResult] listener.
  /// It might throw errors if Bluetooth is not available.
  /// `webRequestOptions` is supported on Web only.
  static Future<void> startScan({
    ScanFilter? scanFilter,
    PlatformConfig? platformConfig,
  }) async {
    return await _bleCommandQueue.queueCommand(
      () => _platform.startScan(
        scanFilter: scanFilter,
        platformConfig: platformConfig,
      ),
      withTimeout: false,
    );
  }

  /// Stop scan.
  /// Set [onScanResult] listener to `null` if you don't need it anymore.
  /// It might throw errors if Bluetooth is not available.
  static Future<void> stopScan() async {
    return await _bleCommandQueue.queueCommand(
      () => _platform.stopScan(),
      withTimeout: false,
    );
  }

  /// Connection stream of a device
  static Stream<BleConnectionUpdate> connectionStream(String deviceId) =>
      _platform.connectionStream(deviceId);

  /// Connect to a device.
  /// It is advised to stop scanning before connecting.
  /// It throws error if device connection fails.
  /// Default connection timeout is 60 sec.
  /// Can throw `ConnectionException` or `PlatformException`.
  static Future<void> connect(
    String deviceId, {
    Duration? connectionTimeout,
  }) async {
    connectionTimeout ??= const Duration(seconds: 60);
    StreamSubscription? connectionSubscription;

    try {
      Completer<bool> completer = Completer();

      connectionSubscription = connectionStream(deviceId).listen(
        (BleConnectionUpdate event) {
          connectionSubscription?.cancel();
          if (!completer.isCompleted) {
            String? error = event.error;
            if (error != null) {
              completer.completeError(ConnectionException(error));
            } else {
              completer.complete(event.isConnected);
            }
          }
        },
        onError: (error) {
          if (!completer.isCompleted) {
            connectionSubscription?.cancel();
            completer.completeError(ConnectionException(error));
          }
        },
      );

      _platform
          .connect(deviceId, connectionTimeout: connectionTimeout)
          .catchError(
        (error) {
          if (!completer.isCompleted) {
            connectionSubscription?.cancel();
            completer.completeError(ConnectionException(error));
          }
        },
      );

      if (!await completer.future.timeout(connectionTimeout)) {
        throw ConnectionException("Failed to connect");
      }
    } finally {
      connectionSubscription?.cancel();
    }
  }

  /// Disconnect from a device.
  /// Get notified of connection state changes in [onConnectionChange] listener.
  static Future<void> disconnect(String deviceId) async {
    return await _bleCommandQueue.queueCommand(
      () => _platform.disconnect(deviceId),
      deviceId: deviceId,
    );
  }

  /// Discover services of a device.
  static Future<List<BleService>> discoverServices(String deviceId) async {
    return await _bleCommandQueue.queueCommand(
      () => _platform.discoverServices(deviceId),
      deviceId: deviceId,
    );
  }

  /// Set a characteristic notifiable.
  /// Set `bleInputProperty` to [BleInputProperty.notification] or [BleInputProperty.indication].
  /// Updates will arrive in [onValueChange] listener.
  /// To stop listening to a characteristic, set `bleInputProperty` to [BleInputProperty.disabled].
  static Future<void> setNotifiable(
    String deviceId,
    String service,
    String characteristic,
    BleInputProperty bleInputProperty,
  ) async {
    return await _bleCommandQueue.queueCommand(
      () => _platform.setNotifiable(
        deviceId,
        BleUuidParser.string(service),
        BleUuidParser.string(characteristic),
        bleInputProperty,
      ),
      deviceId: deviceId,
    );
  }

  /// Read a characteristic value.
  /// On iOS and MacOS this command will also trigger [onValueChange] listener.
  static Future<Uint8List> readValue(
    String deviceId,
    String service,
    String characteristic, {
    final Duration? timeout,
  }) async {
    return await _bleCommandQueue.queueCommand(
      () => _platform.readValue(
        deviceId,
        BleUuidParser.string(service),
        BleUuidParser.string(characteristic),
        timeout: timeout ?? _bleCommandQueue.timeout,
      ),
      timeout: timeout,
      deviceId: deviceId,
    );
  }

  /// Write a characteristic value.
  /// To write a characteristic value with response, set `bleOutputProperty` to [BleOutputProperty.withResponse].
  static Future<void> writeValue(
    String deviceId,
    String service,
    String characteristic,
    Uint8List value,
    BleOutputProperty bleOutputProperty,
  ) async {
    await _bleCommandQueue.queueCommand(
      () => _platform.writeValue(
        deviceId,
        BleUuidParser.string(service),
        BleUuidParser.string(characteristic),
        value,
        bleOutputProperty,
      ),
      deviceId: deviceId,
    );
  }

  /// Request MTU value.
  /// It will **attempt** to set the MTU (Maximum Transmission Unit) but it is not guaranteed to succeed due to platform limitations.
  /// It will always return the current MTU.
  static Future<int> requestMtu(String deviceId, int expectedMtu) async {
    return await _bleCommandQueue.queueCommand(
      () => _platform.requestMtu(deviceId, expectedMtu),
      deviceId: deviceId,
    );
  }

  /// Check if a device is paired.
  ///
  /// For `Apple` and `Web`, you have to pass a "pairingCommand" with an encrypted read or write characteristic.
  /// Returns true/false if it manages to execute the command.
  /// Returns null when no `pairingCommand` is passed.
  /// Note that it will trigger pairing if the device is not already paired.
  static Future<bool?> isPaired(
    String deviceId, {
    BleCommand? pairingCommand,
    Duration? connectionTimeout,
  }) async {
    if (BleCapabilities.hasSystemPairingApi) {
      return _bleCommandQueue.queueCommand(
        () => _platform.isPaired(deviceId),
        deviceId: deviceId,
      );
    }

    if (pairingCommand == null) {
      UniversalLogger.logWarning("PairingCommand required to get result");
      return null;
    }

    try {
      await _connectAndExecuteBleCommand(
        deviceId,
        pairingCommand,
        connectionTimeout: connectionTimeout,
        updateCallbackValue: false,
      );

      // Because pairingCommand will be never null, so we wont get Unknown result here
      return true;
    } catch (e) {
      UniversalLogger.logError("ExecuteBleCommandFailed: $e");
      return false;
    }
  }

  /// Pair a device.
  ///
  /// It throws error if pairing fails.
  ///
  /// On `Apple` and `Web`, it only works on devices with encrypted characteristics.
  /// It is advised to pass a pairingCommand with an encrypted read or write characteristic.
  /// When not passing a pairingCommand, you should afterwards use [isPaired] with a pairingCommand
  /// to verify the pairing state.
  ///
  /// On `Web/Windows` and `Web/Linux`, it does not work for devices that use `ConfirmOnly` pairing.
  /// Can throw `PairingException`, `ConnectionException` or `PlatformException`.
  static Future<void> pair(
    String deviceId, {
    BleCommand? pairingCommand,
    Duration? connectionTimeout,
  }) async {
    if (BleCapabilities.hasSystemPairingApi) {
      bool paired = await _platform.pair(deviceId);
      if (!paired) throw PairingException();
    } else {
      if (pairingCommand == null) {
        UniversalLogger.logWarning("PairingCommand required to get result");
      }
      await _connectAndExecuteBleCommand(
        deviceId,
        pairingCommand,
        connectionTimeout: connectionTimeout,
      );
    }
  }

  /// Unpair a device.
  /// It might throw an error if device is not paired.
  static Future<void> unpair(String deviceId) async {
    return await _bleCommandQueue.queueCommand(
      () => _platform.unpair(deviceId),
      deviceId: deviceId,
    );
  }

  /// Get connected devices to the system (connected by any app).
  /// Use [withServices] to filter devices by services.
  /// On `Apple`, [withServices] is required to get any connected devices. If not passed, several [18XX] generic services will be set by default.
  /// On `Android`, `Linux` and `Windows`, if [withServices] is used, then internally all services will be discovered for each device first (either by connecting or by using cached services).
  /// Not supported on `Web`.
  static Future<List<BleDevice>> getSystemDevices({
    List<String>? withServices,
  }) async {
    return await _bleCommandQueue.queueCommand(
      () => _platform.getSystemDevices(withServices?.toValidUUIDList()),
    );
  }

  /// Returns connection state of the device.
  /// All platforms will return `Connected/Disconnected` states.
  /// `Android` and `Apple` can also return `Connecting/Disconnecting` states.
  static Future<BleConnectionState> getConnectionState(String deviceId) async {
    return await _bleCommandQueue.queueCommand(
      () => _platform.getConnectionState(deviceId),
    );
  }

  /// Enable Bluetooth.
  /// It might throw errors if Bluetooth is not available.
  /// Not supported on `Web` and `Apple`.
  static Future<bool> enableBluetooth() async {
    return await _bleCommandQueue.queueCommand(
      () => _platform.enableBluetooth(),
    );
  }

  /// Disable Bluetooth.
  /// It might throw errors if Bluetooth is not available.
  /// Not supported on `Web` and `Apple`.
  static Future<bool> disableBluetooth() async {
    return await _bleCommandQueue.queueCommand(
      () => _platform.disableBluetooth(),
    );
  }

  /// [receivesAdvertisements] returns true on web if the browser supports receiving advertisements from a certain `deviceId`.
  /// The rest of the platforms will always return true.
  /// If true, then you will be getting scanResult updates for this device.
  ///
  /// For this feature to work, you need to enable the `chrome://flags/#enable-experimental-web-platform-features` flag.
  /// Not every browser supports this API yet.
  /// Even if the browser supports it, sometimes it won't fire any advertisement events even though the device may be sending them.
  static bool receivesAdvertisements(String deviceId) =>
      _platform.receivesAdvertisements(deviceId);

  /// Get Bluetooth state availability.
  static set onAvailabilityChange(OnAvailabilityChange? onAvailabilityChange) {
    _platform.onAvailabilityChange = onAvailabilityChange;
    if (onAvailabilityChange != null) {
      getBluetoothAvailabilityState().then((value) {
        onAvailabilityChange(value);
      }).onError((error, stackTrace) => null);
    }
  }

  static Future<void> _connectAndExecuteBleCommand(
    String deviceId,
    BleCommand? bleCommand, {
    Duration? connectionTimeout,
    bool updateCallbackValue = false,
  }) async {
    // Try to connect first
    if (await getConnectionState(deviceId) != BleConnectionState.connected) {
      UniversalLogger.logInfo("Connecting to $deviceId");
      await connect(
        deviceId,
        connectionTimeout: connectionTimeout,
      );
    }

    List<BleService> services = await discoverServices(deviceId);
    UniversalLogger.logInfo("Discovered services: ${services.length}");

    if (bleCommand == null) {
      // Just attempt pairing
      await _attemptPairingReadingAll(deviceId, services);
      return;
    }

    await _executeBleCommand(deviceId, services, bleCommand);
    if (updateCallbackValue) _platform.updatePairingState(deviceId, true);
  }

  // Fire and forget, and do not rely on result
  static _attemptPairingReadingAll(
    String deviceId,
    List<BleService> services,
  ) async {
    bool containsReadCharacteristics = false;
    try {
      // If BleCommand not given, fallback to reading all characteristics
      for (BleService service in services) {
        for (BleCharacteristic characteristic in service.characteristics) {
          if (characteristic.properties.contains(CharacteristicProperty.read)) {
            containsReadCharacteristics = true;
            await readValue(
              deviceId,
              service.uuid,
              characteristic.uuid,
              timeout: const Duration(seconds: 30),
            );
          }
        }
      }
    } catch (_) {}

    if (!containsReadCharacteristics) {
      throw PairingException("No readable characteristic found");
    }
  }

  static Future<void> _executeBleCommand(
    String deviceId,
    List<BleService> services,
    BleCommand bleCommand,
  ) async {
    // First find BleCommand's characteristic
    BleCharacteristic? characteristic;
    for (BleService service in services) {
      if (BleUuidParser.compareStrings(service.uuid, bleCommand.service)) {
        for (BleCharacteristic char in service.characteristics) {
          if (BleUuidParser.compareStrings(
              char.uuid, bleCommand.characteristic)) {
            characteristic = char;
            break;
          }
        }
      }
    }

    if (characteristic == null) {
      throw PairingException("BleCommand not found in discovered services");
    }

    // Check if BleCommand Supports Read or Write
    BleOutputProperty? bleOutputProperty;
    if (characteristic.properties.contains(CharacteristicProperty.write)) {
      bleOutputProperty = BleOutputProperty.withResponse;
    } else if (characteristic.properties
        .contains(CharacteristicProperty.writeWithoutResponse)) {
      bleOutputProperty = BleOutputProperty.withoutResponse;
    } else if (!characteristic.properties
        .contains(CharacteristicProperty.read)) {
      throw PairingException(
        "BleCommand does not support read or write operation",
      );
    }

    Uint8List? value = bleCommand.writeValue;

    try {
      if (value != null && bleOutputProperty != null) {
        await writeValue(
          deviceId,
          bleCommand.service,
          bleCommand.characteristic,
          value,
          bleOutputProperty,
        );
      } else {
        // Fallback to read if supported
        await readValue(
          deviceId,
          bleCommand.service,
          bleCommand.characteristic,
          timeout: const Duration(seconds: 30),
        );
      }
    } catch (e) {
      throw PairingException(e.toString());
    }
  }

  /// Get updates of remaining items of a queue.
  static set onQueueUpdate(OnQueueUpdate? onQueueUpdate) =>
      _bleCommandQueue.onQueueUpdate = onQueueUpdate;

  /// Get scan results.
  static set onScanResult(OnScanResult? bleDevice) =>
      _platform.onScanResult = bleDevice;

  /// Get connection state changes.
  static set onConnectionChange(OnConnectionChange? onConnectionChange) =>
      _platform.onConnectionChange = onConnectionChange;

  /// Get characteristic value updates, set `bleInputProperty` in [setNotifiable] to [BleInputProperty.notification] or [BleInputProperty.indication].
  static set onValueChange(OnValueChange? onValueChange) =>
      _platform.onValueChange = onValueChange;

  /// Get pair state changes.
  static set onPairingStateChange(OnPairingStateChange pairingStateChange) =>
      _platform.onPairingStateChange = pairingStateChange;

  static UniversalBlePlatform _defaultPlatform() {
    if (kIsWeb) return UniversalBleWeb.instance;
    if (defaultTargetPlatform == TargetPlatform.linux) {
      return UniversalBleLinux.instance;
    }
    return UniversalBlePigeonChannel.instance;
  }
}
