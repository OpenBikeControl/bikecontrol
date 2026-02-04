/// Represents a media key event with device information
class MediaKeyEvent {
  /// Creates a media key event
  const MediaKeyEvent({
    required this.key,
    required this.deviceId,
  });

  /// The media key that was pressed
  final String key;

  /// The unique identifier of the device that sent the event
  final String deviceId;

  @override
  String toString() => 'MediaKeyEvent(key: $key, deviceId: $deviceId)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaKeyEvent &&
          runtimeType == other.runtimeType &&
          key == other.key &&
          deviceId == other.deviceId;

  @override
  int get hashCode => key.hashCode ^ deviceId.hashCode;
}
