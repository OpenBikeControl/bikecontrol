import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeviceIdentityService {
  static const String _deviceIdStorageKey = 'bikecontrol_device_id_v1';

  final FlutterSecureStorage _storage;
  final DeviceInfoPlugin _deviceInfo;

  DeviceIdentityService({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
    DeviceInfoPlugin? deviceInfo,
  }) : _storage = storage,
       _deviceInfo = deviceInfo ?? DeviceInfoPlugin();

  /// Gets the remote device ID (UUID from user_devices table) for the current device.
  /// Returns null if the device is not registered or user is not logged in.
  Future<String?> getRemoteId(SupabaseClient supabase) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final localDeviceId = await getOrCreateDeviceId();
    
    try {
      final response = await supabase
          .from('user_devices')
          .select('id')
          .eq('user_id', userId)
          .eq('device_id', localDeviceId)
          .maybeSingle();
      
      if (response == null) return null;
      
      return response['id'] as String?;
    } catch (e) {
      return null;
    }
  }

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
    final generated = '${platform}_$fingerprintSource';

    final trimmedTo255Characters = generated.length > 255 ? generated.substring(0, 255) : generated;

    await _storage.write(key: _deviceIdStorageKey, value: trimmedTo255Characters);
    return generated;
  }

  Future<String> _buildFingerprintSource(String platform) async {
    return '${DateTime.now().millisecondsSinceEpoch}_${_deviceInfo.hashCode}';
  }
}
