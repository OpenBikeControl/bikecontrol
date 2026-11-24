import 'package:universal_ble/universal_ble.dart';

/// Platform options for every BLE central connect BikeControl makes.
///
/// iOS/macOS: ask CoreBluetooth to wake a suspended app for connection,
/// disconnection and notification events, so controllers and trainers keep
/// working while BikeControl is in the background behind the trainer app.
/// Ignored on the other platforms.
///
/// A fresh instance per call: the pigeon config classes are mutable.
ConnectionPlatformConfig bleConnectionPlatformConfig() => ConnectionPlatformConfig(
  apple: AppleConnectionOptions(
    notifyOnConnection: true,
    notifyOnDisconnection: true,
    notifyOnNotification: true,
  ),
);
