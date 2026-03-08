class RegisterDeviceResult {
  final bool ok;
  final String platform;
  final String deviceId;
  final int maxDevices;
  final int activeDeviceCount;

  const RegisterDeviceResult({
    required this.ok,
    required this.platform,
    required this.deviceId,
    required this.maxDevices,
    required this.activeDeviceCount,
  });

  factory RegisterDeviceResult.fromJson(Map<String, dynamic> json) {
    return RegisterDeviceResult(
      ok: (json['ok'] as bool?) ?? false,
      platform: (json['platform'] as String?) ?? '',
      deviceId: (json['device_id'] as String?) ?? '',
      maxDevices: (json['max_devices'] as num?)?.toInt() ?? 0,
      activeDeviceCount: (json['active_device_count'] as num?)?.toInt() ?? 0,
    );
  }
}
