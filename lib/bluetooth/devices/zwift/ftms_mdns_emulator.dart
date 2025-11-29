import 'dart:io';
import 'dart:typed_data';

import 'package:dartx/dartx.dart';
import 'package:mdns_dart/mdns_dart.dart';
import 'package:swift_control/bluetooth/devices/zwift/constants.dart';
import 'package:swift_control/bluetooth/devices/zwift/protocol/zp.pbenum.dart';
import 'package:swift_control/bluetooth/devices/zwift/protocol/zwift.pb.dart' show RideKeyPadStatus;
import 'package:swift_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:swift_control/utils/keymap/buttons.dart';

class FtmsMdnsEmulator {
  late ServerSocket _server;

  Socket? _socket;
  var lastMessageId = 0;

  Future<void> init() async {
    print('Starting mDNS server...');

    // Get local IP
    final interfaces = await NetworkInterface.list();
    InternetAddress? localIP;

    for (final interface in interfaces) {
      for (final addr in interface.addresses) {
        if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
          localIP = addr;
          break;
        }
      }
      if (localIP != null) break;
    }

    if (localIP == null) {
      print('Could not find network interface');
      return;
    }

    _createTcpServer();

    // Create service
    final service = await MDNSService.create(
      instance: 'KICKR BIKE SHIFT B84D',
      service: '_wahoo-fitness-tnp._tcp',
      port: 36867,
      //hostName: 'KICKR BIKE SHIFT B84D.local',
      ips: [localIP],
      txt: [
        'ble-service-uuids=FC82',
        'mac-address=50-50-25-6C-66-9C',
        'serial-number=244700181',
      ],
    );

    print('Service: ${service.instance} at ${localIP.address}:${service.port}');

    // Start server
    final server = MDNSServer(
      MDNSServerConfig(
        zone: service,
        reusePort: true,
        logger: (log) {},
      ),
    );

