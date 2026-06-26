import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:bike_control/bluetooth/ble.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/app_info_reassembler.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/openbikecontrol_device.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/protocol_parser.dart';
import 'package:bike_control/bluetooth/devices/trainer_connection.dart';
import 'package:bike_control/bluetooth/messages/notification.dart' show AlertNotification, LogNotification;
import 'package:bike_control/bluetooth/peripheral_advertising_recovery.dart';
import 'package:bike_control/bluetooth/peripheral_server.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart' show TrainerConnectionType;
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/widgets/apps/openbikecontrol_ble_tile.dart';
import 'package:bike_control/widgets/title.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/prop.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide ButtonState;
import 'package:universal_ble/universal_ble.dart';

class OpenBikeControlBluetoothEmulator extends TrainerConnection with PeripheralAdvertisingRecovery {
  final _server = PeripheralServer();
  final ValueNotifier<AppInfo?> connectedApp = ValueNotifier<AppInfo?>(null);
  bool _isServiceAdded = false;
  bool _isSubscribedToEvents = false;
  String? _currentDeviceId;
  final _appInfoReassembler = AppInfoReassembler();

  @override
  PeripheralServer get advertisingServer => _server;

  OpenBikeControlBluetoothEmulator()
    : super(
        title: () => AppLocalizations.current.connectUsingBluetooth,
        type: ConnectionMethodType.openBikeControl,
        supportedActions: InGameAction.values,
      );

