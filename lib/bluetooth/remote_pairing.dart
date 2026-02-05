import 'dart:io';

import 'package:bike_control/bluetooth/devices/trainer_connection.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/actions/remote.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:prop/prop.dart';

import '../utils/keymap/keymap.dart';

class RemotePairing extends TrainerConnection {
  bool get isLoading => _isLoading;

  late final _peripheralManager = PeripheralManager();
  bool _isLoading = false;
  bool _isServiceAdded = false;
  bool _isSubscribedToEvents = false;

  Central? _central;
  GATTCharacteristic? _inputReport;

  static const String connectionTitle = 'Remote Control';

  RemotePairing()
    : super(
        title: connectionTitle,
        supportedActions: InGameAction.values,
      );

  Future<void> reconnect() async {
    await _peripheralManager.stopAdvertising();
    await _peripheralManager.removeAllServices();
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
        }
      });

      final status = await Permission.bluetoothAdvertise.request();
      if (!status.isGranted) {
        print('Bluetooth advertise permission not granted');
        isStarted.value = false;
        return;
      }
    }

    while (_peripheralManager.state != BluetoothLowEnergyState.poweredOn && core.settings.getRemoteControlEnabled()) {
      print('Waiting for peripheral manager to be powered on...');
      if (core.settings.getLastTarget() == Target.thisDevice) {
        return;
      }
      await Future.delayed(Duration(seconds: 1));
    }
    final inputReport = GATTCharacteristic.mutable(
      uuid: UUID.fromString('2A4D'),
      permissions: [GATTCharacteristicPermission.read],
      properties: [GATTCharacteristicProperty.notify, GATTCharacteristicProperty.read],
      descriptors: [
        GATTDescriptor.immutable(
          // Report Reference: ID=1, Type=Input(1)
          uuid: UUID.fromString('2908'),
          value: Uint8List.fromList([0x01, 0x01]),
        ),
      ],
    );

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

      // 1) Build characteristics
      final hidInfo = GATTCharacteristic.immutable(
        uuid: UUID.fromString('2A4A'),
        value: Uint8List.fromList([0x11, 0x01, 0x00, 0x02]),
        descriptors: [], // HID v1.11, country=0, flags=2
      );

      final reportMap = GATTCharacteristic.immutable(
        uuid: UUID.fromString('2A4B'),
        //properties: [GATTCharacteristicProperty.read],
        //permissions: [GATTCharacteristicPermission.read],
        value: reportMapDataAbsolute,
        descriptors: [
          GATTDescriptor.immutable(uuid: UUID.fromString('2908'), value: Uint8List.fromList([0x0, 0x0])),
        ],
      );

      final protocolMode = GATTCharacteristic.mutable(
        uuid: UUID.fromString('2A4E'),
        properties: [GATTCharacteristicProperty.read, GATTCharacteristicProperty.writeWithoutResponse],
        permissions: [GATTCharacteristicPermission.read, GATTCharacteristicPermission.write],
        descriptors: [],
      );

      final hidControlPoint = GATTCharacteristic.mutable(
        uuid: UUID.fromString('2A4C'),
        properties: [GATTCharacteristicProperty.writeWithoutResponse],
        permissions: [GATTCharacteristicPermission.write],
        descriptors: [],
      );

      // 2) HID service
      final hidService = GATTService(
        uuid: UUID.fromString(Platform.isIOS ? '1812' : '00001812-0000-1000-8000-00805F9B34FB'),
        isPrimary: true,
        characteristics: [
          hidInfo,
          reportMap,
          protocolMode,
          hidControlPoint,
          inputReport,
        ],
        includedServices: [],
      );

      if (!_isSubscribedToEvents) {
        _isSubscribedToEvents = true;
        _peripheralManager.characteristicReadRequested.forEach((char) {
          print('Read request for characteristic: ${char}');
          // You can respond to read requests here if needed
        });

        _peripheralManager.characteristicNotifyStateChanged.forEach((char) {
          // Check if this is the input report characteristic (2A4D)
          if (char.characteristic.uuid == inputReport.uuid) {
            if (char.state) {
              _central = char.central;
              _inputReport = char.characteristic;
              isConnected.value = true;
              print('Input report subscribed');
            } else {
              _inputReport = null;
              _central = null;
              isConnected.value = false;
              print('Input report unsubscribed');
            }
          }
          print('Notify state changed for characteristic: ${char.characteristic.uuid}: ${char.state}');
        });
      }
      await _peripheralManager.addService(hidService);

      // 3) Optional Battery service
      await _peripheralManager.addService(
        GATTService(
          uuid: UUID.fromString('180F'),
          isPrimary: true,
          characteristics: [
            GATTCharacteristic.immutable(
              uuid: UUID.fromString('2A19'),
              value: Uint8List.fromList([100]),
              descriptors: [],
            ),
          ],
          includedServices: [],
        ),
      );
      _isServiceAdded = true;
    }

    final advertisement = Advertisement(
      name:
          'BikeControl ${Platform.isIOS
              ? 'iOS'
              : Platform.isAndroid
              ? 'Android'
              : ''}',
      serviceUUIDs: [UUID.fromString(Platform.isIOS ? '1812' : '00001812-0000-1000-8000-00805F9B34FB')],
    );
    print('Starting advertising with Remote service...');

    try {
      await _peripheralManager.startAdvertising(advertisement);
    } catch (e) {
      if (e.toString().contains("Advertising has already started")) {
        print('Advertising already started, ignoring error');
        return;
      } else {
        rethrow;
      }
    }
    _isLoading = false;
  }

  Future<void> stopAdvertising() async {
    await _peripheralManager.removeAllServices();
    _isServiceAdded = false;
    await _peripheralManager.stopAdvertising();
    isStarted.value = false;
    isConnected.value = false;
    _isLoading = false;
  }

  Future<void> notifyCharacteristic(Uint8List value) async {
    if (_inputReport != null && _central != null) {
      await _peripheralManager.notifyCharacteristic(_central!, _inputReport!, value: value);
    }
  }

  @override
  Future<ActionResult> sendAction(KeyPair keyPair, {required bool isKeyDown, required bool isKeyUp}) async {
    final point = await (core.actionHandler as RemoteActions).resolveTouchPosition(keyPair: keyPair, windowInfo: null);
    final point2 = point; //Offset(100, 99.0);
    await sendAbsMouseReport(0, point2.dx.toInt(), point2.dy.toInt());
    await sendAbsMouseReport(1, point2.dx.toInt(), point2.dy.toInt());
    await sendAbsMouseReport(0, point2.dx.toInt(), point2.dy.toInt());

    return Success('Mouse clicked at: ${point2.dx.toInt()} ${point2.dy.toInt()}');
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
}
