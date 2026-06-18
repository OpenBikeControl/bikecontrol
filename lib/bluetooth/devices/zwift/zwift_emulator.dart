import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:bike_control/bluetooth/ble.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/openbikecontrol_device.dart';
import 'package:bike_control/bluetooth/devices/trainer_connection.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/bluetooth/peripheral_server.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:bike_control/widgets/apps/zwift_tile.dart';
import 'package:bike_control/widgets/title.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:prop/prop.dart' hide RideButtonMask;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

class ZwiftEmulator extends TrainerConnection {
  bool get isLoading => _isLoading;

  final _server = PeripheralServer();
  bool _isLoading = false;
  bool _isServiceAdded = false;
  bool _isSubscribedToEvents = false;
  String? _currentDeviceId;

  ZwiftEmulator()
    : super(
        title: () => AppLocalizations.current.connectUsingBluetooth,
        type: ConnectionMethodType.bluetooth,
        supportedActions: [
          InGameAction.shiftUp,
          InGameAction.shiftDown,
          InGameAction.uturn,
          InGameAction.steerLeft,
          InGameAction.steerRight,
          InGameAction.openActionBar,
          InGameAction.usePowerUp,
          InGameAction.select,
          InGameAction.back,
          InGameAction.rideOnBomb,
        ],
      );

  Future<void> reconnect() async {
    await _server.stopAdvertising();
    await _server.clearServices();
    _isServiceAdded = false;
    startAdvertising(() {});
  }