  Future<void> startServer() async {
    isStarted.value = true;

    _server.onConnectionChanged((deviceId, connected) {
      print('Peripheral connection state: ${connected ? "connected" : "disconnected"} of $deviceId');
      if (!connected) {
        if (connectedApp.value != null) {
          core.connection.signalNotification(
            AlertNotification(LogLevel.LOGLEVEL_INFO, 'Disconnected from app: ${connectedApp.value?.appId}'),
          );
        }
        isConnected.value = false;
        connectedApp.value = null;
        _currentDeviceId = null;
        // Drop any half-received app-info so it can't poison the next central.
        _appInfoReassembler.reset();
      }
    });

    _server.onAdvertisingStateChanged((state, error) async {
      if (kDebugMode) {
        print('OpenBikeControl advertising state: ${state.name}${error != null ? ' — $error' : ''}');
      }
      if (state == PeripheralAdvertisingState.error) {
        if (await recoverIfAlreadyAdvertising(error)) return;
        core.connection.signalNotification(
          AlertNotification(
            LogLevel.LOGLEVEL_WARNING,
            'OpenBikeControl failed to advertise${error != null ? ': $error' : ''}',
          ),
        );
      }
    });

    while (!(await _server.isReady) && core.settings.getObpBleEnabled()) {
      print('Waiting for peripheral manager to be ready...');
      await Future.delayed(Duration(seconds: 1));
    }

    if (!_isServiceAdded) {
      await Future.delayed(Duration(seconds: 1));

      if (!_isSubscribedToEvents) {
        _isSubscribedToEvents = true;

        _server.onSubscriptionChanged((deviceId, characteristicId, isSubscribed) {
          if (isSubscribed) _currentDeviceId = deviceId;
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

        // Some apps (e.g. TrainingPeaks on macOS) split the app-info write
        // across several BLE packets; the reassembler accumulates fragments
        // until the flattened buffer parses. It's a field so disconnect can
        // reset it (see onConnectionChanged) and so it outlives this closure.
        _server.setWriteHandler(OpenBikeControlConstants.APPINFO_CHARACTERISTIC_UUID, (
          deviceId,
          characteristicId,
          offset,
          value,
        ) {
          if (value == null) return PeripheralWriteRequestResult();
          if (kDebugMode) {
            print('Write request for characteristic: $characteristicId: ${bytesToReadableHex(value)}');
          }
          final appInfo = _appInfoReassembler.offer(value);
          if (appInfo == null) {
            core.connection.signalNotification(
              LogNotification('Error parsing App Info ${bytesToHex(value)}: ${_appInfoReassembler.lastError}'),
            );
            return PeripheralWriteRequestResult();
          }
          isConnected.value = true;
          _currentDeviceId = deviceId;
          connectedApp.value = appInfo;
          supportedActions = appInfo.supportedButtons.mapNotNull((b) => b.action).toList();
          final trainerApp = core.settings.getTrainerApp();
          if (trainerApp != null) {
            unawaited(core.settings.setObpSupportedButtons(trainerApp.name, appInfo.supportedButtons));
          }
          core.connection.signalNotification(
            AlertNotification(LogLevel.LOGLEVEL_INFO, 'Connected to app: ${appInfo.appId}'),
          );
          core.connection.signalNotification(LogNotification('Parsed App Info: $appInfo'));
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
              _immutableChar('2A25', '1337'),
              _immutableChar('2A27', '1.0'),
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

      // OpenBikeControl Service
      await _server.addService(
        BlePeripheralService(
          uuid: OpenBikeControlConstants.SERVICE_UUID,
          characteristics: [
            BlePeripheralCharacteristic(
              uuid: OpenBikeControlConstants.BUTTON_STATE_CHARACTERISTIC_UUID,
              properties: [CharacteristicProperty.notify],
              permissions: [],
            ),
            BlePeripheralCharacteristic(
              uuid: OpenBikeControlConstants.APPINFO_CHARACTERISTIC_UUID,
              properties: [CharacteristicProperty.writeWithoutResponse, CharacteristicProperty.write],
              permissions: [PeripheralAttributePermission.readable, PeripheralAttributePermission.writeable],
            ),
          ],
        ),
      );
      _isServiceAdded = true;
    }

    print('Starting advertising with OpenBikeControl service...');
    // Drop any stale/foreign advertisement (e.g. left over from a previous
    // session or another peripheral role) before claiming the shared manager.
    // stopAdvertising is idempotent on Darwin, so this is safe when idle.
    await restartAdvertising();
  }

  @override
  Future<void> startServiceAdvertising() => _server.startAdvertising(
    services: [OpenBikeControlConstants.SERVICE_UUID],
    localName: 'BikeControl',
  );

  Future<void> stopServer() async {
    if (kDebugMode) {
      print('Stopping OpenBikeControl BLE server...');
    }
    await _server.clearServices();
    _isServiceAdded = false;
    await _server.stopAdvertising();
    isStarted.value = false;
    isConnected.value = false;
    connectedApp.value = null;
  }

  BlePeripheralCharacteristic _immutableChar(String uuid, String value) => BlePeripheralCharacteristic(
    uuid: uuid,
    properties: [CharacteristicProperty.read],
    permissions: [PeripheralAttributePermission.readable],
    value: Uint8List.fromList(value.codeUnits),
  );

  @override
  Future<ActionResult> sendAction(KeyPair keyPair, {required bool isKeyDown, required bool isKeyUp}) async {
    final inGameAction = keyPair.inGameAction;

    final mappedButtons = connectedApp.value!.supportedButtons.filter(
      (supportedButton) => supportedButton.action == inGameAction,
    );

    if (inGameAction == null) {
      return Error(
        'Invalid in-game action for key pair: $keyPair',
        button: keyPair.buttons.firstOrNull,
      );
    } else if (_currentDeviceId == null) {
      return Error(
        'No central connected',
        button: keyPair.buttons.firstOrNull,
      );
    } else if (connectedApp.value == null) {
      return Error(
        'No app info received from central',
        button: keyPair.buttons.firstOrNull,
      );
    } else if (mappedButtons.isEmpty) {
      return NotHandled(
        'App does not support all buttons for action: ${inGameAction.title}',
        button: keyPair.buttons.firstOrNull,
      );
    }

    if (isKeyDown && isKeyUp) {
      final responseDataDown = OpenBikeProtocolParser.encodeButtonState(
        mappedButtons.map((b) => ButtonState(b, 1)).toList(),
      );
      await _server.notify(
        characteristicId: OpenBikeControlConstants.BUTTON_STATE_CHARACTERISTIC_UUID,
        value: responseDataDown,
        deviceId: _currentDeviceId,
      );
      final responseDataUp = OpenBikeProtocolParser.encodeButtonState(
        mappedButtons.map((b) => ButtonState(b, 0)).toList(),
      );
      await _server.notify(
        characteristicId: OpenBikeControlConstants.BUTTON_STATE_CHARACTERISTIC_UUID,
        value: responseDataUp,
        deviceId: _currentDeviceId,
      );
    } else {
      final responseData = OpenBikeProtocolParser.encodeButtonState(
        mappedButtons.map((b) => ButtonState(b, isKeyDown ? 1 : 0)).toList(),
      );
      await _server.notify(
        characteristicId: OpenBikeControlConstants.BUTTON_STATE_CHARACTERISTIC_UUID,
        value: responseData,
        deviceId: _currentDeviceId,
      );
    }

    return Success(
      'Buttons ${inGameAction.title} sent',
      button: keyPair.buttons.firstOrNull,
    );
  }

  @override
  TrainerConnectionType? get virtualShiftingTransport => TrainerConnectionType.bluetooth;

  @override
  Widget getTile({bool small = false}) => OpenBikeControlBluetoothTile(small: small);
}
