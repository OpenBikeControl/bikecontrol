import 'dart:async';
import 'dart:io';

import 'package:bike_control/bluetooth/ble.dart';
import 'package:bike_control/bluetooth/devices/trainer_connection.dart';
import 'package:bike_control/bluetooth/messages/notification.dart' show AlertNotification;
import 'package:bike_control/bluetooth/peripheral_advertising_recovery.dart';
import 'package:bike_control/bluetooth/peripheral_server.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/widgets/apps/cycplus_bc2_ble_tile.dart';
import 'package:bike_control/widgets/title.dart' show packageInfoValue;
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/prop.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

/// Presents BikeControl as a CYCPLUS BC2 shifter, for trainer apps that take
/// buttons over Bluetooth only from one (MyWhoosh, paired as a steering device).
class CycplusBc2BluetoothEmulator extends TrainerConnection with PeripheralAdvertisingRecovery {
  final PeripheralServer _server;
  final _bc2 = CycplusBc2Emulator();
  bool _isServiceAdded = false;
  bool _isSubscribedToEvents = false;
  String? _currentDeviceId;

  static const actions = [
    InGameAction.shiftUp,
    InGameAction.shiftDown,
    InGameAction.steerLeft,
    InGameAction.steerRight,
  ];

  @override
  PeripheralServer get advertisingServer => _server;

  CycplusBc2BluetoothEmulator({@visibleForTesting PeripheralServer? server})
    : _server = server ?? PeripheralServer(),
      super(
        title: () => AppLocalizations.current.connectUsingBluetooth,
        type: ConnectionMethodType.bluetooth,
        supportedActions: actions,
      );

  Future<void> startServer() async {
    isStarted.value = true;

    _server.onConnectionChanged((deviceId, connected) {
      if (!connected && deviceId == _currentDeviceId) {
        if (isConnected.value) {
          core.connection.signalNotification(
            AlertNotification(LogLevel.LOGLEVEL_INFO, 'Disconnected from app: ${_appName()}'),
          );
        }
        isConnected.value = false;
        _currentDeviceId = null;
        _bc2.reset();
      }
    });

    _server.onAdvertisingStateChanged((state, error) async {
      if (state == PeripheralAdvertisingState.error) {
        if (await recoverIfAlreadyAdvertising(error)) return;
        core.connection.signalNotification(
          AlertNotification(LogLevel.LOGLEVEL_WARNING, 'BC2 failed to advertise${error != null ? ': $error' : ''}'),
        );
      }
    });

    while (!(await _server.isReady) && core.settings.getBc2BleEnabled()) {
      await Future.delayed(const Duration(seconds: 1));
    }

    if (!_isServiceAdded) {
      await Future.delayed(const Duration(seconds: 1));

      if (!_isSubscribedToEvents) {
        _isSubscribedToEvents = true;
        _server.onSubscriptionChanged((deviceId, characteristicId, isSubscribed) {
          if (isSubscribed &&
              characteristicId.toLowerCase() == CycplusBc2Emulator.TX_CHARACTERISTIC_UUID.toLowerCase()) {
            unawaited(onSubscribed(deviceId));
          }
        });
        _server.setReadHandler(BleUuid.DEVICE_INFORMATION_CHARACTERISTIC_BATTERY_LEVEL, (
          deviceId,
          characteristicId,
          offset,
          value,
        ) {
          return PeripheralReadRequestResult(value: Uint8List.fromList([100]));
        });
      }

      if (!Platform.isWindows) {
        await _server.addService(
          BlePeripheralService(
            uuid: '180A',
            characteristics: [
              _immutableChar('2A29', 'BikeControl'),
              _immutableChar('2A26', packageInfoValue?.version ?? '1.0.0'),
            ],
          ),
        );
      }
      await _server.addService(
        BlePeripheralService(
          uuid: '180F',
          characteristics: [
            BlePeripheralCharacteristic(
              uuid: '2A19',
              properties: [CharacteristicProperty.read, CharacteristicProperty.notify],
              permissions: [PeripheralAttributePermission.readable],
            ),
          ],
        ),
      );

      // Protected: the Bluetooth trainer bridge shares this peripheral and
      // would otherwise wipe it when it starts or stops.
      SharedPeripheral.protectServices([CycplusBc2Emulator.SERVICE_UUID]);
      await _server.addService(
        BlePeripheralService(
          uuid: CycplusBc2Emulator.SERVICE_UUID,
          characteristics: [
            BlePeripheralCharacteristic(
              uuid: CycplusBc2Emulator.TX_CHARACTERISTIC_UUID,
              properties: [CharacteristicProperty.notify],
              permissions: [],
            ),
            BlePeripheralCharacteristic(
              uuid: CycplusBc2Emulator.RX_CHARACTERISTIC_UUID,
              properties: [CharacteristicProperty.writeWithoutResponse, CharacteristicProperty.write],
              permissions: [PeripheralAttributePermission.writeable],
            ),
          ],
        ),
      );
      _isServiceAdded = true;
    }

    await restartAdvertising();
  }