  Future<void> startAdvertising(VoidCallback onUpdate) async {
    _isLoading = true;
    isStarted.value = true;
    onUpdate();

    final isRouvy = core.settings.getTrainerApp() is Rouvy;

    _server.onConnectionChanged((deviceId, connected) {
      print('Peripheral connection state: ${connected ? "connected" : "disconnected"} of $deviceId');
      if (!connected) {
        _currentDeviceId = null;
        isConnected.value = false;
        core.connection.signalNotification(
          AlertNotification.connection(
            connected: false,
            type: type,
            appName: core.settings.getTrainerApp()?.name,
          ),
        );
        onUpdate();
      }
    });

    _server.onAdvertisingStateChanged((state, error) {
      if (kDebugMode) {
        print('Zwift advertising state: ${state.name}${error != null ? ' — $error' : ''}');
      }
      if (state == PeripheralAdvertisingState.error) {
        core.connection.signalNotification(
          AlertNotification(
            LogLevel.LOGLEVEL_WARNING,
            'Zwift emulator failed to advertise${error != null ? ': $error' : ''}',
          ),
        );
      }
    });

    if (!kIsWeb && Platform.isAndroid) {
      final status = await Permission.bluetoothAdvertise.request();
      if (!status.isGranted) {
        print('Bluetooth advertise permission not granted');
        isStarted.value = false;
        onUpdate();
        return;
      }
    }

    while (!(await _server.isReady) && core.settings.getZwiftBleEmulatorEnabled()) {
      print('Waiting for peripheral manager to be ready...');
      if (core.settings.getLastTarget() == Target.thisDevice) {
        return;
      }
      await Future.delayed(Duration(seconds: 1));
    }

    if (!_isServiceAdded) {
      await Future.delayed(Duration(seconds: 1));

      if (!_isSubscribedToEvents) {
        _isSubscribedToEvents = true;

        _server.onSubscriptionChanged((deviceId, characteristicId, isSubscribed) {
          print('Notify state changed for $characteristicId: $isSubscribed');
        });

        _server.setReadHandler(BleUuid.DEVICE_INFORMATION_CHARACTERISTIC_BATTERY_LEVEL, (
          deviceId,
          characteristicId,
          offset,
          value,
        ) {
          return PeripheralReadRequestResult(value: Uint8List.fromList([100]));
        });

        _server.setWriteHandler(ZwiftConstants.ZWIFT_SYNC_RX_CHARACTERISTIC_UUID, (
          deviceId,
          characteristicId,
          offset,
          value,
        ) {
          _currentDeviceId = deviceId;
          isConnected.value = true;

          core.connection.signalNotification(
            AlertNotification.connection(
              connected: true,
              type: type,
              appName: core.settings.getTrainerApp()?.name,
            ),
          );

          if (value == null) return PeripheralWriteRequestResult();
          final response = SharedLogic.handleWriteRequest(characteristicId, value);
          if (response != null) {
            unawaited(
              _server.notify(
                characteristicId: ZwiftConstants.ZWIFT_SYNC_TX_CHARACTERISTIC_UUID,
                value: response,
                deviceId: _currentDeviceId,
              ),
            );
            onUpdate();
            if (response == ZwiftConstants.RIDE_ON) {
              _sendKeepAlive();
            }
          }

          return PeripheralWriteRequestResult();
        });
      }

      if (!Platform.isWindows) {
        // Device Information
        await _server.addService(
          BlePeripheralService(
            uuid: '180A',
            characteristics: [
              _immutableChar('2A29', 'BikeControl'),
              _immutableChar('2A25', '09-B48123283828F1337'),
              _immutableChar('2A27', 'A.0'),
              _immutableChar('2A26', packageInfoValue?.version ?? '1.0.0'),
            ],
          ),
        );
      }
      // Battery Service
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

      // Zwift Custom Service
      await _server.addService(
        BlePeripheralService(
          uuid: ZwiftConstants.ZWIFT_CUSTOM_SERVICE_UUID,
          characteristics: [
            BlePeripheralCharacteristic(
              uuid: ZwiftConstants.ZWIFT_ASYNC_CHARACTERISTIC_UUID,
              properties: [CharacteristicProperty.notify],
              permissions: [],
            ),
            BlePeripheralCharacteristic(
              uuid: ZwiftConstants.ZWIFT_SYNC_RX_CHARACTERISTIC_UUID,
              properties: [CharacteristicProperty.writeWithoutResponse],
              permissions: [],
            ),
            BlePeripheralCharacteristic(
              uuid: ZwiftConstants.ZWIFT_SYNC_TX_CHARACTERISTIC_UUID,
              properties: [CharacteristicProperty.read, CharacteristicProperty.indicate],
              permissions: [PeripheralAttributePermission.readable],
            ),
            BlePeripheralCharacteristic(
              uuid: '00000005-19CA-4651-86E5-FA29DCDD09D1',
              properties: [CharacteristicProperty.notify],
              permissions: [],
            ),
            BlePeripheralCharacteristic(
              uuid: '00000006-19CA-4651-86E5-FA29DCDD09D1',
              properties: [
                CharacteristicProperty.indicate,
                CharacteristicProperty.read,
                CharacteristicProperty.writeWithoutResponse,
                CharacteristicProperty.write,
              ],
              permissions: [PeripheralAttributePermission.readable, PeripheralAttributePermission.writeable],
            ),
          ],
        ),
      );

      if (isRouvy) {
        await _server.addService(
          BlePeripheralService(
            uuid: OpenBikeControlConstants.SERVICE_UUID,
            characteristics: [],
          ),
        );
      }
      _isServiceAdded = true;
    }

    print('Starting advertising with Zwift service...');

    await _server.startAdvertising(
      services: [
        ZwiftConstants.ZWIFT_RIDE_CUSTOM_SERVICE_UUID_SHORT,
        if (isRouvy) OpenBikeControlConstants.SERVICE_UUID,
      ],
      localName: isRouvy ? 'BikeControl' : 'KICKR BIKE PRO 1337',
    );
    _isLoading = false;
    onUpdate();
  }

  Future<void> stopAdvertising() async {
    await _server.clearServices();
    _isServiceAdded = false;
    await _server.stopAdvertising();
    isStarted.value = false;
    isConnected.value = false;
    _isLoading = false;
  }

