import 'dart:async';
import 'dart:io';

import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/devices/ble_device.dart';
import 'package:swift_control/utils/requirements/android.dart';

import 'messages/notification.dart';

class Connection {
  final devices = <BleDevice>[];
  var androidNotificationsSetup = false;

  final Map<BleDevice, StreamSubscription<BaseNotification>> _streamSubscriptions = {};
  final StreamController<BaseNotification> _actionStreams = StreamController<BaseNotification>.broadcast();
  Stream<BaseNotification> get actionStream => _actionStreams.stream;

  final Map<BleDevice, StreamSubscription<BluetoothConnectionState>> _connectionSubscriptions = {};
  final StreamController<BleDevice> _connectionStreams = StreamController<BleDevice>.broadcast();
  Stream<BleDevice> get connectionStream => _connectionStreams.stream;

  var _lastScanResult = <ScanResult>[];
  final ValueNotifier<bool> hasDevices = ValueNotifier(false);
  late StreamSubscription<List<ScanResult>> _scanResultsSubscription;

  void startScanning() {
    _scanResultsSubscription = FlutterBluePlus.scanResults.listen(
      (results) {
        if (!results.contentEquals(_lastScanResult)) {
          final diff = results
              .where((result) => !_lastScanResult.contains(result))
              .joinToString(
                transform: (result) => "${result.device.platformName} (${result.advertisementData.manufacturerData})",
              );
          _lastScanResult = results;
          if (diff.isNotEmpty) {
            _actionStreams.add(LogNotification('Found new devices: $diff'));
          }
        }
        final scanResults = results.mapNotNull(BleDevice.fromScanResult).toList();
        _addDevices(scanResults);
      },
      onError: (e) {
        _actionStreams.add(LogNotification(e.toString()));
      },
    );
  }

  void _addDevices(List<BleDevice> dev) {
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

  Future<void> _connect(BleDevice bleDevice) async {
    try {
      await bleDevice.connect();

      final actionSubscription = bleDevice.actionStream.listen((data) {
        _actionStreams.add(data);
      });
      _streamSubscriptions[bleDevice] = actionSubscription;

      final connectionStateSubscription = bleDevice.device.connectionState.listen((state) async {
        _connectionStreams.add(bleDevice);
      });
      _connectionSubscriptions[bleDevice] = connectionStateSubscription;
    } catch (e, backtrace) {
      if (e is FlutterBluePlusException && e.code == FbpErrorCode.connectionCanceled.index) {
        // ignore connections canceled by the user
      } else {
        _actionStreams.add(LogNotification(e.toString()));
        if (kDebugMode) {
          print(e);
          print("backtrace: $backtrace");
        }
      }
    }
  }

  void reset() {
    FlutterBluePlus.stopScan();
    for (var device in devices) {
      device.device.disconnect();
    }
    devices.clear();
  }
}
