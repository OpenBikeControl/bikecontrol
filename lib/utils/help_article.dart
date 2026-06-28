import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/cycplus/cycplus_bc2.dart';
import 'package:bike_control/bluetooth/devices/elite/elite_square.dart';
import 'package:bike_control/bluetooth/devices/elite/elite_sterzo.dart';
import 'package:bike_control/bluetooth/devices/gamepad/gamepad_device.dart';
import 'package:bike_control/bluetooth/devices/hid/hid_device.dart';
import 'package:bike_control/bluetooth/devices/shimano/shimano_di2.dart';
import 'package:bike_control/bluetooth/devices/sram/sram_axs.dart';
import 'package:bike_control/bluetooth/devices/thinkrider/thinkrider_vs200.dart';
import 'package:bike_control/bluetooth/devices/wahoo/wahoo_kickr_bike_shift.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_click.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_play.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:flutter/widgets.dart';

/// A link to a bikecontrol.app how-to article for a controller + trainer app.
class HelpArticle {
  const HelpArticle({required this.url, required this.label});
  final String url;
  final String label;
}

/// The how-to-connect article for [controller] + the active trainer [app], or
/// null when [controller] is null or has no dedicated page (so callers can hide
/// the entry). The trainer app falls back to the generic "other-training-app"
/// page when [app] is null or has no page of its own.
HelpArticle? helpArticleFor(
  BuildContext context, {
  required BaseDevice? controller,
  required SupportedApp? app,
}) {
  if (controller == null) return null;
  final ctrl = _controllerArticle(controller);
  if (ctrl == null) return null;
  final appSlug = app?.helpSlug ?? 'other-training-app';
  final appName = app?.name ?? 'your trainer app';
  return HelpArticle(
    url: 'https://bikecontrol.app/use-${ctrl.slug}-with-$appSlug/',
    label: AppLocalizations.of(context).useControllerWithApp(ctrl.name, appName),
  );
}

/// Maps a controller device to its bikecontrol.app slug + display name, or null
/// for device types without a dedicated page (e.g. gyroscope steering, a smart
/// trainer proxy). `ZwiftClickV2 extends ZwiftRide` — keep the V2 check first.
({String slug, String name})? _controllerArticle(BaseDevice device) {
  if (device is ZwiftClickV2) return (slug: 'zwift-click-v2', name: 'Zwift Click V2');
  if (device is ZwiftClick) return (slug: 'zwift-click', name: 'Zwift Click');
  if (device is ZwiftPlay) return (slug: 'zwift-play', name: 'Zwift Play');
  if (device is ZwiftRide) return (slug: 'zwift-ride', name: 'Zwift Ride');
  if (device is ShimanoDi2) return (slug: 'shimano-di2', name: 'Shimano Di2');
  if (device is SramAxs) return (slug: 'sram-axs-etap', name: 'SRAM AXS');
  if (device is WahooKickrBikeShift) return (slug: 'wahoo-kickr-bike-shift', name: 'Wahoo KICKR Bike Shift');
  if (device is CycplusBc2) return (slug: 'cycplus-bc2-virtual-shifter', name: 'CYCPLUS BC2');
  if (device is EliteSquare) return (slug: 'elite-square-smart-frame', name: 'Elite Square');
  if (device is EliteSterzo) return (slug: 'elite-sterzo-smart', name: 'Elite Sterzo');
  if (device is ThinkRiderVs200) return (slug: 'thinkrider-vs200', name: 'ThinkRider VS200');
  if (device is GamepadDevice) return (slug: 'gamepads', name: 'Gamepad');
  if (device is HidDevice) return (slug: 'keyboard-input', name: 'Keyboard');
  return null;
}
