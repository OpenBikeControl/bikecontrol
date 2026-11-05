class OnelapKeyPacket {
  final int deviceType;
  final int deviceIndex;
  final int clickedButtons;
  final int longPressedButtons;

  const OnelapKeyPacket({
    required this.deviceType,
    required this.deviceIndex,
    required this.clickedButtons,
    required this.longPressedButtons,
  });

  static OnelapKeyPacket? parse(List<int> bytes) {
    if (bytes.length < 11 || bytes[1] != 0xf5 || bytes[2] != 0x10) {
      return null;
    }
    final deviceType = bytes[5] & 0x1f;
    if (deviceType > 2) {
      return null;
    }

    return OnelapKeyPacket(
      deviceType: deviceType,
      deviceIndex: (bytes[5] >> 5) & 0x07,
      clickedButtons: bytes[8] & 0x1f,
      longPressedButtons: bytes[10] & 0x1f,
    );
  }
}
