import 'dart:io' show Platform;

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/title.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/prop.dart' hide TrainerMode;

/// Telemetry payload attached to each support chat message.
///
/// Schema matches the existing `submit-trainer-feedback` edge function (minus
/// the `user_feedback`/`user_rating` fields, which are chat-specific).
class TelemetrySnapshot {
  final String? bluetoothName;
  final String? hardwareManufacturer;
  final String? firmwareVersion;
  final bool? trainerSupportsVirtualShifting;
  final String? trainerControlMode;
  final String? virtualShiftingMode;
  final bool? gradeSmoothing;
  final List<double>? gearRatios;
  final String? appVersion;
  final String? appPlatform;
  final String? trainerApp;
  final List<String>? trainerFtmsMachineFeatures;
  final List<String>? trainerFtmsTargetSettingFlags;
  final String? freetext;

  const TelemetrySnapshot({
    this.bluetoothName,
    this.hardwareManufacturer,
    this.firmwareVersion,
    this.trainerSupportsVirtualShifting,
    this.trainerControlMode,
    this.virtualShiftingMode,
    this.gradeSmoothing,
    this.gearRatios,
    this.appVersion,
    this.appPlatform,
    this.trainerApp,
    this.trainerFtmsMachineFeatures,
    this.trainerFtmsTargetSettingFlags,
    this.freetext,
  });

  factory TelemetrySnapshot.fromDevice({
    required ProxyDevice device,
    String? freetextOverride,
  }) {
    final def = device.emulator.activeDefinition;
    final fitnessDef = def is FitnessBikeDefinition ? def : null;
    final cfg = core.shiftingConfigs.activeFor(device.trainerKey);

    return TelemetrySnapshot(
      bluetoothName: _computeBluetoothName(device),
      hardwareManufacturer: device.manufacturerName,
      firmwareVersion: device.firmwareVersion,
      trainerSupportsVirtualShifting: fitnessDef != null ? true : null,
      trainerControlMode: _controlMode(fitnessDef),
      virtualShiftingMode: fitnessDef != null ? _vsMode(cfg.mode) : null,
      gradeSmoothing: fitnessDef != null ? cfg.gradeSmoothing : null,
      gearRatios: fitnessDef != null ? (cfg.gearRatios ?? FitnessBikeDefinition.defaultGearRatios) : null,
      appVersion: _appVersion(),
      appPlatform: _appPlatform(),
      trainerApp: core.settings.getTrainerApp()?.name,
      trainerFtmsMachineFeatures: fitnessDef?.trainerFtmsMachineFeatureFlagNames,
      trainerFtmsTargetSettingFlags: fitnessDef?.trainerFtmsTargetSettingFlagNames,
      freetext: freetextOverride ?? buildProxyServicesFreetext(device),
    );
  }

  factory TelemetrySnapshot.general({String? freetext}) {
    return TelemetrySnapshot(
      appVersion: _appVersion(),
      appPlatform: _appPlatform(),
      trainerApp: core.settings.getTrainerApp()?.name,
      freetext: freetext,
    );
  }

  static const int _trainerAppMaxLength = 100;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (bluetoothName != null) json['bluetooth_name'] = bluetoothName;
    if (hardwareManufacturer != null) json['hardware_manufacturer'] = hardwareManufacturer;
    if (firmwareVersion != null) json['firmware_version'] = firmwareVersion;
    if (trainerSupportsVirtualShifting != null) {
      json['trainer_supports_virtual_shifting'] = trainerSupportsVirtualShifting;
    }
    if (trainerControlMode != null) json['trainer_control_mode'] = trainerControlMode;
    if (virtualShiftingMode != null) json['virtual_shifting_mode'] = virtualShiftingMode;
    if (gradeSmoothing != null) json['grade_smoothing'] = gradeSmoothing;
    if (gearRatios != null && gearRatios!.isNotEmpty) json['gear_ratios'] = gearRatios;
    if (appVersion != null) json['app_version'] = appVersion;
    if (appPlatform != null) json['app_platform'] = appPlatform;
    if (trainerApp != null) {
      json['trainer_app'] = trainerApp!.length > _trainerAppMaxLength
          ? trainerApp!.substring(0, _trainerAppMaxLength)
          : trainerApp;
    }
    if (trainerFtmsMachineFeatures != null && trainerFtmsMachineFeatures!.isNotEmpty) {
      json['trainer_ftms_machine_features'] = trainerFtmsMachineFeatures;
    }
    if (trainerFtmsTargetSettingFlags != null && trainerFtmsTargetSettingFlags!.isNotEmpty) {
      json['trainer_ftms_target_setting_flags'] = trainerFtmsTargetSettingFlags;
    }
    final trimmedFreetext = freetext?.trim();
    if (trimmedFreetext != null && trimmedFreetext.isNotEmpty) {
      json['freetext'] = trimmedFreetext;
    }
    return json;
  }
}

const _standardServiceShortUuids = {
  '1800',
  '1801',
  '180a',
  '180f',
  '180e',
  '1802',
};

bool _isStandardService(String uuid) {
  final lower = uuid.toLowerCase();
  if (lower.length >= 8 && lower.endsWith('-0000-1000-8000-00805f9b34fb')) {
    final shortId = lower.substring(4, 8);
    return _standardServiceShortUuids.contains(shortId);
  }
  return _standardServiceShortUuids.contains(lower);
}

/// Returns a multi-line "Services & characteristics:" block for the given
/// proxy device, skipping the standard GAP/GATT services that aren't useful
/// for diagnostics. Returns `null` when the emulator hasn't discovered any
/// services yet or only standard ones are present. Re-used by
/// [debugText] so the support payload and the standalone debug text both
/// surface the same BLE topology.
String? buildProxyServicesFreetext(ProxyDevice device) {
  final services = device.emulator.services;
  if (services == null || services.isEmpty) return null;
  final filtered = services.where((s) => !_isStandardService(s.uuid)).toList();
  if (filtered.isEmpty) return null;
  final buf = StringBuffer('Services & characteristics:\n');
  for (final s in filtered) {
    buf.writeln('${s.uuid}:');
    for (final c in s.characteristics) {
      buf.writeln('  - ${c.uuid}');
    }
  }
  return buf.toString().trimRight();
}

String? _computeBluetoothName(ProxyDevice device) {
  final name = device.deviceName;
  final hw = device.hardwareRevision;
  if (name != null && hw != null) return '$name (HW: $hw)';
  if (name != null) return name;
  if (hw != null) return 'HW: $hw';
  return device.name;
}

String? _controlMode(FitnessBikeDefinition? def) {
  if (def == null) return null;
  return def.trainerMode.value == TrainerMode.ergMode ? 'ERG' : 'SIM';
}

String _vsMode(VirtualShiftingMode mode) {
  switch (mode) {
    case VirtualShiftingMode.targetPower:
      return 'target_power';
    case VirtualShiftingMode.trackResistance:
      return 'track_resistance';
    case VirtualShiftingMode.basicResistance:
      return 'basic';
  }
}

String? _appVersion() {
  final info = packageInfoValue;
  if (info == null) return null;
  final patch = shorebirdPatch;
  return patch == null ? info.version : '${info.version}+${patch.number}';
}

String _appPlatform() {
  if (kIsWeb) return 'web';
  return Platform.operatingSystem;
}
