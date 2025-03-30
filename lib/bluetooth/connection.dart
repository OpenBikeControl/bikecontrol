import 'dart:async';
import 'dart:io';

import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/requirements/android.dart';
import 'package:universal_ble/universal_ble.dart';

import '../bluetooth/ble.dart';
import 'devices/base_device.dart';
import 'messages/notification.dart';

class Connection {
  final devices = <BaseDevice>[];
  var androidNotificationsSetup = false;

  final Map<BaseDevice, StreamSubscription<BaseNotification>> _streamSubscriptions = {};
  final StreamController<BaseNotification> _actionStreams = StreamController<BaseNotification>.broadcast();
  Stream<BaseNotification> get actionStream => _actionStreams.stream;

  final Map<BaseDevice, StreamSubscription<BleConnectionUpdate>> _connectionSubscriptions = {};
  final StreamController<BaseDevice> _connectionStreams = StreamController<BaseDevice>.broadcast();
  Stream<BaseDevice> get connectionStream => _connectionStreams.stream;

  final _lastScanResult = <BleDevice>[];
  final ValueNotifier<bool> hasDevices = ValueNotifier(false);
  final ValueNotifier<bool> isScanning = ValueNotifier(false);

  void initialize() {
    UniversalBle.onScanResult = (result) {
      if (_lastScanResult.none((e) => e.deviceId == result.deviceId)) {
        _lastScanResult.add(result);
        _actionStreams.add(LogNotification('Found new devices: ${result.name}'));
        final scanResult = BaseDevice.fromScanResult(result);
        if (scanResult != null) {
          _addDevices([scanResult]);
        }
      }
    };

    UniversalBle.onValueChange = (deviceId, characteristicUuid, value) {
      final device = devices.firstOrNullWhere((e) => e.device.deviceId == deviceId);
      if (device == null) {
        _actionStreams.add(LogNotification('Device not found: $deviceId'));
        return;
      } else {
        device.processCharacteristic(characteristicUuid, value);
      }
    };
  }

  Future<void> performScanning() async {
    isScanning.value = true;

    UniversalBle.getSystemDevices(
      withServices: [BleUuid.ZWIFT_CUSTOM_SERVICE_UUID, BleUuid.ZWIFT_RIDE_CUSTOM_SERVICE_UUID],
    ).then((devices) {
      final baseDevices = devices.map((device) => BaseDevice.fromScanResult(device)).whereNotNull().toList();
      if (baseDevices.isNotEmpty) {
        _addDevices(baseDevices);
      }
    });

    await UniversalBle.startScan(
      scanFilter: ScanFilter(withServices: [BleUuid.ZWIFT_CUSTOM_SERVICE_UUID, BleUuid.ZWIFT_RIDE_CUSTOM_SERVICE_UUID]),
      platformConfig: PlatformConfig(web: WebOptions(optionalServices: [BleUuid.ZWIFT_CUSTOM_SERVICE_UUID])),
    );
    Future.delayed(Duration(seconds: 30)).then((_) {
      if (isScanning.value) {
        UniversalBle.stopScan();
        isScanning.value = false;
      }
    });
  }

  void _addDevices(List<BaseDevice> dev) {
    final newDevices = dev.where((device) => !devices.contains(device)).toList();
    devices.addAll(newDevices);

    for (final device in newDevices) {
      _connect(device).then((_) {});
    }

    hasDevices.value = devices.isNotEmpty;
    if (devices.isNotEmpty && !androidNotificationsSetup && !kIsWeb && Platform.isAndroid) {
      androidNotificationsSetup = true;
      actionHandler.init(null);
      NotificationRequirement.setup().catchError((e) {
        _actionStreams.add(LogNotification(e.toString()));
      });
    }
  }

  Future<void> _connect(BaseDevice bleDevice) async {
    try {
      final actionSubscription = bleDevice.actionStream.listen((data) {
        _actionStreams.add(data);
      });
      final connectionStateSubscription = UniversalBle.connectionStream(bleDevice.device.deviceId).listen((
        state,
      ) async {
        bleDevice.isConnected = state.isConnected;
        _connectionStreams.add(bleDevice);
      });
      _connectionSubscriptions[bleDevice] = connectionStateSubscription;

      await bleDevice.connect();

      _streamSubscriptions[bleDevice] = actionSubscription;
    } catch (e, backtrace) {
      _actionStreams.add(LogNotification(e.toString()));
      if (kDebugMode) {
        print(e);
        print("backtrace: $backtrace");
      }
    }
  }

  void reset() {
    UniversalBle.stopScan();
    isScanning.value = false;
    for (var device in devices) {
      _streamSubscriptions[device]?.cancel();
      _streamSubscriptions.remove(device);
      _connectionSubscriptions[device]?.cancel();
      _connectionSubscriptions.remove(device);
      UniversalBle.disconnect(device.device.deviceId);
    }
    _lastScanResult.clear();
    hasDevices.value = false;
    devices.clear();
  }
}
