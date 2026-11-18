import 'package:bike_control/bluetooth/incline/manual_incline_device.dart';
import 'package:bike_control/main.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/utils/wahoo_climb.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' show LucideIcons;
import 'package:universal_ble/universal_ble.dart';

import '../bluetooth_device.dart';

/// Wahoo KICKR Climb — a beta accessory driven by the active bridge's sim grade
/// (auto) or by manual incline actions (manual hold). Direct-to-Climb BLE sink.
class WahooKickrClimb extends BluetoothDevice with Accessory, ManualInclineDevice {
  WahooKickrClimb(super.scanResult)
    : super(availableButtons: const [], icon: LucideIcons.mountain, isBeta: true);

  /// Test seam: overridable to capture writes without real BLE.
  @visibleForTesting
  Future<void> Function(Uint8List bytes)? debugWriteSink;

  @override
  Future<void> handleServices(List<BleService> services) async {
    for (final s in services) {
      debugPrint('[Climb] service ${s.uuid} chars=${s.characteristics.map((c) => c.uuid).toList()}');
    }
    final service = services.firstOrNullWhere((e) => e.uuid == wahooClimbServiceUuid);
    if (service == null) {
      debugPrint('[Climb] proprietary service $wahooClimbServiceUuid not found — incompatible device');
      return;
    }
    final ch = service.characteristics.firstOrNullWhere((e) => e.uuid == wahooClimbCharacteristicUuid);
    if (ch == null) {
      debugPrint('[Climb] characteristic $wahooClimbCharacteristicUuid not found — incompatible device');
      return;
    }
    try {
      await UniversalBle.subscribeNotifications(device.deviceId, service.uuid, ch.uuid);
      await _write(Uint8List.fromList([wahooClimbGetTiltModeOpcode]));
    } catch (e, s) {
      recordError(e, s, context: 'WahooKickrClimb: request-control failed');
    }
  }

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) async {
    debugPrint('[Climb] notify $characteristic: $bytes');
  }

  @override
  Future<bool> writeInclineToDevice(int grade001Pct) async {
    try {
      await _write(wahooClimbInclineToBytes(grade001Pct));
      return true;
    } catch (e, s) {
      recordError(e, s, context: 'WahooKickrClimb: writeIncline failed');
      return false;
    }
  }

  Future<void> _write(Uint8List bytes) async {
    if (debugWriteSink != null) {
      await debugWriteSink!(bytes);
      return;
    }
    await UniversalBle.write(
      device.deviceId, wahooClimbServiceUuid, wahooClimbCharacteristicUuid, bytes,
      withoutResponse: true,
    );
  }
}
