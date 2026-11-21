//INFO: This is a stub - contact me if you need the full implementation.
//
// The full implementation routes the phone's one BLE peripheral between the
// roles that share it (the trainer bridge and the app's own peripherals). This
// stub keeps the static surface so the app compiles; nothing is routed.

import 'package:universal_ble/universal_ble.dart';

class SharedPeripheral {
  SharedPeripheral._();

  static void setReadHandler(String characteristicId, OnPeripheralReadRequest handler) {}

  static void setWriteHandler(String characteristicId, OnPeripheralWriteRequest handler) {}

  static void removeReadHandler(String characteristicId, OnPeripheralReadRequest handler) {}

  static void removeWriteHandler(String characteristicId, OnPeripheralWriteRequest handler) {}

  static void protectServices(Iterable<String> serviceUuids) {}

  static void unprotectServices(Iterable<String> serviceUuids) {}

  static bool isProtected(String serviceUuid) => false;

  static Future<void> clearUnprotectedServices() async {}

  static String normalize(String uuid) => uuid.toLowerCase();

  static void setAdvertisedServices(
    String role,
    Iterable<String> serviceUuids, {
    Future<void> Function()? readvertise,
  }) {}

  static void removeAdvertisedServices(String role) {}

  static bool othersAdvertise(String role) => false;

  static List<String> advertisedServices(String role, Iterable<String> own) => own.toList();

  static int advertisedServicesCost(List<String> services) => 0;

  static List<String> fitPacket(List<String> services) => services;

  static Future<void> readvertiseOthers(String role) async {}
}
