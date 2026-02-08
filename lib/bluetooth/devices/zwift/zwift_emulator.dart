import 'dart:io';

import 'package:bike_control/bluetooth/ble.dart';
import 'package:bike_control/bluetooth/devices/trainer_connection.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:bike_control/widgets/title.dart';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:prop/prop.dart' hide RideButtonMask;

class ZwiftEmulator extends TrainerConnection {
  bool get isLoading => _isLoading;

  static const String connectionTitle = 'Zwift BLE Emulator';

  late final _peripheralManager = PeripheralManager();
  bool _isLoading = false;
  bool _isServiceAdded = false;
  bool _isSubscribedToEvents = false;
  Central? _central;
  GATTCharacteristic? _asyncCharacteristic;
  GATTCharacteristic? _syncTxCharacteristic;

  ZwiftEmulator()
    : super(
        title: connectionTitle,
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
    await _peripheralManager.stopAdvertising();
    await _peripheralManager.removeAllServices();
    _isServiceAdded = false;
    startAdvertising(() {});
  }

  Future<void> startAdvertising(VoidCallback onUpdate) async {
    _isLoading = true;
    isStarted.value = true;
    onUpdate();

    _peripheralManager.stateChanged.forEach((state) {
      print('Peripheral manager state: ${state.state}');
    });

    if (!kIsWeb && Platform.isAndroid) {
      _peripheralManager.connectionStateChanged.forEach((state) {
        print('Peripheral connection state: ${state.state} of ${state.central.uuid}');
        if (state.state == ConnectionState.connected) {
        } else if (state.state == ConnectionState.disconnected) {
          _central = null;
          isConnected.value = false;
          core.connection.signalNotification(
            AlertNotification(LogLevel.LOGLEVEL_INFO, AppLocalizations.current.disconnected),
          );
          onUpdate();
        }
      });

      final status = await Permission.bluetoothAdvertise.request();
      if (!status.isGranted) {
        print('Bluetooth advertise permission not granted');
        isStarted.value = false;
        onUpdate();
        return;
      }
    }

    while (_peripheralManager.state != BluetoothLowEnergyState.poweredOn &&
        core.settings.getZwiftBleEmulatorEnabled()) {
      print('Waiting for peripheral manager to be powered on...');
      if (core.settings.getLastTarget() == Target.thisDevice) {
        return;
      }
      await Future.delayed(Duration(seconds: 1));
    }

    _syncTxCharacteristic = GATTCharacteristic.mutable(
      uuid: UUID.fromString(ZwiftConstants.ZWIFT_SYNC_TX_CHARACTERISTIC_UUID),
      descriptors: [],
      properties: [
        GATTCharacteristicProperty.read,
        GATTCharacteristicProperty.indicate,
      ],
      permissions: [
        GATTCharacteristicPermission.read,
      ],
    );

    _asyncCharacteristic = GATTCharacteristic.mutable(
      uuid: UUID.fromString(ZwiftConstants.ZWIFT_ASYNC_CHARACTERISTIC_UUID),
      descriptors: [],
      properties: [
        GATTCharacteristicProperty.notify,
      ],
      permissions: [],
    );

    if (!_isServiceAdded) {
      await Future.delayed(Duration(seconds: 1));

      if (!_isSubscribedToEvents) {
        _isSubscribedToEvents = true;
        _peripheralManager.characteristicReadRequested.forEach((eventArgs) async {
          print('Read request for characteristic: ${eventArgs.characteristic.uuid}');

          switch (eventArgs.characteristic.uuid.toString().toUpperCase()) {
            case ZwiftConstants.ZWIFT_SYNC_TX_CHARACTERISTIC_UUID:
              print('Handling read request for SYNC TX characteristic');
              break;
            case BleUuid.DEVICE_INFORMATION_CHARACTERISTIC_BATTERY_LEVEL:
              await _peripheralManager.respondReadRequestWithValue(
                eventArgs.request,
                value: Uint8List.fromList([100]),
              );
              break;
            default:
              print('Unhandled read request for characteristic: ${eventArgs.characteristic.uuid}');
          }

          final request = eventArgs.request;
          final trimmedValue = Uint8List.fromList([]);
          await _peripheralManager.respondReadRequestWithValue(
            request,
            value: trimmedValue,
          );
          // You can respond to read requests here if needed
        });

        _peripheralManager.characteristicNotifyStateChanged.forEach((char) {
          print(
            'Notify state changed for characteristic: ${char.characteristic.uuid}: ${char.state}',
          );
        });
        _peripheralManager.characteristicWriteRequested.forEach((eventArgs) async {
          _central = eventArgs.central;
          isConnected.value = true;

          core.connection.signalNotification(
            AlertNotification(LogLevel.LOGLEVEL_INFO, AppLocalizations.current.connected),
          );

          final request = eventArgs.request;
          final response = SharedLogic.handleWriteRequest(eventArgs.characteristic.uuid.toString(), request.value);
          if (response != null) {
            await _peripheralManager.notifyCharacteristic(
              _central!,
              _syncTxCharacteristic!,
              value: response,
            );
            onUpdate();
            if (response == ZwiftConstants.RIDE_ON) {
              _sendKeepAlive();
            }
          }

          await _peripheralManager.respondWriteRequest(request);
        });
      }

      if (!Platform.isWindows) {
        // Device Information
        await _peripheralManager.addService(
          GATTService(
            uuid: UUID.fromString('180A'),
            isPrimary: true,
            characteristics: [
              GATTCharacteristic.immutable(
                uuid: UUID.fromString('2A29'),
                value: Uint8List.fromList('BikeControl'.codeUnits),
                descriptors: [],
              ),
              GATTCharacteristic.immutable(
                uuid: UUID.fromString('2A25'),
                value: Uint8List.fromList('09-B48123283828F1337'.codeUnits),
                descriptors: [],
              ),
              GATTCharacteristic.immutable(
                uuid: UUID.fromString('2A27'),
                value: Uint8List.fromList('A.0'.codeUnits),
                descriptors: [],
              ),
              GATTCharacteristic.immutable(
                uuid: UUID.fromString('2A26'),
                value: Uint8List.fromList((packageInfoValue?.version ?? '1.0.0').codeUnits),
                descriptors: [],
              ),
            ],
            includedServices: [],
          ),
        );
      }
      // Battery Service
      await _peripheralManager.addService(
        GATTService(
          uuid: UUID.fromString('180F'),
          isPrimary: true,
          characteristics: [
            GATTCharacteristic.mutable(
              uuid: UUID.fromString('2A19'),
              descriptors: [],
              properties: [
                GATTCharacteristicProperty.read,
                GATTCharacteristicProperty.notify,
              ],
              permissions: [
                GATTCharacteristicPermission.read,
              ],
            ),
          ],
          includedServices: [],
        ),
      );

      // Unknown Service
      await _peripheralManager.addService(
        GATTService(
          uuid: UUID.fromString(ZwiftConstants.ZWIFT_CUSTOM_SERVICE_UUID),
          isPrimary: true,
          characteristics: [
            _asyncCharacteristic!,
            GATTCharacteristic.mutable(
              uuid: UUID.fromString(ZwiftConstants.ZWIFT_SYNC_RX_CHARACTERISTIC_UUID),
              descriptors: [],
              properties: [
                GATTCharacteristicProperty.writeWithoutResponse,
              ],
              permissions: [],
            ),
            _syncTxCharacteristic!,
            GATTCharacteristic.mutable(
              uuid: UUID.fromString('00000005-19CA-4651-86E5-FA29DCDD09D1'),
              descriptors: [],
              properties: [
                GATTCharacteristicProperty.notify,
              ],
              permissions: [],
            ),
            GATTCharacteristic.mutable(
              uuid: UUID.fromString('00000006-19CA-4651-86E5-FA29DCDD09D1'),
              descriptors: [],
              properties: [
                GATTCharacteristicProperty.indicate,
                GATTCharacteristicProperty.read,
                GATTCharacteristicProperty.writeWithoutResponse,
                GATTCharacteristicProperty.write,
              ],
              permissions: [
                GATTCharacteristicPermission.read,
                GATTCharacteristicPermission.write,
              ],
            ),
          ],
          includedServices: [],
        ),
      );
      _isServiceAdded = true;
    }

    final advertisement = Advertisement(
      name: 'KICKR BIKE PRO 1337',
      serviceUUIDs: [UUID.fromString(ZwiftConstants.ZWIFT_RIDE_CUSTOM_SERVICE_UUID_SHORT)],
      /*serviceData: {
        UUID.fromString(ZwiftConstants.ZWIFT_RIDE_CUSTOM_SERVICE_UUID_SHORT): Uint8List.fromList([0x02]),
      },
      manufacturerSpecificData: [
        ManufacturerSpecificData(
          id: 0x094A,
          data: Uint8List.fromList([ZwiftConstants.CLICK_V2_LEFT_SIDE, 0x13, 0x37]),
        ),
      ],*/
    );
    print('Starting advertising with Zwift service...');

    await _peripheralManager.startAdvertising(advertisement);
    _isLoading = false;
    onUpdate();
  }

