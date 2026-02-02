export 'emulators/click_emulator.dart';
export 'emulators/prefs.dart';
export 'emulators/shared.dart';
export 'protocol/zp.pb.dart';
export 'protocol/zp.pbenum.dart';
export 'protocol/zwift.pb.dart';

String bytesToHex(List<int> bytes, {bool spaced = false}) {
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(spaced ? ' ' : '');
}

String bytesToReadableHex(List<int> bytes) {
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(' ');
}

List<int> hexToBytes(String hex) {
  final bytes = <int>[];
  for (var i = 0; i < hex.length; i += 2) {
    final byte = hex.substring(i, i + 2);
    bytes.add(int.parse(byte, radix: 16));
  }
  return bytes;
}