  @override
  Future<void> startServiceAdvertising() => _server.startAdvertising(
    services: [CycplusBc2Emulator.SERVICE_UUID],
    localName: 'BikeControl',
    // The 128-bit service UUID plus the name overflows the 31-byte primary
    // advertisement on Android.
    servicesInScanResponse: true,
  );

  Future<void> stopServer() async {
    SharedPeripheral.unprotectServices([CycplusBc2Emulator.SERVICE_UUID]);
    for (final service in [if (!Platform.isWindows) '180A', '180F', CycplusBc2Emulator.SERVICE_UUID]) {
      await _server.removeService(service);
    }
    _isServiceAdded = false;
    await _server.stopAdvertising();
    isStarted.value = false;
    isConnected.value = false;
    _currentDeviceId = null;
  }

  /// The trainer app subscribed to the lever notifications: it's connected.
  @visibleForTesting
  Future<void> onSubscribed(String deviceId) async {
    _currentDeviceId = deviceId;
    isConnected.value = true;
    core.connection.signalNotification(AlertNotification(LogLevel.LOGLEVEL_INFO, 'Connected to app: ${_appName()}'));
    await _notify(_bc2.connectFrame());
  }

  String _appName() => core.settings.getTrainerApp()?.name ?? 'app';

  Future<void> _notify(Uint8List frame) => _server.notify(
    characteristicId: CycplusBc2Emulator.TX_CHARACTERISTIC_UUID,
    value: frame,
    deviceId: _currentDeviceId,
  );

  BlePeripheralCharacteristic _immutableChar(String uuid, String value) => BlePeripheralCharacteristic(
    uuid: uuid,
    properties: [CharacteristicProperty.read],
    permissions: [PeripheralAttributePermission.readable],
    value: Uint8List.fromList(value.codeUnits),
  );

  /// Shifting is a short lever press, steering (the path at a junction) a
  /// long one.
  @override
  Future<ActionResult> sendAction(KeyPair keyPair, {required bool isKeyDown, required bool isKeyUp}) async {
    final button = keyPair.buttons.firstOrNull;
    final action = keyPair.inGameAction;
    if (_currentDeviceId == null) {
      return Error('No central connected', button: button);
    }
    final (lever, long) = switch (action) {
      InGameAction.shiftUp => (Bc2Lever.plus, false),
      InGameAction.shiftDown => (Bc2Lever.minus, false),
      InGameAction.steerRight => (Bc2Lever.plus, true),
      InGameAction.steerLeft => (Bc2Lever.minus, true),
      _ => (null, false),
    };
    if (action == null || lever == null) {
      return NotHandled('App does not support action: ${action?.title ?? keyPair.label}', button: button);
    }
    if (isKeyDown) await _notify(_bc2.press(lever, long: long));
    if (isKeyDown && isKeyUp) await Future.delayed(const Duration(milliseconds: 50));
    // A release without a press would read as one, and shift.
    if (isKeyUp && _bc2.isPressed(lever)) await _notify(_bc2.release(lever));
    return Success('Buttons ${action.title} sent', button: button);
  }

  @override
  Widget getTile({bool small = false}) => CycplusBc2BluetoothTile(small: small);
}
