class BleUuidParser {
  BleUuidParser._();

  /// Parse a string to a valid 128-bit UUID.
  /// Throws `FormatException` if the string does not hold a valid UUID format.
  static String string(String uuid) {
    uuid = uuid.trim();
    if (uuid.length < 4) {
      throw const FormatException('Invalid UUID');
    }

    if (uuid.startsWith('0x')) {
      uuid = uuid.substring(2);
    }

    if (uuid.length <= 8) {
      uuid = "${uuid.padLeft(8, '0')}-0000-1000-8000-00805f9b34fb";
    }

    if (!uuid.contains("-")) {
      if (uuid.length != 32) throw const FormatException("Invalid UUID");

      uuid = "${uuid.substring(0, 8)}-${uuid.substring(8, 12)}"
          "-${uuid.substring(12, 16)}-${uuid.substring(16, 20)}-${uuid.substring(20, 32)}";
    }

    var groups = uuid.split('-');

    if (groups.length != 5 ||
        groups[0].length != 8 ||
        groups[1].length != 4 ||
        groups[2].length != 4 ||
        groups[3].length != 4 ||
        groups[4].length != 12) {
      throw const FormatException('Invalid UUID');
    }

    try {
      int.parse(groups[0], radix: 16);
      int.parse(groups[1], radix: 16);
      int.parse(groups[2], radix: 16);
      int.parse(groups[3], radix: 16);
      int.parse(groups[4], radix: 16);
    } catch (e) {
      throw const FormatException('Invalid UUID');
    }

    return uuid.toLowerCase();
  }

  /// Parse an int number into a 128-bit UUID string.
  /// e.g. `0x1800` to `00001800-0000-1000-8000-00805f9b34fb`.
  static String number(int short) {
    if (short <= 0xFF || short > 0xFFFF) {
      throw const FormatException('Invalid UUID');
    }
    return string(short.toRadixString(16).padLeft(4, '0'));
  }

  /// Compare two UUIDs regardless of their format.
  /// Throws `FormatException` if the UUID is invalid.
  static bool compareStrings(String uuid1, String uuid2) =>
      string(uuid1) == string(uuid2);
}

/// Parse a list of strings to a list of UUIDs.
extension StringListToUUID on List<String> {
  List<String> toValidUUIDList() => map(BleUuidParser.string).toList();
}
