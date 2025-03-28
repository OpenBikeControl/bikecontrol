## 0.18.0
* Improve docs for isPaired

## 0.17.0
* Fix Windows crash when calling pair APIs with an unknown deviceId
* Fix Windows crash when calling startScan again after some time
* Fix Windows warning `Unable to establish connection on channel` when hot restarting
* Refactor native Windows code
* Improve Android permission documentation

## 0.16.0
* BREAKING CHANGE: `payload` is now `payloadPrefix`
* BREAKING CHANGE: `mask` is now `payloadMask`
* Bump bluez to 0.8.3
* Do not normalize UUIDs on native side
* Reverse _permissionStatus return values in example app
* Improve readme
* Improve ManufacturerDataFilter

## 0.15.0
* `getSystemDevices(withServices:)` now sets several generic services by default as filter
* `getConnectionState` on Android will now return `BleConnectionState.disconnected` if device is connected to the system but not to the app
* Improve callback error handling

## 0.14.0
* BREAKING CHANGE: `bleDevice.name` now filters out non-printable characters
* Add `bleDevice.rawName`
* Add `disableBluetooth` API
* Fix Apple CBCentralManager lazy initialization on `startScan`
* Fix Android error `scan too frequently` and auto retry scan once sufficient time has passed
* Fix duplicate `onValueChanged` events on Android 11 or earlier
* Fix Windows `withServices` filter
* Fix Windows Bluetooth availability state in release builds
* Throw error on Apple if Bluetooth permission is denied on `startScan`
* Do not throw `Characteristic already notifying` error. Subscribing to characteristic notifications multiple times is now handled safely
* Bump flutter_web_bluetooth to 1.0.0

## 0.13.0
* BREAKING CHANGE: `scanFilter` filters are now in OR relation 
* BREAKING CHANGE: `manufacturerDataHead` is removed from `BleDevice`
* BREAKING CHANGE: `WebConfig` is now `WebOptions`
* BREAKING CHANGE: `ManufacturerDataFilter.data` is now `ManufacturerDataFilter.payload`
* BREAKING CHANGE: `connect()` does not return a boolean anymore. It will throw error on connection failure
* BREAKING CHANGE: `pair()` does not return a boolean anymore. It will throw error on connection failure
* BREAKING CHANGE: `onConnectionChange` returns error as well
* BREAKING CHANGE: rename in-app pairing capabilities
* Deprecation: `manufacturerData` is deprecated in BleDevice and will be removed in the future
* Improve `scanFilter` handling
* Use `ManufacturerData` object instead of `Uint8List` for manufacturerData
* Add `manufacturerDataList` as `List<ManufacturerData>` in `BleDevice`
* Auto convert all services passed to `getSystemDevices()`
* Return false for receivesAdvertisements on Linux/Web
* Add 1s delay in discoverServices on Linux
* Add `connectionStream` API to get connection updates as stream

## 0.12.0
* BREAKING CHANGE: `unPair` is now `unpair`
* BREAKING CHANGE: `onPairingStateChange` does not return error anymore
* Add `pair()`, `isPaired` and `onPairingStateChange` support for Apple and web
* `connect()` and `pair()` now return a bool result
* Add `PlatformConfig` property in `StartScan`
* Add `WebConfig` property in `PlatformConfig`
* Fix notifications for characteristics without cccd on Android
* Promote Linux to stable

## 0.11.1
* Trim spaces in UUIDs
* Receive advertisement events on web
* Improve cleanup after disconnection on web

## 0.11.0
* Unify UUID format across all platforms, 128-bit lowercase
* Add BleUuidParser utility methods for UUID parsing

## 0.10.1
* Improve Android error handling
* Fix Android disconnection events sometimes missed
* Improve cleanup after disconnection on Apple and Android
* Support pairing on Apple
* Improve code level documentation

## 0.10.0
* BREAKING CHANGE: `ScanResult` is now `BleDevice`
* BREAKING CHANGE: `getConnectedDevices` is now `getSystemDevices`
* BREAKING CHANGE: `isPaired` is now nullable
* BREAKING CHANGE: `onValueChanged` is now `onValueChange`
* BREAKING CHANGE: `onConnectionChanged` is now `onConnectionChange`
* Add `connectionState` property to BleDevice
* Add `isSystemDevice` property to BleDevice
* Add `.perDevice` queue
* Support "ProvidePin" pairing on Windows 10/11
* Get RRSI updates on Apple platforms
* Improve enum parsing performance
* Improve code level documentation

## 0.9.11
* Add device name prefix filtering

## 0.9.10
* Fix Windows scan filter
* Remove scan result caching on Windows
* Improve service discovery on Linux
* Use asynchronous callbacks for SetNotifiable
* Remove dependency on `convert`
* Remove dependency on `collection`
* Update Android example app Gradle

## 0.9.9
* Improve service discovery on Apple
* Improve reconnection on Apple
* Persist long scan result name on Windows
* Fix Android serviceUuids in scanResults
* Example app improvements

## 0.9.8
* Improve manufacturer data discovery on Windows
* Example app improvements

## 0.9.7
* Fix characteristic keying on linux allowing receiving data from multiple BLE devices at the same time

## 0.9.6
* Fix a Windows issue where characteristics of certain services would not be discovered
* Improve readme

## 0.9.5
* Windows support has graduated from beta to stable
* Support filtering by manufacturer data
* Unify web's optionalServices API with filtering API
* Implement requestMtu in Linux 
* Fix wrong manufacturer data in Windows release builds
* Improve logging

## 0.9.4
* Fix Windows crash when no Bluetooth adapter is present

## 0.9.3
* Add scan filter (withServices:) in `startScan()`
* Add service UUIDs from advertisements in `BleScanResult`
* Fix Windows release build compilation

## 0.9.2
* Add command queue
* Improve error handling on Android, iOS, macOS, Windows, Linux and web

## 0.9.1
* Improve logging

## 0.9.0
* Improve windows device name discovery
* Improve linux implementation
* Improve titles in example app

## 0.8.4
* Add `WebRequestOptionsBuilder.defaultServices` for convenience when setting `optionalServices` when scanning on web
* Add "try online" URL in readme
* Improve readme
* Improve example app

## 0.8.3
* Rename onPairStateChange *> onPairingStateChange
* Improve readme

## 0.8.2
* Improve readme

## 0.8.1
* Update supported platforms

## 0.8.0
* Initial release
