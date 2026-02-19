import 'package:bike_control/models/device_limit_reached_error.dart';
import 'package:bike_control/models/register_device_result.dart';
import 'package:bike_control/models/user_device.dart';
import 'package:bike_control/services/device_identity_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeviceManagementService {
  static const String registerDeviceFunction = 'devices/register';
  static const String meDevicesFunction = 'me/devices';
  static const String revokeDeviceFunction = 'devices/revoke';

  final SupabaseClient _supabase;
  final DeviceIdentityService _deviceIdentityService;

  DeviceManagementService({
    required SupabaseClient supabase,
    required DeviceIdentityService deviceIdentityService,
  }) : _supabase = supabase,
       _deviceIdentityService = deviceIdentityService;

  Future<RegisterDeviceResult> registerCurrentDevice({
    String? deviceName,
    String? appVersion,
  }) async {
    final session = _requireSession();
    final platform = await _requirePlatform();
    final deviceId = await _deviceIdentityService.getOrCreateDeviceId();

    try {
      final response = await _supabase.functions.invoke(
        registerDeviceFunction,
        method: HttpMethod.post,
        headers: _authHeaders(session),
        body: {
          'platform': platform,
          'device_id': deviceId,
          if (deviceName != null && deviceName.isNotEmpty) 'device_name': deviceName,
          if (appVersion != null && appVersion.isNotEmpty) 'app_version': appVersion,
        },
      );
      final payload = Map<String, dynamic>.from(response.data as Map);
      return RegisterDeviceResult.fromJson(payload);
    } on FunctionException catch (error) {
      final limitError = _parseDeviceLimitError(error);
      if (limitError != null) {
        throw limitError;
      }
      rethrow;
    }
  }

  Future<List<UserDevice>> getMyDevices() async {
    final session = _requireSession();
    final response = await _supabase.functions.invoke(
      meDevicesFunction,
      method: HttpMethod.get,
      headers: _authHeaders(session),
    );
    return _parseDevicesPayload(response.data);
  }

  Future<List<UserDevice>> revokeDevice({
    required String platform,
    required String deviceId,
  }) async {
    final session = _requireSession();
    final response = await _supabase.functions.invoke(
      revokeDeviceFunction,
      method: HttpMethod.post,
      headers: _authHeaders(session),
      body: {
        'platform': platform,
        'device_id': deviceId,
      },
    );

    return _parseDevicesPayload(response.data);
  }

  Future<String> currentDeviceId() {
    return _deviceIdentityService.getOrCreateDeviceId();
  }

  Future<String?> currentPlatform() {
    return _deviceIdentityService.currentPlatform();
  }

  Session _requireSession() {
    final session = _supabase.auth.currentSession;
    if (session == null) {
      throw StateError('No active Supabase session');
    }
    return session;
  }

  Future<String> _requirePlatform() async {
    final platform = await _deviceIdentityService.currentPlatform();
    if (platform == null || platform.isEmpty) {
      throw StateError('Unsupported platform for device management');
    }
    return platform;
  }

  Map<String, String> _authHeaders(Session session) {
    return {'Authorization': 'Bearer ${session.accessToken}'};
  }

  List<UserDevice> _parseDevicesPayload(dynamic payload) {
    if (payload is List) {
      return payload
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .map(UserDevice.fromJson)
          .toList(growable: false);
    }

    if (payload is Map) {
      if (payload['devices'] is List) {
        final devices = payload['devices'] as List;
        return devices
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .map(UserDevice.fromJson)
            .toList(growable: false);
      }

      final grouped = <UserDevice>[];
      for (final entry in payload.entries) {
        final value = entry.value;
        if (value is! List) continue;
        grouped.addAll(
          value.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).map((json) {
            final withPlatform = <String, dynamic>{
              'platform': json['platform'] ?? entry.key,
              ...json,
            };
            return UserDevice.fromJson(withPlatform);
          }),
        );
      }
      return grouped;
    }

    return const <UserDevice>[];
  }

  DeviceLimitReachedError? _parseDeviceLimitError(FunctionException error) {
    if (error.status != 409) {
      return null;
    }
    final details = error.details;
    if (details is! Map) {
      return null;
    }
    final json = Map<String, dynamic>.from(details);
    if (json['error'] != 'device_limit_reached') {
      return null;
    }
    return DeviceLimitReachedError.fromJson(json);
  }
}
