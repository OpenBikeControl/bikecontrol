import 'dart:async';
import 'dart:io';

import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:gamepads/gamepads.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/bluetooth/devices/bluetooth_device.dart';
import 'package:swift_control/bluetooth/devices/gamepad/gamepad_device.dart';
import 'package:swift_control/bluetooth/devices/hid/hid_device.dart';
import 'package:swift_control/bluetooth/devices/wahoo/wahoo_kickr_headwind.dart';
import 'package:swift_control/bluetooth/devices/zwift/protocol/zp.pb.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/actions/android.dart';
import 'package:swift_control/utils/core.dart';
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
  List<WahooKickrHeadwind> get accessories => devices.whereType<WahooKickrHeadwind>().toList();
  List<BaseDevice> get controllerDevices => [
    ...bluetoothDevices.where((d) => d is! WahooKickrHeadwind),
    ...gamepadDevices,
    ...devices.whereType<HidDevice>(),
  ];

  var _androidNotificationsSetup = false;

  final _connectionQueue = <BaseDevice>[];
  var _handlingConnectionQueue = false;

  final Map<BaseDevice, StreamSubscription<BaseNotification>> _streamSubscriptions = {};
  final StreamController<BaseNotification> _actionStreams = StreamController<BaseNotification>.broadcast();
  Stream<BaseNotification> get actionStream => _actionStreams.stream;
  List<({DateTime date, String entry})> lastLogEntries = [];

  final Map<BaseDevice, StreamSubscription<bool>> _connectionSubscriptions = {};
  final StreamController<BaseDevice> _connectionStreams = StreamController<BaseDevice>.broadcast();
  Stream<BaseDevice> get connectionStream => _connectionStreams.stream;

  final _lastScanResult = <BleDevice>[];
  final ValueNotifier<bool> hasDevices = ValueNotifier(false);
  final ValueNotifier<bool> isScanning = ValueNotifier(false);

  Timer? _gamePadSearchTimer;

  void initialize() {
    actionStream.listen((log) {
      lastLogEntries.add((date: DateTime.now(), entry: log.toString()));
      lastLogEntries = lastLogEntries.takeLast(kIsWeb ? 1000 : 60).toList();
    });

    UniversalBle.onAvailabilityChange = (available) {
      _actionStreams.add(BluetoothAvailabilityNotification(available == AvailabilityState.poweredOn));
      if (available == AvailabilityState.poweredOn && !kIsWeb) {
        core.permissions.getScanRequirements().then((perms) {
          if (perms.isEmpty) {
            performScanning();
          }
        });
      } else if (available == AvailabilityState.poweredOff) {
        reset();
      }
    };
    UniversalBle.onScanResult = (result) {
      // Update RSSI for already connected devices
      final existingDevice = bluetoothDevices.firstOrNullWhere(
        (e) => e.device.deviceId == result.deviceId,
      );
      if (existingDevice != null && existingDevice.rssi != result.rssi) {
        existingDevice.rssi = result.rssi;
        _connectionStreams.add(existingDevice); // Notify UI of update
      }

      if (_lastScanResult.none((e) => e.deviceId == result.deviceId && e.services.contentEquals(result.services))) {
        _lastScanResult.add(result);

        if (kDebugMode) {
          print('Scan result: ${result.name} - ${result.deviceId}');
        }

        final scanResult = BluetoothDevice.fromScanResult(result);

        if (scanResult != null) {
          _actionStreams.add(LogNotification('Found new device: ${kIsWeb ? scanResult.name : scanResult.runtimeType}'));
          addDevices([scanResult]);
        } else {
          final manufacturerData = result.manufacturerDataList;
          final data = manufacturerData
              .firstOrNullWhere((e) => e.companyId == ZwiftConstants.ZWIFT_MANUFACTURER_ID)
              ?.payload;
          if (data != null && kDebugMode) {
            _actionStreams.add(
              LogNotification('Found unknown device ${result.name} with identifier: ${data.firstOrNull}'),
            );
          }
        }
      }
    };

    UniversalBle.onValueChange = (deviceId, characteristicUuid, value) async {
      final device = bluetoothDevices.firstOrNullWhere((e) => e.device.deviceId == deviceId);
      if (device == null) {
        _actionStreams.add(LogNotification('Device not found: $deviceId'));
        UniversalBle.disconnect(deviceId);
        return;
      } else {
        try {
          await device.processCharacteristic(characteristicUuid, value);
        } catch (e, backtrace) {
          _actionStreams.add(
            LogNotification(
              "Error processing characteristic for device ${device.name} and char: $characteristicUuid: $e\n$backtrace",
            ),
          );
          if (kDebugMode) {
            print(e);
            print("backtrace: $backtrace");
          }
        }
      }
    };

    UniversalBle.onConnectionChange = (String deviceId, bool isConnected, String? error) {
      final device = bluetoothDevices.firstOrNullWhere((e) => e.device.deviceId == deviceId);
      if (device != null && !isConnected) {
        // allow reconnection
        _lastScanResult.removeWhere((d) => d.deviceId == deviceId);
      }
    };

    if (!kIsWeb && !screenshotMode) {
      core.permissions.getScanRequirements().then((perms) {
        if (perms.isEmpty) {
          performScanning();
        }
      });
    }
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
          addDevices(baseDevices);
        }
      });
    }

    await UniversalBle.startScan(
      // allow all to enable Wahoo Kickr Bike Shift detection
      //scanFilter: kIsWeb ? ScanFilter(withServices: BluetoothDevice.servicesToScan) : null,
      platformConfig: PlatformConfig(web: WebOptions(optionalServices: BluetoothDevice.servicesToScan)),
    );

    if (!kIsWeb) {
      _gamePadSearchTimer = Timer.periodic(Duration(seconds: 3), (_) {
        Gamepads.list().then((list) {
          final pads = list.map((pad) => GamepadDevice(pad.name.isEmpty ? 'Gamepad' : pad.name, id: pad.id)).toList();
          addDevices(pads);

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
    } else {
      isScanning.value = false;
    }

    if (devices.isNotEmpty && !_androidNotificationsSetup && !kIsWeb && Platform.isAndroid) {
      _androidNotificationsSetup = true;
      // start foreground service only when app is in foreground
      NotificationRequirement.setup().catchError((e) {
        _actionStreams.add(LogNotification(e.toString()));
      });
    }
  }

  Future<void> startMyWhooshServer() {
    return core.whooshLink.startServer().catchError((e) {
      core.settings.setMyWhooshLinkEnabled(false);
      _actionStreams.add(LogNotification('Error starting MyWhoosh "Link" server: $e'));
      _actionStreams.add(
        AlertNotification(
          LogLevel.LOGLEVEL_ERROR,
          'Error starting MyWhoosh "Link" server. Please make sure the "MyWhoosh Link" app is not already running on this device.',
        ),
      );
    });
  }

  void addDevices(List<BaseDevice> dev) {
    final ignoredDevices = core.settings.getIgnoredDevices();
    final ignoredDeviceIds = ignoredDevices.map((d) => d.id).toSet();
    final newDevices = dev.where((device) {
      if (devices.contains(device)) return false;

      // Check if device is in the ignored list
      if (device is BluetoothDevice) {
        if (ignoredDeviceIds.contains(device.device.deviceId)) {
          return false;
        }
      }

      return true;
    }).toList();
    devices.addAll(newDevices);
    _connectionQueue.addAll(newDevices);

    _handleConnectionQueue();

    hasDevices.value = devices.isNotEmpty;
  }

  void _handleConnectionQueue() {
    // windows apparently has issues when connecting to multiple devices at once, so don't
    if (_connectionQueue.isNotEmpty && !_handlingConnectionQueue && !screenshotMode) {
      _handlingConnectionQueue = true;
      final device = _connectionQueue.removeAt(0);
      _actionStreams.add(AlertNotification(LogLevel.LOGLEVEL_INFO, 'Connecting to: ${device.name}'));
      _connect(device)
          .then((_) {
            _handlingConnectionQueue = false;
            _actionStreams.add(AlertNotification(LogLevel.LOGLEVEL_INFO, 'Connection finished: ${device.name}'));
            if (_connectionQueue.isNotEmpty) {
              _handleConnectionQueue();
            }
          })
          .catchError((e) {
            device.isConnected = false;
            _handlingConnectionQueue = false;
            if (e is TimeoutException) {
              _actionStreams.add(
                AlertNotification(LogLevel.LOGLEVEL_WARNING, 'Unable to connect to ${device.name}: Timeout'),
              );
            } else {
              _actionStreams.add(
                AlertNotification(LogLevel.LOGLEVEL_ERROR, 'Connection failed: ${device.name} - $e'),
              );
            }
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
            disconnect(device, forget: false, persistForget: false);
            // try reconnect
            performScanning();
          }
        });
        _connectionSubscriptions[device] = connectionStateSubscription;
      }

      await device.connect();
      signalChange(device);

      final newButtons = device.availableButtons.filter(
        (button) => core.actionHandler.supportedApp?.keymap.getKeyPair(button) == null,
      );
      for (final button in newButtons) {
        core.actionHandler.supportedApp?.keymap.addKeyPair(
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

  Future<void> reset() async {
    _actionStreams.add(LogNotification('Disconnecting all devices'));
    if (core.actionHandler is AndroidActions) {
      AndroidFlutterLocalNotificationsPlugin().stopForegroundService();
      _androidNotificationsSetup = false;
    }
    final isBtEnabled = (await UniversalBle.getBluetoothAvailabilityState()) == AvailabilityState.poweredOn;
    if (isBtEnabled) {
      UniversalBle.stopScan();
    }
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

  Future<void> disconnect(BaseDevice device, {required bool persistForget, required bool forget}) async {
    if (device.isConnected) {
      await device.disconnect();
    }

    if (device is BluetoothDevice) {
      if (persistForget) {
        // Add device to ignored list when forgetting
        await core.settings.addIgnoredDevice(device.device.deviceId, device.name);
        _actionStreams.add(LogNotification('Device ignored: ${device.name}'));
      }
      if (!forget) {
        // allow reconnection
        _lastScanResult.removeWhere((d) => d.deviceId == device.device.deviceId);
      }

      // Clean up subscriptions and scan results for reconnection
      _streamSubscriptions[device]?.cancel();
      _streamSubscriptions.remove(device);
      _connectionSubscriptions[device]?.cancel();
      _connectionSubscriptions.remove(device);

      // Remove device from the list
      devices.remove(device);
      hasDevices.value = devices.isNotEmpty;
    }

    signalChange(device);
  }
}
