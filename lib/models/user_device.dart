class UserDevice {
  final String id;
  final String userId;
  final String platform;
  final String deviceId;
  final String? deviceName;
  final String? appVersion;
  final DateTime? lastSeenAt;
  final DateTime? createdAt;
  final DateTime? revokedAt;

  const UserDevice({
    required this.id,
    required this.userId,
    required this.platform,
    required this.deviceId,
    required this.deviceName,
    required this.appVersion,
    required this.lastSeenAt,
    required this.createdAt,
    required this.revokedAt,
  });

  bool get isRevoked => revokedAt != null;
  bool get isActive => !isRevoked;

  factory UserDevice.fromJson(Map<String, dynamic> json) {
    return UserDevice(
      id: (json['id'] as String?) ?? '',
      userId: (json['user_id'] as String?) ?? '',
      platform: (json['platform'] as String?) ?? '',
      deviceId: (json['device_id'] as String?) ?? '',
      deviceName: json['device_name'] as String?,
      appVersion: json['app_version'] as String?,
      lastSeenAt: _parseDateTime(json['last_seen_at']),
      createdAt: _parseDateTime(json['created_at']),
      revokedAt: _parseDateTime(json['revoked_at']),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }
}
