import 'dart:async';
import 'dart:io';

import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/devices/base_device.dart';
import 'package:swift_control/utils/requirements/android.dart';
import 'package:universal_ble/universal_ble.dart';

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

  var _lastScanResult = <BleDevice>[];
  final ValueNotifier<bool> hasDevices = ValueNotifier(false);
  late StreamSubscription<List<BleDevice>> _scanResultsSubscription;

  void startScanning() {
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

      await bleDevice.connect();

      _streamSubscriptions[bleDevice] = actionSubscription;

      final connectionStateSubscription = UniversalBle.connectionStream(bleDevice.device.deviceId).listen((
        state,
      ) async {
        bleDevice.isConnected = state.isConnected;
        _connectionStreams.add(bleDevice);
      });
      _connectionSubscriptions[bleDevice] = connectionStateSubscription;
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
    for (var device in devices) {
      UniversalBle.disconnect(device.device.deviceId);
    }
    devices.clear();
  }
}