    try {
      await server.start();
      print('Server started - advertising service!');
    } finally {
      await server.stop();
      print('Server stopped');
    }
  }

  Future<void> _createTcpServer() async {
    try {
      _server = await ServerSocket.bind(
        InternetAddress.anyIPv6,
        36867,
        shared: true,
        v6Only: false,
      );
    } catch (e) {
      if (true) {
        print('Failed to start server: $e');
      }
      rethrow;
    }
    if (true) {
      print('Server started on port ${_server.port}');
    }

    // Accept connection
    _server.listen(
      (Socket socket) {
        _socket = socket;
        if (true) {
          print('Client connected: ${socket.remoteAddress.address}:${socket.remotePort}');
        }

        // Listen for data from the client
        socket.listen(
          (List<int> data) {
            print('Received message: ${bytesToHex(data)}');

            final mutable = data.toList();
            while (mutable.isNotEmpty) {
              final msgVersion = mutable.takeUInt8();
              final msgId = mutable.takeUInt8();
              lastMessageId = msgId;
              final seqNum = mutable.takeUInt8();
              final respCode = mutable.takeUInt8(); // Response Code
              final length = mutable.takeUInt16BE(); // Length of the message body

              final body = mutable.takeBytes(length);
              print('Parsed message: ID: $msgId, Body: ${bytesToHex(body)}');

              Uint8List buildHeader(int responseCode, int bodyLength) {
                return Uint8List.fromList([
                  msgVersion,
                  msgId,
                  seqNum,
                  responseCode,
                  (bodyLength >> 8) & 0xFF,
                  bodyLength & 0xFF,
                ]);
              }

              switch (msgId) {
                case FtmsMdnsConstants.DC_MESSAGE_DISCOVER_SERVICES:
                  final body = hexToBytes(ZwiftConstants.ZWIFT_RIDE_CUSTOM_SERVICE_UUID.toNonDash());

                  final header = buildHeader(FtmsMdnsConstants.DC_RC_REQUEST_COMPLETED_SUCCESSFULLY, body.length);
                  final bytes = [...header, ...body];

                  // Expected 0101000000100000fc8200001000800000805f9b34fb
                  // Got      0101000000100000fc8200001000800000805f9b34fb
                  _write(socket, bytes);
                case FtmsMdnsConstants.DC_MESSAGE_DISCOVER_CHARACTERISTICS:
                  final rawUUID = body.takeBytes(16);
                  final serviceUUID = bytesToHex(rawUUID).toUUID();
                  if (serviceUUID == ZwiftConstants.ZWIFT_RIDE_CUSTOM_SERVICE_UUID) {
                    final responseBody = [
                      ...rawUUID,
                      ...hexToBytes(ZwiftConstants.ZWIFT_SYNC_RX_CHARACTERISTIC_UUID.toNonDash()),
                      ...[
                        _propertyVal(['write']),
                      ],
                      ...hexToBytes(ZwiftConstants.ZWIFT_ASYNC_CHARACTERISTIC_UUID.toNonDash()),
                      ...[
                        _propertyVal(['notify']),
                      ],
                      ...hexToBytes(ZwiftConstants.ZWIFT_SYNC_TX_CHARACTERISTIC_UUID.toNonDash()),
                      ...[
                        _propertyVal(['notify']),
                      ],
                    ];

                    final responseData = [
                      ...buildHeader(
                        FtmsMdnsConstants.DC_RC_REQUEST_COMPLETED_SUCCESSFULLY,
                        responseBody.length,
                      ),
                      ...responseBody,
                    ];

                    // OK: 0102010000430000fc8200001000800000805f9b34fb0000000319ca465186e5fa29dcdd09d1020000000219ca465186e5fa29dcdd09d1040000000419ca465186e5fa29dcdd09d104
                    _write(socket, responseData);
                  }
                case FtmsMdnsConstants.DC_MESSAGE_READ_CHARACTERISTIC:
                  final rawUUID = body.takeBytes(16);
                  final characteristicUUID = bytesToHex(rawUUID).toUUID();

                  print(
                    'Got Read Characteristic UUID: $characteristicUUID',
                  );

                  final responseBody = rawUUID;
                  final responseData = [
                    ...buildHeader(
                      FtmsMdnsConstants.DC_RC_REQUEST_COMPLETED_SUCCESSFULLY,
                      responseBody.length,
                    ),
                    ...responseBody,
                  ];

                  _write(socket, responseData);
                case FtmsMdnsConstants.DC_MESSAGE_WRITE_CHARACTERISTIC:
                  final rawUUID = body.takeBytes(16);
                  final characteristicUUID = bytesToHex(rawUUID).toUUID();
                  final characteristicData = body.takeBytes(body.length);

                  print(
                    'Got Write Characteristic UUID: $characteristicUUID, Data: ${bytesToHex(characteristicData)}',
                  );

                  final responseBody = rawUUID;
                  final responseData = [
                    ...buildHeader(
                      FtmsMdnsConstants.DC_RC_REQUEST_COMPLETED_SUCCESSFULLY,
                      responseBody.length,
                    ),
                    ...responseBody,
                  ];

                  _write(socket, responseData);

                  if (characteristicUUID == ZwiftConstants.ZWIFT_SYNC_RX_CHARACTERISTIC_UUID.toLowerCase()) {
                    final rideOnCommand = ZwiftConstants.RIDE_ON + ZwiftConstants.RESPONSE_START_CLICK_V2;
                    if (characteristicData.contentEquals(rideOnCommand)) {
                      print('Got RIDE ON command!');

                      final seqNum = (lastMessageId + 1) % 256;
                      lastMessageId = seqNum;

                      final responseBody = [
                        ...hexToBytes(ZwiftConstants.ZWIFT_SYNC_TX_CHARACTERISTIC_UUID.toLowerCase().toNonDash()),
                        ...rideOnCommand,
                      ];
                      final responseData = [
                        // header
                        ...Uint8List.fromList([
                          msgVersion,
                          FtmsMdnsConstants.DC_MESSAGE_CHARACTERISTIC_NOTIFICATION,
                          seqNum,
                          FtmsMdnsConstants.DC_RC_REQUEST_COMPLETED_SUCCESSFULLY,
                          (responseBody.length >> 8) & 0xFF,
                          responseBody.length & 0xFF,
                        ]),
                        // body
                        ...responseBody,
                      ];

                      // 0106050000180000000419ca465186e5fa29dcdd09d1526964654f6e0203
                      _write(socket, responseData);
                    }
                  }
                  return;
                case FtmsMdnsConstants.DC_MESSAGE_ENABLE_CHARACTERISTIC_NOTIFICATIONS:
                  final rawUUID = body.takeBytes(16);
                  final characteristicUUID = bytesToHex(rawUUID).toUUID();
                  final enabled = body.takeUInt8();
                  print(
                    'Got Enable Notifications for Characteristic UUID: $characteristicUUID, Enabled: $enabled',
                  );

                  final responseBody = rawUUID;
                  final responseData = [
                    ...buildHeader(
                      FtmsMdnsConstants.DC_RC_REQUEST_COMPLETED_SUCCESSFULLY,
                      responseBody.length,
                    ),
                    ...responseBody,
                  ];

                  _write(socket, responseData);
                case FtmsMdnsConstants.DC_MESSAGE_CHARACTERISTIC_NOTIFICATION:
                  print('Hamlo');
                default:
                  throw 'DC_ERROR_UNKNOWN_MESSAGE_TYPE';
              }
            }
          },
          onDone: () {
            print('Client disconnected: $socket');
          },
        );
      },
    );
  }

  void _write(Socket socket, List<int> responseData) {
    print('Sending response: ${bytesToHex(responseData)}');
    socket.add(responseData);
  }

  int _propertyVal(List<String> properties) {
    int res = 0;

    if (properties.contains('read')) res |= 0x01;
    if (properties.contains('write')) res |= 0x02;
    if (properties.contains('indicate')) res |= 0x03;
    if (properties.contains('notify')) res |= 0x04;

    return res;
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

    final commandProto = _buildButtonNotify(
      Uint8List.fromList([
        Opcode.CONTROLLER_NOTIFICATION.value,
        ...bytes,
      ]),
    );

    _write(_socket!, commandProto);

    //final zero = _buildButtonNotify(Uint8List.fromList([0x23, 0x08, 0xFF, 0xFF, 0xFF, 0xFF, 0x0F]));
    //_write(_socket!, zero);

    /*final data = ClickKeyPadStatus()
      ..buttonMinus = PlayButtonStatus.ON
      ..buttonPlus = PlayButtonStatus.OFF;

    _write(_socket!, _buildButtonNotify([ZwiftConstants.CLICK_NOTIFICATION_MESSAGE_TYPE, ...data.writeToBuffer()]));*/

    /*final data = PlayKeyPadStatus()
      ..buttonShift = PlayButtonStatus.ON
      ..rightPad = PlayButtonStatus.ON;

    _write(_socket!, _buildButtonNotify([ZwiftConstants.PLAY_NOTIFICATION_MESSAGE_TYPE, ...data.writeToBuffer()]));*/

    return 'Sent action: ${inGameAction.name}';
  }

  List<int> _buildButtonNotify(final List<int> data) {
    final seqNum = (lastMessageId + 1) % 256;
    lastMessageId = seqNum;

    final responseBody = [
      ...hexToBytes(ZwiftConstants.ZWIFT_ASYNC_CHARACTERISTIC_UUID.toLowerCase().toNonDash()),
      ...data,
    ];
    final responseData = [
      // header
      ...Uint8List.fromList([
        0x01,
        FtmsMdnsConstants.DC_MESSAGE_CHARACTERISTIC_NOTIFICATION,
        seqNum,
        FtmsMdnsConstants.DC_RC_REQUEST_COMPLETED_SUCCESSFULLY,
        (responseBody.length >> 8) & 0xFF,
        responseBody.length & 0xFF,
      ]),
      // body
      ...responseBody,
    ];
    return responseData;
  }
}

