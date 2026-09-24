//INFO: This is a stub - contact me if you need the full implementation.
//
// All concrete protocol values below are FAKE placeholders so the app
// compiles without exposing the real reverse-engineered constants.

import 'dart:typed_data';

class FtmsMdnsConstants {
  // DirCon result / message codes — placeholder values.
  static const DC_RC_REQUEST_COMPLETED_SUCCESSFULLY = 0;
  static const DC_RC_UNKNOWN_MESSAGE_TYPE = 1;
  static const DC_RC_UNEXPECTED_ERROR = 2;
  static const DC_RC_SERVICE_NOT_FOUND = 3;
  static const DC_RC_CHARACTERISTIC_NOT_FOUND = 4;
  static const DC_RC_CHARACTERISTIC_OPERATION_NOT_SUPPORTED = 5;
  static const DC_RC_CHARACTERISTIC_WRITE_FAILED_INVALID_SIZE = 6;
  static const DC_RC_UNKNOWN_PROTOCOL_VERSION = 7;

  static const DC_MESSAGE_DISCOVER_SERVICES = 0x01;
  static const DC_MESSAGE_DISCOVER_CHARACTERISTICS = 0x02;
  static const DC_MESSAGE_READ_CHARACTERISTIC = 0x03;
  static const DC_MESSAGE_WRITE_CHARACTERISTIC = 0x04;
  static const DC_MESSAGE_ENABLE_CHARACTERISTIC_NOTIFICATIONS = 0x05;
  static const DC_MESSAGE_CHARACTERISTIC_NOTIFICATION = 0x06;
  static const DC_MESSAGE_ECHO = 0x07;

  // FAKE placeholder UUIDs / handshake bytes.
  static const ZWIFT_PLAY_SERVICE_UUID = "00000000-0000-0000-0000-0000000000A1";
  static const ZWIFT_PLAY_SERVICE_UUID_LC = "00000000-0000-0000-0000-0000000000a1";
  static const ZWIFT_RIDE_CUSTOM_SERVICE_UUID = "00000000-0000-0000-0000-0000000000a2";
  static const ZWIFT_RIDE_CUSTOM_SERVICE_UUID_SHORT = "00a2";
  static const ZWIFT_ASYNC_CHARACTERISTIC_UUID = "00000000-0000-0000-0000-0000000000A3";
  static const ZWIFT_ASYNC_CHARACTERISTIC_UUID_LC = "00000000-0000-0000-0000-0000000000a3";
  static const ZWIFT_SYNC_RX_CHARACTERISTIC_UUID = "00000000-0000-0000-0000-0000000000A4";
  static const ZWIFT_SYNC_RX_CHARACTERISTIC_UUID_LC = "00000000-0000-0000-0000-0000000000a4";
  static const ZWIFT_SYNC_TX_CHARACTERISTIC_UUID = "00000000-0000-0000-0000-0000000000A5";
  static const ZWIFT_SYNC_TX_CHARACTERISTIC_UUID_LC = "00000000-0000-0000-0000-0000000000a5";
  static final RIDE_ON = Uint8List.fromList([0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);
  static const RIDE_ON_FULL = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00];
}

/// Values BikeControl embeds in its own mDNS TXT records so the WiFi scanner
/// can exclude its own advertisements. FAKE placeholder fingerprints.
class BikeControlMdnsMarkers {
  static const macAddress = '00000000-0000-0000-0000-000000000000';
  static const manufacturerData = '0000000000';
  static const clickMacAddress = '00-00-00-00-00-00';
  static const clickManufacturerData = '0000000001';
  static const obcMacAddress = '00:00:00:00:00:01';

  // FAKE placeholder — the real product identifier lives in the full
  // implementation.
  static const tacxProductId = '0';

  static const txtFingerprints = {
    macAddress,
    manufacturerData,
    clickMacAddress,
    clickManufacturerData,
    obcMacAddress,
  };
}

/// A stable all-digits serial number for the mDNS `serial-number` TXT entry,
/// derived from [seed] (a device id, MAC, …). DIRCON clients parse this field
/// as a 64-bit unsigned integer, so it must not carry a sliced MAC or UUID.
String mdnsSerialNumber(String seed) {
  var hash = 0;
  for (final unit in seed.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return hash.toString().padLeft(9, '0');
}

String bytesToHex(List<int> bytes, {bool spaced = false}) {
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(spaced ? ' ' : '');
}

String bytesToReadableHex(List<int> bytes) {
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(' ');
}

List<int> hexToBytes(String hex) {
  final cleanedHex = hex.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
  final bytes = <int>[];
  for (var i = 0; i < cleanedHex.length; i += 2) {
    bytes.add(int.parse(cleanedHex.substring(i, i + 2), radix: 16));
  }
  return bytes;
}
