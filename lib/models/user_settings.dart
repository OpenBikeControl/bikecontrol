import 'package:bike_control/models/shifting_config.dart';

/// Model representing user settings synced across devices.
/// Corresponds to the user_settings table in Supabase.
class UserSettings {
  final String? userId;
  final String? deviceId;
  final Map<String, dynamic>? keymaps;
  final List<ShiftingConfig>? shiftingConfigs;
  final List<String>? ignoredDeviceIds;
  final List<String>? ignoredDeviceNames;
  final int version;
  final DateTime? updatedAt;
  final DateTime? createdAt;

  const UserSettings({
    this.userId,
    this.deviceId,
    this.keymaps,
    this.shiftingConfigs,
    this.ignoredDeviceIds,
    this.ignoredDeviceNames,
    this.version = 0,
    this.updatedAt,
    this.createdAt,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    List<ShiftingConfig>? parseShifting(dynamic raw) {
      if (raw is! List) return null;
      return raw
          .whereType<Map<String, dynamic>>()
          .map(ShiftingConfig.fromJson)
          .toList(growable: false);
    }

    return UserSettings(
      userId: json['user_id'] as String?,
      deviceId: json['device_id'] as String?,
      keymaps: json['keymaps'] as Map<String, dynamic>?,
      shiftingConfigs: parseShifting(json['shifting_configs']),
      ignoredDeviceIds: _parseStringList(json['ignored_device_ids']),
      ignoredDeviceNames: _parseStringList(json['ignored_device_names']),
      version: json['version'] as int? ?? 0,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'device_id': deviceId,
      'keymaps': keymaps,
      if (shiftingConfigs != null)
        'shifting_configs': shiftingConfigs!.map((e) => e.toJson()).toList(),
      'ignored_device_ids': _stringifyList(ignoredDeviceIds),
      'ignored_device_names': _stringifyList(ignoredDeviceNames),
      'version': version,
    };
  }

  UserSettings copyWith({
    String? userId,
    String? deviceId,
    Map<String, dynamic>? keymaps,
    List<ShiftingConfig>? shiftingConfigs,
    List<String>? ignoredDeviceIds,
    List<String>? ignoredDeviceNames,
    int? version,
    DateTime? updatedAt,
    DateTime? createdAt,
  }) {
    return UserSettings(
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      keymaps: keymaps ?? this.keymaps,
      shiftingConfigs: shiftingConfigs ?? this.shiftingConfigs,
      ignoredDeviceIds: ignoredDeviceIds ?? this.ignoredDeviceIds,
      ignoredDeviceNames: ignoredDeviceNames ?? this.ignoredDeviceNames,
      version: version ?? this.version,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static List<String>? _parseStringList(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    if (value is String) {
      return value.isEmpty ? [] : value.split(RegExp(r'[,\n]+')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return null;
  }

  static String? _stringifyList(List<String>? list) {
    if (list == null) return null;
    return list.join(',');
  }

  /// Returns true if this settings instance has newer data than [other].
  /// Compares version first, then falls back to updated_at timestamp.
  bool isNewerThan(UserSettings? other) {
    if (other == null) return true;
    if (version != other.version) {
      return version > other.version;
    }
    if (updatedAt != null && other.updatedAt != null) {
      return updatedAt!.isAfter(other.updatedAt!);
    }
    return updatedAt != null;
  }

  @override
  String toString() {
    return 'UserSettings(deviceId: $deviceId, version: $version, updatedAt: $updatedAt, keymaps: ${keymaps?.length ?? 0} items)';
  }
}