  Future<void> stopAdvertising() async {
    await _peripheralManager.removeAllServices();
    _isServiceAdded = false;
    await _peripheralManager.stopAdvertising();
    isStarted.value = false;
    isConnected.value = false;
    _isLoading = false;
  }

  Future<void> _sendKeepAlive() async {
    await Future.delayed(const Duration(seconds: 5));
    if (isConnected.value && _central != null) {
      final zero = Uint8List.fromList([Opcode.CONTROLLER_NOTIFICATION.value, 0x08, 0xFF, 0xFF, 0xFF, 0xFF, 0x0F]);
      _peripheralManager.notifyCharacteristic(_central!, _syncTxCharacteristic!, value: zero);
      _sendKeepAlive();
    }
  }

  @override
  Future<ActionResult> sendAction(KeyPair keyPair, {required bool isKeyDown, required bool isKeyUp}) async {
    final button = switch (keyPair.inGameAction) {
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
      return NotHandled('Action ${keyPair.inGameAction!.name} not supported by Zwift Emulator');
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

      _peripheralManager.notifyCharacteristic(
        _central!,
        _asyncCharacteristic!,
        value: commandProto,
      );
    }

    if (isKeyUp) {
      final zero = Uint8List.fromList([Opcode.CONTROLLER_NOTIFICATION.value, 0x08, 0xFF, 0xFF, 0xFF, 0xFF, 0x0F]);
      _peripheralManager.notifyCharacteristic(_central!, _asyncCharacteristic!, value: zero);
    }

    return Success('Sent action: ${keyPair.inGameAction!.name}');
  }

  void cleanup() {
    _peripheralManager.stopAdvertising();
    _peripheralManager.removeAllServices();
    _isServiceAdded = false;
    _isSubscribedToEvents = false;
    _central = null;
    isConnected.value = false;
    isStarted.value = false;
    _isLoading = false;
  }
}
