enum BleConnectionState {
  connected,
  disconnected,
  connecting,
  disconnecting;

  const BleConnectionState();

  factory BleConnectionState.parse(int index) =>
      BleConnectionState.values[index];
}
