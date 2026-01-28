import 'dart:io';

import 'package:bike_control/bluetooth/ble.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/openbikecontrol_device.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/protocol_parser.dart';
import 'package:bike_control/bluetooth/devices/trainer_connection.dart';
import 'package:bike_control/bluetooth/messages/notification.dart' show AlertNotification, LogNotification;
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/widgets/title.dart';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/prop.dart';

class OpenBikeControlBluetoothEmulator extends TrainerConnection {
  late final _peripheralManager = PeripheralManager();
  final ValueNotifier<AppInfo?> connectedApp = ValueNotifier<AppInfo?>(null);
  bool _isServiceAdded = false;
  bool _isSubscribedToEvents = false;
  Central? _central;

  late GATTCharacteristic _buttonCharacteristic;

  static const String connectionTitle = 'OpenBikeControl BLE Emulator';

  OpenBikeControlBluetoothEmulator()
    : super(
        title: connectionTitle,
        supportedActions: InGameAction.values,
      );

  Future<void> startServer() async {
    isStarted.value = true;

    _peripheralManager.stateChanged.forEach((state) {
      print('Peripheral manager state: ${state.state}');
    });

    if (!kIsWeb && Platform.isAndroid) {
      _peripheralManager.connectionStateChanged.forEach((state) {
        print('Peripheral connection state: ${state.state} of ${state.central.uuid}');
        if (state.state == ConnectionState.connected) {
        } else if (state.state == ConnectionState.disconnected) {
          if (connectedApp.value != null) {
            core.connection.signalNotification(
              AlertNotification(LogLevel.LOGLEVEL_INFO, 'Disconnected from app: ${connectedApp.value?.appId}'),
            );
          }
          isConnected.value = false;
          connectedApp.value = null;
          _central = null;
        }
      });
    }

    while (_peripheralManager.state != BluetoothLowEnergyState.poweredOn && core.settings.getObpBleEnabled()) {
      print('Waiting for peripheral manager to be powered on...');
      await Future.delayed(Duration(seconds: 1));
    }

    _buttonCharacteristic = GATTCharacteristic.mutable(
      uuid: UUID.fromString(OpenBikeControlConstants.BUTTON_STATE_CHARACTERISTIC_UUID),
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
            case BleUuid.DEVICE_INFORMATION_CHARACTERISTIC_BATTERY_LEVEL:
              await _peripheralManager.respondReadRequestWithValue(
                eventArgs.request,
                value: Uint8List.fromList([100]),
              );
              return;
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
          _central = char.central;
          print(
            'Notify state changed for characteristic: ${char.characteristic.uuid}: ${char.state}',
          );
        });
        _peripheralManager.characteristicWriteRequested.forEach((eventArgs) async {
          final characteristic = eventArgs.characteristic;
          final request = eventArgs.request;
          final value = request.value;
          print(
            'Write request for characteristic: ${characteristic.uuid}',
          );

          switch (eventArgs.characteristic.uuid.toString().toLowerCase()) {
            case OpenBikeControlConstants.APPINFO_CHARACTERISTIC_UUID:
              try {
                final appInfo = OpenBikeProtocolParser.parseAppInfo(value);
                isConnected.value = true;
                connectedApp.value = appInfo;
                supportedActions = appInfo.supportedButtons.mapNotNull((b) => b.action).toList();
                core.connection.signalNotification(
                  AlertNotification(LogLevel.LOGLEVEL_INFO, 'Connected to app: ${appInfo.appId}'),
                );
                core.connection.signalNotification(LogNotification('Parsed App Info: $appInfo'));
              } catch (e) {
                core.connection.signalNotification(LogNotification('Error parsing App Info ${bytesToHex(value)}: $e'));
              }
              break;
            default:
              print('Unhandled write request for characteristic: ${eventArgs.characteristic.uuid}');
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
                value: Uint8List.fromList('1337'.codeUnits),
                descriptors: [],
              ),
              GATTCharacteristic.immutable(
                uuid: UUID.fromString('2A27'),
                value: Uint8List.fromList('1.0'.codeUnits),
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
          uuid: UUID.fromString(OpenBikeControlConstants.SERVICE_UUID),
          isPrimary: true,
          characteristics: [
            _buttonCharacteristic,
            GATTCharacteristic.mutable(
              uuid: UUID.fromString(OpenBikeControlConstants.APPINFO_CHARACTERISTIC_UUID),
              descriptors: [],
              properties: [
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
      name: 'BikeControl',
      serviceUUIDs: [UUID.fromString(OpenBikeControlConstants.SERVICE_UUID)],
    );
    print('Starting advertising with OpenBikeControl service...');

    await _peripheralManager.startAdvertising(advertisement);
  }

  Future<void> stopServer() async {
    if (kDebugMode) {
      print('Stopping OpenBikeControl BLE server...');
    }
    await _peripheralManager.stopAdvertising();
    isStarted.value = false;
    isConnected.value = false;
    connectedApp.value = null;
  }

  @override
  Future<ActionResult> sendAction(KeyPair keyPair, {required bool isKeyDown, required bool isKeyUp}) async {
    final inGameAction = keyPair.inGameAction;

    final mappedButtons = connectedApp.value!.supportedButtons.filter(
      (supportedButton) => supportedButton.action == inGameAction,
    );

    if (inGameAction == null) {
      return Error('Invalid in-game action for key pair: $keyPair');
    } else if (_central == null) {
      return Error('No central connected');
    } else if (connectedApp.value == null) {
      return Error('No app info received from central');
    } else if (mappedButtons.isEmpty) {
      return NotHandled('App does not support all buttons for action: ${inGameAction.title}');
    }

    if (isKeyDown && isKeyUp) {
      final responseDataDown = OpenBikeProtocolParser.encodeButtonState(
        mappedButtons.map((b) => ButtonState(b, 1)).toList(),
      );
      await _peripheralManager.notifyCharacteristic(_central!, _buttonCharacteristic, value: responseDataDown);
      final responseDataUp = OpenBikeProtocolParser.encodeButtonState(
        mappedButtons.map((b) => ButtonState(b, 0)).toList(),
      );
      await _peripheralManager.notifyCharacteristic(_central!, _buttonCharacteristic, value: responseDataUp);
    } else {
      final responseData = OpenBikeProtocolParser.encodeButtonState(
        mappedButtons.map((b) => ButtonState(b, isKeyDown ? 1 : 0)).toList(),
      );
      await _peripheralManager.notifyCharacteristic(_central!, _buttonCharacteristic, value: responseData);
    }

    return Success('Buttons ${inGameAction.title} sent');
  }
}
