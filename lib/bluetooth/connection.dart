import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:gamepads/gamepads.dart';
import 'package:swift_control/bluetooth/devices/bluetooth_device.dart';
import 'package:swift_control/bluetooth/devices/gamepad/gamepad_device.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/actions/android.dart';
import 'package:swift_control/utils/keymap/keymap.dart';
import 'package:swift_control/utils/requirements/android.dart';
import 'package:universal_ble/universal_ble.dart';

import 'devices/base_device.dart';
import 'devices/zwift/constants.dart';
import 'messages/notification.dart';

class Connection {
  final devices = <BaseDevice>[];

  List<BluetoothDevice> get bluetoothDevices => devices.whereType<BluetoothDevice>().toList();
  List<GamepadDevice> get gamepadDevices => devices.whereType<GamepadDevice>().toList();

  var _androidNotificationsSetup = false;

  final _connectionQueue = <BaseDevice>[];
  var _handlingConnectionQueue = false;

  final Map<BaseDevice, StreamSubscription<BaseNotification>> _streamSubscriptions = {};
  final StreamController<BaseNotification> _actionStreams = StreamController<BaseNotification>.broadcast();
  Stream<BaseNotification> get actionStream => _actionStreams.stream;

  final Map<BaseDevice, StreamSubscription<bool>> _connectionSubscriptions = {};
  final StreamController<BaseDevice> _connectionStreams = StreamController<BaseDevice>.broadcast();
  Stream<BaseDevice> get connectionStream => _connectionStreams.stream;

  final _lastScanResult = <BleDevice>[];
  final ValueNotifier<bool> hasDevices = ValueNotifier(false);
  final ValueNotifier<bool> isScanning = ValueNotifier(false);

  Timer? _gamePadSearchTimer;

  void initialize() {
    UniversalBle.onAvailabilityChange = (available) {
      _actionStreams.add(LogNotification('Bluetooth availability changed: $available'));
      if (available == AvailabilityState.poweredOn) {
        performScanning();
      } else if (available == AvailabilityState.poweredOff) {
        reset();
      }
    };
    UniversalBle.onScanResult = (result) {
      if (_lastScanResult.none((e) => e.deviceId == result.deviceId)) {
        _lastScanResult.add(result);

        if (kDebugMode) {
          print('Scan result: ${result.name} - ${result.deviceId}');
        }

        final scanResult = BluetoothDevice.fromScanResult(result);

        if (scanResult != null) {
          _actionStreams.add(LogNotification('Found new device: ${scanResult.runtimeType}'));
          _addDevices([scanResult]);
        } else {
          final manufacturerData = result.manufacturerDataList;
          final data = manufacturerData
              .firstOrNullWhere((e) => e.companyId == ZwiftConstants.ZWIFT_MANUFACTURER_ID)
              ?.payload;
          if (data != null) {
            _actionStreams.add(LogNotification('Found unknown device with identifier: ${data.firstOrNull}'));
          }
        }
      }
    };

    UniversalBle.onValueChange = (deviceId, characteristicUuid, value) {
      final device = bluetoothDevices.firstOrNullWhere((e) => e.device.deviceId == deviceId);
      if (device == null) {
        _actionStreams.add(LogNotification('Device not found: $deviceId'));
        UniversalBle.disconnect(deviceId);
        return;
      } else {
        device.processCharacteristic(characteristicUuid, value);
      }
    };
    // ...
  }

  Future<void> performScanning() async {
    if (isScanning.value) {
      return;
    }
    isScanning.value = true;
    _actionStreams.add(LogNotification('Scanning for devices...'));

    // does not work on web, may not work on Windows
    if (!kIsWeb && !Platform.isWindows) {
      UniversalBle.getSystemDevices(
        withServices: BluetoothDevice.servicesToScan,
      ).then((devices) async {
        final baseDevices = devices.mapNotNull(BluetoothDevice.fromScanResult).toList();
        if (baseDevices.isNotEmpty) {
          _addDevices(baseDevices);
        }
      });
    }

    await UniversalBle.startScan(
      // allow all to enable Wahoo Kickr Bike Shift detection
      //scanFilter: ScanFilter(withServices: BaseDevice.servicesToScan),
      platformConfig: PlatformConfig(web: WebOptions(optionalServices: BluetoothDevice.servicesToScan)),
    );

    _gamePadSearchTimer = Timer.periodic(Duration(seconds: 3), (_) {
      Gamepads.list().then((list) {
        final pads = list.map((pad) => GamepadDevice(pad.name, id: pad.id)).toList();
        _addDevices(pads);

        final removedDevices = gamepadDevices.where((device) => list.none((pad) => pad.id == device.id)).toList();
        for (var device in removedDevices) {
          devices.remove(device);
          _streamSubscriptions[device]?.cancel();
          _streamSubscriptions.remove(device);
          _connectionSubscriptions[device]?.cancel();
          _connectionSubscriptions.remove(device);
          signalChange(device);
        }
      });
    });
    Gamepads.list().then((list) {
      final pads = list.map((pad) => GamepadDevice(pad.name, id: pad.id)).toList();
      _addDevices(pads);
    });
  }

