import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Utilities for determining whether the app is running in a Windows Store/MSIX
/// packaged context.
///
/// Security note:
/// - Build-time secrets (e.g. --dart-define) are extractable from the binary.
/// - This check is meant to answer a platform truth: "Is this app packaged?"
/// - For real entitlement enforcement, rely on Store license APIs (and
///   optionally a backend), not on compile-time flags.
class WindowsStoreEnvironment {
  static const MethodChannel _channel = MethodChannel('bike_control/store_env');
  static bool? _isPackagedCache;

  /// Debug-only escape hatch to simulate Store packaged mode.
  ///
  /// This is intentionally *not* a security feature.
  static const bool _forcePackagedForDebug = bool.fromEnvironment('FORCE_STORE_PACKAGED', defaultValue: false);

  static Future<void> initialize() async {
    _isPackagedCache = await isPackaged();
  }

  static bool get isPackagedCached => _isPackagedCache ?? false;

  static bool get isOutsideStoreCached => !isPackagedCached;

  /// Returns true when running as an MSIX/Store packaged app.
  ///
  /// In debug/profile you may set `--dart-define=FORCE_STORE_PACKAGED=true`
  /// for local testing.
  static Future<bool> isPackaged() async {
    if (!kReleaseMode && _forcePackagedForDebug) return true;
    if (_isPackagedCache != null) return _isPackagedCache!;

    try {
      final result = await _channel.invokeMethod<bool>('isPackaged');
      _isPackagedCache = result ?? false;
      return _isPackagedCache!;
    } catch (_) {
      // If the platform implementation isn't present (e.g., non-Windows),
      // treat as unpackaged.
      _isPackagedCache = false;
      return false;
    }
  }
}
