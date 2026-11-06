import 'package:dartx/dartx.dart';
import 'package:universal_ble/universal_ble.dart';

/// Whether [result] should be classified.
///
/// The first advertisement of a controller often carries only the Battery
/// Service. The local name, which is how an Onelap Key is recognised, can
/// arrive in a later packet with the same service list. Treating that packet
/// as a duplicate drops the controller before it can be named.
bool scanResultAddsIdentity(Iterable<BleDevice> seen, BleDevice result) {
  final prior = seen.where(
    (device) =>
        device.deviceId == result.deviceId &&
        device.services.contentEquals(result.services),
  );
  if (prior.isEmpty) return true;
  if (!_hasName(result.name)) return false;
  return prior.every((device) => !_hasName(device.name));
}

bool _hasName(String? name) {
  final trimmed = name?.trim();
  return trimmed != null && trimmed.isNotEmpty;
}
