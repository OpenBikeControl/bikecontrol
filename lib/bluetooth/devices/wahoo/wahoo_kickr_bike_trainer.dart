import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/devices/wahoo/wahoo_kickr_bike_shift.dart';
import 'package:bike_control/utils/core.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:universal_ble/universal_ble.dart';

/// The smart-trainer half of a KICKR BIKE.
///
/// A KICKR BIKE is one Bluetooth peripheral that is both a smart trainer and
/// the host of its own shifters. One peripheral maps to one device class, and
/// the bike is classified by name as [WahooKickrBikeShift] (the controller)
/// so its buttons keep working. When that controller's service discovery
/// finds a trainer service, it attaches this trainer role next to itself, so
/// the same bike is also listed, bridged and controlled like any other
/// [ProxyDevice].
///
/// The controller owns the Bluetooth link: it connects as soon as the bike is
/// found, while a trainer is only bridged once the rider asked for it. This
/// role therefore never opens or closes the link itself — it rides on the
/// controller's connection ([connectUpstream] / [disconnectUpstream]), and
/// the controller tears it down whenever its own connection goes away (see
/// [WahooKickrBikeShift.disconnect]), so a dropped bike never leaves a
/// trainer entry behind that still looks alive.
class WahooKickrBikeTrainer extends ProxyDevice {
  WahooKickrBikeTrainer._(super.scanResult, {required this.host, required List<BleService> trainerServices})
    : _trainerServices = trainerServices;

  /// The controller that owns the Bluetooth link to the bike.
  final WahooKickrBikeShift host;

  /// The bike's GATT database as discovered by [host], minus the shifter
  /// service — that one belongs to the controller role, and mirroring it
  /// through a Proxy bridge would hand the trainer app a second copy of the
  /// buttons BikeControl is already acting on.
  final List<BleService> _trainerServices;

  /// The services that make a peripheral a trainer BikeControl can drive:
  /// FTMS, FE-C over BLE, or Cycling Power (Proxy only, like any power-only
  /// trainer). Heart rate is deliberately not one of them — a bike relaying a
  /// strap is not a trainer because of it.
  static final _trainerServiceUuids = {
    FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID.toLowerCase(),
    FitnessBikeDefinition.FEC_BLE_SERVICE_UUID.toLowerCase(),
    FitnessBikeDefinition.CYCLING_POWER_SERVICE_UUID.toLowerCase(),
  };

  /// Builds the trainer role for [host] from the services its discovery
  /// returned, or null when the bike exposes no trainer service — then it
  /// stays a controller only, exactly as before.
  ///
  /// The scan advertisement is not trusted for this: whether the bike lists
  /// its trainer services there is unknown, so the role's own scan result
  /// carries the trainer services actually discovered. That is what
  /// [isSmartTrainer] (and with it the default bridge mode) reads.
  static WahooKickrBikeTrainer? forHost(WahooKickrBikeShift host, List<BleService> discovered) {
    final found = discovered.map((s) => s.uuid.toLowerCase()).where(_trainerServiceUuids.contains).toSet();
    if (found.isEmpty) return null;

    final ad = host.scanResult;
    final scanResult = BleDevice(
      deviceId: ad.deviceId,
      name: ad.rawName ?? ad.name,
      rssi: ad.rssi,
      paired: ad.paired,
      services: {...ad.services.map((s) => s.toLowerCase()), ...found}.toList(),
      isSystemDevice: ad.isSystemDevice,
      manufacturerDataList: ad.manufacturerDataList,
      serviceData: ad.serviceData,
    );
    return WahooKickrBikeTrainer._(
      scanResult,
      host: host,
      trainerServices: discovered
          .where((s) => s.uuid.toLowerCase() != WahooKickrBikeShiftConstants.SERVICE_UUID.toLowerCase())
          .toList(),
    );
  }

  @override
  Future<void> connectUpstream() async {
    // Never a second connect to the same peripheral: the controller already
    // holds the link. Without it there is nothing to ride on — fail like a
    // real connect would, rather than report a trainer that is not there.
    if (!host.isConnected) {
      throw StateError('$this: the Bluetooth connection to the bike is not up');
    }
    // The link was up before this role existed, so no connection-state event
    // will ever arrive to flip this flag — set it here, like a WiFi trainer.
    isConnected = true;
    core.connection.signalChange(this);
  }

  /// The controller's discovery already ran on this exact link; a copy, since
  /// [disconnect] clears the list it was handed.
  @override
  Future<List<BleService>> discoverUpstreamServices() async => _trainerServices.toList();

  /// Stopping the bridge must not cut the controller's link — the buttons
  /// keep working after "No connection". The link goes down with the
  /// controller, which then releases this role.
  @override
  Future<void> disconnectUpstream() async {}

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) {
    // Notifications are routed by device id, and both roles share one. Hand
    // shifter frames to the controller whichever role received them.
    if (characteristic.toLowerCase() == WahooKickrBikeShiftConstants.CHARACTERISTIC_UUID.toLowerCase()) {
      return host.processCharacteristic(characteristic, bytes);
    }
    return super.processCharacteristic(characteristic, bytes);
  }
}
