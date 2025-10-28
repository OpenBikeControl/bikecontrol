import 'dart:io';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:permission_handler/permission_handler.dart';
import 'package:swift_control/bluetooth/ble.dart';
import 'package:swift_control/bluetooth/devices/zwift/constants.dart';
import 'package:swift_control/bluetooth/devices/zwift/protocol/zwift.pb.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/actions/remote.dart';
import 'package:swift_control/utils/crypto/local_key_provider.dart';
import 'package:swift_control/utils/crypto/zap_crypto.dart';
import 'package:swift_control/utils/keymap/apps/my_whoosh.dart';
import 'package:swift_control/utils/requirements/multi.dart';
import 'package:swift_control/utils/requirements/platform.dart';
import 'package:swift_control/widgets/small_progress_indicator.dart';

import '../../pages/markdown.dart';

final peripheralManager = PeripheralManager();
bool _isAdvertising = false;
bool _isLoading = false;
bool _isServiceAdded = false;
bool _isSubscribedToEvents = false;
final _zapEncryption = ZapCrypto(LocalKeyProvider());
Central? _central;
GATTCharacteristic? _asyncCharacteristic;

class ZwiftRequirement extends PlatformRequirement {
  ZwiftRequirement()
    : super(
        'Connect to your target device',
      );

  @override
  Future<void> call(BuildContext context, VoidCallback onUpdate) async {}

  @override
  Widget? buildDescription() {
    return settings.getLastTarget() == null
        ? null
        : Text(
            switch (settings.getLastTarget()) {
              Target.iPad =>
                'On your iPad go to Settings > Accessibility > Touch > AssistiveTouch > Pointer Devices > Devices and pair your device. Make sure AssistiveTouch is enabled.',
              _ =>
                'On your ${settings.getLastTarget()?.title} go into Bluetooth settings and look for SwiftControl or your machines name. Pairing is required to use the remote feature.',
            },
          );
  }

  Future<void> reconnect() async {
    await peripheralManager.stopAdvertising();
    await peripheralManager.removeAllServices();
    _isServiceAdded = false;
    _isAdvertising = false;
    (actionHandler as RemoteActions).setConnectedCentral(null, null);
    startAdvertising(() {});
  }

