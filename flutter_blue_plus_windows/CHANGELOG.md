## 1.26.1
* Add setOptions.

## 1.26.0
* Set `flutter_blue_plus` upperbound <1.35.0 (due to api changes)

## 1.25.0
* Ensure tracing connection when reconnection occurs after force disconnection.   

## 1.24.22
* Upgrade FBP version to `>=1.32.4 <=1.40.0` #24.

## 1.24.21
* fix: startScan() doesn't return correct ScanResult #25

## 1.24.20
* Downgrade FBP version to `>=1.32.4 <=1.33.6` due to the breaking changes.
* After upgrade process, the dependencies will be returned to `>=1.34.4 <1.40.0` #24.  

## 1.24.19
* Fix a bug with `onValueReceived` of emitting write packet #22.

## 1.24.18
* Add implementation of `BluetoothDeviceWindow.fromId()` #21.

## 1.24.15
* Fix a bug w.r.t. company ID in manufacturer data. (@betto-a #18)

## 1.24.14
* Implement cancelOnDisconnect (@jefflongo  #16)

## 1.24.12
* Fix minor bug w.r.t. `characteristic.isNotifying`.

## 1.24.11
* Fix breaking changes of FBP w.r.t. `systemDevices(List withServices)`.

## 1.24.10
* Add support for `cancelWhenScanComplete`

## 1.24.9
* Implement scan filter (including `withServices`, `withRemoteIds`, `withNames`).  

## 1.24.8
* Keep manufacturer data when scanning.

## 1.24.7
* Keep service uuids when scanning.

## 1.24.0
* Update `README.md`.

## 1.23.6
* Add unimplemented notification for `read` or `write`.   

## 1.14.0
* Remove dependencies `ffi` and `win32` to avoid compile error for web 

## 1.9.5
* Apply `flutter blue plus` to `1.28.13`.

## 1.9.0
* Apply a breaking changes `Guid` in `Flutter blue plus` packages.
* Use `uuid128` instead of `toString()`.

## 1.8.10
* Fix `Guid` bug related with `Flutter blue plus` packages.

## 1.8.0
* Fix bug with Guid converted from string due to starting/ending with '{ }' in `WinBLE`

## 1.7.0
* Apply `flutter blue plus 1.28.5` (there is several breaking changes.).

## 1.6.6
* Add cache for storing characteristics.

## 1.6.0
* Apply `Flutter blue plus 1.26.0`, (there is a breaking change with `connect()`).

## 1.5.7
* Remove connection by OS when performing `startScan`.

## 1.5.3
* Write logs when connection state stream is started/terminated. 

## 1.5.2
* Fix a bug of features added in `1.5.1` 

## 1.5.1
* Remove device from connected device list when device is disconnected.

## 1.5.0
* Split functionality of `disconnect` / `removeBond`.

## 1.4.0
* Implement `Subscribe/Unsubscribe Characteristic`.

## 1.1.0
* Implement `Read/Write Characteristic`.

## 1.0.5
* Change `rxdart` version to `0.27.7`.

## 1.0.0
* Initial release (using Github action).