[![pub package](https://img.shields.io/pub/v/flutter_blue_plus_windows.svg)](https://pub.dartlang.org/packages/flutter_blue_plus_windows)

## Flutter Blue Plus Windows

This project is a wrapper library for `Flutter Blue Plus` and `Win_ble`.
It allows `Flutter_blue_plus` to operate on Windows.

With minimal effort, you can use Flutter Blue Plus on Windows.

## Usage
Only you need to do is change the import statement.

```dart
// instead of import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_blue_plus_windows/flutter_blue_plus_windows.dart';

// Alternatively, you can hide FlutterBluePlus when importing the FBP statement
import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide FlutterBluePlus;
import 'package:flutter_blue_plus_windows/flutter_blue_plus_windows.dart';

```

### Scan devices
```dart
final scannedDevices = <ScanResult>{};

const timeout = Duration(seconds: 3);
FlutterBluePlus.startScan(timeout: timeout);

final sub = FlutterBluePlus.scanResults.expand((e)=>e).listen(scannedDevices.add);

await Future.delayed(timeout);
sub.cancel();
scannedDevices.forEach(print);
```

### Connect a device
```dart
final scannedDevice = scannedDevices
    .where((scanResult) => scanResult.device.platformName == DEVICE_NAME)
    .firstOrNull;
final device = scannedDevice?.device;
device?.connect();
```

### Disconnect the device
```dart
device?.disconnect();
```

Check out the usage of Flutter Blue Plus on [Flutter Blue Plus](https://pub.dev/packages/flutter_blue_plus)



