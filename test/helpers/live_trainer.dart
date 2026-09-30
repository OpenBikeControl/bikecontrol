import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/emulators/transporter/network_transporter.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

/// A bridged smart trainer in a virtual shifting session — 250 W at 90 rpm in
/// gear 12 of 24 — registered with the connection so `chainProxy()` finds it.
/// Detached again when the test ends.
({ProxyDevice proxy, FitnessBikeDefinition definition}) attachLiveTrainer({
  String id = 'live-kickr',
  String name = 'KICKR CORE',
  bool register = true,
}) {
  final proxy =
      ProxyDevice(
          BleDevice(name: name, deviceId: id, services: [FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID]),
        )
        ..services = [BleService(FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID, [])]
        ..isConnected = true;
  final definition = FitnessBikeDefinition(
    connectedDevice: proxy.scanResult,
    connectedDeviceServices: proxy.services!,
    data: ValueNotifier(''),
  )..setDebugValues();
  proxy.emulator.debugSetTransporter(NetworkTransporter(definition: definition));
  proxy.debugSetTrainerAppConnected(true);
  proxy.debugAttachFitnessBike(definition);
  if (register) core.connection.devices.add(proxy);
  addTearDown(() {
    proxy.debugAttachFitnessBike(null);
    proxy.debugSetTrainerAppConnected(false);
    core.connection.devices.remove(proxy);
  });
  return (proxy: proxy, definition: definition);
}
