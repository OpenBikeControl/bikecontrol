import 'package:bike_control/models/user_device.dart';

class DeviceLimitReachedError implements Exception {
  final String platform;
  final int maxDevices;
  final List<UserDevice> devices;

  const DeviceLimitReachedError({
    required this.platform,
    required this.maxDevices,
    required this.devices,
  });

  factory DeviceLimitReachedError.fromJson(Map<String, dynamic> json) {
    final rawDevices = json['devices'];
    final parsedDevices = rawDevices is List
        ? rawDevices
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .map(UserDevice.fromJson)
              .toList(growable: false)
        : const <UserDevice>[];

    return DeviceLimitReachedError(
      platform: (json['platform'] as String?) ?? '',
      maxDevices: (json['max_devices'] as num?)?.toInt() ?? 0,
      devices: parsedDevices,
    );
  }

  @override
  String toString() {
    return 'Device limit reached for $platform ($maxDevices)';
  }
}
