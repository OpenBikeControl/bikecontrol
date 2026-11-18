import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:bike_control/bluetooth/devices/elite/elite_rizer.dart';
import 'package:bike_control/bluetooth/devices/wahoo/wahoo_kickr_headwind.dart';
import 'package:bike_control/bluetooth/incline/manual_incline_device.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/controller/headwind_section.dart';
import 'package:bike_control/widgets/controller/incline_section.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:bike_control/widgets/ui/bk_status_dot.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// What an accessory reports, live: the values its row on Devices shows.
Listenable accessoryReadoutListenable(BluetoothDevice device) => Listenable.merge([
  if (device is ManualInclineDevice) ...[device.inclineApplied, device.inclineReported],
  if (device is EliteRizer) device.steeringAngle,
  if (device is WahooKickrHeadwind) ...[device.mode, device.speed, device.followsPower],
]);

/// "← 12°" (left), "12° →" (right) or "0°" for a gauge angle, where positive
/// steers left.
String formatSteeringAngle(double gaugeAngle) {
  final degrees = gaugeAngle.round();
  if (degrees == 0) return '0°';
  return degrees > 0 ? '← $degrees°' : '${-degrees}° →';
}

/// "Incline 4.5% · Steering 12° →" for a Rizer, "Fan 50%" for a Headwind; null
/// while the accessory is not connected or has nothing to report yet.
String? accessoryReadout(BuildContext context, BluetoothDevice device) {
  if (!device.isConnected) return null;
  final l = context.i18n;
  final parts = <String>[
    if (device is ManualInclineDevice && device.inclineShown != null)
      l.inclineRideReadout(formatIncline001(device.inclineShown)),
    if (device is EliteRizer) l.accessorySteeringReadout(formatSteeringAngle(device.steeringAngle.value)),
    if (device is WahooKickrHeadwind && (device.mode.value != HeadwindMode.unknown || device.followsPower.value))
      l.accessoryFanReadout(
        headwindStateText(context, device.mode.value, device.speed.value, followsPower: device.followsPower.value),
      ),
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// An accessory's row among the controllers on Devices: its name, its live
/// values, its status, and its page on tap.
class AccessoryRow extends StatelessWidget {
  const AccessoryRow({super.key, required this.device, required this.leading, required this.onPressed});

  final BluetoothDevice device;
  final Widget leading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l = context.i18n;
    return ListenableBuilder(
      listenable: accessoryReadoutListenable(device),
      builder: (context, _) => BkGroupedRow(
        leading: leading,
        title: device.displayName(context),
        subtitle: accessoryReadout(context, device),
        trailing: BkStatusDot(
          label: device.isConnected ? l.connected : l.notConnected,
          tone: device.isConnected ? BkStatusTone.success : BkStatusTone.neutral,
        ),
        chevron: true,
        onPressed: onPressed,
      ),
    );
  }
}
