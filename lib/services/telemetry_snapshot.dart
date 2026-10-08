import 'dart:convert';
import 'dart:io' show Platform;

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/services/trainer_self_test/self_test_result.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/title.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';

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
  final bool? cadenceFilterEnabled;
  final List<double>? gearRatios;
  final String? appVersion;
  final String? appPlatform;
  final String? trainerApp;
  final List<String>? trainerFtmsMachineFeatures;
  final List<String>? trainerFtmsTargetSettingFlags;
  final String? freetext;

  /// Structured trainer diagnostics. Null when no trainer is involved, in
  /// which case none of its keys are sent at all.
  final TrainerDiagnostics? trainerDiagnostics;

  const TelemetrySnapshot({
    this.bluetoothName,
    this.hardwareManufacturer,
    this.firmwareVersion,
    this.trainerSupportsVirtualShifting,
    this.trainerControlMode,
    this.virtualShiftingMode,
    this.gradeSmoothing,
    this.cadenceFilterEnabled,
    this.gearRatios,
    this.appVersion,
    this.appPlatform,
    this.trainerApp,
    this.trainerFtmsMachineFeatures,
    this.trainerFtmsTargetSettingFlags,
    this.freetext,
    this.trainerDiagnostics,
  });

  factory TelemetrySnapshot.fromDevice({
    required ProxyDevice device,
    String? freetextOverride,
  }) {
    final fitnessDef = device.fitnessBike;
    final cfg = core.shiftingConfigs.activeFor(device.trainerKey);

    return TelemetrySnapshot(
      bluetoothName: _computeBluetoothName(device),
      hardwareManufacturer: device.manufacturerName,
      firmwareVersion: device.firmwareVersion,
      trainerSupportsVirtualShifting: fitnessDef != null ? true : null,
      trainerControlMode: _controlMode(fitnessDef),
      virtualShiftingMode: fitnessDef != null ? _vsMode(cfg.mode) : null,
      gradeSmoothing: fitnessDef != null ? cfg.gradeSmoothing : null,
      cadenceFilterEnabled: fitnessDef != null ? cfg.cadenceFilterEnabled : null,
      gearRatios: fitnessDef != null ? (cfg.gearRatios ?? FitnessBikeDefinition.defaultGearRatios) : null,
      appVersion: _appVersion(),
      appPlatform: _appPlatform(),
      trainerApp: core.settings.getTrainerApp()?.name,
      trainerFtmsMachineFeatures: fitnessDef?.trainerFtmsMachineFeatureFlagNames,
      trainerFtmsTargetSettingFlags: fitnessDef?.trainerFtmsTargetSettingFlagNames,
      freetext: freetextOverride ?? buildProxyServicesFreetext(device),
      trainerDiagnostics: TrainerDiagnostics.fromDevice(device),
    );
  }

  factory TelemetrySnapshot.general({String? freetext}) {
    final trainer = _connectedTrainer();
    return TelemetrySnapshot(
      // Same identity fields as [TelemetrySnapshot.fromDevice], so the trainer
      // diagnostics below can be attributed to a model and firmware.
      bluetoothName: trainer == null ? null : _computeBluetoothName(trainer),
      hardwareManufacturer: trainer?.manufacturerName,
      firmwareVersion: trainer?.firmwareVersion,
      appVersion: _appVersion(),
      appPlatform: _appPlatform(),
      trainerApp: core.settings.getTrainerApp()?.name,
      freetext: freetext,
      trainerDiagnostics: trainer == null ? null : TrainerDiagnostics.fromDevice(trainer),
    );
  }

  /// The trainer a general support message is about: a connected proxy device
  /// (never a controller), preferring one BikeControl actually drives.
  static ProxyDevice? _connectedTrainer() {
    final connected = core.connection.proxyDevices.where((d) => d.isConnected).toList();
    if (connected.isEmpty) return null;
    return connected.firstWhere((d) => d.fitnessBike != null, orElse: () => connected.first);
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
    if (cadenceFilterEnabled != null) json['cadence_filter_enabled'] = cadenceFilterEnabled;
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
    final diagnostics = trainerDiagnostics;
    if (diagnostics != null) json.addAll(diagnostics.toJson());
    return json;
  }
}