  Future<void> _sendKeepAlive() async {
    await Future.delayed(const Duration(seconds: 5));
    if (isConnected.value && _currentDeviceId != null) {
      final zero = Uint8List.fromList([Opcode.CONTROLLER_NOTIFICATION.value, 0x08, 0xFF, 0xFF, 0xFF, 0xFF, 0x0F]);
      unawaited(
        _server.notify(
          characteristicId: ZwiftConstants.ZWIFT_SYNC_TX_CHARACTERISTIC_UUID,
          value: zero,
          deviceId: _currentDeviceId,
        ),
      );
      _sendKeepAlive();
    }
  }

  BlePeripheralCharacteristic _immutableChar(String uuid, String value) => BlePeripheralCharacteristic(
    uuid: uuid,
    properties: [CharacteristicProperty.read],
    permissions: [PeripheralAttributePermission.readable],
    value: Uint8List.fromList(value.codeUnits),
  );

  @override
  Future<ActionResult> sendAction(KeyPair keyPair, {required bool isKeyDown, required bool isKeyUp}) async {
    // Resolve mapped app-specific actions (e.g. Rouvy's kudos) back to Zwift Click V2 actions
    final mapping = core.settings.getTrainerApp()?.inGameActionsMapping;
    var action = mapping?.entries.firstOrNullWhere((e) => e.value == keyPair.inGameAction) ?? keyPair.inGameAction;

    final button = switch (action) {
      InGameAction.shiftUp => RideButtonMask.SHFT_UP_R_BTN,
      InGameAction.shiftDown => RideButtonMask.SHFT_UP_L_BTN,
      InGameAction.uturn => RideButtonMask.DOWN_BTN,
      InGameAction.steerLeft => RideButtonMask.LEFT_BTN,
      InGameAction.steerRight => RideButtonMask.RIGHT_BTN,
      InGameAction.openActionBar => RideButtonMask.UP_BTN,
      InGameAction.usePowerUp => RideButtonMask.Y_BTN,
      InGameAction.select => RideButtonMask.A_BTN,
      InGameAction.back => RideButtonMask.B_BTN,
      InGameAction.rideOnBomb => RideButtonMask.Z_BTN,
      _ => null,
    };

    if (button == null) {
      return NotHandled(
        'Action ${keyPair.inGameAction!.name} not supported by Zwift Emulator',
        button: keyPair.buttons.firstOrNull,
      );
    }

    final status = RideKeyPadStatus()
      ..buttonMap = (~button.mask) & 0xFFFFFFFF
      ..analogPaddles.clear();

    final bytes = status.writeToBuffer();

    if (isKeyDown) {
      final commandProto = Uint8List.fromList([
        Opcode.CONTROLLER_NOTIFICATION.value,
        ...bytes,
      ]);
      await _server.notify(
        characteristicId: ZwiftConstants.ZWIFT_ASYNC_CHARACTERISTIC_UUID,
        value: commandProto,
        deviceId: _currentDeviceId,
      );
    }

    if (isKeyUp) {
      final zero = Uint8List.fromList([Opcode.CONTROLLER_NOTIFICATION.value, 0x08, 0xFF, 0xFF, 0xFF, 0xFF, 0x0F]);
      await _server.notify(
        characteristicId: ZwiftConstants.ZWIFT_ASYNC_CHARACTERISTIC_UUID,
        value: zero,
        deviceId: _currentDeviceId,
      );
    }

    return Success(
      'Sent action: ${keyPair.inGameAction!.name}',
      button: keyPair.buttons.firstOrNull,
    );
  }

  void cleanup() {
    _server.stopAdvertising();
    _server.clearServices();
    _isServiceAdded = false;
    _isSubscribedToEvents = false;
    _currentDeviceId = null;
    isConnected.value = false;
    isStarted.value = false;
    _isLoading = false;
  }

  @override
  Widget getTile({bool small = false}) => ZwiftTile(onUpdate: () {}, small: small);
}
