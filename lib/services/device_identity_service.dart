import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DeviceIdentityService {
  static const String _deviceIdStorageKey = 'bikecontrol_device_id_v1';

  final FlutterSecureStorage _storage;
  final DeviceInfoPlugin _deviceInfo;

  DeviceIdentityService({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
    DeviceInfoPlugin? deviceInfo,
  }) : _storage = storage,
       _deviceInfo = deviceInfo ?? DeviceInfoPlugin();

  Future<String?> currentPlatform() async {
    if (kIsWeb) return null;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return null;
    }
  }

  Future<String> getOrCreateDeviceId() async {
    final existing = await _storage.read(key: _deviceIdStorageKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final platform = await currentPlatform();
    if (platform == null || platform.isEmpty) {
      throw StateError('Unsupported platform for device identity');
    }

    final fingerprintSource = await _buildFingerprintSource(platform);
    final generated = 'devinfo_${platform}_$fingerprintSource';

    final trimmedTo255Characters = generated.length > 255 ? generated.substring(0, 255) : generated;

    await _storage.write(key: _deviceIdStorageKey, value: trimmedTo255Characters);
    return generated;
  }

  Future<String> _buildFingerprintSource(String platform) async {
    switch (platform) {
      case 'android':
        final info = await _deviceInfo.androidInfo;
        return _buildFromMap(
          info.data,
          const ['androidId', 'id', 'fingerprint', 'hardware', 'board', 'device', 'model', 'brand', 'manufacturer'],
        );
      case 'ios':
        final info = await _deviceInfo.iosInfo;
        return _buildFromMap(
          info.data,
          const ['identifierForVendor', 'utsname.machine', 'model', 'name', 'systemName'],
        );
      case 'macos':
        final info = await _deviceInfo.macOsInfo;
        return _buildFromMap(
          info.data,
          const ['systemGUID', 'computerName', 'model', 'arch'],
        );
      case 'windows':
        final info = await _deviceInfo.windowsInfo;
        return _buildFromMap(
          info.data,
          const ['deviceId', 'computerName', 'productName', 'buildLabEx', 'registeredOwner'],
        );
      default:
        throw StateError('Unsupported platform for device identity: $platform');
    }
  }

  String _buildFromMap(Map<String, dynamic> data, List<String> prioritizedKeys) {
    final parts = <String>[];
    for (final key in prioritizedKeys) {
      final value = _normalizeValue(data[key]);
      if (value == null) continue;
      parts.add('$key=$value');
    }

    if (parts.isEmpty) {
      final keys = data.keys.toList()..sort();
      for (final key in keys) {
        final value = _normalizeValue(data[key]);
        if (value == null) continue;
        parts.add('$key=$value');
      }
    }

    if (parts.isEmpty) {
      throw StateError('Unable to derive device identity from platform information');
    }

    return parts.join('|');
  }

  String? _normalizeValue(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    if (text.toLowerCase() == 'unknown') return null;
    return text;
  }
}
