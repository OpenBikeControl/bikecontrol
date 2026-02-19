import 'dart:convert';

import 'package:bike_control/models/device_limit_reached_error.dart';
import 'package:bike_control/models/entitlement.dart';
import 'package:bike_control/services/device_identity_service.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/prop.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EntitlementsService extends ChangeNotifier {
  static const Duration refreshTtl = Duration(minutes: 10);

  static const String _entitlementsFunction = 'get-entitlements';
  static const String _cacheEntitlementsKey = 'entitlements_cache_items';
  static const String _cacheLastFetchedAtKey = 'entitlements_cache_last_fetched_at';
  static const String _cacheRegisteredDeviceKey = 'entitlements_cache_registered_device';

  final SupabaseClient _supabase;
  final DeviceIdentityService _deviceIdentityService;

  SharedPreferences? _prefs;
  bool _isInitialized = false;
  Future<void>? _inFlightRefresh;

  DateTime? _lastFetchedAt;
  List<Entitlement> _entitlements = const [];
  bool _isRegisteredDevice = false;
  DeviceLimitReachedError? _lastDeviceLimitError;

  EntitlementsService(
    this._supabase, {
    required DeviceIdentityService deviceIdentityService,
  }) : _deviceIdentityService = deviceIdentityService;

  List<Entitlement> get current => List.unmodifiable(_entitlements);

  DateTime? get lastFetchedAt => _lastFetchedAt;
  bool get isRegisteredDevice => _isRegisteredDevice;
  DeviceLimitReachedError? get lastDeviceLimitError => _lastDeviceLimitError;

  bool get isCacheStale {
    final fetchedAt = _lastFetchedAt;
    if (fetchedAt == null) {
      return true;
    }
    return DateTime.now().difference(fetchedAt) >= refreshTtl;
  }

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    _prefs = await SharedPreferences.getInstance();
    _restoreCacheFromPrefs();
    _isInitialized = true;
  }

  Future<void> refresh({bool force = false}) async {
    await initialize();

    if (!force && !isCacheStale) {
      return;
    }

    final existing = _inFlightRefresh;
    if (existing != null) {
      return existing;
    }

    final task = _refreshInternal();
    _inFlightRefresh = task;
    try {
      await task;
    } finally {
      _inFlightRefresh = null;
    }
  }

  bool hasActive(String productKey) {
    return _entitlements.any((entitlement) {
      return entitlement.productKey == productKey && entitlement.isActive;
    });
  }

  DateTime? activeUntil(String productKey) {
    DateTime? latest;
    for (final entitlement in _entitlements) {
      if (entitlement.productKey != productKey) {
        continue;
      }
      final value = entitlement.activeUntil;
      if (value == null) {
        continue;
      }
      if (latest == null || value.isAfter(latest)) {
        latest = value;
      }
    }
    return latest;
  }

  Future<void> clearCache() async {
    await initialize();
    _entitlements = const [];
    _lastFetchedAt = null;
    _isRegisteredDevice = false;
    await _prefs?.remove(_cacheEntitlementsKey);
    await _prefs?.remove(_cacheLastFetchedAtKey);
    await _prefs?.remove(_cacheRegisteredDeviceKey);
    notifyListeners();
  }

  Future<void> _refreshInternal() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) {
        return;
      }
      final platform = await _deviceIdentityService.currentPlatform();
      if (platform == null || platform.isEmpty) {
        return;
      }
      final deviceId = await _deviceIdentityService.getOrCreateDeviceId();

      final response = await _supabase.functions.invoke(
        _entitlementsFunction,
        method: HttpMethod.get,
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'X-Device-Platform': platform,
          'X-Device-Id': deviceId,
        },
      );

      final payload = response.data;
      Logger.debug('Entitlements response: $payload');
      final parsed = _extractPayload(payload);
      final list = parsed.entitlements;
      final entitlements = list
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .map(Entitlement.fromJson)
          .toList(growable: false);

      _entitlements = entitlements;
      _isRegisteredDevice = parsed.isRegisteredDevice;
      _lastFetchedAt = DateTime.now();
      _lastDeviceLimitError = null;
      await _persistCache();
      notifyListeners();
    } on FunctionException catch (error, stackTrace) {
      final details = error.details;
      if (error.status == 409 && details is Map) {
        final json = Map<String, dynamic>.from(details);
        if (json['error'] == 'device_limit_reached') {
          _lastDeviceLimitError = DeviceLimitReachedError.fromJson(json);
          notifyListeners();
          return;
        }
      }
      debugPrint('Failed to refresh entitlements: $error');
      debugPrintStack(stackTrace: stackTrace);
    } catch (error, stackTrace) {
      debugPrint('Failed to refresh entitlements: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  _EntitlementsPayload _extractPayload(dynamic payload) {
    if (payload is List) {
      return _EntitlementsPayload(
        entitlements: payload,
        isRegisteredDevice: false,
      );
    }
    if (payload is Map && payload['entitlements'] is List) {
      return _EntitlementsPayload(
        entitlements: payload['entitlements'] as List<dynamic>,
        isRegisteredDevice: payload['is_registered_device'] == true,
      );
    }
    throw StateError('Unexpected entitlements response: $payload');
  }

  Future<void> _persistCache() async {
    await _prefs?.setString(
      _cacheEntitlementsKey,
      jsonEncode(_entitlements.map((e) => e.toJson()).toList(growable: false)),
    );
    await _prefs?.setString(
      _cacheLastFetchedAtKey,
      _lastFetchedAt?.toIso8601String() ?? '',
    );
    await _prefs?.setBool(
      _cacheRegisteredDeviceKey,
      _isRegisteredDevice,
    );
  }

  void _restoreCacheFromPrefs() {
    final rawLastFetchedAt = _prefs?.getString(_cacheLastFetchedAtKey);
    _lastFetchedAt = DateTime.tryParse(rawLastFetchedAt ?? '');
    _isRegisteredDevice = _prefs?.getBool(_cacheRegisteredDeviceKey) ?? false;

    final rawEntitlements = _prefs?.getString(_cacheEntitlementsKey);
    if (rawEntitlements == null || rawEntitlements.isEmpty) {
      _entitlements = const [];
      return;
    }

    try {
      final decoded = jsonDecode(rawEntitlements);
      if (decoded is! List) {
        _entitlements = const [];
        return;
      }
      _entitlements = decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .map(Entitlement.fromJson)
          .toList(growable: false);
    } catch (error, stackTrace) {
      debugPrint('Failed to restore entitlement cache: $error');
      debugPrintStack(stackTrace: stackTrace);
      _entitlements = const [];
    }
  }
}

class _EntitlementsPayload {
  final List<dynamic> entitlements;
  final bool isRegisteredDevice;

  const _EntitlementsPayload({
    required this.entitlements,
    required this.isRegisteredDevice,
  });
}
