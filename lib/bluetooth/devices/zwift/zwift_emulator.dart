import 'dart:io';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:permission_handler/permission_handler.dart';
import 'package:swift_control/bluetooth/ble.dart';
import 'package:swift_control/bluetooth/devices/zwift/constants.dart';
import 'package:swift_control/bluetooth/devices/zwift/protocol/zp.pbenum.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:swift_control/utils/requirements/multi.dart';
import 'package:swift_control/widgets/title.dart';

import 'protocol/zwift.pb.dart' show RideKeyPadStatus;

final zwiftEmulator = ZwiftEmulator();

class ZwiftEmulator {
  static final List<InGameAction> supportedActions = [
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
  ];

  ValueNotifier<bool> isConnected = ValueNotifier<bool>(false);
  bool get isAdvertising => _isAdvertising;
  bool get isLoading => _isLoading;

  late final _peripheralManager = PeripheralManager();
  bool _isAdvertising = false;
  bool _isLoading = false;
  bool _isServiceAdded = false;
  bool _isSubscribedToEvents = false;
  Central? _central;
  GATTCharacteristic? _asyncCharacteristic;

  Future<void> reconnect() async {
    await _peripheralManager.stopAdvertising();
    await _peripheralManager.removeAllServices();
    _isServiceAdded = false;
    _isAdvertising = false;
    startAdvertising(() {});
  }

  Future<void> startAdvertising(VoidCallback onUpdate) async {
    _isLoading = true;
    onUpdate();

    _peripheralManager.stateChanged.forEach((state) {
      print('Peripheral manager state: ${state.state}');
    });

    if (!kIsWeb && Platform.isAndroid) {
      if (Platform.isAndroid) {
        _peripheralManager.connectionStateChanged.forEach((state) {
          print('Peripheral connection state: ${state.state} of ${state.central.uuid}');
          if (state.state == ConnectionState.connected) {
          } else if (state.state == ConnectionState.disconnected) {
            _central = null;
            isConnected.value = false;
            onUpdate();
          }
        });
      }

      final status = await Permission.bluetoothAdvertise.request();
      if (!status.isGranted) {
        print('Bluetooth advertise permission not granted');
        _isAdvertising = false;
        onUpdate();
        return;
      }
    }

    while (_peripheralManager.state != BluetoothLowEnergyState.poweredOn) {
      print('Waiting for peripheral manager to be powered on...');
      if (settings.getLastTarget() == Target.thisDevice) {
        return;
      }
      await Future.delayed(Duration(seconds: 1));
    }

    final syncTxCharacteristic = GATTCharacteristic.mutable(
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

          final characteristic = eventArgs.characteristic;
          final request = eventArgs.request;
          final value = request.value;
          print(
            'Write request for characteristic: ${characteristic.uuid}',
          );

          switch (eventArgs.characteristic.uuid.toString().toUpperCase()) {
            case ZwiftConstants.ZWIFT_SYNC_RX_CHARACTERISTIC_UUID:
              print(
                'Handling write request for SYNC RX characteristic, value: ${value.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}\n${String.fromCharCodes(value)}',
              );

              final handshake = [...ZwiftConstants.RIDE_ON, ...ZwiftConstants.RESPONSE_START_CLICK_V2];
              final handshakeAlternative = ZwiftConstants.RIDE_ON; // e.g. Rouvy

              if (value.contentEquals(handshake) || value.contentEquals(handshakeAlternative)) {
                print('Sending handshake');
                await _peripheralManager.notifyCharacteristic(
                  _central!,
                  syncTxCharacteristic,
                  value: ZwiftConstants.RIDE_ON,
                );
                onUpdate();
              }
              break;
            default:
              print('Unhandled write request for characteristic: ${eventArgs.characteristic.uuid}');
          }

          await _peripheralManager.respondWriteRequest(request);
        });
      }

      // Device Information
      await _peripheralManager.addService(
        GATTService(
          uuid: UUID.fromString('180A'),
          isPrimary: true,
          characteristics: [
            GATTCharacteristic.immutable(
              uuid: UUID.fromString('2A29'),
              value: Uint8List.fromList('SwiftControl'.codeUnits),
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
          uuid: UUID.fromString(ZwiftConstants.ZWIFT_RIDE_CUSTOM_SERVICE_UUID_SHORT),
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
            syncTxCharacteristic,
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
      name: 'SwiftControl',
      serviceUUIDs: [UUID.fromString(ZwiftConstants.ZWIFT_RIDE_CUSTOM_SERVICE_UUID_SHORT)],
      serviceData: {
        UUID.fromString(ZwiftConstants.ZWIFT_RIDE_CUSTOM_SERVICE_UUID_SHORT): Uint8List.fromList([0x02]),
      },
      manufacturerSpecificData: [
        ManufacturerSpecificData(
          id: 0x094A,
          data: Uint8List.fromList([ZwiftConstants.CLICK_V2_LEFT_SIDE, 0x13, 0x37]),
        ),
      ],
    );
    print('Starting advertising with Zwift service...');

    await _peripheralManager.startAdvertising(advertisement);
    _isAdvertising = true;
    _isLoading = false;
    onUpdate();
  }

  Future<void> stopAdvertising() async {
    await _peripheralManager.stopAdvertising();
    _isAdvertising = false;
    _isLoading = false;
  }

  Future<String> sendAction(InGameAction inGameAction, int? inGameActionValue) async {
    final button = switch (inGameAction) {
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
      return 'Action ${inGameAction.name} not supported by Zwift Emulator';
    }

    final status = RideKeyPadStatus()
      ..buttonMap = (~button.mask) & 0xFFFFFFFF
      ..analogPaddles.clear();

    final bytes = status.writeToBuffer();

    final commandProto = Uint8List.fromList([
      Opcode.CONTROLLER_NOTIFICATION.value,
      ...bytes,
    ]);

    _peripheralManager.notifyCharacteristic(_central!, _asyncCharacteristic!, value: commandProto);

    final zero = Uint8List.fromList([0x23, 0x08, 0xFF, 0xFF, 0xFF, 0xFF, 0x0F]);
    _peripheralManager.notifyCharacteristic(_central!, _asyncCharacteristic!, value: zero);
    return 'Sent action: ${inGameAction.name}';
  }
}

class ZwiftEmulatorInformation extends StatelessWidget {
  const ZwiftEmulatorInformation({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: zwiftEmulator.isConnected,
      builder: (context, isConnected, _) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Text('Zwift is ${isConnected ? 'connected' : 'not connected'}');
          },
        );
      },
    );
  }
}
