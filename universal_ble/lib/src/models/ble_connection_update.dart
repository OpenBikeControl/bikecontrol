class BleConnectionUpdate {
  final String deviceId;
  final bool isConnected;
  final String? error;

  BleConnectionUpdate({
    required this.deviceId,
    required this.isConnected,
    this.error,
  });
}
