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

  final _connectionQueue = <BaseDevice>[];
  var _handlingConnectionQueue = false;

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
        _actionStreams.add(LogNotification('Found new device: ${result.name}'));
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

    // does not work on web, may not work on Windows
    if (!kIsWeb && !Platform.isWindows) {
      UniversalBle.getSystemDevices(
        withServices: [BleUuid.ZWIFT_CUSTOM_SERVICE_UUID, BleUuid.ZWIFT_RIDE_CUSTOM_SERVICE_UUID],
      ).then((devices) async {
        final baseDevices = devices.mapNotNull(BaseDevice.fromScanResult).toList();
        if (baseDevices.isNotEmpty) {
          _addDevices(baseDevices);
        }
      });
    }

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

    _connectionQueue.addAll(newDevices);
    _handleConnectionQueue();

    hasDevices.value = devices.isNotEmpty;
    if (devices.isNotEmpty && !androidNotificationsSetup && !kIsWeb && Platform.isAndroid) {
      androidNotificationsSetup = true;
      actionHandler.init(null);
      NotificationRequirement.setup().catchError((e) {
        _actionStreams.add(LogNotification(e.toString()));
      });
    }
  }

  void _handleConnectionQueue() {
    // windows apparently has issues when connecting to multiple devices at once, so don't
    if (_connectionQueue.isNotEmpty && !_handlingConnectionQueue) {
      _handlingConnectionQueue = true;
      final device = _connectionQueue.removeAt(0);
      _actionStreams.add(LogNotification('Connecting to: ${device.device.name}'));
      _connect(device)
          .then((_) {
            _handlingConnectionQueue = false;
            _actionStreams.add(LogNotification('Connection finished: ${device.device.name}'));
            if (_connectionQueue.isNotEmpty) {
              _handleConnectionQueue();
            }
          })
          .catchError((e) {
            _handlingConnectionQueue = false;
            _actionStreams.add(LogNotification('Connection failed: ${device.device.name} - $e'));
            if (_connectionQueue.isNotEmpty) {
              _handleConnectionQueue();
            }
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
