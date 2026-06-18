import 'dart:io';
import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/trainer_connection.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/bluetooth/peripheral_server.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/actions/remote.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:prop/prop.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../utils/keymap/keymap.dart';
import '../widgets/mouse_pair_widget.dart';

class RemotePairing extends TrainerConnection {
  bool get isLoading => _isLoading;

  final _server = PeripheralServer();
  bool _isLoading = false;
  bool _isServiceAdded = false;
  bool _isSubscribedToEvents = false;

  String? _currentDeviceId;
  static const _inputReportUuid = '2A4D';
  static const _hidServiceUuid = '1812';

  RemotePairing()
    : super(
        title: () => AppLocalizations.current.enablePairingProcess,
        type: ConnectionMethodType.bluetooth,
        supportedActions: InGameAction.values,
      );

  Future<void> reconnect() async {
    await _server.stopAdvertising();
    await _server.clearServices();
    _isServiceAdded = false;
    startAdvertising().catchError((e) {
      core.settings.setRemoteControlEnabled(false);
      core.connection.signalNotification(
        AlertNotification(LogLevel.LOGLEVEL_WARNING, 'Failed to start Remote Control pairing: $e'),
      );
    });
  }

  Future<void> startAdvertising() async {
    _isLoading = true;
    isStarted.value = true;

    _server.onConnectionChanged((deviceId, connected) {
      print('Peripheral connection state: ${connected ? "connected" : "disconnected"} of $deviceId');
      if (!connected) {
        _currentDeviceId = null;
        isConnected.value = false;
        core.connection.signalNotification(
          AlertNotification(LogLevel.LOGLEVEL_INFO, AppLocalizations.current.disconnected),
        );
      }
    });

    _server.onAdvertisingStateChanged((state, error) {
      if (kDebugMode) {
        print('Remote control advertising state: ${state.name}${error != null ? ' — $error' : ''}');
      }
      if (state == PeripheralAdvertisingState.error) {
        core.connection.signalNotification(
          AlertNotification(
            LogLevel.LOGLEVEL_WARNING,
            'Remote control failed to advertise${error != null ? ': $error' : ''}',
          ),
        );
      }
    });

    if (!kIsWeb && Platform.isAndroid) {
      final status = await Permission.bluetoothAdvertise.request();
      if (!status.isGranted) {
        print('Bluetooth advertise permission not granted');
        isStarted.value = false;
        return;
      }
    }

    while (!(await _server.isReady) && core.settings.getRemoteControlEnabled()) {
      print('Waiting for peripheral manager to be ready...');
      if (core.settings.getLastTarget() == Target.thisDevice) {
        return;
      }
      await Future.delayed(Duration(seconds: 1));
    }

    if (!_isServiceAdded) {
      await Future.delayed(Duration(seconds: 1));

      final reportMapDataAbsolute = Uint8List.fromList([
        0x05, 0x01, // Usage Page (Generic Desktop)
        0x09, 0x02, // Usage (Mouse)
        0xA1, 0x01, // Collection (Application)
        0x85, 0x01, //   Report ID (1)
        0x09, 0x01, //   Usage (Pointer)
        0xA1, 0x00, //   Collection (Physical)
        0x05, 0x09, //     Usage Page (Button)
        0x19, 0x01, //     Usage Min (1)
        0x29, 0x03, //     Usage Max (3)
        0x15, 0x00, //     Logical Min (0)
        0x25, 0x01, //     Logical Max (1)
        0x95, 0x03, //     Report Count (3)
        0x75, 0x01, //     Report Size (1)
        0x81, 0x02, //     Input (Data,Var,Abs)  // buttons
        0x95, 0x01, //     Report Count (1)
        0x75, 0x05, //     Report Size (5)
        0x81, 0x03, //     Input (Const,Var,Abs) // padding
        0x05, 0x01, //     Usage Page (Generic Desktop)
        0x09, 0x30, //     Usage (X)
        0x09, 0x31, //     Usage (Y)
        0x15, 0x00, //     Logical Min (0)
        0x25, 0x64, //     Logical Max (100)
        0x75, 0x08, //     Report Size (8)
        0x95, 0x02, //     Report Count (2)
        0x81, 0x02, //     Input (Data,Var,Abs)
        0xC0,
        0xC0,
      ]);

      // HID characteristics
      final hidInfo = BlePeripheralCharacteristic(
        uuid: '2A4A',
        properties: [CharacteristicProperty.read],
        permissions: [PeripheralAttributePermission.readable],
        value: Uint8List.fromList([0x11, 0x01, 0x00, 0x02]),
      );

      final reportMap = BlePeripheralCharacteristic(
        uuid: '2A4B',
        properties: [CharacteristicProperty.read],
        permissions: [PeripheralAttributePermission.readable],
        value: reportMapDataAbsolute,
        descriptors: [
          BlePeripheralDescriptor(uuid: '2908', value: Uint8List.fromList([0x0, 0x0])),
        ],
      );

      final protocolMode = BlePeripheralCharacteristic(
        uuid: '2A4E',
        properties: [CharacteristicProperty.read, CharacteristicProperty.writeWithoutResponse],
        permissions: [PeripheralAttributePermission.readable, PeripheralAttributePermission.writeable],
      );

      final hidControlPoint = BlePeripheralCharacteristic(
        uuid: '2A4C',
        properties: [CharacteristicProperty.writeWithoutResponse],
        permissions: [PeripheralAttributePermission.writeable],
      );

      final inputReport = BlePeripheralCharacteristic(
        uuid: _inputReportUuid,
        permissions: [PeripheralAttributePermission.readable],
        properties: [CharacteristicProperty.notify, CharacteristicProperty.read],
        descriptors: [
          // Report Reference: ID=1, Type=Input(1)
          BlePeripheralDescriptor(uuid: '2908', value: Uint8List.fromList([0x01, 0x01])),
        ],
      );

      if (!_isSubscribedToEvents) {
        _isSubscribedToEvents = true;
        _server.onSubscriptionChanged((deviceId, characteristicId, isSubscribed) {
          if (characteristicId.toLowerCase() == _inputReportUuid.toLowerCase()) {
            if (isSubscribed) {
              _currentDeviceId = deviceId;
              isConnected.value = true;
              print('Input report subscribed');
            } else {
              _currentDeviceId = null;
              isConnected.value = false;
              print('Input report unsubscribed');
            }
          }
          print('Notify state changed for $characteristicId: $isSubscribed');
        });
      }

      await _server.addService(
        BlePeripheralService(
          uuid: Platform.isIOS ? _hidServiceUuid : '00001812-0000-1000-8000-00805F9B34FB',
          characteristics: [
            hidInfo,
            reportMap,
            protocolMode,
            hidControlPoint,
            inputReport,
          ],
        ),
      );

      // Optional Battery service
      await _server.addService(
        BlePeripheralService(
          uuid: '180F',
          characteristics: [
            BlePeripheralCharacteristic(
              uuid: '2A19',
              properties: [CharacteristicProperty.read],
              permissions: [PeripheralAttributePermission.readable],
              value: Uint8List.fromList([100]),
            ),
          ],
        ),
      );
      _isServiceAdded = true;
    }

    print('Starting advertising with Remote service...');

    try {
      await _server.startAdvertising(
        services: [Platform.isIOS ? _hidServiceUuid : '00001812-0000-1000-8000-00805F9B34FB'],
        localName:
            'BikeControl ${Platform.isIOS
                ? 'iOS'
                : Platform.isAndroid
                ? 'Android'
                : ''}',
      );
    } catch (e) {
      if (e.toString().contains("Advertising has already started") || e.toString().contains("already")) {
        print('Advertising already started, ignoring error');
        return;
      } else {
        rethrow;
      }
    }
    _isLoading = false;
  }

  Future<void> stopAdvertising() async {
    await _server.clearServices();
    _isServiceAdded = false;
    await _server.stopAdvertising();
    isStarted.value = false;
    isConnected.value = false;
    _isLoading = false;
  }

  Future<void> notifyCharacteristic(Uint8List value) async {
    if (_currentDeviceId != null) {
      await _server.notify(
        characteristicId: _inputReportUuid,
        value: value,
        deviceId: _currentDeviceId,
      );
    }
  }

  @override
  Future<ActionResult> sendAction(KeyPair keyPair, {required bool isKeyDown, required bool isKeyUp}) async {
    final point = await (core.actionHandler as RemoteActions).resolveTouchPosition(keyPair: keyPair, windowInfo: null);
    final point2 = point; //Offset(100, 99.0);
    await sendAbsMouseReport(0, point2.dx.toInt(), point2.dy.toInt());
    await sendAbsMouseReport(1, point2.dx.toInt(), point2.dy.toInt());
    await sendAbsMouseReport(0, point2.dx.toInt(), point2.dy.toInt());

    return Success(
      'Mouse clicked at: ${point2.dx.toInt()} ${point2.dy.toInt()}',
      button: keyPair.buttons.firstOrNull,
    );
  }

  Uint8List absMouseReport(int buttons3bit, int x, int y) {
    final b = buttons3bit & 0x07;
    final xi = x.clamp(0, 100);
    final yi = y.clamp(0, 100);
    return Uint8List.fromList([b, xi, yi]);
  }

  // Send a relative mouse move + button state as 3-byte report: [buttons, dx, dy]
  Future<void> sendAbsMouseReport(int buttons, int dx, int dy) async {
    final bytes = absMouseReport(buttons, dx, dy);
    if (kDebugMode) {
      print('Preparing to send abs mouse report: buttons=$buttons, dx=$dx, dy=$dy');
      print('Sending abs mouse report: ${bytes.map((e) => e.toRadixString(16).padLeft(2, '0'))}');
    }

    await notifyCharacteristic(bytes);

    // we don't want to overwhelm the target device
    await Future.delayed(Duration(milliseconds: 10));
  }

  @override
  Widget getTile({bool small = false}) => RemoteMousePairingWidget(small: small);
}
