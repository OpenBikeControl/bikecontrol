import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as FBP;
import 'package:flutter_blue_plus_windows/flutter_blue_plus_windows.dart';

class FlutterBluePlus {
  static Future<void> startScan({
    List<Guid> withServices = const [],
    List<String> withRemoteIds = const [],
    List<String> withNames = const [],
    List<String> withKeywords = const [],
    List<MsdFilter> withMsd = const [],
    List<ServiceDataFilter> withServiceData = const [],
    Duration? timeout,
    Duration? removeIfGone,
    bool continuousUpdates = false,
    int continuousDivisor = 1,
    bool oneByOne = false,
    bool androidLegacy = false,
    AndroidScanMode androidScanMode = AndroidScanMode.lowLatency,
    bool androidUsesFineLocation = false,
    List<Guid> webOptionalServices = const [],
  }) async {
    if (!kIsWeb && Platform.isWindows) {
      return await FlutterBluePlusWindows.startScan(
        withServices: withServices,
        withRemoteIds: withRemoteIds,
        withNames: withNames,
        withKeywords: withKeywords,
        withMsd: withMsd,
        withServiceData: withServiceData,
        timeout: timeout,
        removeIfGone: removeIfGone,
        continuousUpdates: continuousUpdates,
        continuousDivisor: continuousDivisor,
        oneByOne: oneByOne,
        androidLegacy: androidLegacy,
        androidScanMode: androidScanMode,
        androidUsesFineLocation: androidUsesFineLocation,
      );
    }

    return await FBP.FlutterBluePlus.startScan(
      withServices: withServices,
      withRemoteIds: withRemoteIds,
      withNames: withNames,
      withKeywords: withKeywords,
      withMsd: withMsd,
      withServiceData: withServiceData,
      timeout: timeout,
      removeIfGone: removeIfGone,
      continuousUpdates: continuousUpdates,
      continuousDivisor: continuousDivisor,
      oneByOne: oneByOne,
      androidLegacy: androidLegacy,
      androidScanMode: androidScanMode,
      androidUsesFineLocation: androidUsesFineLocation,
      webOptionalServices: webOptionalServices,
    );
  }

  static Stream<BluetoothAdapterState> get adapterState {
    if (!kIsWeb && Platform.isWindows) return FlutterBluePlusWindows.adapterState;
    return FBP.FlutterBluePlus.adapterState;
  }

  static Stream<List<ScanResult>> get scanResults {
    if (!kIsWeb && Platform.isWindows) return FlutterBluePlusWindows.scanResults;
    return FBP.FlutterBluePlus.scanResults;
  }

  static bool get isScanningNow {
    if (!kIsWeb && Platform.isWindows) return FlutterBluePlusWindows.isScanningNow;
    return FBP.FlutterBluePlus.isScanningNow;
  }

  static Stream<bool> get isScanning {
    if (!kIsWeb && Platform.isWindows) return FlutterBluePlusWindows.isScanning;
    return FBP.FlutterBluePlus.isScanning;
  }

  static Future<void> stopScan() async {
    if (!kIsWeb && Platform.isWindows) return await FlutterBluePlusWindows.stopScan();
    return await FBP.FlutterBluePlus.stopScan();
  }

  static Future<void> setLogLevel(LogLevel level, {color = true}) async {
    if (!kIsWeb && Platform.isWindows) return FlutterBluePlusWindows.setLogLevel(level, color: color);
    return FBP.FlutterBluePlus.setLogLevel(level, color: color);
  }

  /// TODO: need to verify
  static LogLevel get logLevel => FBP.FlutterBluePlus.logLevel;

  static Future<void> setOptions({bool restoreState = false, bool showPowerAlert = true}) async {
    if (!kIsWeb && Platform.isWindows) return;
    FBP.FlutterBluePlus.setOptions(restoreState: restoreState, showPowerAlert: showPowerAlert);
  }

  static Future<bool> get isSupported async {
    if (!kIsWeb && Platform.isWindows) return await FlutterBluePlusWindows.isSupported;
    return await FBP.FlutterBluePlus.isSupported;
  }

  static Future<String> get adapterName async {
    if (!kIsWeb && Platform.isWindows) return await FlutterBluePlusWindows.adapterName;
    return await FBP.FlutterBluePlus.adapterName;
  }

  static Future<void> turnOn({int timeout = 60}) async {
    if (!kIsWeb && Platform.isWindows) return await FlutterBluePlusWindows.turnOn(timeout: timeout);
    return await FBP.FlutterBluePlus.turnOn(timeout: timeout);
  }

  static List<FBP.BluetoothDevice> get connectedDevices {
    if (!kIsWeb && Platform.isWindows) return FlutterBluePlusWindows.connectedDevices;
    return FBP.FlutterBluePlus.connectedDevices;
  }

  static Future<List<FBP.BluetoothDevice>> systemDevices(List<Guid> withServices) async {
    //TODO: connected devices => system devices
    if (!kIsWeb && Platform.isWindows) return FlutterBluePlusWindows.connectedDevices;
    return await FBP.FlutterBluePlus.systemDevices(withServices);
  }

  static Future<PhySupport> getPhySupport() {
    return FBP.FlutterBluePlus.getPhySupport();
  }

  static Future<List<FBP.BluetoothDevice>> get bondedDevices async {
    if (!kIsWeb && Platform.isWindows) return FlutterBluePlusWindows.connectedDevices;
    return await FBP.FlutterBluePlus.bondedDevices;
  }

  static void cancelWhenScanComplete(StreamSubscription subscription) {
    if (!kIsWeb && Platform.isWindows) return FlutterBluePlusWindows.cancelWhenScanComplete(subscription);
    return FBP.FlutterBluePlus.cancelWhenScanComplete(subscription);
  }
}
