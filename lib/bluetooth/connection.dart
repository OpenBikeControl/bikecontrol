import 'dart:async';
import 'dart:io';

import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:bike_control/bluetooth/devices/gamepad/gamepad_device.dart';
import 'package:bike_control/bluetooth/devices/gyroscope/gyroscope_steering.dart';
import 'package:bike_control/bluetooth/devices/hid/hid_device.dart';
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/inactivity_disconnector.dart';
import 'package:bike_control/bluetooth/devices/wahoo/wahoo_kickr_headwind.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/bluetooth/wifi_trainer_scanner.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/interpreter.dart';
import 'package:bike_control/utils/requirements/android.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:gamepads/gamepads.dart';
import 'package:prop/prop.dart';
import 'package:universal_ble/universal_ble.dart';

import 'devices/base_device.dart';
import 'devices/zwift/constants.dart';
import 'messages/notification.dart';

class Connection {
  final devices = <BaseDevice>[];

  List<BluetoothDevice> get bluetoothDevices => devices.whereType<BluetoothDevice>().toList();
  List<ProxyDevice> get proxyDevices => devices.whereType<ProxyDevice>().toList();
  List<GamepadDevice> get gamepadDevices => devices.whereType<GamepadDevice>().toList();
  List<GyroscopeSteering> get gyroscopeDevices => devices.whereType<GyroscopeSteering>().toList();
  List<WahooKickrHeadwind> get accessories => devices.whereType<WahooKickrHeadwind>().toList();
  List<BaseDevice> get controllerDevices => [
    ...bluetoothDevices.where((d) => d is! WahooKickrHeadwind && d is! ProxyDevice),
    ...gamepadDevices,
    ...gyroscopeDevices,
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
  final StreamController<BluetoothDevice> _rssiConnectionStreams = StreamController<BluetoothDevice>.broadcast();
  Stream<BluetoothDevice> get rssiConnectionStream => _rssiConnectionStreams.stream;

  final _lastScanResult = <BleDevice>[];
  final ValueNotifier<bool> hasDevices = ValueNotifier(false);
  final ValueNotifier<bool> isScanning = ValueNotifier(false);

  Timer? _gamePadSearchTimer;
  WifiTrainerScanner? _wifiTrainerScanner;

  /// Auto-disconnects idle BLE controllers to save battery (issue #329).
  /// Created in [initialize] once `core` is ready.
  InactivityDisconnector? _inactivityDisconnector;

  /// Devices whose in-place ("No connection") disconnect is currently in
  /// flight. UniversalBle.disconnect resolves only after the platform's
  /// disconnect event has fired — while our connectionStream listener is
  /// still attached. Without this guard that listener re-enters [disconnect]
  /// WITHOUT keepInList and drops the device from the registry, orphaning the
  /// object the open details page still holds.
  final _inPlaceDisconnects = <BaseDevice>{};

  void initialize() {
    actionStream.listen((log) {
      lastLogEntries.add((date: DateTime.now(), entry: log.toString()));
      lastLogEntries = lastLogEntries.takeLast(kIsWeb ? 1000 : 60).toList();
    });

    _inactivityDisconnector = InactivityDisconnector(
      isTrainerAppConnected: () => core.logic.connectedNonLocalTrainerConnections.isNotEmpty,
      isOnlyLocalActive: () =>
          core.logic.enabledNonLocalTrainerConnections.isEmpty && core.settings.getLocalEnabled(),
      hasEligibleControllers: () =>
          controllerDevices.whereType<BluetoothDevice>().any((d) => d.isConnected),
      onTimeout: _onInactivityTimeout,
    );

    // A trainer app attaching/leaving any non-Local connection method drives
    // the battery saver. These emulator singletons live for the app lifetime,
    // so the listeners never need removing.
    for (final connection in [
      core.zwiftEmulator,
      core.zwiftMdnsEmulator,
      core.rouvyMdnsEmulator,
      core.obpMdnsEmulator,
      core.obpBluetoothEmulator,
      core.di2Emulator,
      core.whooshLink,
      core.remotePairing,
      core.remoteKeyboardPairing,
    ]) {
      connection.isConnected.addListener(() => _inactivityDisconnector?.onTrainerConnectionChanged());
    }

    if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isIOS)) {
      core.mediaKeyHandler.initialize();
      // Load saved media key detection state
      core.mediaKeyHandler.isMediaKeyDetectionEnabled.value = core.settings.getMediaKeyDetectionEnabled();
    }

