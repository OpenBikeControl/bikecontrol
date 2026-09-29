import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Stands another operating system in for the one the app runs on, for the
/// gates that go through [HostPlatform]. For the feature-video capture, which
/// films the Android build's options on a desktop test host. Off everywhere
/// else: while null, [HostPlatform] is dart:io's [Platform].
@visibleForTesting
TargetPlatform? debugHostPlatformOverride;

/// The operating system BikeControl runs on, as the feature gates that read it
/// see it — dart:io's [Platform] (false on the web), unless a test stages
/// another one with [debugHostPlatformOverride].
abstract final class HostPlatform {
  static bool get isAndroid => _is(TargetPlatform.android, () => Platform.isAndroid);

  static bool get isIOS => _is(TargetPlatform.iOS, () => Platform.isIOS);

  static bool get isMacOS => _is(TargetPlatform.macOS, () => Platform.isMacOS);

  static bool get isWindows => _is(TargetPlatform.windows, () => Platform.isWindows);

  static bool _is(TargetPlatform platform, bool Function() host) {
    final override = debugHostPlatformOverride;
    if (override != null) return override == platform;
    return !kIsWeb && host();
  }
}
