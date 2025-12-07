import 'dart:io';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:swift_control/bluetooth/devices/openbikecontrol/openbikecontrol_device.dart';
import 'package:swift_control/bluetooth/devices/openbikecontrol/protocol_parser.dart';
import 'package:swift_control/bluetooth/devices/zwift/protocol/zp.pbenum.dart';
import 'package:swift_control/utils/actions/base_actions.dart';
import 'package:swift_control/utils/core.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:swift_control/widgets/title.dart';

import '../../messages/notification.dart' show AlertNotification;

class OpenBikeControlBluetoothEmulator {
  late final _peripheralManager = PeripheralManager();
  final ValueNotifier<bool> isStarted = ValueNotifier<bool>(false);
  final ValueNotifier<AppInfo?> isConnected = ValueNotifier<AppInfo?>(null);
  bool _isServiceAdded = false;
  bool _isSubscribedToEvents = false;
  Central? _central;

  late GATTCharacteristic _buttonCharacteristic;

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
          core.connection.signalNotification(
            AlertNotification(LogLevel.LOGLEVEL_INFO, 'Disconnected from app: ${isConnected.value?.appId}'),
          );
          isConnected.value = null;
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
                isConnected.value = appInfo;
                core.connection.signalNotification(
                  AlertNotification(LogLevel.LOGLEVEL_INFO, 'Connected to app: ${appInfo.appId}'),
                );
                print('Parsed App Info: $appInfo');
              } catch (e) {
                print('Error parsing App Info: $e');
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
    isConnected.value = null;
  }

  Future<ActionResult> sendButtonPress(
    List<ControllerButton> buttons, {
    required bool isKeyDown,
    required bool isKeyUp,
  }) async {
    if (_central == null) {
      return Error('No central connected');
    } else if (isConnected.value == null) {
      return Error('No app info received from central');
    } else if (!isConnected.value!.supportedButtons.containsAll(buttons)) {
      return NotHandled('App does not support all buttons: ${buttons.map((b) => b.name).join(', ')}');
    }

    final responseData = OpenBikeProtocolParser.encodeButtonState(
      buttons
          .map(
            (b) => ButtonState(
              b,
              isKeyDown ? 1 : 0,
            ),
          )
          .toList(),
    );
    await _peripheralManager.notifyCharacteristic(_central!, _buttonCharacteristic, value: responseData);

    return Success('Buttons ${buttons.map((b) => b.name).join(', ')} sent');
  }
}