extension on String {
  String toNonDash() {
    return replaceAll('-', '');
  }

  String toUUID() {
    return '${substring(0, 8)}-${substring(8, 12)}-${substring(12, 16)}-${substring(16, 20)}-${substring(20)}';
  }
}

extension on List<int> {
  int takeUInt8() {
    final value = this[0];
    removeAt(0);
    return value;
  }

  int readUInt8(int offset) {
    return this[offset];
  }

  int takeUInt16BE() {
    final value = (this[0] << 8) | this[0 + 1];
    removeAt(0);
    removeAt(0);
    return value;
  }

  List<int> takeBytes(int length) {
    final value = sublist(0, length);
    removeRange(0, length);
    return value;
  }

  int readUInt16BE(int i) {
    final value = (this[i] << 8) | this[i + 1];
    return value;
  }
}

String bytesToHex(List<int> bytes) {
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}

List<int> hexToBytes(String hex) {
  final bytes = <int>[];
  for (var i = 0; i < hex.length; i += 2) {
    final byte = hex.substring(i, i + 2);
    bytes.add(int.parse(byte, radix: 16));
  }
  return bytes;
}

class FtmsMdnsConstants {
  static const DC_RC_REQUEST_COMPLETED_SUCCESSFULLY = 0; // Request completed successfully
  static const DC_RC_UNKNOWN_MESSAGE_TYPE = 1; // Unknown Message Type
  static const DC_RC_UNEXPECTED_ERROR = 2; // Unexpected Error
  static const DC_RC_SERVICE_NOT_FOUND = 3; // Service Not Found
  static const DC_RC_CHARACTERISTIC_NOT_FOUND = 4; // Characteristic Not Found
  static const DC_RC_CHARACTERISTIC_OPERATION_NOT_SUPPORTED =
      5; // Characteristic Operation Not Supported (See Characteristic Properties)
  static const DC_RC_CHARACTERISTIC_WRITE_FAILED_INVALID_SIZE =
      6; // Characteristic Write Failed – Invalid characteristic data size
  static const DC_RC_UNKNOWN_PROTOCOL_VERSION =
      7; // Unknown Protocol Version – the command contains a protocol version that the device does not recognize

  static const DC_MESSAGE_DISCOVER_SERVICES = 0x01; // Discover Services
  static const DC_MESSAGE_DISCOVER_CHARACTERISTICS = 0x02; // Discover Characteristics
  static const DC_MESSAGE_READ_CHARACTERISTIC = 0x03; // Read Characteristic
  static const DC_MESSAGE_WRITE_CHARACTERISTIC = 0x04; // Write Characteristic
  static const DC_MESSAGE_ENABLE_CHARACTERISTIC_NOTIFICATIONS = 0x05; // Enable Characteristic Notifications
  static const DC_MESSAGE_CHARACTERISTIC_NOTIFICATION = 0x06; // Characteristic Notification
}
