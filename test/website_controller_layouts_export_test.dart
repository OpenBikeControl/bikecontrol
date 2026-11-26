@Tags(['screenshots'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/cycplus/cycplus_bc2.dart';
import 'package:bike_control/bluetooth/devices/elite/elite_rizer.dart';
import 'package:bike_control/bluetooth/devices/elite/elite_sterzo.dart';
import 'package:bike_control/bluetooth/devices/gyroscope/gyroscope_steering.dart';
import 'package:bike_control/bluetooth/devices/magene/onelap_key.dart';
import 'package:bike_control/bluetooth/devices/shimano/shimano_di2.dart';
import 'package:bike_control/bluetooth/devices/thinkrider/thinkrider_vs200.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_click.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2_left_side.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2_right_side.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_play.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/widgets/controller/controller_layout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import 'widget_snapshot.dart';

// Exports every controller layout the onboarding draws (ControllerCanvas in the
// gear step) for the website's interactive setup tutorial: the silhouette, its
// aspect ratio and transform, and each button's position, glyph and default action.
// The website renders the same picture in HTML so a press can light the right button.
//
//   flutter test --run-skipped --tags screenshots test/website_controller_layouts_export_test.dart
//
// Output: build/website_export/controller_layouts.json. Copy it to the website's
// src/data/tutorial/controllerLayouts.json and the SVGs it names to
// public/images/tutorial/contours/.

/// The Lucide glyphs controller buttons use, by the name the website looks up.
/// A button with a glyph that's missing here fails the export: add it.
final Map<IconData, String> _iconNames = {
  LucideIcons.plus: 'plus',
  LucideIcons.minus: 'minus',
  LucideIcons.chevronUp: 'chevron-up',
  LucideIcons.chevronDown: 'chevron-down',
  LucideIcons.chevronLeft: 'chevron-left',
  LucideIcons.chevronRight: 'chevron-right',
  LucideIcons.power: 'power',
  LucideIcons.zap: 'zap',
  LucideIcons.triangle: 'triangle',
  LucideIcons.circle: 'circle',
  LucideIcons.square: 'square',
  LucideIcons.grip: 'grip',
};

String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

Map<String, Object?> _export(String id, ControllerLayout layout, List<ControllerButton> buttons) {
  Offset? positionOf(ControllerButton b) {
    for (final e in layout.positions.entries) {
      if (e.key.name == b.name) return e.value;
    }
    return null;
  }

  final placed = <Map<String, Object?>>[];
  for (final b in buttons) {
    final pos = positionOf(b);
    if (pos == null) continue; // ControllerCanvas skips a button without a position too.
    final icon = b.icon;
    if (icon != null && !_iconNames.containsKey(icon)) {
      fail('$id: button ${b.name} uses an icon (codePoint ${icon.codePoint}) the exporter has no name for.');
    }
    placed.add({
      'name': b.name,
      // LastPressStrip shows plainName.
      'plainName': b.plainName,
      'x': pos.dx,
      'y': pos.dy,
      if (icon != null) 'icon': _iconNames[icon],
      // ButtonWidget: no icon → shortLabel (label ?? initials).
      if (icon == null) 'label': b.shortLabel,
      // ButtonWidget: no colour → the theme's muted fill.
      if (b.color != null) 'color': _hex(b.color!),
      if (b.action != null) 'action': b.action!.englishTitle,
    });
  }
  return {
    'id': id,
    'aspectRatio': layout.aspectRatio,
    'shape': layout.shape.name,
    'padding': layout.padding,
    if (layout.svgAsset != null) 'svg': layout.svgAsset!.split('/').last,
    'rotation': layout.rotation,
    'mirrorX': layout.mirrorX,
    'svgAlignment': {'x': layout.svgAlignment.x, 'y': layout.svgAlignment.y},
    'buttons': placed,
  };
}

Map<String, Object?> _device(String id, BaseDevice device) =>
    _export(id, device.controllerLayout!, device.availableButtons);

BleDevice _ble(String name) => BleDevice(deviceId: 'export-$name', name: name);

Future<void> main() async {
  await ensureSnapshotHarness();

  test('export controller layouts for the website', () async {
    final layouts = [
      _device('zwift-click', ZwiftClick(_ble('Zwift Click'))),
      _device('zwift-click-v2', ZwiftClickV2(_ble('Zwift Click'))),
      _device('zwift-click-v2-left', ZwiftClickV2LeftSide(_ble('Zwift Click'))),
      _device('zwift-click-v2-right', ZwiftClickV2RightSide(_ble('Zwift Click'))),
      _device('zwift-ride', ZwiftRide(_ble('Zwift Ride'))),
      _device('zwift-play-left', ZwiftPlay(_ble('Zwift Play'), deviceType: ZwiftDeviceType.playLeft)),
      _device('zwift-play-right', ZwiftPlay(_ble('Zwift Play'), deviceType: ZwiftDeviceType.playRight)),
      // The Di2 card draws its buttons in button mode only (ShimanoDi2.controllerLayout).
      _export('shimano-di2', ShimanoDi2Buttons.layout, ShimanoDi2Buttons.values),
      _device('thinkrider-vs200', ThinkRiderVs200(_ble('VS200'))),
      _device('cycplus-bc2-virtual-shifter', CycplusBc2(_ble('CYCPLUS BC2'))),
      _device('magene-onelap-key', OnelapKey(_ble('Onelap Key'))),
      _device('elite-sterzo-smart', EliteSterzo(_ble('STERZO'))),
      _device('elite-rizer', EliteRizer(_ble('RIZER'))),
      _device('phone-steering', GyroscopeSteering()),
    ];
    final out = File('build/website_export/controller_layouts.json');
    await out.parent.create(recursive: true);
    await out.writeAsString('${const JsonEncoder.withIndent('  ').convert(layouts)}\n');
  });
}