  Future<void> startAdvertising(VoidCallback onUpdate) async {
    peripheralManager.stateChanged.forEach((state) {
      print('Peripheral manager state: ${state.state}');
    });

    if (!kIsWeb && Platform.isAndroid) {
      if (Platform.isAndroid) {
        peripheralManager.connectionStateChanged.forEach((state) {
          print('Peripheral connection state: ${state.state} of ${state.central.uuid}');
          if (state.state == ConnectionState.connected) {
            /*(actionHandler as RemoteActions).setConnectedCentral(state.central, inputReport);
            //peripheralManager.stopAdvertising();
            onUpdate();*/
          } else if (state.state == ConnectionState.disconnected) {
            //(actionHandler as RemoteActions).setConnectedCentral(null, null);
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

    while (peripheralManager.state != BluetoothLowEnergyState.poweredOn) {
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
        peripheralManager.characteristicReadRequested.forEach((eventArgs) async {
          print('Read request for characteristic: ${eventArgs.characteristic.uuid}');

          switch (eventArgs.characteristic.uuid.toString().toUpperCase()) {
            case ZwiftConstants.ZWIFT_SYNC_TX_CHARACTERISTIC_UUID:
              print('Handling read request for SYNC TX characteristic');
              break;
            case BleUuid.DEVICE_INFORMATION_CHARACTERISTIC_BATTERY_LEVEL:
              await peripheralManager.respondReadRequestWithValue(
                eventArgs.request,
                value: Uint8List.fromList([100]),
              );
              break;
            default:
              print('Unhandled read request for characteristic: ${eventArgs.characteristic.uuid}');
          }

          final central = eventArgs.central;
          final characteristic = eventArgs.characteristic;
          final request = eventArgs.request;
          final offset = request.offset;
          final trimmedValue = Uint8List.fromList([]);
          await peripheralManager.respondReadRequestWithValue(
            request,
            value: trimmedValue,
          );
          // You can respond to read requests here if needed
        });

        peripheralManager.characteristicNotifyStateChanged.forEach((char) {
          print(
            'Notify state changed for characteristic: ${char.characteristic.uuid}: ${char.state}',
          );
        });
        peripheralManager.characteristicWriteRequested.forEach((eventArgs) async {
          _central = eventArgs.central;
          final characteristic = eventArgs.characteristic;
          final request = eventArgs.request;
          final offset = request.offset;
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

              if (value.contentEquals(handshake)) {
                await peripheralManager.notifyCharacteristic(
                  _central!,
                  syncTxCharacteristic,
                  value: ZwiftConstants.RIDE_ON,
                );
              } else if (value.startsWith(handshake)) {
                final devicePublicKeyBytes = value.sublist(
                  ZwiftConstants.RIDE_ON.length + ZwiftConstants.RESPONSE_START_CLICK_V2.length,
                );
                if (kDebugMode) {
                  print(
                    "Device Public Key - ${devicePublicKeyBytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}",
                  );
                }
                _zapEncryption.initialise(devicePublicKeyBytes);
                // respond with our public key
                final response = [
                  ...ZwiftConstants.RIDE_ON,
                  ...ZwiftConstants.RESPONSE_START_CLICK,
                  ..._zapEncryption.localKeyProvider.getPublicKeyBytes(),
                ];
                await peripheralManager.notifyCharacteristic(
                  _central!,
                  syncTxCharacteristic,
                  value: Uint8List.fromList(response),
                );
              }
              break;
            default:
              print('Unhandled write request for characteristic: ${eventArgs.characteristic.uuid}');
          }

          await peripheralManager.respondWriteRequest(request);
        });
      }

      // Device Information
      await peripheralManager.addService(
        GATTService(
          uuid: UUID.fromString('180A'),
          isPrimary: true,
          characteristics: [
            GATTCharacteristic.immutable(
              uuid: UUID.fromString('2A29'),
              value: Uint8List.fromList('Zwift Inc'.codeUnits),
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
              value: Uint8List.fromList('1.1.0'.codeUnits),
              descriptors: [],
            ),
          ],
          includedServices: [],
        ),
      );

      // Battery Service
      await peripheralManager.addService(
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
      await peripheralManager.addService(
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
      serviceUUIDs: [UUID.fromString(ZwiftConstants.ZWIFT_CUSTOM_SERVICE_UUID)],
      manufacturerSpecificData: [
        ManufacturerSpecificData(id: 0x094A, data: Uint8List.fromList([0x09, 0xFD, 0x82])),
      ],
    );
    print('Starting advertising with HID service...');

    await peripheralManager.startAdvertising(advertisement);
    _isAdvertising = true;
    onUpdate();
  }

  @override
  Widget? build(BuildContext context, VoidCallback onUpdate) {
    return _PairWidget(onUpdate: onUpdate, requirement: this);
  }

  @override
  Future<void> getStatus() async {
    status = (actionHandler as RemoteActions).isConnected || screenshotMode;
  }

  int counter = 0;

  void writeCommand() {
    final down = true;
    final constructed = ClickKeyPadStatus.create()
      ..buttonPlus = down ? PlayButtonStatus.ON : PlayButtonStatus.OFF
      ..buttonMinus = !down ? PlayButtonStatus.ON : PlayButtonStatus.OFF;
    final commandProto = constructed.writeToBuffer();

    final command = down
        ? Uint8List.fromList([ZwiftConstants.CLICK_NOTIFICATION_MESSAGE_TYPE, ...commandProto])
        : Uint8List.fromList([0x37, 0x08, 0x01, 0x10, 0x01]);

    print('Constructed command      : ${command.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}');
    print('Constructed command proto:    ${commandProto.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}');

    final encrypted = _zapEncryption.encrypt(command);
    print('Sending command          : ${encrypted.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}');
    print('vs                       : 10 00 00 00 99 56 9e d2 c4 f2 a3 e5 b6');

    final counter = encrypted.sublist(0, 4); // Int.SIZE_BYTES is 4
    final payload = encrypted.sublist(4);
    final data = _zapEncryption.decrypt(counter, payload);
    final type = data[0];
    final message = data.sublist(1);

    print(
      'Decrypted message type: ${type.toRadixString(16).padLeft(2, '0')}, message: ${message.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}',
    );

    peripheralManager.notifyCharacteristic(
      _central!,
      _asyncCharacteristic!,
      value: encrypted,
    );
  }
}

class _PairWidget extends StatefulWidget {
  final ZwiftRequirement requirement;
  final VoidCallback onUpdate;
  const _PairWidget({super.key, required this.onUpdate, required this.requirement});

  @override
  State<_PairWidget> createState() => _PairWidgetState();
}

class _PairWidgetState extends State<_PairWidget> {
  @override
  void initState() {
    super.initState();
    // after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      toggle().catchError((e) {
        print('Error starting advertising: $e');
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 10,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          spacing: 10,
          children: [
            ElevatedButton(
              onPressed: () async {
                try {
                  await toggle();
                } catch (e) {
                  print('Error toggling advertising: $e');
                }
              },
              child: Text(_isAdvertising ? 'Stop Pairing' : 'Start Pairing'),
            ),
            if (_isAdvertising || _isLoading) SizedBox(height: 20, width: 20, child: SmallProgressIndicator()),
          ],
        ),
        if (settings.getTrainerApp() is MyWhoosh)
          ElevatedButton(
            onPressed: () async {
              widget.requirement.writeCommand();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text('Send command'),
            ),
          ),
        if (_isAdvertising) ...[
          TextButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (c) => MarkdownPage(assetPath: 'TROUBLESHOOTING.md')));
            },
            child: Text('Check the troubleshooting guide'),
          ),
        ],
      ],
    );
  }

  Future<void> toggle() async {
    if (_isAdvertising) {
      await peripheralManager.stopAdvertising();
      _isAdvertising = false;
      (actionHandler as RemoteActions).setConnectedCentral(null, null);
      widget.onUpdate();
      _isLoading = false;
      setState(() {});
    } else {
      _isLoading = true;
      setState(() {});
      await widget.requirement.startAdvertising(widget.onUpdate);
      _isLoading = false;
      if (mounted) setState(() {});
    }
  }
}
