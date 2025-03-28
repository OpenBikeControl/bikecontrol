import 'package:flutter/foundation.dart';

class BleCapabilities {
  /// Returns true if in-app pairing is possible either by API or by encrypted characteristic
  /// using any kind of pairing method (Just Works, Numeric Comparison or Passkey Entry).
  ///
  /// All platforms return true except Web/Windows and Web/Linux which return false
  /// because they only support "Numeric Comparison" and "Passkey Entry".
  ///
  /// For more fine-grained control it is recommended to use `triggersConfirmOnlyPairing`
  /// in conjunction with the pairing method of your peripheral,
  /// e.g. if (!BleCapabilities.triggersConfirmOnlyPairing && peripheralUsesConfirmOnlyPairing) throw "In-app pairing not supported";
  static final bool supportsAllPairingKinds =
      triggersConfirmOnlyPairing || hasSystemPairingApi;

  /// Returns true if the platform triggers pairing for devices that use only confirmation pairing
  /// (a.k.a. "Just Works" or legacy pairing) when trying to read or write to an encrypted characteristic.
  ///
  /// The "Numeric Comparison" and "Passkey Entry" pairing methods trigger pairing on all platforms.
  ///
  /// `Web/Linux` could also, under certain conditions, trigger "Just Works" pairing
  /// but it very unreliable, therefore we return false.
  static final triggersConfirmOnlyPairing =
      defaultTargetPlatform != TargetPlatform.windows &&
          defaultTargetPlatform != TargetPlatform.linux;

  /// Returns true if pair()/unpair() are supported on the platform.
  static bool hasSystemPairingApi = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

  static bool requiresRuntimePermission =
      !_Platform.isWeb && !_Platform.isWindows && !_Platform.isLinux;

  static bool supportsBluetoothEnableApi =
      !_Platform.isWeb && !_Platform.isCupertino;

  static bool supportsConnectedDevicesApi = !_Platform.isWeb;

  static bool supportsRequestMtuApi = !_Platform.isWeb;
}

class _Platform {
  static bool isWeb = kIsWeb;
  static bool isIOS = !isWeb && defaultTargetPlatform == TargetPlatform.iOS;
  static bool isMacos = !isWeb && defaultTargetPlatform == TargetPlatform.macOS;
  static bool isWindows =
      !isWeb && defaultTargetPlatform == TargetPlatform.windows;
  static bool isLinux = !isWeb && defaultTargetPlatform == TargetPlatform.linux;
  static bool get isCupertino => isIOS || isMacos;
}