    ftmsEmulator.trainerApp = () => core.settings.getTrainerApp()?.name;
    ftmsEmulator.isTrial = () => !IAPManager.instance.isProEnabledForCurrentDevice;

    // The advertised name depends on the selected trainer app (e.g. Rouvy →
    // "Zwift Hub"). Restart the transport on every change so the new name
    // shows up on the wire without the user reconnecting.
    core.settings.trainerAppListenable.addListener(() {
      unawaited(ftmsEmulator.restart());
      for (final pd in proxyDevices) {
        unawaited(pd.restartProxyEmulator());
      }
    });

    // Inform the user when ClickLogic restarts a device on purpose — its
    // entry greys out for a few seconds, so explain why.
    ClickLogic.onResetSent = (deviceId) {
      final device = bluetoothDevices.firstOrNullWhere((e) => e.device.deviceId == deviceId);
      if (device != null) {
        _actionStreams.add(
          AlertNotification(LogLevel.LOGLEVEL_INFO, AppLocalizations.current.deviceIsRestarting(device.toString())),
        );
      }
    };

    UniversalBle.onAvailabilityChange = (available) {
      _actionStreams.add(BluetoothAvailabilityNotification(available == AvailabilityState.poweredOn));
      if (available == AvailabilityState.poweredOn && !kIsWeb) {
        core.permissions.getScanRequirements().then((perms) {
          if (perms.isEmpty) {
            performScanning();
          }
        });
      } else if (available == AvailabilityState.poweredOff) {
        disconnectAll();
        stop();
      }
    };
    UniversalBle.onScanResult = (result) {
      // Update RSSI for already connected devices
      final existingDevice = bluetoothDevices.firstOrNullWhere(
        (e) => e.device.deviceId == result.deviceId,
      );
      if (existingDevice != null && existingDevice.rssi != result.rssi) {
        existingDevice.rssi = result.rssi;
        _rssiConnectionStreams.add(existingDevice); // Notify UI of update
      }

      if (_lastScanResult.none((e) => e.deviceId == result.deviceId && e.services.contentEquals(result.services))) {
        _lastScanResult.add(result);

        if (kDebugMode) {
          debugPrint('Scan result: ${result.name} - ${result.deviceId} - Services: ${result.services}');
        }

        try {
          final scanResult = BluetoothDevice.fromScanResult(result);

          if (scanResult != null) {
            _actionStreams.add(
              LogNotification('Found new device: ${scanResult.toString()}'),
            );
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
        } catch (e, backtrace) {
          _actionStreams.add(
            LogNotification("Error processing scan result for device ${result.deviceId}: $e\n$backtrace"),
          );
          if (kDebugMode) {
            print(e);
            print("backtrace: $backtrace");
          }
        }
      }
    };

    UniversalBle.onValueChange = (deviceId, characteristicUuid, value, timestamp) async {
      final device = bluetoothDevices.firstOrNullWhere((e) => e.device.deviceId == deviceId);
      if (device == null) {
        _actionStreams.add(LogNotification('Device not found: $deviceId'));
        UniversalBle.disconnect(deviceId);
        return;
      } else {
        if (kIsWeb) {
          // on web, log all characteristic changes for debugging
          _actionStreams.add(
            LogNotification(
              'Characteristic update for device ${device.toString()}, char: $characteristicUuid, value: ${bytesToReadableHex(value)}',
            ),
          );
        }
        try {
          await device.processCharacteristic(characteristicUuid, value);
        } catch (e, backtrace) {
          _actionStreams.add(
            LogNotification(
              "Error processing characteristic for device ${device.toString()} and char: $characteristicUuid: $e\n$backtrace",
            ),
          );
          if (kDebugMode) {
            print(e);
            print("backtrace: $backtrace");
          }
        }

        try {
          await _runCustomDeviceScript(
            device: device,
            characteristicUuid: characteristicUuid,
            value: value,
          );
        } catch (e, backtrace) {
          _actionStreams.add(
            LogNotification(
              "Error executing script for ${device.runtimeType} and char: $characteristicUuid: $e\n$backtrace",
            ),
          );
          if (e is FormatException) {
            final deviceType = device.runtimeType.toString();
            await DeviceScriptService.instance.deleteScript(deviceType);
            _actionStreams.add(
              LogNotification(
                "Deactivated custom script for ${device.runtimeType} due to invalid output format.",
              ),
            );
          }
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
      if (core.settings.getPhoneSteeringEnabled() && IAPManager.instance.isProEnabledForCurrentDeviceOrDidPurchaseOld) {
        toggleGyroscopeSteering(true);
      }
    }
  }

  Future<void> performScanning() async {
    if (isScanning.value) {
      return;
    }
    isScanning.value = true;
    _actionStreams.add(LogNotification(AppLocalizations.current.scanningForDevicesShort));

    if (screenshotMode) {
      return;
    }

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
      _startWifiTrainerDiscovery();
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
  }

  /// Browse the LAN for DirCon trainers (always on while scanning; the
  /// scanner excludes BikeControl's own advertisements). Failures — e.g. the
  /// user denied the Local Network permission — are logged and never affect
  /// BLE scanning.
  void _startWifiTrainerDiscovery() {
    _wifiTrainerScanner ??= WifiTrainerScanner(
      onFound: (trainer) {
        _actionStreams.add(LogNotification('Found WiFi trainer: ${trainer.syntheticDevice.name}'));
        addDevices([ProxyDevice.wifi(trainer.syntheticDevice, host: trainer.host, port: trainer.port)]);
      },
      onLost: (deviceId) {
        final device = proxyDevices.firstOrNullWhere((d) => d.scanResult.deviceId == deviceId);
        // A connected device stays — the live TCP connection is the source
        // of truth; mDNS visibility can flap.
        if (device != null && !device.isConnected && !device.isStarting.value) {
          devices.remove(device);
          _streamSubscriptions[device]?.cancel();
          _streamSubscriptions.remove(device);
          _connectionSubscriptions[device]?.cancel();
          _connectionSubscriptions.remove(device);
          hasDevices.value = devices.isNotEmpty;
          signalChange(device);
        }
      },
    );
    _wifiTrainerScanner!.start().catchError((Object e, s) {
      _actionStreams.add(LogNotification('WiFi trainer discovery unavailable: $e'));
      recordError(e, s, context: 'Wifi Trainer Discovery');
    });
  }

  Future<void> _runCustomDeviceScript({
    required BluetoothDevice device,
    required String characteristicUuid,
    required Uint8List value,
  }) async {
    if (!IAPManager.instance.isPurchased.value && !IAPManager.instance.hasActiveSubscription) {
      return;
    }

    final scriptOutput = await DeviceScriptService.instance.runCustomScript(
      deviceType: device.runtimeType.toString(),
      characteristicUuid: characteristicUuid,
      data: value,
    );

    if (scriptOutput == null) {
      return;
    }

    final serviceUuid = device.serviceUuidForCharacteristic(scriptOutput.characteristicUuid);
    if (serviceUuid == null) {
      _actionStreams.add(
        LogNotification(
          'Script output characteristic ${scriptOutput.characteristicUuid} was not found on ${device.runtimeType}.',
        ),
      );
      return;
    }

    final characteristic = device.services
        ?.firstOrNullWhere((s) => s.uuid == serviceUuid)
        ?.characteristics
        .firstOrNullWhere((c) => c.uuid == scriptOutput.characteristicUuid);

    if (characteristic == null) {
      _actionStreams.add(
        LogNotification(
          'Script output characteristic ${scriptOutput.characteristicUuid} was not found on ${device.runtimeType}.',
        ),
      );
      return;
    } else if (!characteristic.properties.containsAny([
      CharacteristicProperty.write,
      CharacteristicProperty.writeWithoutResponse,
    ])) {
      _actionStreams.add(
        LogNotification(
          'Script output characteristic ${scriptOutput.characteristicUuid} on ${device.runtimeType} does not support writing.',
        ),
      );
      return;
    }

    await UniversalBle.write(
      device.device.deviceId,
      serviceUuid,
      scriptOutput.characteristicUuid,
      scriptOutput.data,
      withoutResponse: characteristic.properties.contains(CharacteristicProperty.writeWithoutResponse) == true,
    );
  }

  Future<void> startMyWhooshServer() {
    return core.whooshLink.startServer().catchError((e) {
      core.settings.setMyWhooshLinkEnabled(false);
      _actionStreams.add(LogNotification('Error starting MyWhoosh "Link" server: $e'));
      _actionStreams.add(
        AlertNotification(
          LogLevel.LOGLEVEL_ERROR,
          AppLocalizations.current.errorStartingMyWhooshLink,
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

    // A device kept in the list during an automatic reset cycle reappeared in
    // the scan: its fresh instance is filtered out above (same id), so queue
    // the existing instance for reconnection instead.
    final resetDevices = dev
        .mapNotNull((d) => devices.firstOrNullWhere((e) => e == d))
        .where((e) => e.isResetting && !e.isConnected && !_connectionQueue.contains(e))
        .toList();
    _connectionQueue.addAll(resetDevices);

    _handleConnectionQueue();

    hasDevices.value = devices.isNotEmpty;
  }

  void toggleGyroscopeSteering(bool enable) {
    final existing = gyroscopeDevices.firstOrNull;
    if (existing != null && !enable) {
      // Remove gyroscope steering
      disconnect(existing, forget: true, persistForget: false);
    } else if (enable) {
      // Add gyroscope steering
      final gyroDevice = GyroscopeSteering();
      addDevices([gyroDevice]);
    }
  }

  void _handleConnectionQueue() {
    // windows apparently has issues when connecting to multiple devices at once, so don't
    if (_connectionQueue.isNotEmpty && !_handlingConnectionQueue && !screenshotMode) {
      _handlingConnectionQueue = true;
      final device = _connectionQueue.removeAt(0);

      final willConnect = device is! ProxyDevice || device.shouldAutoConnect;
      // Reconnections after an automatic reset happen every minute — keep
      // them silent. Captured here because the flag clears during handshake.
      final notify = willConnect && !device.isResetting;
      if (notify) {
        _actionStreams.add(
          AlertNotification(LogLevel.LOGLEVEL_INFO, AppLocalizations.current.connectingToDevice(device.toString())),
        );
      }
      _connect(device)
          .then((_) {
            _handlingConnectionQueue = false;

            if (notify) {
              _actionStreams.add(
                AlertNotification(
                  LogLevel.LOGLEVEL_INFO,
                  AppLocalizations.current.connectionSucceeded(device.toString()),
                ),
              );
            }
            if (_connectionQueue.isNotEmpty) {
              _handleConnectionQueue();
            }
          })
          .catchError((e) {
            device.isConnected = false;
            _handlingConnectionQueue = false;
            if (e is TimeoutException) {
              _actionStreams.add(
                AlertNotification(
                  LogLevel.LOGLEVEL_WARNING,
                  AppLocalizations.current.unableToConnectToDeviceTimeout(device.toString()),
                ),
              );
            } else {
              _actionStreams.add(
                AlertNotification(
                  LogLevel.LOGLEVEL_ERROR,
                  AppLocalizations.current.connectionFailed(device.toString(), e.toString()),
                ),
              );
            }
            if (_connectionQueue.isNotEmpty) {
              _handleConnectionQueue();
            }
          });
    }
  }

  /// Connect a device that is already in the list — used by the in-place
  /// picker ("No connection" -> Virtual Shifting / Proxy on the same object).
  ///
  /// Routes through the same [_connect] path the auto-connect queue uses so the
  /// action / connection-state listeners are (re)attached. A bare
  /// [ProxyDevice.startProxy] would reconnect the BLE upstream but leave
  /// `isConnected` stuck — the listener that flips it is torn down on
  /// disconnect and only [_connect] re-establishes it.
  Future<void> connectDevice(BaseDevice device) => _connect(device);

  Future<void> _connect(BaseDevice device) async {
    // Cancel any stale subscriptions from a previous connect attempt so a retry
    // doesn't stack listeners on the same device's streams.
    await _streamSubscriptions.remove(device)?.cancel();
    await _connectionSubscriptions.remove(device)?.cancel();

    final actionSubscription = device.actionStream.listen((data) {
      _actionStreams.add(data);
      // Any button press — from a BLE controller or any other input device —
      // counts as rider activity and slides the inactivity timer. The timer only
      // arms while a BLE controller is connected (see hasEligibleControllers), so
      // non-BLE button activity simply keeps a co-connected controller alive.
      if (data is ButtonNotification) {
        _inactivityDisconnector?.onButtonActivity();
      }
    });
    _streamSubscriptions[device] = actionSubscription;

    if (device is BluetoothDevice) {
      final connectionStateSubscription = device.device.connectionStream.listen((state) {
        device.isConnected = state;
        _connectionStreams.add(device);
        // An automatic reset cycle (ClickLogic) reboots the device every
        // minute — don't spam connect/disconnect notifications for it.
        final isSilentReset = device.isResetting;
        if (!state && !isSilentReset) {
          _actionStreams.add(
            AlertNotification(
              state ? LogLevel.LOGLEVEL_INFO : LogLevel.LOGLEVEL_WARNING,
              '${device.toString()} ${state ? AppLocalizations.current.connected.decapitalize() : AppLocalizations.current.disconnected.decapitalize()}',
            ),
          );
        }
        if (!isSilentReset) {
          core.flutterLocalNotificationsPlugin.show(
            1338,
            '${device.toString()} ${state ? AppLocalizations.current.connected.decapitalize() : AppLocalizations.current.disconnected.decapitalize()}',
            !state ? AppLocalizations.current.tryingToConnectAgain : null,
            NotificationDetails(
              android: AndroidNotificationDetails('Connection', 'Connection Status'),
              iOS: DarwinNotificationDetails(presentAlert: true, presentSound: false),
            ),
          );
        }
        if (!device.isConnected && !_inPlaceDisconnects.contains(device)) {
          disconnect(device, forget: false, persistForget: false);
          // try reconnect
          performScanning();
        }
      });
      _connectionSubscriptions[device] = connectionStateSubscription;
    }

    try {
      await device.connect();
      signalChange(device);

      IAPManager.instance.setAttributes();

      core.actionHandler.supportedApp?.keymap.addNewButtons(device.availableButtons);

      // Let the battery saver re-evaluate now that a device connected.
      _inactivityDisconnector?.onDeviceConnectionChanged();

      if (devices.isNotEmpty && !_androidNotificationsSetup && !kIsWeb && Platform.isAndroid) {
        _androidNotificationsSetup = true;
        // start foreground service only when app is in foreground
        NotificationRequirement.addPersistentNotification().catchError((e) {
          _actionStreams.add(LogNotification(e.toString()));
        });
      }
    } catch (e, backtrace) {
      await _streamSubscriptions.remove(device)?.cancel();
      await _connectionSubscriptions.remove(device)?.cancel();
      _actionStreams.add(LogNotification("$e\n$backtrace"));
      if (kDebugMode) {
        print(e);
        print("backtrace: $backtrace");
      }
      rethrow;
    }
  }

  void signalNotification(BaseNotification notification) {
    _actionStreams.add(notification);
  }

  void signalChange(BaseDevice baseDevice) {
    _connectionStreams.add(baseDevice);
  }

  Future<void> disconnect(
    BaseDevice device, {
    required bool persistForget,
    required bool forget,
    bool keepInList = false,
  }) async {
    if (keepInList) _inPlaceDisconnects.add(device);
    try {
      if (device.isConnected) {
        await device.disconnect();
      }
    } finally {
      if (keepInList) _inPlaceDisconnects.remove(device);
    }

    if (device is BluetoothDevice) {
      if (persistForget) {
        // Add device to ignored list when forgetting
        await core.settings.addIgnoredDevice(device.device.deviceId, device.toString());
        _actionStreams.add(LogNotification('Device ignored: ${device.toString()}'));
      }
      // For an in-place disconnect (the "No connection" picker entry) keep the
      // scan result so the scanner doesn't churn a fresh duplicate while the
      // user stays on the details page — the same device object must remain
      // reconnectable.
      if (!forget && !keepInList) {
        // allow reconnection
        _lastScanResult.removeWhere((d) => d.deviceId == device.device.deviceId);
      }

      // Clean up subscriptions and scan results for reconnection
      _streamSubscriptions[device]?.cancel();
      _streamSubscriptions.remove(device);
      _connectionSubscriptions[device]?.cancel();
      _connectionSubscriptions.remove(device);

      // Remove device from the list — unless it is rebooting due to an
      // automatic reset and will be back in a few seconds, or this is an
      // in-place disconnect (keepInList) where the open details page still
      // holds this exact object and must be able to reconnect it. Dropping it
      // here would orphan that reference: rediscovery builds a *new* device,
      // and the page's stale one fails to reconnect ("Device not found").
      if (!keepInList && (forget || !device.isResetting)) {
        devices.remove(device);
        hasDevices.value = devices.isNotEmpty;
      }
    } else if (device is GyroscopeSteering || device is HidDevice) {
      // Clean up subscriptions
      _streamSubscriptions[device]?.cancel();
      _streamSubscriptions.remove(device);
      _connectionSubscriptions[device]?.cancel();
      _connectionSubscriptions.remove(device);

      // Remove device from the list
      devices.remove(device);
      hasDevices.value = devices.isNotEmpty;
    }

    signalChange(device);
    _inactivityDisconnector?.onDeviceConnectionChanged();
  }

  Future<void> disconnectAll() async {
    _actionStreams.add(LogNotification(AppLocalizations.current.disconnectingAllDevices));
    for (var device in bluetoothDevices) {
      _streamSubscriptions[device]?.cancel();
      _streamSubscriptions.remove(device);
      _connectionSubscriptions[device]?.cancel();
      _connectionSubscriptions.remove(device);
      device.disconnect();
      signalChange(device);
      devices.remove(device);
    }
    _gamePadSearchTimer?.cancel();
    _lastScanResult.clear();
    hasDevices.value = false;
    _inactivityDisconnector?.onDeviceConnectionChanged();
  }

  Future<void> stop() async {
    final isBtEnabled = (await UniversalBle.getBluetoothAvailabilityState()) == AvailabilityState.poweredOn;
    if (isBtEnabled) {
      UniversalBle.stopScan();
    }
    _wifiTrainerScanner?.stop();
    isScanning.value = false;
    _lastScanResult.clear();
    _androidNotificationsSetup = false;
  }

  // ── Inactivity / battery-saver disconnect (issue #329) ─────────────────────

  /// Called by [_inactivityDisconnector] when the idle timeout elapses.
  /// Disconnects every connected BLE controller (battery-powered; ProxyDevice
  /// and accessories excluded), then surfaces an in-app alert with a Reconnect
  /// action and an OS push notification. [timeout] is the elapsed window, used
  /// for the human-readable message.
  void _onInactivityTimeout(Duration timeout) {
    final controllers = controllerDevices.whereType<BluetoothDevice>().where((d) => d.isConnected).toList();
    if (controllers.isEmpty) return;

    for (final device in controllers) {
      unawaited(
        disconnect(device, forget: true, persistForget: false).catchError((Object error, StackTrace stackTrace) {
          _actionStreams.add(
            LogNotification('Failed to disconnect ${device.toString()} after inactivity timeout: $error\n$stackTrace'),
          );
        }),
      );
    }

    _actionStreams.add(
      AlertNotification(
        LogLevel.LOGLEVEL_WARNING,
        AppLocalizations.current.controllersDisconnectedInactivity(timeout.inMinutes),
        buttonTitle: AppLocalizations.current.reconnect,
        // Route reconnection through the connection queue so BLE connects are
        // serialized (Windows fails on parallel connects) and ignored-device
        // filtering applies. disconnect(persistForget: false) above did not add
        // these to the ignore list, so they are eligible to be re-added.
        onTap: () => addDevices(controllers),
      ),
    );

    if (!kIsWeb) {
      core.flutterLocalNotificationsPlugin.show(
        1339,
        AppLocalizations.current.batterySaverTitle,
        AppLocalizations.current.controllersDisconnectedInactivity(timeout.inMinutes),
        NotificationDetails(
          android: AndroidNotificationDetails('BatterySaver', 'Battery Saver'),
          iOS: DarwinNotificationDetails(presentAlert: true, presentSound: false),
        ),
      );
    }
  }
}