/// Trainer diagnostics sent as their own structured fields rather than inside
/// the free-text dump, so they can be kept on their own without any of the
/// personal data that dump carries (data minimisation).
///
/// [toJson] always emits all three keys, with explicit nulls for what is
/// unknown, so "no self-test run" is distinguishable from "no trainer".
class TrainerDiagnostics {
  /// The stored resistance self-test, passed through
  /// [sanitizeSelfTestResultJson]. Null when the trainer has never been tested.
  final Map<String, dynamic>? selfTestResult;

  /// Whether [selfTestResult]'s verdict is a full pass. Null without a result.
  final bool? selfTestPassed;

  /// Non-standard BLE service UUIDs, lowercased. Null before discovery.
  final List<String>? bleServices;

  const TrainerDiagnostics({this.selfTestResult, this.selfTestPassed, this.bleServices});

  factory TrainerDiagnostics.fromDevice(ProxyDevice device) {
    final selfTest = _storedSelfTest(device.trainerKey);
    return TrainerDiagnostics(
      selfTestResult: selfTest,
      selfTestPassed: selfTest == null ? null : selfTest['verdict'] == SelfTestVerdict.pass.name,
      bleServices: _bleServiceUuids(device),
    );
  }

  Map<String, dynamic> toJson() => {
    'self_test_result': selfTestResult,
    'self_test_passed': selfTestPassed,
    'ble_services': bleServices,
  };

  static Map<String, dynamic>? _storedSelfTest(String trainerKey) {
    final raw = core.settings.getSelfTestResultJson(trainerKey);
    if (raw == null) return null;
    try {
      // Round-trip through the model so only a well-formed result is sent.
      final result = SelfTestResult.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      return sanitizeSelfTestResultJson(result.toJson());
    } catch (e, s) {
      recordError(e, s, context: 'TrainerDiagnostics.storedSelfTest');
      return null;
    }
  }

  static List<String>? _bleServiceUuids(ProxyDevice device) {
    final services = device.services;
    if (services == null) return null;
    final uuids = <String>[];
    for (final service in services) {
      final uuid = service.uuid.toLowerCase();
      if (!_isStandardService(uuid) && !uuids.contains(uuid)) uuids.add(uuid);
    }
    return uuids.isEmpty ? null : uuids;
  }
}

const _selfTestResultFields = {
  'verdict',
  'ergStepsPassed',
  'ergStepsTotal',
  'shiftStepsPassed',
  'shiftStepsTotal',
  'vsMode',
  'protocol',
  'cadenceless',
};

final _uuidPattern = RegExp(r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}');
final _macPattern = RegExp(r'\b(?:[0-9a-fA-F]{2}[:-]){5}[0-9a-fA-F]{2}\b');
final _ipv4Pattern = RegExp(r'\b\d{1,3}(?:\.\d{1,3}){3}\b');
final _ipv6Pattern = RegExp(
  r'[0-9a-fA-F]{0,4}(?::[0-9a-fA-F]{0,4})*::[0-9a-fA-F]{0,4}(?::[0-9a-fA-F]{0,4})*'
  r'|\b(?:[0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}\b',
);
final _emailPattern = RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+');
final _engineErrorPattern = RegExp(r'^(aborted: engine error)\s*\(.*\)$', dotAll: true);

/// Reduces a stored [SelfTestResult] JSON to what describes the trainer's
/// behaviour, for data minimisation: an allow-list of known fields (so a field
/// added later is never sent by accident), the run's date without its time,
/// and step log lines with exception text, device identifiers, hardware and
/// network addresses and e-mail addresses removed.
@visibleForTesting
Map<String, dynamic> sanitizeSelfTestResultJson(Map<String, dynamic> json) {
  final out = <String, dynamic>{};
  final at = DateTime.tryParse(json['at'] as String? ?? '');
  if (at != null) {
    out['at'] =
        '${at.year.toString().padLeft(4, '0')}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')}';
  }
  for (final key in _selfTestResultFields) {
    if (json.containsKey(key)) out[key] = json[key];
  }
  final stepLog = json['stepLog'];
  if (stepLog is List) {
    out['stepLog'] = stepLog.whereType<String>().map(_scrubStepLine).toList();
  }
  return out;
}

String _scrubStepLine(String line) {
  const redacted = '<redacted>';
  return line
      .replaceFirstMapped(_engineErrorPattern, (m) => m.group(1)!)
      .replaceAll(_uuidPattern, redacted)
      .replaceAll(_emailPattern, redacted)
      .replaceAll(_macPattern, redacted)
      .replaceAll(_ipv4Pattern, redacted)
      .replaceAll(_ipv6Pattern, redacted);
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
  final services = device.services;
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