  void _addDevices(List<BaseDevice> dev) {
    final newDevices = dev.where((device) => !devices.contains(device)).toList();
    devices.addAll(newDevices);
    _connectionQueue.addAll(newDevices);

    _handleConnectionQueue();

    hasDevices.value = devices.isNotEmpty;
    if (devices.isNotEmpty && !_androidNotificationsSetup && !kIsWeb && Platform.isAndroid) {
      _androidNotificationsSetup = true;
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
      _actionStreams.add(LogNotification('Connecting to: ${device.name}'));
      _connect(device)
          .then((_) {
            _handlingConnectionQueue = false;
            _actionStreams.add(LogNotification('Connection finished: ${device.name}'));
            if (_connectionQueue.isNotEmpty) {
              _handleConnectionQueue();
            }
          })
          .catchError((e) {
            _handlingConnectionQueue = false;
            _actionStreams.add(
              LogNotification('Connection failed: ${device.name} - $e'),
            );
            if (_connectionQueue.isNotEmpty) {
              _handleConnectionQueue();
            }
          });
    }
  }

  Future<void> _connect(BaseDevice device) async {
    try {
      final actionSubscription = device.actionStream.listen((data) {
        _actionStreams.add(data);
      });
      if (device is BluetoothDevice) {
        final connectionStateSubscription = UniversalBle.connectionStream(device.device.deviceId).listen((state) {
          device.isConnected = state;
          _connectionStreams.add(device);
          if (!device.isConnected) {
            devices.remove(device);
            _streamSubscriptions[device]?.cancel();
            _streamSubscriptions.remove(device);
            _connectionSubscriptions[device]?.cancel();
            _connectionSubscriptions.remove(device);
            _lastScanResult.clear();
            // try reconnect
            performScanning();
          }
        });
        _connectionSubscriptions[device] = connectionStateSubscription;
      }

      await device.connect();

      final newButtons = device.availableButtons.filter(
        (button) => actionHandler.supportedApp?.keymap.getKeyPair(button) == null,
      );
      for (final button in newButtons) {
        actionHandler.supportedApp?.keymap.addKeyPair(
          KeyPair(
            touchPosition: Offset.zero,
            buttons: [button],
            physicalKey: null,
            logicalKey: null,
            isLongPress: false,
          ),
        );
      }

      _streamSubscriptions[device] = actionSubscription;
    } catch (e, backtrace) {
      _actionStreams.add(LogNotification("$e\n$backtrace"));
      if (kDebugMode) {
        print(e);
        print("backtrace: $backtrace");
      }
      rethrow;
    }
  }

  void reset() {
    _actionStreams.add(LogNotification('Disconnecting all devices'));
    if (actionHandler is AndroidActions) {
      AndroidFlutterLocalNotificationsPlugin().stopForegroundService();
      _androidNotificationsSetup = false;
    }
    UniversalBle.stopScan();
    isScanning.value = false;
    for (var device in bluetoothDevices) {
      _streamSubscriptions[device]?.cancel();
      _streamSubscriptions.remove(device);
      _connectionSubscriptions[device]?.cancel();
      _connectionSubscriptions.remove(device);
      UniversalBle.disconnect(device.device.deviceId);
      signalChange(device);
    }
    _gamePadSearchTimer?.cancel();
    _lastScanResult.clear();
    hasDevices.value = false;
    devices.clear();
  }

  void signalNotification(BaseNotification notification) {
    _actionStreams.add(notification);
  }

  void signalChange(BaseDevice baseDevice) {
    _connectionStreams.add(baseDevice);
  }
}
