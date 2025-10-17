//
//  Generated code. Do not modify.
//  source: zp.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'zp.pbenum.dart';

export 'zp.pbenum.dart';

class TrainerEnvSim extends $pb.GeneratedMessage {
  factory TrainerEnvSim({
    $core.int? simulatedWind,
    $core.int? simulatedGrade,
    $core.int? simulatedCW,
    $core.int? simulatedCRR,
  }) {
    final $result = create();
    if (simulatedWind != null) {
      $result.simulatedWind = simulatedWind;
    }
    if (simulatedGrade != null) {
      $result.simulatedGrade = simulatedGrade;
    }
    if (simulatedCW != null) {
      $result.simulatedCW = simulatedCW;
    }
    if (simulatedCRR != null) {
      $result.simulatedCRR = simulatedCRR;
    }
    return $result;
  }
  TrainerEnvSim._() : super();
  factory TrainerEnvSim.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory TrainerEnvSim.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'TrainerEnvSim', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'simulatedWind', $pb.PbFieldType.OS3, protoName: 'simulatedWind')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'simulatedGrade', $pb.PbFieldType.OS3, protoName: 'simulatedGrade')
    ..a<$core.int>(3, _omitFieldNames ? '' : 'simulatedCW', $pb.PbFieldType.OU3, protoName: 'simulatedCW')
    ..a<$core.int>(4, _omitFieldNames ? '' : 'simulatedCRR', $pb.PbFieldType.OU3, protoName: 'simulatedCRR')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  TrainerEnvSim clone() => TrainerEnvSim()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  TrainerEnvSim copyWith(void Function(TrainerEnvSim) updates) => super.copyWith((message) => updates(message as TrainerEnvSim)) as TrainerEnvSim;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TrainerEnvSim create() => TrainerEnvSim._();
  TrainerEnvSim createEmptyInstance() => create();
  static $pb.PbList<TrainerEnvSim> createRepeated() => $pb.PbList<TrainerEnvSim>();
  @$core.pragma('dart2js:noInline')
  static TrainerEnvSim getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TrainerEnvSim>(create);
  static TrainerEnvSim? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get simulatedWind => $_getIZ(0);
  @$pb.TagNumber(1)
  set simulatedWind($core.int v) { $_setSignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSimulatedWind() => $_has(0);
  @$pb.TagNumber(1)
  void clearSimulatedWind() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get simulatedGrade => $_getIZ(1);
  @$pb.TagNumber(2)
  set simulatedGrade($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasSimulatedGrade() => $_has(1);
  @$pb.TagNumber(2)
  void clearSimulatedGrade() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get simulatedCW => $_getIZ(2);
  @$pb.TagNumber(3)
  set simulatedCW($core.int v) { $_setUnsignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasSimulatedCW() => $_has(2);
  @$pb.TagNumber(3)
  void clearSimulatedCW() => clearField(3);

  @$pb.TagNumber(4)
  $core.int get simulatedCRR => $_getIZ(3);
  @$pb.TagNumber(4)
  set simulatedCRR($core.int v) { $_setUnsignedInt32(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasSimulatedCRR() => $_has(3);
  @$pb.TagNumber(4)
  void clearSimulatedCRR() => clearField(4);
}

class TrainerBikeSim extends $pb.GeneratedMessage {
  factory TrainerBikeSim({
    $core.int? simulatedRealGearRatio,
    $core.int? simulatedVirtualGearRatio,
    $core.int? simulatedWheelDiameter,
    $core.int? simulatedBikeMass,
    $core.int? simulatedRiderMass,
    $core.int? simulatedFrontalArea,
    $core.int? eBrake,
  }) {
    final $result = create();
    if (simulatedRealGearRatio != null) {
      $result.simulatedRealGearRatio = simulatedRealGearRatio;
    }
    if (simulatedVirtualGearRatio != null) {
      $result.simulatedVirtualGearRatio = simulatedVirtualGearRatio;
    }
    if (simulatedWheelDiameter != null) {
      $result.simulatedWheelDiameter = simulatedWheelDiameter;
    }
    if (simulatedBikeMass != null) {
      $result.simulatedBikeMass = simulatedBikeMass;
    }
    if (simulatedRiderMass != null) {
      $result.simulatedRiderMass = simulatedRiderMass;
    }
    if (simulatedFrontalArea != null) {
      $result.simulatedFrontalArea = simulatedFrontalArea;
    }
    if (eBrake != null) {
      $result.eBrake = eBrake;
    }
    return $result;
  }
  TrainerBikeSim._() : super();
  factory TrainerBikeSim.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory TrainerBikeSim.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'TrainerBikeSim', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'simulatedRealGearRatio', $pb.PbFieldType.OU3, protoName: 'simulatedRealGearRatio')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'simulatedVirtualGearRatio', $pb.PbFieldType.OU3, protoName: 'simulatedVirtualGearRatio')
    ..a<$core.int>(3, _omitFieldNames ? '' : 'simulatedWheelDiameter', $pb.PbFieldType.OU3, protoName: 'simulatedWheelDiameter')
    ..a<$core.int>(4, _omitFieldNames ? '' : 'simulatedBikeMass', $pb.PbFieldType.OU3, protoName: 'simulatedBikeMass')
    ..a<$core.int>(5, _omitFieldNames ? '' : 'simulatedRiderMass', $pb.PbFieldType.OU3, protoName: 'simulatedRiderMass')
    ..a<$core.int>(6, _omitFieldNames ? '' : 'simulatedFrontalArea', $pb.PbFieldType.OU3, protoName: 'simulatedFrontalArea')
    ..a<$core.int>(7, _omitFieldNames ? '' : 'eBrake', $pb.PbFieldType.OU3, protoName: 'eBrake')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  TrainerBikeSim clone() => TrainerBikeSim()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  TrainerBikeSim copyWith(void Function(TrainerBikeSim) updates) => super.copyWith((message) => updates(message as TrainerBikeSim)) as TrainerBikeSim;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TrainerBikeSim create() => TrainerBikeSim._();
  TrainerBikeSim createEmptyInstance() => create();
  static $pb.PbList<TrainerBikeSim> createRepeated() => $pb.PbList<TrainerBikeSim>();
  @$core.pragma('dart2js:noInline')
  static TrainerBikeSim getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TrainerBikeSim>(create);
  static TrainerBikeSim? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get simulatedRealGearRatio => $_getIZ(0);
  @$pb.TagNumber(1)
  set simulatedRealGearRatio($core.int v) { $_setUnsignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSimulatedRealGearRatio() => $_has(0);
  @$pb.TagNumber(1)
  void clearSimulatedRealGearRatio() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get simulatedVirtualGearRatio => $_getIZ(1);
  @$pb.TagNumber(2)
  set simulatedVirtualGearRatio($core.int v) { $_setUnsignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasSimulatedVirtualGearRatio() => $_has(1);
  @$pb.TagNumber(2)
  void clearSimulatedVirtualGearRatio() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get simulatedWheelDiameter => $_getIZ(2);
  @$pb.TagNumber(3)
  set simulatedWheelDiameter($core.int v) { $_setUnsignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasSimulatedWheelDiameter() => $_has(2);
  @$pb.TagNumber(3)
  void clearSimulatedWheelDiameter() => clearField(3);

  @$pb.TagNumber(4)
  $core.int get simulatedBikeMass => $_getIZ(3);
  @$pb.TagNumber(4)
  set simulatedBikeMass($core.int v) { $_setUnsignedInt32(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasSimulatedBikeMass() => $_has(3);
  @$pb.TagNumber(4)
  void clearSimulatedBikeMass() => clearField(4);

  @$pb.TagNumber(5)
  $core.int get simulatedRiderMass => $_getIZ(4);
  @$pb.TagNumber(5)
  set simulatedRiderMass($core.int v) { $_setUnsignedInt32(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasSimulatedRiderMass() => $_has(4);
  @$pb.TagNumber(5)
  void clearSimulatedRiderMass() => clearField(5);

  @$pb.TagNumber(6)
  $core.int get simulatedFrontalArea => $_getIZ(5);
  @$pb.TagNumber(6)
  set simulatedFrontalArea($core.int v) { $_setUnsignedInt32(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasSimulatedFrontalArea() => $_has(5);
  @$pb.TagNumber(6)
  void clearSimulatedFrontalArea() => clearField(6);

  @$pb.TagNumber(7)
  $core.int get eBrake => $_getIZ(6);
  @$pb.TagNumber(7)
  set eBrake($core.int v) { $_setUnsignedInt32(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasEBrake() => $_has(6);
  @$pb.TagNumber(7)
  void clearEBrake() => clearField(7);
}

class ControllerAnalogEvent extends $pb.GeneratedMessage {
  factory ControllerAnalogEvent({
    $core.int? sensorId,
    $core.int? value,
  }) {
    final $result = create();
    if (sensorId != null) {
      $result.sensorId = sensorId;
    }
    if (value != null) {
      $result.value = value;
    }
    return $result;
  }
  ControllerAnalogEvent._() : super();
  factory ControllerAnalogEvent.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ControllerAnalogEvent.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ControllerAnalogEvent', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'sensorId', $pb.PbFieldType.OU3, protoName: 'sensorId')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'value', $pb.PbFieldType.OS3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ControllerAnalogEvent clone() => ControllerAnalogEvent()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ControllerAnalogEvent copyWith(void Function(ControllerAnalogEvent) updates) => super.copyWith((message) => updates(message as ControllerAnalogEvent)) as ControllerAnalogEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ControllerAnalogEvent create() => ControllerAnalogEvent._();
  ControllerAnalogEvent createEmptyInstance() => create();
  static $pb.PbList<ControllerAnalogEvent> createRepeated() => $pb.PbList<ControllerAnalogEvent>();
  @$core.pragma('dart2js:noInline')
  static ControllerAnalogEvent getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ControllerAnalogEvent>(create);
  static ControllerAnalogEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get sensorId => $_getIZ(0);
  @$pb.TagNumber(1)
  set sensorId($core.int v) { $_setUnsignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSensorId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSensorId() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get value => $_getIZ(1);
  @$pb.TagNumber(2)
  set value($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearValue() => clearField(2);
}

class InputAnalogRange extends $pb.GeneratedMessage {
  factory InputAnalogRange({
    $core.int? sensorId,
    $core.int? minAnalogValue,
    $core.int? maxAnalogValue,
  }) {
    final $result = create();
    if (sensorId != null) {
      $result.sensorId = sensorId;
    }
    if (minAnalogValue != null) {
      $result.minAnalogValue = minAnalogValue;
    }
    if (maxAnalogValue != null) {
      $result.maxAnalogValue = maxAnalogValue;
    }
    return $result;
  }
  InputAnalogRange._() : super();
  factory InputAnalogRange.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory InputAnalogRange.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'InputAnalogRange', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'sensorId', $pb.PbFieldType.OU3, protoName: 'sensorId')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'minAnalogValue', $pb.PbFieldType.OS3, protoName: 'minAnalogValue')
    ..a<$core.int>(3, _omitFieldNames ? '' : 'maxAnalogValue', $pb.PbFieldType.OS3, protoName: 'maxAnalogValue')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  InputAnalogRange clone() => InputAnalogRange()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  InputAnalogRange copyWith(void Function(InputAnalogRange) updates) => super.copyWith((message) => updates(message as InputAnalogRange)) as InputAnalogRange;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static InputAnalogRange create() => InputAnalogRange._();
  InputAnalogRange createEmptyInstance() => create();
  static $pb.PbList<InputAnalogRange> createRepeated() => $pb.PbList<InputAnalogRange>();
  @$core.pragma('dart2js:noInline')
  static InputAnalogRange getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<InputAnalogRange>(create);
  static InputAnalogRange? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get sensorId => $_getIZ(0);
  @$pb.TagNumber(1)
  set sensorId($core.int v) { $_setUnsignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSensorId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSensorId() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get minAnalogValue => $_getIZ(1);
  @$pb.TagNumber(2)
  set minAnalogValue($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMinAnalogValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearMinAnalogValue() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get maxAnalogValue => $_getIZ(2);
  @$pb.TagNumber(3)
  set maxAnalogValue($core.int v) { $_setSignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasMaxAnalogValue() => $_has(2);
  @$pb.TagNumber(3)
  void clearMaxAnalogValue() => clearField(3);
}

class InputAnalogDeadzone extends $pb.GeneratedMessage {
  factory InputAnalogDeadzone({
    $core.int? sensorId,
    $core.int? negDeadzoneValue,
    $core.int? posDeadzoneValue,
  }) {
    final $result = create();
    if (sensorId != null) {
      $result.sensorId = sensorId;
    }
    if (negDeadzoneValue != null) {
      $result.negDeadzoneValue = negDeadzoneValue;
    }
    if (posDeadzoneValue != null) {
      $result.posDeadzoneValue = posDeadzoneValue;
    }
    return $result;
  }
  InputAnalogDeadzone._() : super();
  factory InputAnalogDeadzone.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory InputAnalogDeadzone.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'InputAnalogDeadzone', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'sensorId', $pb.PbFieldType.OU3, protoName: 'sensorId')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'negDeadzoneValue', $pb.PbFieldType.OS3, protoName: 'negDeadzoneValue')
    ..a<$core.int>(3, _omitFieldNames ? '' : 'posDeadzoneValue', $pb.PbFieldType.OS3, protoName: 'posDeadzoneValue')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  InputAnalogDeadzone clone() => InputAnalogDeadzone()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  InputAnalogDeadzone copyWith(void Function(InputAnalogDeadzone) updates) => super.copyWith((message) => updates(message as InputAnalogDeadzone)) as InputAnalogDeadzone;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static InputAnalogDeadzone create() => InputAnalogDeadzone._();
  InputAnalogDeadzone createEmptyInstance() => create();
  static $pb.PbList<InputAnalogDeadzone> createRepeated() => $pb.PbList<InputAnalogDeadzone>();
  @$core.pragma('dart2js:noInline')
  static InputAnalogDeadzone getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<InputAnalogDeadzone>(create);
  static InputAnalogDeadzone? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get sensorId => $_getIZ(0);
  @$pb.TagNumber(1)
  set sensorId($core.int v) { $_setUnsignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSensorId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSensorId() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get negDeadzoneValue => $_getIZ(1);
  @$pb.TagNumber(2)
  set negDeadzoneValue($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasNegDeadzoneValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearNegDeadzoneValue() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get posDeadzoneValue => $_getIZ(2);
  @$pb.TagNumber(3)
  set posDeadzoneValue($core.int v) { $_setSignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasPosDeadzoneValue() => $_has(2);
  @$pb.TagNumber(3)
  void clearPosDeadzoneValue() => clearField(3);
}

class WifiNetwork extends $pb.GeneratedMessage {
  factory WifiNetwork({
    $core.int? networkId,
    $core.List<$core.int>? ssid,
    $core.List<$core.int>? password,
  }) {
    final $result = create();
    if (networkId != null) {
      $result.networkId = networkId;
    }
    if (ssid != null) {
      $result.ssid = ssid;
    }
    if (password != null) {
      $result.password = password;
    }
    return $result;
  }
  WifiNetwork._() : super();
  factory WifiNetwork.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory WifiNetwork.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'WifiNetwork', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'networkId', $pb.PbFieldType.OU3, protoName: 'networkId')
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'ssid', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(3, _omitFieldNames ? '' : 'password', $pb.PbFieldType.OY)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  WifiNetwork clone() => WifiNetwork()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  WifiNetwork copyWith(void Function(WifiNetwork) updates) => super.copyWith((message) => updates(message as WifiNetwork)) as WifiNetwork;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WifiNetwork create() => WifiNetwork._();
  WifiNetwork createEmptyInstance() => create();
  static $pb.PbList<WifiNetwork> createRepeated() => $pb.PbList<WifiNetwork>();
  @$core.pragma('dart2js:noInline')
  static WifiNetwork getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<WifiNetwork>(create);
  static WifiNetwork? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get networkId => $_getIZ(0);
  @$pb.TagNumber(1)
  set networkId($core.int v) { $_setUnsignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasNetworkId() => $_has(0);
  @$pb.TagNumber(1)
  void clearNetworkId() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get ssid => $_getN(1);
  @$pb.TagNumber(2)
  set ssid($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasSsid() => $_has(1);
  @$pb.TagNumber(2)
  void clearSsid() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get password => $_getN(2);
  @$pb.TagNumber(3)
  set password($core.List<$core.int> v) { $_setBytes(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasPassword() => $_has(2);
  @$pb.TagNumber(3)
  void clearPassword() => clearField(3);
}

class WifiRegionCode extends $pb.GeneratedMessage {
  factory WifiRegionCode({
    WifiRegionCode_RegionCodeType? regionCodeType,
    $core.List<$core.int>? regionCode,
  }) {
    final $result = create();
    if (regionCodeType != null) {
      $result.regionCodeType = regionCodeType;
    }
    if (regionCode != null) {
      $result.regionCode = regionCode;
    }
    return $result;
  }
  WifiRegionCode._() : super();
  factory WifiRegionCode.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory WifiRegionCode.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'WifiRegionCode', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..e<WifiRegionCode_RegionCodeType>(1, _omitFieldNames ? '' : 'regionCodeType', $pb.PbFieldType.OE, protoName: 'regionCodeType', defaultOrMaker: WifiRegionCode_RegionCodeType.ALPHA_2, valueOf: WifiRegionCode_RegionCodeType.valueOf, enumValues: WifiRegionCode_RegionCodeType.values)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'regionCode', $pb.PbFieldType.OY, protoName: 'regionCode')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  WifiRegionCode clone() => WifiRegionCode()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  WifiRegionCode copyWith(void Function(WifiRegionCode) updates) => super.copyWith((message) => updates(message as WifiRegionCode)) as WifiRegionCode;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WifiRegionCode create() => WifiRegionCode._();
  WifiRegionCode createEmptyInstance() => create();
  static $pb.PbList<WifiRegionCode> createRepeated() => $pb.PbList<WifiRegionCode>();
  @$core.pragma('dart2js:noInline')
  static WifiRegionCode getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<WifiRegionCode>(create);
  static WifiRegionCode? _defaultInstance;

  @$pb.TagNumber(1)
  WifiRegionCode_RegionCodeType get regionCodeType => $_getN(0);
  @$pb.TagNumber(1)
  set regionCodeType(WifiRegionCode_RegionCodeType v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasRegionCodeType() => $_has(0);
  @$pb.TagNumber(1)
  void clearRegionCodeType() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get regionCode => $_getN(1);
  @$pb.TagNumber(2)
  set regionCode($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasRegionCode() => $_has(1);
  @$pb.TagNumber(2)
  void clearRegionCode() => clearField(2);
}

class WifiNetworkDetails extends $pb.GeneratedMessage {
  factory WifiNetworkDetails({
    $core.int? networkId,
    $core.List<$core.int>? bssid,
    $core.List<$core.int>? ssid,
    $core.int? securityType,
    $core.int? band,
    $core.int? rssi,
  }) {
    final $result = create();
    if (networkId != null) {
      $result.networkId = networkId;
    }
    if (bssid != null) {
      $result.bssid = bssid;
    }
    if (ssid != null) {
      $result.ssid = ssid;
    }
    if (securityType != null) {
      $result.securityType = securityType;
    }
    if (band != null) {
      $result.band = band;
    }
    if (rssi != null) {
      $result.rssi = rssi;
    }
    return $result;
  }
  WifiNetworkDetails._() : super();
  factory WifiNetworkDetails.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory WifiNetworkDetails.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'WifiNetworkDetails', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'networkId', $pb.PbFieldType.OU3, protoName: 'networkId')
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'bssid', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(3, _omitFieldNames ? '' : 'ssid', $pb.PbFieldType.OY)
    ..a<$core.int>(4, _omitFieldNames ? '' : 'securityType', $pb.PbFieldType.OU3, protoName: 'securityType')
    ..a<$core.int>(5, _omitFieldNames ? '' : 'band', $pb.PbFieldType.OU3)
    ..a<$core.int>(6, _omitFieldNames ? '' : 'rssi', $pb.PbFieldType.OS3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  WifiNetworkDetails clone() => WifiNetworkDetails()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  WifiNetworkDetails copyWith(void Function(WifiNetworkDetails) updates) => super.copyWith((message) => updates(message as WifiNetworkDetails)) as WifiNetworkDetails;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WifiNetworkDetails create() => WifiNetworkDetails._();
  WifiNetworkDetails createEmptyInstance() => create();
  static $pb.PbList<WifiNetworkDetails> createRepeated() => $pb.PbList<WifiNetworkDetails>();
  @$core.pragma('dart2js:noInline')
  static WifiNetworkDetails getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<WifiNetworkDetails>(create);
  static WifiNetworkDetails? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get networkId => $_getIZ(0);
  @$pb.TagNumber(1)
  set networkId($core.int v) { $_setUnsignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasNetworkId() => $_has(0);
  @$pb.TagNumber(1)
  void clearNetworkId() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get bssid => $_getN(1);
  @$pb.TagNumber(2)
  set bssid($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasBssid() => $_has(1);
  @$pb.TagNumber(2)
  void clearBssid() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get ssid => $_getN(2);
  @$pb.TagNumber(3)
  set ssid($core.List<$core.int> v) { $_setBytes(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasSsid() => $_has(2);
  @$pb.TagNumber(3)
  void clearSsid() => clearField(3);

  @$pb.TagNumber(4)
  $core.int get securityType => $_getIZ(3);
  @$pb.TagNumber(4)
  set securityType($core.int v) { $_setUnsignedInt32(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasSecurityType() => $_has(3);
  @$pb.TagNumber(4)
  void clearSecurityType() => clearField(4);

  @$pb.TagNumber(5)
  $core.int get band => $_getIZ(4);
  @$pb.TagNumber(5)
  set band($core.int v) { $_setUnsignedInt32(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasBand() => $_has(4);
  @$pb.TagNumber(5)
  void clearBand() => clearField(5);

  @$pb.TagNumber(6)
  $core.int get rssi => $_getIZ(5);
  @$pb.TagNumber(6)
  set rssi($core.int v) { $_setSignedInt32(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasRssi() => $_has(5);
  @$pb.TagNumber(6)
  void clearRssi() => clearField(6);
}

class SensorInfo extends $pb.GeneratedMessage {
  factory SensorInfo({
    $core.int? relayAssignedId,
    $core.List<$core.int>? sensorName,
    $core.List<$core.int>? sensorAddress,
    InterfaceType? interfaceType,
    SensorConnectionStatus? connectionStatus,
    $core.Iterable<DeviceType>? deviceTypes,
    $core.bool? supportsZp,
  }) {
    final $result = create();
    if (relayAssignedId != null) {
      $result.relayAssignedId = relayAssignedId;
    }
    if (sensorName != null) {
      $result.sensorName = sensorName;
    }
    if (sensorAddress != null) {
      $result.sensorAddress = sensorAddress;
    }
    if (interfaceType != null) {
      $result.interfaceType = interfaceType;
    }
    if (connectionStatus != null) {
      $result.connectionStatus = connectionStatus;
    }
    if (deviceTypes != null) {
      $result.deviceTypes.addAll(deviceTypes);
    }
    if (supportsZp != null) {
      $result.supportsZp = supportsZp;
    }
    return $result;
  }
  SensorInfo._() : super();
  factory SensorInfo.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SensorInfo.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SensorInfo', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'relayAssignedId', $pb.PbFieldType.OU3, protoName: 'relayAssignedId')
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'sensorName', $pb.PbFieldType.OY, protoName: 'sensorName')
    ..a<$core.List<$core.int>>(4, _omitFieldNames ? '' : 'sensorAddress', $pb.PbFieldType.OY, protoName: 'sensorAddress')
    ..e<InterfaceType>(5, _omitFieldNames ? '' : 'interfaceType', $pb.PbFieldType.OE, protoName: 'interfaceType', defaultOrMaker: InterfaceType.INTERFACE_BLE, valueOf: InterfaceType.valueOf, enumValues: InterfaceType.values)
    ..e<SensorConnectionStatus>(6, _omitFieldNames ? '' : 'connectionStatus', $pb.PbFieldType.OE, protoName: 'connectionStatus', defaultOrMaker: SensorConnectionStatus.SENSOR_STATUS_DISCOVERED, valueOf: SensorConnectionStatus.valueOf, enumValues: SensorConnectionStatus.values)
    ..pc<DeviceType>(7, _omitFieldNames ? '' : 'deviceTypes', $pb.PbFieldType.PE, protoName: 'deviceTypes', valueOf: DeviceType.valueOf, enumValues: DeviceType.values, defaultEnumValue: DeviceType.UNDEFINED)
    ..aOB(8, _omitFieldNames ? '' : 'supportsZp', protoName: 'supportsZp')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SensorInfo clone() => SensorInfo()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SensorInfo copyWith(void Function(SensorInfo) updates) => super.copyWith((message) => updates(message as SensorInfo)) as SensorInfo;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SensorInfo create() => SensorInfo._();
  SensorInfo createEmptyInstance() => create();
  static $pb.PbList<SensorInfo> createRepeated() => $pb.PbList<SensorInfo>();
  @$core.pragma('dart2js:noInline')
  static SensorInfo getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SensorInfo>(create);
  static SensorInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get relayAssignedId => $_getIZ(0);
  @$pb.TagNumber(1)
  set relayAssignedId($core.int v) { $_setUnsignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasRelayAssignedId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRelayAssignedId() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get sensorName => $_getN(1);
  @$pb.TagNumber(2)
  set sensorName($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasSensorName() => $_has(1);
  @$pb.TagNumber(2)
  void clearSensorName() => clearField(2);

  @$pb.TagNumber(4)
  $core.List<$core.int> get sensorAddress => $_getN(2);
  @$pb.TagNumber(4)
  set sensorAddress($core.List<$core.int> v) { $_setBytes(2, v); }
  @$pb.TagNumber(4)
  $core.bool hasSensorAddress() => $_has(2);
  @$pb.TagNumber(4)
  void clearSensorAddress() => clearField(4);

  @$pb.TagNumber(5)
  InterfaceType get interfaceType => $_getN(3);
  @$pb.TagNumber(5)
  set interfaceType(InterfaceType v) { setField(5, v); }
  @$pb.TagNumber(5)
  $core.bool hasInterfaceType() => $_has(3);
  @$pb.TagNumber(5)
  void clearInterfaceType() => clearField(5);

  @$pb.TagNumber(6)
  SensorConnectionStatus get connectionStatus => $_getN(4);
  @$pb.TagNumber(6)
  set connectionStatus(SensorConnectionStatus v) { setField(6, v); }
  @$pb.TagNumber(6)
  $core.bool hasConnectionStatus() => $_has(4);
  @$pb.TagNumber(6)
  void clearConnectionStatus() => clearField(6);

  @$pb.TagNumber(7)
  $core.List<DeviceType> get deviceTypes => $_getList(5);

  @$pb.TagNumber(8)
  $core.bool get supportsZp => $_getBF(6);
  @$pb.TagNumber(8)
  set supportsZp($core.bool v) { $_setBool(6, v); }
  @$pb.TagNumber(8)
  $core.bool hasSupportsZp() => $_has(6);
  @$pb.TagNumber(8)
  void clearSupportsZp() => clearField(8);
}

class SensorInfoList extends $pb.GeneratedMessage {
  factory SensorInfoList({
    $core.Iterable<SensorInfo>? sensorInfo,
  }) {
    final $result = create();
    if (sensorInfo != null) {
      $result.sensorInfo.addAll(sensorInfo);
    }
    return $result;
  }
  SensorInfoList._() : super();
  factory SensorInfoList.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SensorInfoList.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SensorInfoList', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..pc<SensorInfo>(1, _omitFieldNames ? '' : 'sensorInfo', $pb.PbFieldType.PM, protoName: 'sensorInfo', subBuilder: SensorInfo.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SensorInfoList clone() => SensorInfoList()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SensorInfoList copyWith(void Function(SensorInfoList) updates) => super.copyWith((message) => updates(message as SensorInfoList)) as SensorInfoList;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SensorInfoList create() => SensorInfoList._();
  SensorInfoList createEmptyInstance() => create();
  static $pb.PbList<SensorInfoList> createRepeated() => $pb.PbList<SensorInfoList>();
  @$core.pragma('dart2js:noInline')
  static SensorInfoList getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SensorInfoList>(create);
  static SensorInfoList? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<SensorInfo> get sensorInfo => $_getList(0);
}

class DeviceUpdatePage extends $pb.GeneratedMessage {
  factory DeviceUpdatePage({
    $core.int? updateStatus,
    $core.int? newVersion,
  }) {
    final $result = create();
    if (updateStatus != null) {
      $result.updateStatus = updateStatus;
    }
    if (newVersion != null) {
      $result.newVersion = newVersion;
    }
    return $result;
  }
  DeviceUpdatePage._() : super();
  factory DeviceUpdatePage.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DeviceUpdatePage.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DeviceUpdatePage', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'updateStatus', $pb.PbFieldType.OU3, protoName: 'updateStatus')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'newVersion', $pb.PbFieldType.OU3, protoName: 'newVersion')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DeviceUpdatePage clone() => DeviceUpdatePage()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DeviceUpdatePage copyWith(void Function(DeviceUpdatePage) updates) => super.copyWith((message) => updates(message as DeviceUpdatePage)) as DeviceUpdatePage;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeviceUpdatePage create() => DeviceUpdatePage._();
  DeviceUpdatePage createEmptyInstance() => create();
  static $pb.PbList<DeviceUpdatePage> createRepeated() => $pb.PbList<DeviceUpdatePage>();
  @$core.pragma('dart2js:noInline')
  static DeviceUpdatePage getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DeviceUpdatePage>(create);
  static DeviceUpdatePage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get updateStatus => $_getIZ(0);
  @$pb.TagNumber(1)
  set updateStatus($core.int v) { $_setUnsignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUpdateStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearUpdateStatus() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get newVersion => $_getIZ(1);
  @$pb.TagNumber(2)
  set newVersion($core.int v) { $_setUnsignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasNewVersion() => $_has(1);
  @$pb.TagNumber(2)
  void clearNewVersion() => clearField(2);
}

class DateTimePage extends $pb.GeneratedMessage {
  factory DateTimePage({
    $core.int? utcDateTime,
  }) {
    final $result = create();
    if (utcDateTime != null) {
      $result.utcDateTime = utcDateTime;
    }
    return $result;
  }
  DateTimePage._() : super();
  factory DateTimePage.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DateTimePage.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DateTimePage', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'utcDateTime', $pb.PbFieldType.OU3, protoName: 'utcDateTime')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DateTimePage clone() => DateTimePage()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DateTimePage copyWith(void Function(DateTimePage) updates) => super.copyWith((message) => updates(message as DateTimePage)) as DateTimePage;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DateTimePage create() => DateTimePage._();
  DateTimePage createEmptyInstance() => create();
  static $pb.PbList<DateTimePage> createRepeated() => $pb.PbList<DateTimePage>();
  @$core.pragma('dart2js:noInline')
  static DateTimePage getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DateTimePage>(create);
  static DateTimePage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get utcDateTime => $_getIZ(0);
  @$pb.TagNumber(1)
  set utcDateTime($core.int v) { $_setUnsignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUtcDateTime() => $_has(0);
  @$pb.TagNumber(1)
  void clearUtcDateTime() => clearField(1);
}

class BleSecurityPage extends $pb.GeneratedMessage {
  factory BleSecurityPage({
    BleSecureConnectionStatus? secureConnectionStatus,
    BleSecureConnectionWindowStatus? secureConnectionWindowStatus,
  }) {
    final $result = create();
    if (secureConnectionStatus != null) {
      $result.secureConnectionStatus = secureConnectionStatus;
    }
    if (secureConnectionWindowStatus != null) {
      $result.secureConnectionWindowStatus = secureConnectionWindowStatus;
    }
    return $result;
  }
  BleSecurityPage._() : super();
  factory BleSecurityPage.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BleSecurityPage.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'BleSecurityPage', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..e<BleSecureConnectionStatus>(1, _omitFieldNames ? '' : 'secureConnectionStatus', $pb.PbFieldType.OE, protoName: 'secureConnectionStatus', defaultOrMaker: BleSecureConnectionStatus.BLE_CONNECTION_SECURITY_STATUS_NONE, valueOf: BleSecureConnectionStatus.valueOf, enumValues: BleSecureConnectionStatus.values)
    ..e<BleSecureConnectionWindowStatus>(2, _omitFieldNames ? '' : 'secureConnectionWindowStatus', $pb.PbFieldType.OE, protoName: 'secureConnectionWindowStatus', defaultOrMaker: BleSecureConnectionWindowStatus.BLE_SECURE_CONNECTION_WINDOW_STATUS_CLOSED, valueOf: BleSecureConnectionWindowStatus.valueOf, enumValues: BleSecureConnectionWindowStatus.values)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BleSecurityPage clone() => BleSecurityPage()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BleSecurityPage copyWith(void Function(BleSecurityPage) updates) => super.copyWith((message) => updates(message as BleSecurityPage)) as BleSecurityPage;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BleSecurityPage create() => BleSecurityPage._();
  BleSecurityPage createEmptyInstance() => create();
  static $pb.PbList<BleSecurityPage> createRepeated() => $pb.PbList<BleSecurityPage>();
  @$core.pragma('dart2js:noInline')
  static BleSecurityPage getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BleSecurityPage>(create);
  static BleSecurityPage? _defaultInstance;

  @$pb.TagNumber(1)
  BleSecureConnectionStatus get secureConnectionStatus => $_getN(0);
  @$pb.TagNumber(1)
  set secureConnectionStatus(BleSecureConnectionStatus v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasSecureConnectionStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearSecureConnectionStatus() => clearField(1);

  @$pb.TagNumber(2)
  BleSecureConnectionWindowStatus get secureConnectionWindowStatus => $_getN(1);
  @$pb.TagNumber(2)
  set secureConnectionWindowStatus(BleSecureConnectionWindowStatus v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasSecureConnectionWindowStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearSecureConnectionWindowStatus() => clearField(2);
}

class DevInfoPage_DeviceCapabilities extends $pb.GeneratedMessage {
  factory DevInfoPage_DeviceCapabilities({
    $core.int? deviceType,
    $core.int? capabilities,
  }) {
    final $result = create();
    if (deviceType != null) {
      $result.deviceType = deviceType;
    }
    if (capabilities != null) {
      $result.capabilities = capabilities;
    }
    return $result;
  }
  DevInfoPage_DeviceCapabilities._() : super();
  factory DevInfoPage_DeviceCapabilities.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DevInfoPage_DeviceCapabilities.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DevInfoPage.DeviceCapabilities', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'deviceType', $pb.PbFieldType.QU3, protoName: 'deviceType')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'capabilities', $pb.PbFieldType.QU3)
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DevInfoPage_DeviceCapabilities clone() => DevInfoPage_DeviceCapabilities()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DevInfoPage_DeviceCapabilities copyWith(void Function(DevInfoPage_DeviceCapabilities) updates) => super.copyWith((message) => updates(message as DevInfoPage_DeviceCapabilities)) as DevInfoPage_DeviceCapabilities;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DevInfoPage_DeviceCapabilities create() => DevInfoPage_DeviceCapabilities._();
  DevInfoPage_DeviceCapabilities createEmptyInstance() => create();
  static $pb.PbList<DevInfoPage_DeviceCapabilities> createRepeated() => $pb.PbList<DevInfoPage_DeviceCapabilities>();
  @$core.pragma('dart2js:noInline')
  static DevInfoPage_DeviceCapabilities getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DevInfoPage_DeviceCapabilities>(create);
  static DevInfoPage_DeviceCapabilities? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get deviceType => $_getIZ(0);
  @$pb.TagNumber(1)
  set deviceType($core.int v) { $_setUnsignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasDeviceType() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeviceType() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get capabilities => $_getIZ(1);
  @$pb.TagNumber(2)
  set capabilities($core.int v) { $_setUnsignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasCapabilities() => $_has(1);
  @$pb.TagNumber(2)
  void clearCapabilities() => clearField(2);
}

/// Page ID 0x000
class DevInfoPage extends $pb.GeneratedMessage {
  factory DevInfoPage({
    $core.int? protocolVersion,
    $core.List<$core.int>? systemFwVersion,
    $core.List<$core.int>? deviceName,
    $core.List<$core.int>? serialNumber,
    $core.List<$core.int>? systemHwRevision,
    $core.Iterable<DevInfoPage_DeviceCapabilities>? deviceCapabilities,
    $core.int? manufacturerId,
    $core.int? productId,
    $core.List<$core.int>? deviceUid,
  }) {
    final $result = create();
    if (protocolVersion != null) {
      $result.protocolVersion = protocolVersion;
    }
    if (systemFwVersion != null) {
      $result.systemFwVersion = systemFwVersion;
    }
    if (deviceName != null) {
      $result.deviceName = deviceName;
    }
    if (serialNumber != null) {
      $result.serialNumber = serialNumber;
    }
    if (systemHwRevision != null) {
      $result.systemHwRevision = systemHwRevision;
    }
    if (deviceCapabilities != null) {
      $result.deviceCapabilities.addAll(deviceCapabilities);
    }
    if (manufacturerId != null) {
      $result.manufacturerId = manufacturerId;
    }
    if (productId != null) {
      $result.productId = productId;
    }
    if (deviceUid != null) {
      $result.deviceUid = deviceUid;
    }
    return $result;
  }
  DevInfoPage._() : super();
  factory DevInfoPage.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DevInfoPage.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DevInfoPage', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'protocolVersion', $pb.PbFieldType.OU3, protoName: 'protocolVersion')
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'systemFwVersion', $pb.PbFieldType.OY, protoName: 'systemFwVersion')
    ..a<$core.List<$core.int>>(3, _omitFieldNames ? '' : 'deviceName', $pb.PbFieldType.OY, protoName: 'deviceName')
    ..a<$core.List<$core.int>>(6, _omitFieldNames ? '' : 'serialNumber', $pb.PbFieldType.OY, protoName: 'serialNumber')
    ..a<$core.List<$core.int>>(7, _omitFieldNames ? '' : 'systemHwRevision', $pb.PbFieldType.OY, protoName: 'systemHwRevision')
    ..pc<DevInfoPage_DeviceCapabilities>(8, _omitFieldNames ? '' : 'deviceCapabilities', $pb.PbFieldType.PM, protoName: 'deviceCapabilities', subBuilder: DevInfoPage_DeviceCapabilities.create)
    ..a<$core.int>(9, _omitFieldNames ? '' : 'manufacturerId', $pb.PbFieldType.OU3, protoName: 'manufacturerId')
    ..a<$core.int>(10, _omitFieldNames ? '' : 'productId', $pb.PbFieldType.OU3, protoName: 'productId')
    ..a<$core.List<$core.int>>(11, _omitFieldNames ? '' : 'deviceUid', $pb.PbFieldType.OY, protoName: 'deviceUid')
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DevInfoPage clone() => DevInfoPage()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DevInfoPage copyWith(void Function(DevInfoPage) updates) => super.copyWith((message) => updates(message as DevInfoPage)) as DevInfoPage;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DevInfoPage create() => DevInfoPage._();
  DevInfoPage createEmptyInstance() => create();
  static $pb.PbList<DevInfoPage> createRepeated() => $pb.PbList<DevInfoPage>();
  @$core.pragma('dart2js:noInline')
  static DevInfoPage getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DevInfoPage>(create);
  static DevInfoPage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get protocolVersion => $_getIZ(0);
  @$pb.TagNumber(1)
  set protocolVersion($core.int v) { $_setUnsignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasProtocolVersion() => $_has(0);
  @$pb.TagNumber(1)
  void clearProtocolVersion() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get systemFwVersion => $_getN(1);
  @$pb.TagNumber(2)
  set systemFwVersion($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasSystemFwVersion() => $_has(1);
  @$pb.TagNumber(2)
  void clearSystemFwVersion() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get deviceName => $_getN(2);
  @$pb.TagNumber(3)
  set deviceName($core.List<$core.int> v) { $_setBytes(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasDeviceName() => $_has(2);
  @$pb.TagNumber(3)
  void clearDeviceName() => clearField(3);

  @$pb.TagNumber(6)
  $core.List<$core.int> get serialNumber => $_getN(3);
  @$pb.TagNumber(6)
  set serialNumber($core.List<$core.int> v) { $_setBytes(3, v); }
  @$pb.TagNumber(6)
  $core.bool hasSerialNumber() => $_has(3);
  @$pb.TagNumber(6)
  void clearSerialNumber() => clearField(6);

  @$pb.TagNumber(7)
  $core.List<$core.int> get systemHwRevision => $_getN(4);
  @$pb.TagNumber(7)
  set systemHwRevision($core.List<$core.int> v) { $_setBytes(4, v); }
  @$pb.TagNumber(7)
  $core.bool hasSystemHwRevision() => $_has(4);
  @$pb.TagNumber(7)
  void clearSystemHwRevision() => clearField(7);

  @$pb.TagNumber(8)
  $core.List<DevInfoPage_DeviceCapabilities> get deviceCapabilities => $_getList(5);

  @$pb.TagNumber(9)
  $core.int get manufacturerId => $_getIZ(6);
  @$pb.TagNumber(9)
  set manufacturerId($core.int v) { $_setUnsignedInt32(6, v); }
  @$pb.TagNumber(9)
  $core.bool hasManufacturerId() => $_has(6);
  @$pb.TagNumber(9)
  void clearManufacturerId() => clearField(9);

  @$pb.TagNumber(10)
  $core.int get productId => $_getIZ(7);
  @$pb.TagNumber(10)
  set productId($core.int v) { $_setUnsignedInt32(7, v); }
  @$pb.TagNumber(10)
  $core.bool hasProductId() => $_has(7);
  @$pb.TagNumber(10)
  void clearProductId() => clearField(10);

  @$pb.TagNumber(11)
  $core.List<$core.int> get deviceUid => $_getN(8);
  @$pb.TagNumber(11)
  set deviceUid($core.List<$core.int> v) { $_setBytes(8, v); }
  @$pb.TagNumber(11)
  $core.bool hasDeviceUid() => $_has(8);
  @$pb.TagNumber(11)
  void clearDeviceUid() => clearField(11);
}

/// Page ID 0x010
class ClientServerCfgPage extends $pb.GeneratedMessage {
  factory ClientServerCfgPage({
    $core.int? notifications,
  }) {
    final $result = create();
    if (notifications != null) {
      $result.notifications = notifications;
    }
    return $result;
  }
  ClientServerCfgPage._() : super();
  factory ClientServerCfgPage.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ClientServerCfgPage.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ClientServerCfgPage', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'notifications', $pb.PbFieldType.OU3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ClientServerCfgPage clone() => ClientServerCfgPage()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ClientServerCfgPage copyWith(void Function(ClientServerCfgPage) updates) => super.copyWith((message) => updates(message as ClientServerCfgPage)) as ClientServerCfgPage;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClientServerCfgPage create() => ClientServerCfgPage._();
  ClientServerCfgPage createEmptyInstance() => create();
  static $pb.PbList<ClientServerCfgPage> createRepeated() => $pb.PbList<ClientServerCfgPage>();
  @$core.pragma('dart2js:noInline')
  static ClientServerCfgPage getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ClientServerCfgPage>(create);
  static ClientServerCfgPage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get notifications => $_getIZ(0);
  @$pb.TagNumber(1)
  set notifications($core.int v) { $_setUnsignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasNotifications() => $_has(0);
  @$pb.TagNumber(1)
  void clearNotifications() => clearField(1);
}

/// Page ID 0x020
class TrainerSimulationParam extends $pb.GeneratedMessage {
  factory TrainerSimulationParam({
    $core.int? configuredResistance,
    $core.int? ergPower,
    $core.int? averagingWindow,
    $core.int? simulatedWind,
    $core.int? simulatedGrade,
    $core.int? simulatedRealGearRatio,
    $core.int? simulatedVirtualGearRatio,
    $core.int? simulatedCW,
    $core.int? simulatedWheelDiameter,
    $core.int? simulatedBikeMass,
    $core.int? simulatedRiderMass,
    $core.int? simulatedCRR,
    $core.int? simulatedFrontalArea,
    $core.int? simulatedEBrake,
  }) {
    final $result = create();
    if (configuredResistance != null) {
      $result.configuredResistance = configuredResistance;
    }
    if (ergPower != null) {
      $result.ergPower = ergPower;
    }
    if (averagingWindow != null) {
      $result.averagingWindow = averagingWindow;
    }
    if (simulatedWind != null) {
      $result.simulatedWind = simulatedWind;
    }
    if (simulatedGrade != null) {
      $result.simulatedGrade = simulatedGrade;
    }
    if (simulatedRealGearRatio != null) {
      $result.simulatedRealGearRatio = simulatedRealGearRatio;
    }
    if (simulatedVirtualGearRatio != null) {
      $result.simulatedVirtualGearRatio = simulatedVirtualGearRatio;
    }
    if (simulatedCW != null) {
      $result.simulatedCW = simulatedCW;
    }
    if (simulatedWheelDiameter != null) {
      $result.simulatedWheelDiameter = simulatedWheelDiameter;
    }
    if (simulatedBikeMass != null) {
      $result.simulatedBikeMass = simulatedBikeMass;
    }
    if (simulatedRiderMass != null) {
      $result.simulatedRiderMass = simulatedRiderMass;
    }
    if (simulatedCRR != null) {
      $result.simulatedCRR = simulatedCRR;
    }
    if (simulatedFrontalArea != null) {
      $result.simulatedFrontalArea = simulatedFrontalArea;
    }
    if (simulatedEBrake != null) {
      $result.simulatedEBrake = simulatedEBrake;
    }
    return $result;
  }
  TrainerSimulationParam._() : super();
  factory TrainerSimulationParam.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory TrainerSimulationParam.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'TrainerSimulationParam', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'configuredResistance', $pb.PbFieldType.OU3, protoName: 'configuredResistance')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'ergPower', $pb.PbFieldType.OU3, protoName: 'ergPower')
    ..a<$core.int>(3, _omitFieldNames ? '' : 'averagingWindow', $pb.PbFieldType.OU3, protoName: 'averagingWindow')
    ..a<$core.int>(4, _omitFieldNames ? '' : 'simulatedWind', $pb.PbFieldType.OS3, protoName: 'simulatedWind')
    ..a<$core.int>(5, _omitFieldNames ? '' : 'simulatedGrade', $pb.PbFieldType.OS3, protoName: 'simulatedGrade')
    ..a<$core.int>(6, _omitFieldNames ? '' : 'simulatedRealGearRatio', $pb.PbFieldType.OU3, protoName: 'simulatedRealGearRatio')
    ..a<$core.int>(7, _omitFieldNames ? '' : 'simulatedVirtualGearRatio', $pb.PbFieldType.OU3, protoName: 'simulatedVirtualGearRatio')
    ..a<$core.int>(8, _omitFieldNames ? '' : 'simulatedCW', $pb.PbFieldType.OU3, protoName: 'simulatedCW')
    ..a<$core.int>(9, _omitFieldNames ? '' : 'simulatedWheelDiameter', $pb.PbFieldType.OU3, protoName: 'simulatedWheelDiameter')
    ..a<$core.int>(10, _omitFieldNames ? '' : 'simulatedBikeMass', $pb.PbFieldType.OU3, protoName: 'simulatedBikeMass')
    ..a<$core.int>(11, _omitFieldNames ? '' : 'simulatedRiderMass', $pb.PbFieldType.OU3, protoName: 'simulatedRiderMass')
    ..a<$core.int>(12, _omitFieldNames ? '' : 'simulatedCRR', $pb.PbFieldType.OU3, protoName: 'simulatedCRR')
    ..a<$core.int>(13, _omitFieldNames ? '' : 'simulatedFrontalArea', $pb.PbFieldType.OU3, protoName: 'simulatedFrontalArea')
    ..a<$core.int>(14, _omitFieldNames ? '' : 'simulatedEBrake', $pb.PbFieldType.OU3, protoName: 'simulatedEBrake')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  TrainerSimulationParam clone() => TrainerSimulationParam()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  TrainerSimulationParam copyWith(void Function(TrainerSimulationParam) updates) => super.copyWith((message) => updates(message as TrainerSimulationParam)) as TrainerSimulationParam;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TrainerSimulationParam create() => TrainerSimulationParam._();
  TrainerSimulationParam createEmptyInstance() => create();
  static $pb.PbList<TrainerSimulationParam> createRepeated() => $pb.PbList<TrainerSimulationParam>();
  @$core.pragma('dart2js:noInline')
  static TrainerSimulationParam getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TrainerSimulationParam>(create);
  static TrainerSimulationParam? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get configuredResistance => $_getIZ(0);
  @$pb.TagNumber(1)
  set configuredResistance($core.int v) { $_setUnsignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasConfiguredResistance() => $_has(0);
  @$pb.TagNumber(1)
  void clearConfiguredResistance() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get ergPower => $_getIZ(1);
  @$pb.TagNumber(2)
  set ergPower($core.int v) { $_setUnsignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasErgPower() => $_has(1);
  @$pb.TagNumber(2)
  void clearErgPower() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get averagingWindow => $_getIZ(2);
  @$pb.TagNumber(3)
  set averagingWindow($core.int v) { $_setUnsignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasAveragingWindow() => $_has(2);
  @$pb.TagNumber(3)
  void clearAveragingWindow() => clearField(3);

  @$pb.TagNumber(4)
  $core.int get simulatedWind => $_getIZ(3);
  @$pb.TagNumber(4)
  set simulatedWind($core.int v) { $_setSignedInt32(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasSimulatedWind() => $_has(3);
  @$pb.TagNumber(4)
  void clearSimulatedWind() => clearField(4);

  @$pb.TagNumber(5)
  $core.int get simulatedGrade => $_getIZ(4);
  @$pb.TagNumber(5)
  set simulatedGrade($core.int v) { $_setSignedInt32(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasSimulatedGrade() => $_has(4);
  @$pb.TagNumber(5)
  void clearSimulatedGrade() => clearField(5);

  @$pb.TagNumber(6)
  $core.int get simulatedRealGearRatio => $_getIZ(5);
  @$pb.TagNumber(6)
  set simulatedRealGearRatio($core.int v) { $_setUnsignedInt32(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasSimulatedRealGearRatio() => $_has(5);
  @$pb.TagNumber(6)
  void clearSimulatedRealGearRatio() => clearField(6);

  @$pb.TagNumber(7)
  $core.int get simulatedVirtualGearRatio => $_getIZ(6);
  @$pb.TagNumber(7)
  set simulatedVirtualGearRatio($core.int v) { $_setUnsignedInt32(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasSimulatedVirtualGearRatio() => $_has(6);
  @$pb.TagNumber(7)
  void clearSimulatedVirtualGearRatio() => clearField(7);

  @$pb.TagNumber(8)
  $core.int get simulatedCW => $_getIZ(7);
  @$pb.TagNumber(8)
  set simulatedCW($core.int v) { $_setUnsignedInt32(7, v); }
  @$pb.TagNumber(8)
  $core.bool hasSimulatedCW() => $_has(7);
  @$pb.TagNumber(8)
  void clearSimulatedCW() => clearField(8);

  @$pb.TagNumber(9)
  $core.int get simulatedWheelDiameter => $_getIZ(8);
  @$pb.TagNumber(9)
  set simulatedWheelDiameter($core.int v) { $_setUnsignedInt32(8, v); }
  @$pb.TagNumber(9)
  $core.bool hasSimulatedWheelDiameter() => $_has(8);
  @$pb.TagNumber(9)
  void clearSimulatedWheelDiameter() => clearField(9);

  @$pb.TagNumber(10)
  $core.int get simulatedBikeMass => $_getIZ(9);
  @$pb.TagNumber(10)
  set simulatedBikeMass($core.int v) { $_setUnsignedInt32(9, v); }
  @$pb.TagNumber(10)
  $core.bool hasSimulatedBikeMass() => $_has(9);
  @$pb.TagNumber(10)
  void clearSimulatedBikeMass() => clearField(10);

  @$pb.TagNumber(11)
  $core.int get simulatedRiderMass => $_getIZ(10);
  @$pb.TagNumber(11)
  set simulatedRiderMass($core.int v) { $_setUnsignedInt32(10, v); }
  @$pb.TagNumber(11)
  $core.bool hasSimulatedRiderMass() => $_has(10);
  @$pb.TagNumber(11)
  void clearSimulatedRiderMass() => clearField(11);

  @$pb.TagNumber(12)
  $core.int get simulatedCRR => $_getIZ(11);
  @$pb.TagNumber(12)
  set simulatedCRR($core.int v) { $_setUnsignedInt32(11, v); }
  @$pb.TagNumber(12)
  $core.bool hasSimulatedCRR() => $_has(11);
  @$pb.TagNumber(12)
  void clearSimulatedCRR() => clearField(12);

  @$pb.TagNumber(13)
  $core.int get simulatedFrontalArea => $_getIZ(12);
  @$pb.TagNumber(13)
  set simulatedFrontalArea($core.int v) { $_setUnsignedInt32(12, v); }
  @$pb.TagNumber(13)
  $core.bool hasSimulatedFrontalArea() => $_has(12);
  @$pb.TagNumber(13)
  void clearSimulatedFrontalArea() => clearField(13);

  @$pb.TagNumber(14)
  $core.int get simulatedEBrake => $_getIZ(13);
  @$pb.TagNumber(14)
  set simulatedEBrake($core.int v) { $_setUnsignedInt32(13, v); }
  @$pb.TagNumber(14)
  $core.bool hasSimulatedEBrake() => $_has(13);
  @$pb.TagNumber(14)
  void clearSimulatedEBrake() => clearField(14);
}

/// Page ID 0x022
class TrainerOptions extends $pb.GeneratedMessage {
  factory TrainerOptions({
    $core.bool? highSpeedDataEnabled,
    $core.bool? ergPowerSmoothingEnabled,
    $core.int? virtualShiftingMode,
  }) {
    final $result = create();
    if (highSpeedDataEnabled != null) {
      $result.highSpeedDataEnabled = highSpeedDataEnabled;
    }
    if (ergPowerSmoothingEnabled != null) {
      $result.ergPowerSmoothingEnabled = ergPowerSmoothingEnabled;
    }
    if (virtualShiftingMode != null) {
      $result.virtualShiftingMode = virtualShiftingMode;
    }
    return $result;
  }
  TrainerOptions._() : super();
  factory TrainerOptions.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory TrainerOptions.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'TrainerOptions', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'highSpeedDataEnabled', protoName: 'highSpeedDataEnabled')
    ..aOB(2, _omitFieldNames ? '' : 'ergPowerSmoothingEnabled', protoName: 'ergPowerSmoothingEnabled')
    ..a<$core.int>(3, _omitFieldNames ? '' : 'virtualShiftingMode', $pb.PbFieldType.OU3, protoName: 'virtualShiftingMode')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  TrainerOptions clone() => TrainerOptions()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  TrainerOptions copyWith(void Function(TrainerOptions) updates) => super.copyWith((message) => updates(message as TrainerOptions)) as TrainerOptions;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TrainerOptions create() => TrainerOptions._();
  TrainerOptions createEmptyInstance() => create();
  static $pb.PbList<TrainerOptions> createRepeated() => $pb.PbList<TrainerOptions>();
  @$core.pragma('dart2js:noInline')
  static TrainerOptions getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TrainerOptions>(create);
  static TrainerOptions? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get highSpeedDataEnabled => $_getBF(0);
  @$pb.TagNumber(1)
  set highSpeedDataEnabled($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasHighSpeedDataEnabled() => $_has(0);
  @$pb.TagNumber(1)
  void clearHighSpeedDataEnabled() => clearField(1);

  @$pb.TagNumber(2)
  $core.bool get ergPowerSmoothingEnabled => $_getBF(1);
  @$pb.TagNumber(2)
  set ergPowerSmoothingEnabled($core.bool v) { $_setBool(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasErgPowerSmoothingEnabled() => $_has(1);
  @$pb.TagNumber(2)
  void clearErgPowerSmoothingEnabled() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get virtualShiftingMode => $_getIZ(2);
  @$pb.TagNumber(3)
  set virtualShiftingMode($core.int v) { $_setUnsignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasVirtualShiftingMode() => $_has(2);
  @$pb.TagNumber(3)
  void clearVirtualShiftingMode() => clearField(3);
}

/// Page ID 0x020 and 0x022   (Get Response)
class TrainerCfgPage extends $pb.GeneratedMessage {
  factory TrainerCfgPage({
    TrainerMode? trainerMode,
    $core.int? configuredResistance,
    $core.int? ergPower,
    $core.int? averagingWindow,
    $core.int? simulatedWind,
    $core.int? simulatedGrade,
    $core.int? simulatedRealGearRatio,
    $core.int? simulatedVirtualGearRatio,
    $core.int? simulatedCW,
    $core.int? simulatedWheelDiameter,
    $core.int? simulatedBikeMass,
    $core.int? simulatedRiderMass,
    $core.int? simulatedCRR,
    $core.int? simulatedFrontalArea,
    $core.int? simulatedEBrake,
    $core.bool? highSpeedDataEnabled,
    $core.bool? ergPowerSmoothingEnabled,
    $core.int? virtualShiftingMode,
  }) {
    final $result = create();
    if (trainerMode != null) {
      $result.trainerMode = trainerMode;
    }
    if (configuredResistance != null) {
      $result.configuredResistance = configuredResistance;
    }
    if (ergPower != null) {
      $result.ergPower = ergPower;
    }
    if (averagingWindow != null) {
      $result.averagingWindow = averagingWindow;
    }
    if (simulatedWind != null) {
      $result.simulatedWind = simulatedWind;
    }
    if (simulatedGrade != null) {
      $result.simulatedGrade = simulatedGrade;
    }
    if (simulatedRealGearRatio != null) {
      $result.simulatedRealGearRatio = simulatedRealGearRatio;
    }
    if (simulatedVirtualGearRatio != null) {
      $result.simulatedVirtualGearRatio = simulatedVirtualGearRatio;
    }
    if (simulatedCW != null) {
      $result.simulatedCW = simulatedCW;
    }
    if (simulatedWheelDiameter != null) {
      $result.simulatedWheelDiameter = simulatedWheelDiameter;
    }
    if (simulatedBikeMass != null) {
      $result.simulatedBikeMass = simulatedBikeMass;
    }
    if (simulatedRiderMass != null) {
      $result.simulatedRiderMass = simulatedRiderMass;
    }
    if (simulatedCRR != null) {
      $result.simulatedCRR = simulatedCRR;
    }
    if (simulatedFrontalArea != null) {
      $result.simulatedFrontalArea = simulatedFrontalArea;
    }
    if (simulatedEBrake != null) {
      $result.simulatedEBrake = simulatedEBrake;
    }
    if (highSpeedDataEnabled != null) {
      $result.highSpeedDataEnabled = highSpeedDataEnabled;
    }
    if (ergPowerSmoothingEnabled != null) {
      $result.ergPowerSmoothingEnabled = ergPowerSmoothingEnabled;
    }
    if (virtualShiftingMode != null) {
      $result.virtualShiftingMode = virtualShiftingMode;
    }
    return $result;
  }
  TrainerCfgPage._() : super();
  factory TrainerCfgPage.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory TrainerCfgPage.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'TrainerCfgPage', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..e<TrainerMode>(1, _omitFieldNames ? '' : 'trainerMode', $pb.PbFieldType.OE, protoName: 'trainerMode', defaultOrMaker: TrainerMode.MODE_UNKNOWN, valueOf: TrainerMode.valueOf, enumValues: TrainerMode.values)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'configuredResistance', $pb.PbFieldType.OU3, protoName: 'configuredResistance')
    ..a<$core.int>(3, _omitFieldNames ? '' : 'ergPower', $pb.PbFieldType.OU3, protoName: 'ergPower')
    ..a<$core.int>(4, _omitFieldNames ? '' : 'averagingWindow', $pb.PbFieldType.OU3, protoName: 'averagingWindow')
    ..a<$core.int>(5, _omitFieldNames ? '' : 'simulatedWind', $pb.PbFieldType.OS3, protoName: 'simulatedWind')
    ..a<$core.int>(6, _omitFieldNames ? '' : 'simulatedGrade', $pb.PbFieldType.OS3, protoName: 'simulatedGrade')
    ..a<$core.int>(7, _omitFieldNames ? '' : 'simulatedRealGearRatio', $pb.PbFieldType.OU3, protoName: 'simulatedRealGearRatio')
    ..a<$core.int>(8, _omitFieldNames ? '' : 'simulatedVirtualGearRatio', $pb.PbFieldType.OU3, protoName: 'simulatedVirtualGearRatio')
    ..a<$core.int>(9, _omitFieldNames ? '' : 'simulatedCW', $pb.PbFieldType.OU3, protoName: 'simulatedCW')
    ..a<$core.int>(10, _omitFieldNames ? '' : 'simulatedWheelDiameter', $pb.PbFieldType.OU3, protoName: 'simulatedWheelDiameter')
    ..a<$core.int>(11, _omitFieldNames ? '' : 'simulatedBikeMass', $pb.PbFieldType.OU3, protoName: 'simulatedBikeMass')
    ..a<$core.int>(12, _omitFieldNames ? '' : 'simulatedRiderMass', $pb.PbFieldType.OU3, protoName: 'simulatedRiderMass')
    ..a<$core.int>(13, _omitFieldNames ? '' : 'simulatedCRR', $pb.PbFieldType.OU3, protoName: 'simulatedCRR')
    ..a<$core.int>(14, _omitFieldNames ? '' : 'simulatedFrontalArea', $pb.PbFieldType.OU3, protoName: 'simulatedFrontalArea')
    ..a<$core.int>(15, _omitFieldNames ? '' : 'simulatedEBrake', $pb.PbFieldType.OU3, protoName: 'simulatedEBrake')
    ..aOB(16, _omitFieldNames ? '' : 'highSpeedDataEnabled', protoName: 'highSpeedDataEnabled')
    ..aOB(17, _omitFieldNames ? '' : 'ergPowerSmoothingEnabled', protoName: 'ergPowerSmoothingEnabled')
    ..a<$core.int>(18, _omitFieldNames ? '' : 'virtualShiftingMode', $pb.PbFieldType.OU3, protoName: 'virtualShiftingMode')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  TrainerCfgPage clone() => TrainerCfgPage()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  TrainerCfgPage copyWith(void Function(TrainerCfgPage) updates) => super.copyWith((message) => updates(message as TrainerCfgPage)) as TrainerCfgPage;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TrainerCfgPage create() => TrainerCfgPage._();
  TrainerCfgPage createEmptyInstance() => create();
  static $pb.PbList<TrainerCfgPage> createRepeated() => $pb.PbList<TrainerCfgPage>();
  @$core.pragma('dart2js:noInline')
  static TrainerCfgPage getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TrainerCfgPage>(create);
  static TrainerCfgPage? _defaultInstance;

  @$pb.TagNumber(1)
  TrainerMode get trainerMode => $_getN(0);
  @$pb.TagNumber(1)
  set trainerMode(TrainerMode v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasTrainerMode() => $_has(0);
  @$pb.TagNumber(1)
  void clearTrainerMode() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get configuredResistance => $_getIZ(1);
  @$pb.TagNumber(2)
  set configuredResistance($core.int v) { $_setUnsignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasConfiguredResistance() => $_has(1);
  @$pb.TagNumber(2)
  void clearConfiguredResistance() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get ergPower => $_getIZ(2);
  @$pb.TagNumber(3)
  set ergPower($core.int v) { $_setUnsignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasErgPower() => $_has(2);
  @$pb.TagNumber(3)
  void clearErgPower() => clearField(3);

  @$pb.TagNumber(4)
  $core.int get averagingWindow => $_getIZ(3);
  @$pb.TagNumber(4)
  set averagingWindow($core.int v) { $_setUnsignedInt32(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasAveragingWindow() => $_has(3);
  @$pb.TagNumber(4)
  void clearAveragingWindow() => clearField(4);

  @$pb.TagNumber(5)
  $core.int get simulatedWind => $_getIZ(4);
  @$pb.TagNumber(5)
  set simulatedWind($core.int v) { $_setSignedInt32(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasSimulatedWind() => $_has(4);
  @$pb.TagNumber(5)
  void clearSimulatedWind() => clearField(5);

  @$pb.TagNumber(6)
  $core.int get simulatedGrade => $_getIZ(5);
  @$pb.TagNumber(6)
  set simulatedGrade($core.int v) { $_setSignedInt32(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasSimulatedGrade() => $_has(5);
  @$pb.TagNumber(6)
  void clearSimulatedGrade() => clearField(6);

  @$pb.TagNumber(7)
  $core.int get simulatedRealGearRatio => $_getIZ(6);
  @$pb.TagNumber(7)
  set simulatedRealGearRatio($core.int v) { $_setUnsignedInt32(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasSimulatedRealGearRatio() => $_has(6);
  @$pb.TagNumber(7)
  void clearSimulatedRealGearRatio() => clearField(7);

  @$pb.TagNumber(8)
  $core.int get simulatedVirtualGearRatio => $_getIZ(7);
  @$pb.TagNumber(8)
  set simulatedVirtualGearRatio($core.int v) { $_setUnsignedInt32(7, v); }
  @$pb.TagNumber(8)
  $core.bool hasSimulatedVirtualGearRatio() => $_has(7);
  @$pb.TagNumber(8)
  void clearSimulatedVirtualGearRatio() => clearField(8);

  @$pb.TagNumber(9)
  $core.int get simulatedCW => $_getIZ(8);
  @$pb.TagNumber(9)
  set simulatedCW($core.int v) { $_setUnsignedInt32(8, v); }
  @$pb.TagNumber(9)
  $core.bool hasSimulatedCW() => $_has(8);
  @$pb.TagNumber(9)
  void clearSimulatedCW() => clearField(9);

  @$pb.TagNumber(10)
  $core.int get simulatedWheelDiameter => $_getIZ(9);
  @$pb.TagNumber(10)
  set simulatedWheelDiameter($core.int v) { $_setUnsignedInt32(9, v); }
  @$pb.TagNumber(10)
  $core.bool hasSimulatedWheelDiameter() => $_has(9);
  @$pb.TagNumber(10)
  void clearSimulatedWheelDiameter() => clearField(10);

  @$pb.TagNumber(11)
  $core.int get simulatedBikeMass => $_getIZ(10);
  @$pb.TagNumber(11)
  set simulatedBikeMass($core.int v) { $_setUnsignedInt32(10, v); }
  @$pb.TagNumber(11)
  $core.bool hasSimulatedBikeMass() => $_has(10);
  @$pb.TagNumber(11)
  void clearSimulatedBikeMass() => clearField(11);

  @$pb.TagNumber(12)
  $core.int get simulatedRiderMass => $_getIZ(11);
  @$pb.TagNumber(12)
  set simulatedRiderMass($core.int v) { $_setUnsignedInt32(11, v); }
  @$pb.TagNumber(12)
  $core.bool hasSimulatedRiderMass() => $_has(11);
  @$pb.TagNumber(12)
  void clearSimulatedRiderMass() => clearField(12);

  @$pb.TagNumber(13)
  $core.int get simulatedCRR => $_getIZ(12);
  @$pb.TagNumber(13)
  set simulatedCRR($core.int v) { $_setUnsignedInt32(12, v); }
  @$pb.TagNumber(13)
  $core.bool hasSimulatedCRR() => $_has(12);
  @$pb.TagNumber(13)
  void clearSimulatedCRR() => clearField(13);

  @$pb.TagNumber(14)
  $core.int get simulatedFrontalArea => $_getIZ(13);
  @$pb.TagNumber(14)
  set simulatedFrontalArea($core.int v) { $_setUnsignedInt32(13, v); }
  @$pb.TagNumber(14)
  $core.bool hasSimulatedFrontalArea() => $_has(13);
  @$pb.TagNumber(14)
  void clearSimulatedFrontalArea() => clearField(14);

  @$pb.TagNumber(15)
  $core.int get simulatedEBrake => $_getIZ(14);
  @$pb.TagNumber(15)
  set simulatedEBrake($core.int v) { $_setUnsignedInt32(14, v); }
  @$pb.TagNumber(15)
  $core.bool hasSimulatedEBrake() => $_has(14);
  @$pb.TagNumber(15)
  void clearSimulatedEBrake() => clearField(15);

  @$pb.TagNumber(16)
  $core.bool get highSpeedDataEnabled => $_getBF(15);
  @$pb.TagNumber(16)
  set highSpeedDataEnabled($core.bool v) { $_setBool(15, v); }
  @$pb.TagNumber(16)
  $core.bool hasHighSpeedDataEnabled() => $_has(15);
  @$pb.TagNumber(16)
  void clearHighSpeedDataEnabled() => clearField(16);

  @$pb.TagNumber(17)
  $core.bool get ergPowerSmoothingEnabled => $_getBF(16);
  @$pb.TagNumber(17)
  set ergPowerSmoothingEnabled($core.bool v) { $_setBool(16, v); }
  @$pb.TagNumber(17)
  $core.bool hasErgPowerSmoothingEnabled() => $_has(16);
  @$pb.TagNumber(17)
  void clearErgPowerSmoothingEnabled() => clearField(17);

  @$pb.TagNumber(18)
  $core.int get virtualShiftingMode => $_getIZ(17);
  @$pb.TagNumber(18)
  set virtualShiftingMode($core.int v) { $_setUnsignedInt32(17, v); }
  @$pb.TagNumber(18)
  $core.bool hasVirtualShiftingMode() => $_has(17);
  @$pb.TagNumber(18)
  void clearVirtualShiftingMode() => clearField(18);
}

/// Page ID 0x021
class TrainerGearIndexConfigPage extends $pb.GeneratedMessage {
  factory TrainerGearIndexConfigPage({
    $core.int? frontGearIdx,
    $core.int? frontGearIdxMax,
    $core.int? frontGearIdxMin,
    $core.int? rearGearIdx,
    $core.int? rearGearIdxMax,
    $core.int? rearGearIdxMin,
  }) {
    final $result = create();
    if (frontGearIdx != null) {
      $result.frontGearIdx = frontGearIdx;
    }
    if (frontGearIdxMax != null) {
      $result.frontGearIdxMax = frontGearIdxMax;
    }
    if (frontGearIdxMin != null) {
      $result.frontGearIdxMin = frontGearIdxMin;
    }
    if (rearGearIdx != null) {
      $result.rearGearIdx = rearGearIdx;
    }
    if (rearGearIdxMax != null) {
      $result.rearGearIdxMax = rearGearIdxMax;
    }
    if (rearGearIdxMin != null) {
      $result.rearGearIdxMin = rearGearIdxMin;
    }
    return $result;
  }
  TrainerGearIndexConfigPage._() : super();
  factory TrainerGearIndexConfigPage.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory TrainerGearIndexConfigPage.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'TrainerGearIndexConfigPage', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'frontGearIdx', $pb.PbFieldType.OU3, protoName: 'frontGearIdx')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'frontGearIdxMax', $pb.PbFieldType.OU3, protoName: 'frontGearIdxMax')
    ..a<$core.int>(3, _omitFieldNames ? '' : 'frontGearIdxMin', $pb.PbFieldType.OU3, protoName: 'frontGearIdxMin')
    ..a<$core.int>(4, _omitFieldNames ? '' : 'rearGearIdx', $pb.PbFieldType.OU3, protoName: 'rearGearIdx')
    ..a<$core.int>(5, _omitFieldNames ? '' : 'rearGearIdxMax', $pb.PbFieldType.OU3, protoName: 'rearGearIdxMax')
    ..a<$core.int>(6, _omitFieldNames ? '' : 'rearGearIdxMin', $pb.PbFieldType.OU3, protoName: 'rearGearIdxMin')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  TrainerGearIndexConfigPage clone() => TrainerGearIndexConfigPage()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  TrainerGearIndexConfigPage copyWith(void Function(TrainerGearIndexConfigPage) updates) => super.copyWith((message) => updates(message as TrainerGearIndexConfigPage)) as TrainerGearIndexConfigPage;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TrainerGearIndexConfigPage create() => TrainerGearIndexConfigPage._();
  TrainerGearIndexConfigPage createEmptyInstance() => create();
  static $pb.PbList<TrainerGearIndexConfigPage> createRepeated() => $pb.PbList<TrainerGearIndexConfigPage>();
  @$core.pragma('dart2js:noInline')
  static TrainerGearIndexConfigPage getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TrainerGearIndexConfigPage>(create);
  static TrainerGearIndexConfigPage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get frontGearIdx => $_getIZ(0);
  @$pb.TagNumber(1)
  set frontGearIdx($core.int v) { $_setUnsignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasFrontGearIdx() => $_has(0);
  @$pb.TagNumber(1)
  void clearFrontGearIdx() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get frontGearIdxMax => $_getIZ(1);
  @$pb.TagNumber(2)
  set frontGearIdxMax($core.int v) { $_setUnsignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasFrontGearIdxMax() => $_has(1);
  @$pb.TagNumber(2)
  void clearFrontGearIdxMax() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get frontGearIdxMin => $_getIZ(2);
  @$pb.TagNumber(3)
  set frontGearIdxMin($core.int v) { $_setUnsignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasFrontGearIdxMin() => $_has(2);
  @$pb.TagNumber(3)
  void clearFrontGearIdxMin() => clearField(3);

  @$pb.TagNumber(4)
  $core.int get rearGearIdx => $_getIZ(3);
  @$pb.TagNumber(4)
  set rearGearIdx($core.int v) { $_setUnsignedInt32(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasRearGearIdx() => $_has(3);
  @$pb.TagNumber(4)
  void clearRearGearIdx() => clearField(4);

  @$pb.TagNumber(5)
  $core.int get rearGearIdxMax => $_getIZ(4);
  @$pb.TagNumber(5)
  set rearGearIdxMax($core.int v) { $_setUnsignedInt32(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasRearGearIdxMax() => $_has(4);
  @$pb.TagNumber(5)
  void clearRearGearIdxMax() => clearField(5);

  @$pb.TagNumber(6)
  $core.int get rearGearIdxMin => $_getIZ(5);
  @$pb.TagNumber(6)
  set rearGearIdxMin($core.int v) { $_setUnsignedInt32(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasRearGearIdxMin() => $_has(5);
  @$pb.TagNumber(6)
  void clearRearGearIdxMin() => clearField(6);
}

/// Page ID 0x023
class DeviceTiltConfigPage extends $pb.GeneratedMessage {
  factory DeviceTiltConfigPage({
    $core.bool? tiltEnabled,
    $core.int? tiltGradientMin,
    $core.int? tiltGradientMax,
    $core.int? tiltGradient,
  }) {
    final $result = create();
    if (tiltEnabled != null) {
      $result.tiltEnabled = tiltEnabled;
    }
    if (tiltGradientMin != null) {
      $result.tiltGradientMin = tiltGradientMin;
    }
    if (tiltGradientMax != null) {
      $result.tiltGradientMax = tiltGradientMax;
    }
    if (tiltGradient != null) {
      $result.tiltGradient = tiltGradient;
    }
    return $result;
  }
  DeviceTiltConfigPage._() : super();
  factory DeviceTiltConfigPage.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DeviceTiltConfigPage.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DeviceTiltConfigPage', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'tiltEnabled', protoName: 'tiltEnabled')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'tiltGradientMin', $pb.PbFieldType.OS3, protoName: 'tiltGradientMin')
    ..a<$core.int>(3, _omitFieldNames ? '' : 'tiltGradientMax', $pb.PbFieldType.OS3, protoName: 'tiltGradientMax')
    ..a<$core.int>(4, _omitFieldNames ? '' : 'tiltGradient', $pb.PbFieldType.OS3, protoName: 'tiltGradient')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DeviceTiltConfigPage clone() => DeviceTiltConfigPage()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DeviceTiltConfigPage copyWith(void Function(DeviceTiltConfigPage) updates) => super.copyWith((message) => updates(message as DeviceTiltConfigPage)) as DeviceTiltConfigPage;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeviceTiltConfigPage create() => DeviceTiltConfigPage._();
  DeviceTiltConfigPage createEmptyInstance() => create();
  static $pb.PbList<DeviceTiltConfigPage> createRepeated() => $pb.PbList<DeviceTiltConfigPage>();
  @$core.pragma('dart2js:noInline')
  static DeviceTiltConfigPage getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DeviceTiltConfigPage>(create);
  static DeviceTiltConfigPage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get tiltEnabled => $_getBF(0);
  @$pb.TagNumber(1)
  set tiltEnabled($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasTiltEnabled() => $_has(0);
  @$pb.TagNumber(1)
  void clearTiltEnabled() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get tiltGradientMin => $_getIZ(1);
  @$pb.TagNumber(2)
  set tiltGradientMin($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasTiltGradientMin() => $_has(1);
  @$pb.TagNumber(2)
  void clearTiltGradientMin() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get tiltGradientMax => $_getIZ(2);
  @$pb.TagNumber(3)
  set tiltGradientMax($core.int v) { $_setSignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasTiltGradientMax() => $_has(2);
  @$pb.TagNumber(3)
  void clearTiltGradientMax() => clearField(3);

  @$pb.TagNumber(4)
  $core.int get tiltGradient => $_getIZ(3);
  @$pb.TagNumber(4)
  set tiltGradient($core.int v) { $_setSignedInt32(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasTiltGradient() => $_has(3);
  @$pb.TagNumber(4)
  void clearTiltGradient() => clearField(4);
}

/// Page ID 0x040
class ControllerInputConfigPage extends $pb.GeneratedMessage {
  factory ControllerInputConfigPage({
    $core.int? supportedDigitalInputs,
    $core.int? supportedAnalogInputs,
    $core.Iterable<InputAnalogRange>? analogInputRange,
    $core.Iterable<InputAnalogDeadzone>? analogDeadZone,
  }) {
    final $result = create();
    if (supportedDigitalInputs != null) {
      $result.supportedDigitalInputs = supportedDigitalInputs;
    }
    if (supportedAnalogInputs != null) {
      $result.supportedAnalogInputs = supportedAnalogInputs;
    }
    if (analogInputRange != null) {
      $result.analogInputRange.addAll(analogInputRange);
    }
    if (analogDeadZone != null) {
      $result.analogDeadZone.addAll(analogDeadZone);
    }
    return $result;
  }
  ControllerInputConfigPage._() : super();
  factory ControllerInputConfigPage.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ControllerInputConfigPage.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ControllerInputConfigPage', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'supportedDigitalInputs', $pb.PbFieldType.OU3, protoName: 'supportedDigitalInputs')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'supportedAnalogInputs', $pb.PbFieldType.OU3, protoName: 'supportedAnalogInputs')
    ..pc<InputAnalogRange>(3, _omitFieldNames ? '' : 'analogInputRange', $pb.PbFieldType.PM, protoName: 'analogInputRange', subBuilder: InputAnalogRange.create)
    ..pc<InputAnalogDeadzone>(4, _omitFieldNames ? '' : 'analogDeadZone', $pb.PbFieldType.PM, protoName: 'analogDeadZone', subBuilder: InputAnalogDeadzone.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ControllerInputConfigPage clone() => ControllerInputConfigPage()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ControllerInputConfigPage copyWith(void Function(ControllerInputConfigPage) updates) => super.copyWith((message) => updates(message as ControllerInputConfigPage)) as ControllerInputConfigPage;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ControllerInputConfigPage create() => ControllerInputConfigPage._();
  ControllerInputConfigPage createEmptyInstance() => create();
  static $pb.PbList<ControllerInputConfigPage> createRepeated() => $pb.PbList<ControllerInputConfigPage>();
  @$core.pragma('dart2js:noInline')
  static ControllerInputConfigPage getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ControllerInputConfigPage>(create);
  static ControllerInputConfigPage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get supportedDigitalInputs => $_getIZ(0);
  @$pb.TagNumber(1)
  set supportedDigitalInputs($core.int v) { $_setUnsignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSupportedDigitalInputs() => $_has(0);
  @$pb.TagNumber(1)
  void clearSupportedDigitalInputs() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get supportedAnalogInputs => $_getIZ(1);
  @$pb.TagNumber(2)
  set supportedAnalogInputs($core.int v) { $_setUnsignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasSupportedAnalogInputs() => $_has(1);
  @$pb.TagNumber(2)
  void clearSupportedAnalogInputs() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<InputAnalogRange> get analogInputRange => $_getList(2);

  @$pb.TagNumber(4)
  $core.List<InputAnalogDeadzone> get analogDeadZone => $_getList(3);
}

/// Page 0x041
class IpTransportPage extends $pb.GeneratedMessage {
  factory IpTransportPage({
    $core.int? ipv4Address,
    $core.int? tcpPort,
  }) {
    final $result = create();
    if (ipv4Address != null) {
      $result.ipv4Address = ipv4Address;
    }
    if (tcpPort != null) {
      $result.tcpPort = tcpPort;
    }
    return $result;
  }
  IpTransportPage._() : super();
  factory IpTransportPage.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory IpTransportPage.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'IpTransportPage', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'ipv4Address', $pb.PbFieldType.OU3, protoName: 'ipv4Address')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'tcpPort', $pb.PbFieldType.OU3, protoName: 'tcpPort')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  IpTransportPage clone() => IpTransportPage()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  IpTransportPage copyWith(void Function(IpTransportPage) updates) => super.copyWith((message) => updates(message as IpTransportPage)) as IpTransportPage;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static IpTransportPage create() => IpTransportPage._();
  IpTransportPage createEmptyInstance() => create();
  static $pb.PbList<IpTransportPage> createRepeated() => $pb.PbList<IpTransportPage>();
  @$core.pragma('dart2js:noInline')
  static IpTransportPage getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<IpTransportPage>(create);
  static IpTransportPage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get ipv4Address => $_getIZ(0);
  @$pb.TagNumber(1)
  set ipv4Address($core.int v) { $_setUnsignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasIpv4Address() => $_has(0);
  @$pb.TagNumber(1)
  void clearIpv4Address() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get tcpPort => $_getIZ(1);
  @$pb.TagNumber(2)
  set tcpPort($core.int v) { $_setUnsignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasTcpPort() => $_has(1);
  @$pb.TagNumber(2)
  void clearTcpPort() => clearField(2);
}

/// Page 0x042
class WifiConfigurationPage extends $pb.GeneratedMessage {
  factory WifiConfigurationPage({
    $core.bool? wifiEnabled,
    $core.int? wifiStatus,
    $core.List<$core.int>? wifiSsid,
    $core.int? wifiBand,
    $core.int? wifiRssi,
    $core.List<$core.int>? wifiRegionCode,
  }) {
    final $result = create();
    if (wifiEnabled != null) {
      $result.wifiEnabled = wifiEnabled;
    }
    if (wifiStatus != null) {
      $result.wifiStatus = wifiStatus;
    }
    if (wifiSsid != null) {
      $result.wifiSsid = wifiSsid;
    }
    if (wifiBand != null) {
      $result.wifiBand = wifiBand;
    }
    if (wifiRssi != null) {
      $result.wifiRssi = wifiRssi;
    }
    if (wifiRegionCode != null) {
      $result.wifiRegionCode = wifiRegionCode;
    }
    return $result;
  }
  WifiConfigurationPage._() : super();
  factory WifiConfigurationPage.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory WifiConfigurationPage.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'WifiConfigurationPage', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'wifiEnabled', protoName: 'wifiEnabled')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'wifiStatus', $pb.PbFieldType.OU3, protoName: 'wifiStatus')
    ..a<$core.List<$core.int>>(3, _omitFieldNames ? '' : 'wifiSsid', $pb.PbFieldType.OY, protoName: 'wifiSsid')
    ..a<$core.int>(4, _omitFieldNames ? '' : 'wifiBand', $pb.PbFieldType.OU3, protoName: 'wifiBand')
    ..a<$core.int>(5, _omitFieldNames ? '' : 'wifiRssi', $pb.PbFieldType.OS3, protoName: 'wifiRssi')
    ..a<$core.List<$core.int>>(6, _omitFieldNames ? '' : 'wifiRegionCode', $pb.PbFieldType.OY, protoName: 'wifiRegionCode')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  WifiConfigurationPage clone() => WifiConfigurationPage()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  WifiConfigurationPage copyWith(void Function(WifiConfigurationPage) updates) => super.copyWith((message) => updates(message as WifiConfigurationPage)) as WifiConfigurationPage;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WifiConfigurationPage create() => WifiConfigurationPage._();
  WifiConfigurationPage createEmptyInstance() => create();
  static $pb.PbList<WifiConfigurationPage> createRepeated() => $pb.PbList<WifiConfigurationPage>();
  @$core.pragma('dart2js:noInline')
  static WifiConfigurationPage getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<WifiConfigurationPage>(create);
  static WifiConfigurationPage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get wifiEnabled => $_getBF(0);
  @$pb.TagNumber(1)
  set wifiEnabled($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasWifiEnabled() => $_has(0);
  @$pb.TagNumber(1)
  void clearWifiEnabled() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get wifiStatus => $_getIZ(1);
  @$pb.TagNumber(2)
  set wifiStatus($core.int v) { $_setUnsignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasWifiStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearWifiStatus() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get wifiSsid => $_getN(2);
  @$pb.TagNumber(3)
  set wifiSsid($core.List<$core.int> v) { $_setBytes(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasWifiSsid() => $_has(2);
  @$pb.TagNumber(3)
  void clearWifiSsid() => clearField(3);

  @$pb.TagNumber(4)
  $core.int get wifiBand => $_getIZ(3);
  @$pb.TagNumber(4)
  set wifiBand($core.int v) { $_setUnsignedInt32(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasWifiBand() => $_has(3);
  @$pb.TagNumber(4)
  void clearWifiBand() => clearField(4);

  @$pb.TagNumber(5)
  $core.int get wifiRssi => $_getIZ(4);
  @$pb.TagNumber(5)
  set wifiRssi($core.int v) { $_setSignedInt32(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasWifiRssi() => $_has(4);
  @$pb.TagNumber(5)
  void clearWifiRssi() => clearField(5);

  @$pb.TagNumber(6)
  $core.List<$core.int> get wifiRegionCode => $_getN(5);
  @$pb.TagNumber(6)
  set wifiRegionCode($core.List<$core.int> v) { $_setBytes(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasWifiRegionCode() => $_has(5);
  @$pb.TagNumber(6)
  void clearWifiRegionCode() => clearField(6);
}

/// Page ID 0x050
class SensorRelayDataPage extends $pb.GeneratedMessage {
  factory SensorRelayDataPage({
    $core.Iterable<$core.int>? supportedSensors,
    $core.Iterable<$core.int>? pairedSensors,
  }) {
    final $result = create();
    if (supportedSensors != null) {
      $result.supportedSensors.addAll(supportedSensors);
    }
    if (pairedSensors != null) {
      $result.pairedSensors.addAll(pairedSensors);
    }
    return $result;
  }
  SensorRelayDataPage._() : super();
  factory SensorRelayDataPage.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SensorRelayDataPage.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SensorRelayDataPage', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..p<$core.int>(1, _omitFieldNames ? '' : 'supportedSensors', $pb.PbFieldType.PU3, protoName: 'supportedSensors')
    ..p<$core.int>(2, _omitFieldNames ? '' : 'pairedSensors', $pb.PbFieldType.PU3, protoName: 'pairedSensors')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SensorRelayDataPage clone() => SensorRelayDataPage()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SensorRelayDataPage copyWith(void Function(SensorRelayDataPage) updates) => super.copyWith((message) => updates(message as SensorRelayDataPage)) as SensorRelayDataPage;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SensorRelayDataPage create() => SensorRelayDataPage._();
  SensorRelayDataPage createEmptyInstance() => create();
  static $pb.PbList<SensorRelayDataPage> createRepeated() => $pb.PbList<SensorRelayDataPage>();
  @$core.pragma('dart2js:noInline')
  static SensorRelayDataPage getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SensorRelayDataPage>(create);
  static SensorRelayDataPage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get supportedSensors => $_getList(0);

  @$pb.TagNumber(2)
  $core.List<$core.int> get pairedSensors => $_getList(1);
}

/// OpCode 0x00
class Get extends $pb.GeneratedMessage {
  factory Get({
    $core.int? dataObjectId,
  }) {
    final $result = create();
    if (dataObjectId != null) {
      $result.dataObjectId = dataObjectId;
    }
    return $result;
  }
  Get._() : super();
  factory Get.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Get.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Get', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'dataObjectId', $pb.PbFieldType.QU3, protoName: 'dataObjectId')
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  Get clone() => Get()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  Get copyWith(void Function(Get) updates) => super.copyWith((message) => updates(message as Get)) as Get;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Get create() => Get._();
  Get createEmptyInstance() => create();
  static $pb.PbList<Get> createRepeated() => $pb.PbList<Get>();
  @$core.pragma('dart2js:noInline')
  static Get getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Get>(create);
  static Get? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get dataObjectId => $_getIZ(0);
  @$pb.TagNumber(1)
  set dataObjectId($core.int v) { $_setUnsignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasDataObjectId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDataObjectId() => clearField(1);
}

/// OpCode 0x01
class DevInfo extends $pb.GeneratedMessage {
  factory DevInfo({
    DevInfoPage? devInfo,
  }) {
    final $result = create();
    if (devInfo != null) {
      $result.devInfo = devInfo;
    }
    return $result;
  }
  DevInfo._() : super();
  factory DevInfo.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DevInfo.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DevInfo', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..aQM<DevInfoPage>(1, _omitFieldNames ? '' : 'devInfo', protoName: 'devInfo', subBuilder: DevInfoPage.create)
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DevInfo clone() => DevInfo()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DevInfo copyWith(void Function(DevInfo) updates) => super.copyWith((message) => updates(message as DevInfo)) as DevInfo;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DevInfo create() => DevInfo._();
  DevInfo createEmptyInstance() => create();
  static $pb.PbList<DevInfo> createRepeated() => $pb.PbList<DevInfo>();
  @$core.pragma('dart2js:noInline')
  static DevInfo getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DevInfo>(create);
  static DevInfo? _defaultInstance;

  @$pb.TagNumber(1)
  DevInfoPage get devInfo => $_getN(0);
  @$pb.TagNumber(1)
  set devInfo(DevInfoPage v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasDevInfo() => $_has(0);
  @$pb.TagNumber(1)
  void clearDevInfo() => clearField(1);
  @$pb.TagNumber(1)
  DevInfoPage ensureDevInfo() => $_ensure(0);
}

enum BleSecurityRequest_Request {
  startSecureConnection, 
  notSet
}

/// OpCode 0x02
class BleSecurityRequest extends $pb.GeneratedMessage {
  factory BleSecurityRequest({
    $core.bool? startSecureConnection,
  }) {
    final $result = create();
    if (startSecureConnection != null) {
      $result.startSecureConnection = startSecureConnection;
    }
    return $result;
  }
  BleSecurityRequest._() : super();
  factory BleSecurityRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BleSecurityRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static const $core.Map<$core.int, BleSecurityRequest_Request> _BleSecurityRequest_RequestByTag = {
    1 : BleSecurityRequest_Request.startSecureConnection,
    0 : BleSecurityRequest_Request.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'BleSecurityRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..oo(0, [1])
    ..aOB(1, _omitFieldNames ? '' : 'startSecureConnection', protoName: 'startSecureConnection')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BleSecurityRequest clone() => BleSecurityRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BleSecurityRequest copyWith(void Function(BleSecurityRequest) updates) => super.copyWith((message) => updates(message as BleSecurityRequest)) as BleSecurityRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BleSecurityRequest create() => BleSecurityRequest._();
  BleSecurityRequest createEmptyInstance() => create();
  static $pb.PbList<BleSecurityRequest> createRepeated() => $pb.PbList<BleSecurityRequest>();
  @$core.pragma('dart2js:noInline')
  static BleSecurityRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BleSecurityRequest>(create);
  static BleSecurityRequest? _defaultInstance;

  BleSecurityRequest_Request whichRequest() => _BleSecurityRequest_RequestByTag[$_whichOneof(0)]!;
  void clearRequest() => clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $core.bool get startSecureConnection => $_getBF(0);
  @$pb.TagNumber(1)
  set startSecureConnection($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasStartSecureConnection() => $_has(0);
  @$pb.TagNumber(1)
  void clearStartSecureConnection() => clearField(1);
}

/// OpCode 0x03
class TrainerNotification extends $pb.GeneratedMessage {
  factory TrainerNotification({
    $core.int? power,
    $core.int? cadence,
    $core.int? bikeSpeed,
    $core.int? averagedPower,
    $core.int? wheelSpeed,
    $core.int? calculatedRealGearRatio,
  }) {
    final $result = create();
    if (power != null) {
      $result.power = power;
    }
    if (cadence != null) {
      $result.cadence = cadence;
    }
    if (bikeSpeed != null) {
      $result.bikeSpeed = bikeSpeed;
    }
    if (averagedPower != null) {
      $result.averagedPower = averagedPower;
    }
    if (wheelSpeed != null) {
      $result.wheelSpeed = wheelSpeed;
    }
    if (calculatedRealGearRatio != null) {
      $result.calculatedRealGearRatio = calculatedRealGearRatio;
    }
    return $result;
  }
  TrainerNotification._() : super();
  factory TrainerNotification.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory TrainerNotification.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'TrainerNotification', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'power', $pb.PbFieldType.QU3)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'cadence', $pb.PbFieldType.QU3)
    ..a<$core.int>(3, _omitFieldNames ? '' : 'bikeSpeed', $pb.PbFieldType.QU3, protoName: 'bikeSpeed')
    ..a<$core.int>(4, _omitFieldNames ? '' : 'averagedPower', $pb.PbFieldType.QU3, protoName: 'averagedPower')
    ..a<$core.int>(5, _omitFieldNames ? '' : 'wheelSpeed', $pb.PbFieldType.QU3, protoName: 'wheelSpeed')
    ..a<$core.int>(6, _omitFieldNames ? '' : 'calculatedRealGearRatio', $pb.PbFieldType.OU3, protoName: 'calculatedRealGearRatio')
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  TrainerNotification clone() => TrainerNotification()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  TrainerNotification copyWith(void Function(TrainerNotification) updates) => super.copyWith((message) => updates(message as TrainerNotification)) as TrainerNotification;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TrainerNotification create() => TrainerNotification._();
  TrainerNotification createEmptyInstance() => create();
  static $pb.PbList<TrainerNotification> createRepeated() => $pb.PbList<TrainerNotification>();
  @$core.pragma('dart2js:noInline')
  static TrainerNotification getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TrainerNotification>(create);
  static TrainerNotification? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get power => $_getIZ(0);
  @$pb.TagNumber(1)
  set power($core.int v) { $_setUnsignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasPower() => $_has(0);
  @$pb.TagNumber(1)
  void clearPower() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get cadence => $_getIZ(1);
  @$pb.TagNumber(2)
  set cadence($core.int v) { $_setUnsignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasCadence() => $_has(1);
  @$pb.TagNumber(2)
  void clearCadence() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get bikeSpeed => $_getIZ(2);
  @$pb.TagNumber(3)
  set bikeSpeed($core.int v) { $_setUnsignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasBikeSpeed() => $_has(2);
  @$pb.TagNumber(3)
  void clearBikeSpeed() => clearField(3);

  @$pb.TagNumber(4)
  $core.int get averagedPower => $_getIZ(3);
  @$pb.TagNumber(4)
  set averagedPower($core.int v) { $_setUnsignedInt32(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasAveragedPower() => $_has(3);
  @$pb.TagNumber(4)
  void clearAveragedPower() => clearField(4);

  @$pb.TagNumber(5)
  $core.int get wheelSpeed => $_getIZ(4);
  @$pb.TagNumber(5)
  set wheelSpeed($core.int v) { $_setUnsignedInt32(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasWheelSpeed() => $_has(4);
  @$pb.TagNumber(5)
  void clearWheelSpeed() => clearField(5);

  @$pb.TagNumber(6)
  $core.int get calculatedRealGearRatio => $_getIZ(5);
  @$pb.TagNumber(6)
  set calculatedRealGearRatio($core.int v) { $_setUnsignedInt32(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasCalculatedRealGearRatio() => $_has(5);
  @$pb.TagNumber(6)
  void clearCalculatedRealGearRatio() => clearField(6);
}

enum TrainerConfigSet_Config {
  configuredResistance, 
  ergPower, 
  envSim, 
  bikeSim, 
  averagingWindow, 
  trainerOptions, 
  notSet
}

/// OpCode 0x04
class TrainerConfigSet extends $pb.GeneratedMessage {
  factory TrainerConfigSet({
    $core.int? configuredResistance,
    $core.int? ergPower,
    TrainerEnvSim? envSim,
    TrainerBikeSim? bikeSim,
    $core.int? averagingWindow,
    TrainerOptions? trainerOptions,
  }) {
    final $result = create();
    if (configuredResistance != null) {
      $result.configuredResistance = configuredResistance;
    }
    if (ergPower != null) {
      $result.ergPower = ergPower;
    }
    if (envSim != null) {
      $result.envSim = envSim;
    }
    if (bikeSim != null) {
      $result.bikeSim = bikeSim;
    }
    if (averagingWindow != null) {
      $result.averagingWindow = averagingWindow;
    }
    if (trainerOptions != null) {
      $result.trainerOptions = trainerOptions;
    }
    return $result;
  }
  TrainerConfigSet._() : super();
  factory TrainerConfigSet.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory TrainerConfigSet.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static const $core.Map<$core.int, TrainerConfigSet_Config> _TrainerConfigSet_ConfigByTag = {
    2 : TrainerConfigSet_Config.configuredResistance,
    3 : TrainerConfigSet_Config.ergPower,
    4 : TrainerConfigSet_Config.envSim,
    5 : TrainerConfigSet_Config.bikeSim,
    6 : TrainerConfigSet_Config.averagingWindow,
    7 : TrainerConfigSet_Config.trainerOptions,
    0 : TrainerConfigSet_Config.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'TrainerConfigSet', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..oo(0, [2, 3, 4, 5, 6, 7])
    ..a<$core.int>(2, _omitFieldNames ? '' : 'configuredResistance', $pb.PbFieldType.OU3, protoName: 'configuredResistance')
    ..a<$core.int>(3, _omitFieldNames ? '' : 'ergPower', $pb.PbFieldType.OU3, protoName: 'ergPower')
    ..aOM<TrainerEnvSim>(4, _omitFieldNames ? '' : 'envSim', protoName: 'envSim', subBuilder: TrainerEnvSim.create)
    ..aOM<TrainerBikeSim>(5, _omitFieldNames ? '' : 'bikeSim', protoName: 'bikeSim', subBuilder: TrainerBikeSim.create)
    ..a<$core.int>(6, _omitFieldNames ? '' : 'averagingWindow', $pb.PbFieldType.OU3, protoName: 'averagingWindow')
    ..aOM<TrainerOptions>(7, _omitFieldNames ? '' : 'trainerOptions', protoName: 'trainerOptions', subBuilder: TrainerOptions.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  TrainerConfigSet clone() => TrainerConfigSet()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  TrainerConfigSet copyWith(void Function(TrainerConfigSet) updates) => super.copyWith((message) => updates(message as TrainerConfigSet)) as TrainerConfigSet;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TrainerConfigSet create() => TrainerConfigSet._();
  TrainerConfigSet createEmptyInstance() => create();
  static $pb.PbList<TrainerConfigSet> createRepeated() => $pb.PbList<TrainerConfigSet>();
  @$core.pragma('dart2js:noInline')
  static TrainerConfigSet getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TrainerConfigSet>(create);
  static TrainerConfigSet? _defaultInstance;

  TrainerConfigSet_Config whichConfig() => _TrainerConfigSet_ConfigByTag[$_whichOneof(0)]!;
  void clearConfig() => clearField($_whichOneof(0));

  @$pb.TagNumber(2)
  $core.int get configuredResistance => $_getIZ(0);
  @$pb.TagNumber(2)
  set configuredResistance($core.int v) { $_setUnsignedInt32(0, v); }
  @$pb.TagNumber(2)
  $core.bool hasConfiguredResistance() => $_has(0);
  @$pb.TagNumber(2)
  void clearConfiguredResistance() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get ergPower => $_getIZ(1);
  @$pb.TagNumber(3)
  set ergPower($core.int v) { $_setUnsignedInt32(1, v); }
  @$pb.TagNumber(3)
  $core.bool hasErgPower() => $_has(1);
  @$pb.TagNumber(3)
  void clearErgPower() => clearField(3);

  @$pb.TagNumber(4)
  TrainerEnvSim get envSim => $_getN(2);
  @$pb.TagNumber(4)
  set envSim(TrainerEnvSim v) { setField(4, v); }
  @$pb.TagNumber(4)
  $core.bool hasEnvSim() => $_has(2);
  @$pb.TagNumber(4)
  void clearEnvSim() => clearField(4);
  @$pb.TagNumber(4)
  TrainerEnvSim ensureEnvSim() => $_ensure(2);

  @$pb.TagNumber(5)
  TrainerBikeSim get bikeSim => $_getN(3);
  @$pb.TagNumber(5)
  set bikeSim(TrainerBikeSim v) { setField(5, v); }
  @$pb.TagNumber(5)
  $core.bool hasBikeSim() => $_has(3);
  @$pb.TagNumber(5)
  void clearBikeSim() => clearField(5);
  @$pb.TagNumber(5)
  TrainerBikeSim ensureBikeSim() => $_ensure(3);

  @$pb.TagNumber(6)
  $core.int get averagingWindow => $_getIZ(4);
  @$pb.TagNumber(6)
  set averagingWindow($core.int v) { $_setUnsignedInt32(4, v); }
  @$pb.TagNumber(6)
  $core.bool hasAveragingWindow() => $_has(4);
  @$pb.TagNumber(6)
  void clearAveragingWindow() => clearField(6);

  @$pb.TagNumber(7)
  TrainerOptions get trainerOptions => $_getN(5);
  @$pb.TagNumber(7)
  set trainerOptions(TrainerOptions v) { setField(7, v); }
  @$pb.TagNumber(7)
  $core.bool hasTrainerOptions() => $_has(5);
  @$pb.TagNumber(7)
  void clearTrainerOptions() => clearField(7);
  @$pb.TagNumber(7)
  TrainerOptions ensureTrainerOptions() => $_ensure(5);
}

/// OpCode 0x05
class TrainerConfigStatus extends $pb.GeneratedMessage {
  factory TrainerConfigStatus({
    TrainerCfgPage? trainerCfg,
  }) {
    final $result = create();
    if (trainerCfg != null) {
      $result.trainerCfg = trainerCfg;
    }
    return $result;
  }
  TrainerConfigStatus._() : super();
  factory TrainerConfigStatus.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory TrainerConfigStatus.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'TrainerConfigStatus', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..aQM<TrainerCfgPage>(1, _omitFieldNames ? '' : 'trainerCfg', protoName: 'trainerCfg', subBuilder: TrainerCfgPage.create)
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  TrainerConfigStatus clone() => TrainerConfigStatus()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  TrainerConfigStatus copyWith(void Function(TrainerConfigStatus) updates) => super.copyWith((message) => updates(message as TrainerConfigStatus)) as TrainerConfigStatus;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TrainerConfigStatus create() => TrainerConfigStatus._();
  TrainerConfigStatus createEmptyInstance() => create();
  static $pb.PbList<TrainerConfigStatus> createRepeated() => $pb.PbList<TrainerConfigStatus>();
  @$core.pragma('dart2js:noInline')
  static TrainerConfigStatus getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TrainerConfigStatus>(create);
  static TrainerConfigStatus? _defaultInstance;

  @$pb.TagNumber(1)
  TrainerCfgPage get trainerCfg => $_getN(0);
  @$pb.TagNumber(1)
  set trainerCfg(TrainerCfgPage v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasTrainerCfg() => $_has(0);
  @$pb.TagNumber(1)
  void clearTrainerCfg() => clearField(1);
  @$pb.TagNumber(1)
  TrainerCfgPage ensureTrainerCfg() => $_ensure(0);
}

enum DevInfoSet_DevInfo {
  deviceName, 
  notSet
}

/// OpCode 0x0C
class DevInfoSet extends $pb.GeneratedMessage {
  factory DevInfoSet({
    $core.List<$core.int>? deviceName,
  }) {
    final $result = create();
    if (deviceName != null) {
      $result.deviceName = deviceName;
    }
    return $result;
  }
  DevInfoSet._() : super();
  factory DevInfoSet.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DevInfoSet.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static const $core.Map<$core.int, DevInfoSet_DevInfo> _DevInfoSet_DevInfoByTag = {
    1 : DevInfoSet_DevInfo.deviceName,
    0 : DevInfoSet_DevInfo.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DevInfoSet', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..oo(0, [1])
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'deviceName', $pb.PbFieldType.OY, protoName: 'deviceName')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DevInfoSet clone() => DevInfoSet()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DevInfoSet copyWith(void Function(DevInfoSet) updates) => super.copyWith((message) => updates(message as DevInfoSet)) as DevInfoSet;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DevInfoSet create() => DevInfoSet._();
  DevInfoSet createEmptyInstance() => create();
  static $pb.PbList<DevInfoSet> createRepeated() => $pb.PbList<DevInfoSet>();
  @$core.pragma('dart2js:noInline')
  static DevInfoSet getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DevInfoSet>(create);
  static DevInfoSet? _defaultInstance;

  DevInfoSet_DevInfo whichDevInfo() => _DevInfoSet_DevInfoByTag[$_whichOneof(0)]!;
  void clearDevInfo() => clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $core.List<$core.int> get deviceName => $_getN(0);
  @$pb.TagNumber(1)
  set deviceName($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasDeviceName() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeviceName() => clearField(1);
}

/// OpCode 0x18
class Reset extends $pb.GeneratedMessage {
  factory Reset({
    $core.int? resetProcedure,
  }) {
    final $result = create();
    if (resetProcedure != null) {
      $result.resetProcedure = resetProcedure;
    }
    return $result;
  }
  Reset._() : super();
  factory Reset.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Reset.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Reset', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'resetProcedure', $pb.PbFieldType.OU3, protoName: 'resetProcedure')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  Reset clone() => Reset()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  Reset copyWith(void Function(Reset) updates) => super.copyWith((message) => updates(message as Reset)) as Reset;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Reset create() => Reset._();
  Reset createEmptyInstance() => create();
  static $pb.PbList<Reset> createRepeated() => $pb.PbList<Reset>();
  @$core.pragma('dart2js:noInline')
  static Reset getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Reset>(create);
  static Reset? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get resetProcedure => $_getIZ(0);
  @$pb.TagNumber(1)
  set resetProcedure($core.int v) { $_setUnsignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasResetProcedure() => $_has(0);
  @$pb.TagNumber(1)
  void clearResetProcedure() => clearField(1);
}

enum BatteryNotification_Alert {
  newChgState, 
  newPercLevel, 
  notSet
}

/// OpCode 0x19
class BatteryNotification extends $pb.GeneratedMessage {
  factory BatteryNotification({
    ChargingState? newChgState,
    $core.int? newPercLevel,
    $core.int? source,
  }) {
    final $result = create();
    if (newChgState != null) {
      $result.newChgState = newChgState;
    }
    if (newPercLevel != null) {
      $result.newPercLevel = newPercLevel;
    }
    if (source != null) {
      $result.source = source;
    }
    return $result;
  }
  BatteryNotification._() : super();
  factory BatteryNotification.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BatteryNotification.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static const $core.Map<$core.int, BatteryNotification_Alert> _BatteryNotification_AlertByTag = {
    1 : BatteryNotification_Alert.newChgState,
    2 : BatteryNotification_Alert.newPercLevel,
    0 : BatteryNotification_Alert.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'BatteryNotification', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..oo(0, [1, 2])
    ..e<ChargingState>(1, _omitFieldNames ? '' : 'newChgState', $pb.PbFieldType.OE, protoName: 'newChgState', defaultOrMaker: ChargingState.CHARGING_IDLE, valueOf: ChargingState.valueOf, enumValues: ChargingState.values)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'newPercLevel', $pb.PbFieldType.OU3, protoName: 'newPercLevel')
    ..a<$core.int>(3, _omitFieldNames ? '' : 'source', $pb.PbFieldType.OU3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BatteryNotification clone() => BatteryNotification()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BatteryNotification copyWith(void Function(BatteryNotification) updates) => super.copyWith((message) => updates(message as BatteryNotification)) as BatteryNotification;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BatteryNotification create() => BatteryNotification._();
  BatteryNotification createEmptyInstance() => create();
  static $pb.PbList<BatteryNotification> createRepeated() => $pb.PbList<BatteryNotification>();
  @$core.pragma('dart2js:noInline')
  static BatteryNotification getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BatteryNotification>(create);
  static BatteryNotification? _defaultInstance;

  BatteryNotification_Alert whichAlert() => _BatteryNotification_AlertByTag[$_whichOneof(0)]!;
  void clearAlert() => clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  ChargingState get newChgState => $_getN(0);
  @$pb.TagNumber(1)
  set newChgState(ChargingState v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasNewChgState() => $_has(0);
  @$pb.TagNumber(1)
  void clearNewChgState() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get newPercLevel => $_getIZ(1);
  @$pb.TagNumber(2)
  set newPercLevel($core.int v) { $_setUnsignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasNewPercLevel() => $_has(1);
  @$pb.TagNumber(2)
  void clearNewPercLevel() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get source => $_getIZ(2);
  @$pb.TagNumber(3)
  set source($core.int v) { $_setUnsignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasSource() => $_has(2);
  @$pb.TagNumber(3)
  void clearSource() => clearField(3);
}

/// OpCode 0x1A
class BatteryStatus extends $pb.GeneratedMessage {
  factory BatteryStatus({
    ChargingState? chgState,
    $core.int? percLevel,
    $core.int? timeToEmpty,
    $core.int? timeToFull,
  }) {
    final $result = create();
    if (chgState != null) {
      $result.chgState = chgState;
    }
    if (percLevel != null) {
      $result.percLevel = percLevel;
    }
    if (timeToEmpty != null) {
      $result.timeToEmpty = timeToEmpty;
    }
    if (timeToFull != null) {
      $result.timeToFull = timeToFull;
    }
    return $result;
  }
  BatteryStatus._() : super();
  factory BatteryStatus.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BatteryStatus.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'BatteryStatus', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..e<ChargingState>(1, _omitFieldNames ? '' : 'chgState', $pb.PbFieldType.QE, protoName: 'chgState', defaultOrMaker: ChargingState.CHARGING_IDLE, valueOf: ChargingState.valueOf, enumValues: ChargingState.values)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'percLevel', $pb.PbFieldType.QU3, protoName: 'percLevel')
    ..a<$core.int>(3, _omitFieldNames ? '' : 'timeToEmpty', $pb.PbFieldType.QU3, protoName: 'timeToEmpty')
    ..a<$core.int>(4, _omitFieldNames ? '' : 'timeToFull', $pb.PbFieldType.QU3, protoName: 'timeToFull')
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BatteryStatus clone() => BatteryStatus()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BatteryStatus copyWith(void Function(BatteryStatus) updates) => super.copyWith((message) => updates(message as BatteryStatus)) as BatteryStatus;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BatteryStatus create() => BatteryStatus._();
  BatteryStatus createEmptyInstance() => create();
  static $pb.PbList<BatteryStatus> createRepeated() => $pb.PbList<BatteryStatus>();
  @$core.pragma('dart2js:noInline')
  static BatteryStatus getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BatteryStatus>(create);
  static BatteryStatus? _defaultInstance;

  @$pb.TagNumber(1)
  ChargingState get chgState => $_getN(0);
  @$pb.TagNumber(1)
  set chgState(ChargingState v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasChgState() => $_has(0);
  @$pb.TagNumber(1)
  void clearChgState() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get percLevel => $_getIZ(1);
  @$pb.TagNumber(2)
  set percLevel($core.int v) { $_setUnsignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasPercLevel() => $_has(1);
  @$pb.TagNumber(2)
  void clearPercLevel() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get timeToEmpty => $_getIZ(2);
  @$pb.TagNumber(3)
  set timeToEmpty($core.int v) { $_setUnsignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasTimeToEmpty() => $_has(2);
  @$pb.TagNumber(3)
  void clearTimeToEmpty() => clearField(3);

  @$pb.TagNumber(4)
  $core.int get timeToFull => $_getIZ(3);
  @$pb.TagNumber(4)
  set timeToFull($core.int v) { $_setUnsignedInt32(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasTimeToFull() => $_has(3);
  @$pb.TagNumber(4)
  void clearTimeToFull() => clearField(4);
}

/// OpCode 0x23
class ControllerNotification extends $pb.GeneratedMessage {
  factory ControllerNotification({
    $core.int? buttonEvent,
    $core.Iterable<ControllerAnalogEvent>? analogEventList,
  }) {
    final $result = create();
    if (buttonEvent != null) {
      $result.buttonEvent = buttonEvent;
    }
    if (analogEventList != null) {
      $result.analogEventList.addAll(analogEventList);
    }
    return $result;
  }
  ControllerNotification._() : super();
  factory ControllerNotification.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ControllerNotification.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ControllerNotification', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'buttonEvent', $pb.PbFieldType.OU3, protoName: 'buttonEvent')
    ..pc<ControllerAnalogEvent>(3, _omitFieldNames ? '' : 'analogEventList', $pb.PbFieldType.PM, protoName: 'analogEventList', subBuilder: ControllerAnalogEvent.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ControllerNotification clone() => ControllerNotification()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ControllerNotification copyWith(void Function(ControllerNotification) updates) => super.copyWith((message) => updates(message as ControllerNotification)) as ControllerNotification;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ControllerNotification create() => ControllerNotification._();
  ControllerNotification createEmptyInstance() => create();
  static $pb.PbList<ControllerNotification> createRepeated() => $pb.PbList<ControllerNotification>();
  @$core.pragma('dart2js:noInline')
  static ControllerNotification getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ControllerNotification>(create);
  static ControllerNotification? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get buttonEvent => $_getIZ(0);
  @$pb.TagNumber(1)
  set buttonEvent($core.int v) { $_setUnsignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasButtonEvent() => $_has(0);
  @$pb.TagNumber(1)
  void clearButtonEvent() => clearField(1);

  @$pb.TagNumber(3)
  $core.List<ControllerAnalogEvent> get analogEventList => $_getList(1);
}

class LogDataNotification_ConnectionParameters extends $pb.GeneratedMessage {
  factory LogDataNotification_ConnectionParameters({
    $core.int? interval,
    $core.int? latency,
    $core.int? supervisorTimeout,
    $core.List<$core.int>? bleChannelMap,
    $core.int? mtuSize,
  }) {
    final $result = create();
    if (interval != null) {
      $result.interval = interval;
    }
    if (latency != null) {
      $result.latency = latency;
    }
    if (supervisorTimeout != null) {
      $result.supervisorTimeout = supervisorTimeout;
    }
    if (bleChannelMap != null) {
      $result.bleChannelMap = bleChannelMap;
    }
    if (mtuSize != null) {
      $result.mtuSize = mtuSize;
    }
    return $result;
  }
  LogDataNotification_ConnectionParameters._() : super();
  factory LogDataNotification_ConnectionParameters.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory LogDataNotification_ConnectionParameters.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'LogDataNotification.ConnectionParameters', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'interval', $pb.PbFieldType.QU3)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'latency', $pb.PbFieldType.QU3)
    ..a<$core.int>(3, _omitFieldNames ? '' : 'supervisorTimeout', $pb.PbFieldType.QU3, protoName: 'supervisorTimeout')
    ..a<$core.List<$core.int>>(4, _omitFieldNames ? '' : 'bleChannelMap', $pb.PbFieldType.QY, protoName: 'bleChannelMap')
    ..a<$core.int>(5, _omitFieldNames ? '' : 'mtuSize', $pb.PbFieldType.OU3, protoName: 'mtuSize')
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  LogDataNotification_ConnectionParameters clone() => LogDataNotification_ConnectionParameters()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  LogDataNotification_ConnectionParameters copyWith(void Function(LogDataNotification_ConnectionParameters) updates) => super.copyWith((message) => updates(message as LogDataNotification_ConnectionParameters)) as LogDataNotification_ConnectionParameters;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LogDataNotification_ConnectionParameters create() => LogDataNotification_ConnectionParameters._();
  LogDataNotification_ConnectionParameters createEmptyInstance() => create();
  static $pb.PbList<LogDataNotification_ConnectionParameters> createRepeated() => $pb.PbList<LogDataNotification_ConnectionParameters>();
  @$core.pragma('dart2js:noInline')
  static LogDataNotification_ConnectionParameters getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LogDataNotification_ConnectionParameters>(create);
  static LogDataNotification_ConnectionParameters? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get interval => $_getIZ(0);
  @$pb.TagNumber(1)
  set interval($core.int v) { $_setUnsignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasInterval() => $_has(0);
  @$pb.TagNumber(1)
  void clearInterval() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get latency => $_getIZ(1);
  @$pb.TagNumber(2)
  set latency($core.int v) { $_setUnsignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasLatency() => $_has(1);
  @$pb.TagNumber(2)
  void clearLatency() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get supervisorTimeout => $_getIZ(2);
  @$pb.TagNumber(3)
  set supervisorTimeout($core.int v) { $_setUnsignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasSupervisorTimeout() => $_has(2);
  @$pb.TagNumber(3)
  void clearSupervisorTimeout() => clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get bleChannelMap => $_getN(3);
  @$pb.TagNumber(4)
  set bleChannelMap($core.List<$core.int> v) { $_setBytes(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasBleChannelMap() => $_has(3);
  @$pb.TagNumber(4)
  void clearBleChannelMap() => clearField(4);

  @$pb.TagNumber(5)
  $core.int get mtuSize => $_getIZ(4);
  @$pb.TagNumber(5)
  set mtuSize($core.int v) { $_setUnsignedInt32(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasMtuSize() => $_has(4);
  @$pb.TagNumber(5)
  void clearMtuSize() => clearField(5);
}

class LogDataNotification_EnergySurveySummary extends $pb.GeneratedMessage {
  factory LogDataNotification_EnergySurveySummary({
    $core.int? samples,
    $core.List<$core.int>? averageEnergy,
  }) {
    final $result = create();
    if (samples != null) {
      $result.samples = samples;
    }
    if (averageEnergy != null) {
      $result.averageEnergy = averageEnergy;
    }
    return $result;
  }
  LogDataNotification_EnergySurveySummary._() : super();
  factory LogDataNotification_EnergySurveySummary.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory LogDataNotification_EnergySurveySummary.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'LogDataNotification.EnergySurveySummary', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'samples', $pb.PbFieldType.QU3)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'averageEnergy', $pb.PbFieldType.QY, protoName: 'averageEnergy')
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  LogDataNotification_EnergySurveySummary clone() => LogDataNotification_EnergySurveySummary()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  LogDataNotification_EnergySurveySummary copyWith(void Function(LogDataNotification_EnergySurveySummary) updates) => super.copyWith((message) => updates(message as LogDataNotification_EnergySurveySummary)) as LogDataNotification_EnergySurveySummary;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LogDataNotification_EnergySurveySummary create() => LogDataNotification_EnergySurveySummary._();
  LogDataNotification_EnergySurveySummary createEmptyInstance() => create();
  static $pb.PbList<LogDataNotification_EnergySurveySummary> createRepeated() => $pb.PbList<LogDataNotification_EnergySurveySummary>();
  @$core.pragma('dart2js:noInline')
  static LogDataNotification_EnergySurveySummary getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LogDataNotification_EnergySurveySummary>(create);
  static LogDataNotification_EnergySurveySummary? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get samples => $_getIZ(0);
  @$pb.TagNumber(1)
  set samples($core.int v) { $_setUnsignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSamples() => $_has(0);
  @$pb.TagNumber(1)
  void clearSamples() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get averageEnergy => $_getN(1);
  @$pb.TagNumber(2)
  set averageEnergy($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasAverageEnergy() => $_has(1);
  @$pb.TagNumber(2)
  void clearAverageEnergy() => clearField(2);
}

enum LogDataNotification_DataLogObject_Event {
  logData, 
  connectionParam, 
  energySurvey, 
  logString, 
  notSet
}

class LogDataNotification_DataLogObject extends $pb.GeneratedMessage {
  factory LogDataNotification_DataLogObject({
    $core.List<$core.int>? logData,
    LogDataNotification_ConnectionParameters? connectionParam,
    LogDataNotification_EnergySurveySummary? energySurvey,
    $core.List<$core.int>? logString,
  }) {
    final $result = create();
    if (logData != null) {
      $result.logData = logData;
    }
    if (connectionParam != null) {
      $result.connectionParam = connectionParam;
    }
    if (energySurvey != null) {
      $result.energySurvey = energySurvey;
    }
    if (logString != null) {
      $result.logString = logString;
    }
    return $result;
  }
  LogDataNotification_DataLogObject._() : super();
  factory LogDataNotification_DataLogObject.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory LogDataNotification_DataLogObject.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static const $core.Map<$core.int, LogDataNotification_DataLogObject_Event> _LogDataNotification_DataLogObject_EventByTag = {
    1 : LogDataNotification_DataLogObject_Event.logData,
    2 : LogDataNotification_DataLogObject_Event.connectionParam,
    3 : LogDataNotification_DataLogObject_Event.energySurvey,
    4 : LogDataNotification_DataLogObject_Event.logString,
    0 : LogDataNotification_DataLogObject_Event.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'LogDataNotification.DataLogObject', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..oo(0, [1, 2, 3, 4])
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'logData', $pb.PbFieldType.OY, protoName: 'logData')
    ..aOM<LogDataNotification_ConnectionParameters>(2, _omitFieldNames ? '' : 'connectionParam', protoName: 'connectionParam', subBuilder: LogDataNotification_ConnectionParameters.create)
    ..aOM<LogDataNotification_EnergySurveySummary>(3, _omitFieldNames ? '' : 'energySurvey', protoName: 'energySurvey', subBuilder: LogDataNotification_EnergySurveySummary.create)
    ..a<$core.List<$core.int>>(4, _omitFieldNames ? '' : 'logString', $pb.PbFieldType.OY, protoName: 'logString')
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  LogDataNotification_DataLogObject clone() => LogDataNotification_DataLogObject()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  LogDataNotification_DataLogObject copyWith(void Function(LogDataNotification_DataLogObject) updates) => super.copyWith((message) => updates(message as LogDataNotification_DataLogObject)) as LogDataNotification_DataLogObject;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LogDataNotification_DataLogObject create() => LogDataNotification_DataLogObject._();
  LogDataNotification_DataLogObject createEmptyInstance() => create();
  static $pb.PbList<LogDataNotification_DataLogObject> createRepeated() => $pb.PbList<LogDataNotification_DataLogObject>();
  @$core.pragma('dart2js:noInline')
  static LogDataNotification_DataLogObject getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LogDataNotification_DataLogObject>(create);
  static LogDataNotification_DataLogObject? _defaultInstance;

  LogDataNotification_DataLogObject_Event whichEvent() => _LogDataNotification_DataLogObject_EventByTag[$_whichOneof(0)]!;
  void clearEvent() => clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $core.List<$core.int> get logData => $_getN(0);
  @$pb.TagNumber(1)
  set logData($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasLogData() => $_has(0);
  @$pb.TagNumber(1)
  void clearLogData() => clearField(1);

  @$pb.TagNumber(2)
  LogDataNotification_ConnectionParameters get connectionParam => $_getN(1);
  @$pb.TagNumber(2)
  set connectionParam(LogDataNotification_ConnectionParameters v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasConnectionParam() => $_has(1);
  @$pb.TagNumber(2)
  void clearConnectionParam() => clearField(2);
  @$pb.TagNumber(2)
  LogDataNotification_ConnectionParameters ensureConnectionParam() => $_ensure(1);

  @$pb.TagNumber(3)
  LogDataNotification_EnergySurveySummary get energySurvey => $_getN(2);
  @$pb.TagNumber(3)
  set energySurvey(LogDataNotification_EnergySurveySummary v) { setField(3, v); }
  @$pb.TagNumber(3)
  $core.bool hasEnergySurvey() => $_has(2);
  @$pb.TagNumber(3)
  void clearEnergySurvey() => clearField(3);
  @$pb.TagNumber(3)
  LogDataNotification_EnergySurveySummary ensureEnergySurvey() => $_ensure(2);

  @$pb.TagNumber(4)
  $core.List<$core.int> get logString => $_getN(3);
  @$pb.TagNumber(4)
  set logString($core.List<$core.int> v) { $_setBytes(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasLogString() => $_has(3);
  @$pb.TagNumber(4)
  void clearLogString() => clearField(4);
}

class LogDataNotification extends $pb.GeneratedMessage {
  factory LogDataNotification({
    LogLevel? logLevel,
    LogDataNotification_DataLogObject? dataLogObject,
  }) {
    final $result = create();
    if (logLevel != null) {
      $result.logLevel = logLevel;
    }
    if (dataLogObject != null) {
      $result.dataLogObject = dataLogObject;
    }
    return $result;
  }
  LogDataNotification._() : super();
  factory LogDataNotification.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory LogDataNotification.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'LogDataNotification', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..e<LogLevel>(1, _omitFieldNames ? '' : 'logLevel', $pb.PbFieldType.QE, protoName: 'logLevel', defaultOrMaker: LogLevel.LOGLEVEL_OFF, valueOf: LogLevel.valueOf, enumValues: LogLevel.values)
    ..aQM<LogDataNotification_DataLogObject>(2, _omitFieldNames ? '' : 'dataLogObject', protoName: 'dataLogObject', subBuilder: LogDataNotification_DataLogObject.create)
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  LogDataNotification clone() => LogDataNotification()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  LogDataNotification copyWith(void Function(LogDataNotification) updates) => super.copyWith((message) => updates(message as LogDataNotification)) as LogDataNotification;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LogDataNotification create() => LogDataNotification._();
  LogDataNotification createEmptyInstance() => create();
  static $pb.PbList<LogDataNotification> createRepeated() => $pb.PbList<LogDataNotification>();
  @$core.pragma('dart2js:noInline')
  static LogDataNotification getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LogDataNotification>(create);
  static LogDataNotification? _defaultInstance;

  @$pb.TagNumber(1)
  LogLevel get logLevel => $_getN(0);
  @$pb.TagNumber(1)
  set logLevel(LogLevel v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasLogLevel() => $_has(0);
  @$pb.TagNumber(1)
  void clearLogLevel() => clearField(1);

  @$pb.TagNumber(2)
  LogDataNotification_DataLogObject get dataLogObject => $_getN(1);
  @$pb.TagNumber(2)
  set dataLogObject(LogDataNotification_DataLogObject v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasDataLogObject() => $_has(1);
  @$pb.TagNumber(2)
  void clearDataLogObject() => clearField(2);
  @$pb.TagNumber(2)
  LogDataNotification_DataLogObject ensureDataLogObject() => $_ensure(1);
}

class SpindownRequest_StartSpindown extends $pb.GeneratedMessage {
  factory SpindownRequest_StartSpindown({
    $core.bool? enable,
  }) {
    final $result = create();
    if (enable != null) {
      $result.enable = enable;
    }
    return $result;
  }
  SpindownRequest_StartSpindown._() : super();
  factory SpindownRequest_StartSpindown.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SpindownRequest_StartSpindown.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SpindownRequest.StartSpindown', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..a<$core.bool>(1, _omitFieldNames ? '' : 'enable', $pb.PbFieldType.QB)
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SpindownRequest_StartSpindown clone() => SpindownRequest_StartSpindown()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SpindownRequest_StartSpindown copyWith(void Function(SpindownRequest_StartSpindown) updates) => super.copyWith((message) => updates(message as SpindownRequest_StartSpindown)) as SpindownRequest_StartSpindown;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SpindownRequest_StartSpindown create() => SpindownRequest_StartSpindown._();
  SpindownRequest_StartSpindown createEmptyInstance() => create();
  static $pb.PbList<SpindownRequest_StartSpindown> createRepeated() => $pb.PbList<SpindownRequest_StartSpindown>();
  @$core.pragma('dart2js:noInline')
  static SpindownRequest_StartSpindown getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SpindownRequest_StartSpindown>(create);
  static SpindownRequest_StartSpindown? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get enable => $_getBF(0);
  @$pb.TagNumber(1)
  set enable($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasEnable() => $_has(0);
  @$pb.TagNumber(1)
  void clearEnable() => clearField(1);
}

class SpindownRequest_IgnoreSpindown extends $pb.GeneratedMessage {
  factory SpindownRequest_IgnoreSpindown({
    $core.bool? enable,
  }) {
    final $result = create();
    if (enable != null) {
      $result.enable = enable;
    }
    return $result;
  }
  SpindownRequest_IgnoreSpindown._() : super();
  factory SpindownRequest_IgnoreSpindown.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SpindownRequest_IgnoreSpindown.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SpindownRequest.IgnoreSpindown', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..a<$core.bool>(1, _omitFieldNames ? '' : 'enable', $pb.PbFieldType.QB)
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SpindownRequest_IgnoreSpindown clone() => SpindownRequest_IgnoreSpindown()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SpindownRequest_IgnoreSpindown copyWith(void Function(SpindownRequest_IgnoreSpindown) updates) => super.copyWith((message) => updates(message as SpindownRequest_IgnoreSpindown)) as SpindownRequest_IgnoreSpindown;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SpindownRequest_IgnoreSpindown create() => SpindownRequest_IgnoreSpindown._();
  SpindownRequest_IgnoreSpindown createEmptyInstance() => create();
  static $pb.PbList<SpindownRequest_IgnoreSpindown> createRepeated() => $pb.PbList<SpindownRequest_IgnoreSpindown>();
  @$core.pragma('dart2js:noInline')
  static SpindownRequest_IgnoreSpindown getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SpindownRequest_IgnoreSpindown>(create);
  static SpindownRequest_IgnoreSpindown? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get enable => $_getBF(0);
  @$pb.TagNumber(1)
  set enable($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasEnable() => $_has(0);
  @$pb.TagNumber(1)
  void clearEnable() => clearField(1);
}

enum SpindownRequest_Request {
  startSpindown, 
  ignoreSpindown, 
  notSet
}

/// OpCode 0x3A
class SpindownRequest extends $pb.GeneratedMessage {
  factory SpindownRequest({
    SpindownRequest_StartSpindown? startSpindown,
    SpindownRequest_IgnoreSpindown? ignoreSpindown,
  }) {
    final $result = create();
    if (startSpindown != null) {
      $result.startSpindown = startSpindown;
    }
    if (ignoreSpindown != null) {
      $result.ignoreSpindown = ignoreSpindown;
    }
    return $result;
  }
  SpindownRequest._() : super();
  factory SpindownRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SpindownRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static const $core.Map<$core.int, SpindownRequest_Request> _SpindownRequest_RequestByTag = {
    1 : SpindownRequest_Request.startSpindown,
    2 : SpindownRequest_Request.ignoreSpindown,
    0 : SpindownRequest_Request.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SpindownRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..oo(0, [1, 2])
    ..aOM<SpindownRequest_StartSpindown>(1, _omitFieldNames ? '' : 'startSpindown', protoName: 'startSpindown', subBuilder: SpindownRequest_StartSpindown.create)
    ..aOM<SpindownRequest_IgnoreSpindown>(2, _omitFieldNames ? '' : 'ignoreSpindown', protoName: 'ignoreSpindown', subBuilder: SpindownRequest_IgnoreSpindown.create)
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SpindownRequest clone() => SpindownRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SpindownRequest copyWith(void Function(SpindownRequest) updates) => super.copyWith((message) => updates(message as SpindownRequest)) as SpindownRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SpindownRequest create() => SpindownRequest._();
  SpindownRequest createEmptyInstance() => create();
  static $pb.PbList<SpindownRequest> createRepeated() => $pb.PbList<SpindownRequest>();
  @$core.pragma('dart2js:noInline')
  static SpindownRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SpindownRequest>(create);
  static SpindownRequest? _defaultInstance;

  SpindownRequest_Request whichRequest() => _SpindownRequest_RequestByTag[$_whichOneof(0)]!;
  void clearRequest() => clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  SpindownRequest_StartSpindown get startSpindown => $_getN(0);
  @$pb.TagNumber(1)
  set startSpindown(SpindownRequest_StartSpindown v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasStartSpindown() => $_has(0);
  @$pb.TagNumber(1)
  void clearStartSpindown() => clearField(1);
  @$pb.TagNumber(1)
  SpindownRequest_StartSpindown ensureStartSpindown() => $_ensure(0);

  @$pb.TagNumber(2)
  SpindownRequest_IgnoreSpindown get ignoreSpindown => $_getN(1);
  @$pb.TagNumber(2)
  set ignoreSpindown(SpindownRequest_IgnoreSpindown v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasIgnoreSpindown() => $_has(1);
  @$pb.TagNumber(2)
  void clearIgnoreSpindown() => clearField(2);
  @$pb.TagNumber(2)
  SpindownRequest_IgnoreSpindown ensureIgnoreSpindown() => $_ensure(1);
}

class SpindownNotification_ManualSpindownStatus extends $pb.GeneratedMessage {
  factory SpindownNotification_ManualSpindownStatus({
    SpindownStatus? spindownStatus,
    $core.int? targetSpeedLow,
    $core.int? targetSpeedHigh,
  }) {
    final $result = create();
    if (spindownStatus != null) {
      $result.spindownStatus = spindownStatus;
    }
    if (targetSpeedLow != null) {
      $result.targetSpeedLow = targetSpeedLow;
    }
    if (targetSpeedHigh != null) {
      $result.targetSpeedHigh = targetSpeedHigh;
    }
    return $result;
  }
  SpindownNotification_ManualSpindownStatus._() : super();
  factory SpindownNotification_ManualSpindownStatus.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SpindownNotification_ManualSpindownStatus.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SpindownNotification.ManualSpindownStatus', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..e<SpindownStatus>(1, _omitFieldNames ? '' : 'spindownStatus', $pb.PbFieldType.QE, protoName: 'spindownStatus', defaultOrMaker: SpindownStatus.SPINDOWN_IDLE, valueOf: SpindownStatus.valueOf, enumValues: SpindownStatus.values)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'targetSpeedLow', $pb.PbFieldType.OU3, protoName: 'targetSpeedLow')
    ..a<$core.int>(3, _omitFieldNames ? '' : 'targetSpeedHigh', $pb.PbFieldType.OU3, protoName: 'targetSpeedHigh')
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SpindownNotification_ManualSpindownStatus clone() => SpindownNotification_ManualSpindownStatus()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SpindownNotification_ManualSpindownStatus copyWith(void Function(SpindownNotification_ManualSpindownStatus) updates) => super.copyWith((message) => updates(message as SpindownNotification_ManualSpindownStatus)) as SpindownNotification_ManualSpindownStatus;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SpindownNotification_ManualSpindownStatus create() => SpindownNotification_ManualSpindownStatus._();
  SpindownNotification_ManualSpindownStatus createEmptyInstance() => create();
  static $pb.PbList<SpindownNotification_ManualSpindownStatus> createRepeated() => $pb.PbList<SpindownNotification_ManualSpindownStatus>();
  @$core.pragma('dart2js:noInline')
  static SpindownNotification_ManualSpindownStatus getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SpindownNotification_ManualSpindownStatus>(create);
  static SpindownNotification_ManualSpindownStatus? _defaultInstance;

  @$pb.TagNumber(1)
  SpindownStatus get spindownStatus => $_getN(0);
  @$pb.TagNumber(1)
  set spindownStatus(SpindownStatus v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasSpindownStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearSpindownStatus() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get targetSpeedLow => $_getIZ(1);
  @$pb.TagNumber(2)
  set targetSpeedLow($core.int v) { $_setUnsignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasTargetSpeedLow() => $_has(1);
  @$pb.TagNumber(2)
  void clearTargetSpeedLow() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get targetSpeedHigh => $_getIZ(2);
  @$pb.TagNumber(3)
  set targetSpeedHigh($core.int v) { $_setUnsignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasTargetSpeedHigh() => $_has(2);
  @$pb.TagNumber(3)
  void clearTargetSpeedHigh() => clearField(3);
}

class SpindownNotification_AutoSpindownStatus extends $pb.GeneratedMessage {
  factory SpindownNotification_AutoSpindownStatus({
    $core.bool? completed,
  }) {
    final $result = create();
    if (completed != null) {
      $result.completed = completed;
    }
    return $result;
  }
  SpindownNotification_AutoSpindownStatus._() : super();
  factory SpindownNotification_AutoSpindownStatus.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SpindownNotification_AutoSpindownStatus.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SpindownNotification.AutoSpindownStatus', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..a<$core.bool>(1, _omitFieldNames ? '' : 'completed', $pb.PbFieldType.QB)
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SpindownNotification_AutoSpindownStatus clone() => SpindownNotification_AutoSpindownStatus()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SpindownNotification_AutoSpindownStatus copyWith(void Function(SpindownNotification_AutoSpindownStatus) updates) => super.copyWith((message) => updates(message as SpindownNotification_AutoSpindownStatus)) as SpindownNotification_AutoSpindownStatus;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SpindownNotification_AutoSpindownStatus create() => SpindownNotification_AutoSpindownStatus._();
  SpindownNotification_AutoSpindownStatus createEmptyInstance() => create();
  static $pb.PbList<SpindownNotification_AutoSpindownStatus> createRepeated() => $pb.PbList<SpindownNotification_AutoSpindownStatus>();
  @$core.pragma('dart2js:noInline')
  static SpindownNotification_AutoSpindownStatus getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SpindownNotification_AutoSpindownStatus>(create);
  static SpindownNotification_AutoSpindownStatus? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get completed => $_getBF(0);
  @$pb.TagNumber(1)
  set completed($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasCompleted() => $_has(0);
  @$pb.TagNumber(1)
  void clearCompleted() => clearField(1);
}

enum SpindownNotification_Event {
  manualSpindownStatus, 
  autoSpindownStatus, 
  notSet
}

/// OpCode 0x3B
class SpindownNotification extends $pb.GeneratedMessage {
  factory SpindownNotification({
    SpindownNotification_ManualSpindownStatus? manualSpindownStatus,
    SpindownNotification_AutoSpindownStatus? autoSpindownStatus,
  }) {
    final $result = create();
    if (manualSpindownStatus != null) {
      $result.manualSpindownStatus = manualSpindownStatus;
    }
    if (autoSpindownStatus != null) {
      $result.autoSpindownStatus = autoSpindownStatus;
    }
    return $result;
  }
  SpindownNotification._() : super();
  factory SpindownNotification.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SpindownNotification.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static const $core.Map<$core.int, SpindownNotification_Event> _SpindownNotification_EventByTag = {
    1 : SpindownNotification_Event.manualSpindownStatus,
    2 : SpindownNotification_Event.autoSpindownStatus,
    0 : SpindownNotification_Event.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SpindownNotification', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..oo(0, [1, 2])
    ..aOM<SpindownNotification_ManualSpindownStatus>(1, _omitFieldNames ? '' : 'manualSpindownStatus', protoName: 'manualSpindownStatus', subBuilder: SpindownNotification_ManualSpindownStatus.create)
    ..aOM<SpindownNotification_AutoSpindownStatus>(2, _omitFieldNames ? '' : 'autoSpindownStatus', protoName: 'autoSpindownStatus', subBuilder: SpindownNotification_AutoSpindownStatus.create)
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SpindownNotification clone() => SpindownNotification()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SpindownNotification copyWith(void Function(SpindownNotification) updates) => super.copyWith((message) => updates(message as SpindownNotification)) as SpindownNotification;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SpindownNotification create() => SpindownNotification._();
  SpindownNotification createEmptyInstance() => create();
  static $pb.PbList<SpindownNotification> createRepeated() => $pb.PbList<SpindownNotification>();
  @$core.pragma('dart2js:noInline')
  static SpindownNotification getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SpindownNotification>(create);
  static SpindownNotification? _defaultInstance;

  SpindownNotification_Event whichEvent() => _SpindownNotification_EventByTag[$_whichOneof(0)]!;
  void clearEvent() => clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  SpindownNotification_ManualSpindownStatus get manualSpindownStatus => $_getN(0);
  @$pb.TagNumber(1)
  set manualSpindownStatus(SpindownNotification_ManualSpindownStatus v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasManualSpindownStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearManualSpindownStatus() => clearField(1);
  @$pb.TagNumber(1)
  SpindownNotification_ManualSpindownStatus ensureManualSpindownStatus() => $_ensure(0);

  @$pb.TagNumber(2)
  SpindownNotification_AutoSpindownStatus get autoSpindownStatus => $_getN(1);
  @$pb.TagNumber(2)
  set autoSpindownStatus(SpindownNotification_AutoSpindownStatus v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasAutoSpindownStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearAutoSpindownStatus() => clearField(2);
  @$pb.TagNumber(2)
  SpindownNotification_AutoSpindownStatus ensureAutoSpindownStatus() => $_ensure(1);
}

/// OpCode 0x3C
class GetResponse extends $pb.GeneratedMessage {
  factory GetResponse({
    $core.int? dataObjectId,
    $core.List<$core.int>? dataObjectData,
  }) {
    final $result = create();
    if (dataObjectId != null) {
      $result.dataObjectId = dataObjectId;
    }
    if (dataObjectData != null) {
      $result.dataObjectData = dataObjectData;
    }
    return $result;
  }
  GetResponse._() : super();
  factory GetResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GetResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GetResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'dataObjectId', $pb.PbFieldType.QU3, protoName: 'dataObjectId')
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'dataObjectData', $pb.PbFieldType.OY, protoName: 'dataObjectData')
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GetResponse clone() => GetResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GetResponse copyWith(void Function(GetResponse) updates) => super.copyWith((message) => updates(message as GetResponse)) as GetResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetResponse create() => GetResponse._();
  GetResponse createEmptyInstance() => create();
  static $pb.PbList<GetResponse> createRepeated() => $pb.PbList<GetResponse>();
  @$core.pragma('dart2js:noInline')
  static GetResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetResponse>(create);
  static GetResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get dataObjectId => $_getIZ(0);
  @$pb.TagNumber(1)
  set dataObjectId($core.int v) { $_setUnsignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasDataObjectId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDataObjectId() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get dataObjectData => $_getN(1);
  @$pb.TagNumber(2)
  set dataObjectData($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasDataObjectData() => $_has(1);
  @$pb.TagNumber(2)
  void clearDataObjectData() => clearField(2);
}

/// OpCode 0x3E
class StatusResponse extends $pb.GeneratedMessage {
  factory StatusResponse({
    $core.int? command,
    $core.int? status,
  }) {
    final $result = create();
    if (command != null) {
      $result.command = command;
    }
    if (status != null) {
      $result.status = status;
    }
    return $result;
  }
  StatusResponse._() : super();
  factory StatusResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory StatusResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'StatusResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'command', $pb.PbFieldType.QU3)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'status', $pb.PbFieldType.QU3)
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  StatusResponse clone() => StatusResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  StatusResponse copyWith(void Function(StatusResponse) updates) => super.copyWith((message) => updates(message as StatusResponse)) as StatusResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StatusResponse create() => StatusResponse._();
  StatusResponse createEmptyInstance() => create();
  static $pb.PbList<StatusResponse> createRepeated() => $pb.PbList<StatusResponse>();
  @$core.pragma('dart2js:noInline')
  static StatusResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<StatusResponse>(create);
  static StatusResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get command => $_getIZ(0);
  @$pb.TagNumber(1)
  set command($core.int v) { $_setUnsignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasCommand() => $_has(0);
  @$pb.TagNumber(1)
  void clearCommand() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get status => $_getIZ(1);
  @$pb.TagNumber(2)
  set status($core.int v) { $_setUnsignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearStatus() => clearField(2);
}

enum Set_Set {
  devInfo, 
  trainerSimParam, 
  trainerOptions, 
  deviceTiltConfig, 
  controllerInputConfig, 
  trainerGearIndexConfig, 
  wifiConfig, 
  dateTimeConfig, 
  notSet
}

/// OpCode 0x3F
class Set extends $pb.GeneratedMessage {
  factory Set({
    $core.int? options,
    $core.int? msgId,
    DevInfoSet? devInfo,
    TrainerSimulationParam? trainerSimParam,
    TrainerOptions? trainerOptions,
    DeviceTiltConfigPage? deviceTiltConfig,
    ControllerInputConfigPage? controllerInputConfig,
    TrainerGearIndexConfigPage? trainerGearIndexConfig,
    WifiConfigurationPage? wifiConfig,
    DateTimePage? dateTimeConfig,
  }) {
    final $result = create();
    if (options != null) {
      $result.options = options;
    }
    if (msgId != null) {
      $result.msgId = msgId;
    }
    if (devInfo != null) {
      $result.devInfo = devInfo;
    }
    if (trainerSimParam != null) {
      $result.trainerSimParam = trainerSimParam;
    }
    if (trainerOptions != null) {
      $result.trainerOptions = trainerOptions;
    }
    if (deviceTiltConfig != null) {
      $result.deviceTiltConfig = deviceTiltConfig;
    }
    if (controllerInputConfig != null) {
      $result.controllerInputConfig = controllerInputConfig;
    }
    if (trainerGearIndexConfig != null) {
      $result.trainerGearIndexConfig = trainerGearIndexConfig;
    }
    if (wifiConfig != null) {
      $result.wifiConfig = wifiConfig;
    }
    if (dateTimeConfig != null) {
      $result.dateTimeConfig = dateTimeConfig;
    }
    return $result;
  }
  Set._() : super();
  factory Set.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Set.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static const $core.Map<$core.int, Set_Set> _Set_SetByTag = {
    3 : Set_Set.devInfo,
    4 : Set_Set.trainerSimParam,
    5 : Set_Set.trainerOptions,
    6 : Set_Set.deviceTiltConfig,
    7 : Set_Set.controllerInputConfig,
    8 : Set_Set.trainerGearIndexConfig,
    10 : Set_Set.wifiConfig,
    11 : Set_Set.dateTimeConfig,
    0 : Set_Set.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Set', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..oo(0, [3, 4, 5, 6, 7, 8, 10, 11])
    ..a<$core.int>(1, _omitFieldNames ? '' : 'options', $pb.PbFieldType.OU3)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'msgId', $pb.PbFieldType.OU3, protoName: 'msgId')
    ..aOM<DevInfoSet>(3, _omitFieldNames ? '' : 'devInfo', protoName: 'devInfo', subBuilder: DevInfoSet.create)
    ..aOM<TrainerSimulationParam>(4, _omitFieldNames ? '' : 'trainerSimParam', protoName: 'trainerSimParam', subBuilder: TrainerSimulationParam.create)
    ..aOM<TrainerOptions>(5, _omitFieldNames ? '' : 'trainerOptions', protoName: 'trainerOptions', subBuilder: TrainerOptions.create)
    ..aOM<DeviceTiltConfigPage>(6, _omitFieldNames ? '' : 'deviceTiltConfig', protoName: 'deviceTiltConfig', subBuilder: DeviceTiltConfigPage.create)
    ..aOM<ControllerInputConfigPage>(7, _omitFieldNames ? '' : 'controllerInputConfig', protoName: 'controllerInputConfig', subBuilder: ControllerInputConfigPage.create)
    ..aOM<TrainerGearIndexConfigPage>(8, _omitFieldNames ? '' : 'trainerGearIndexConfig', protoName: 'trainerGearIndexConfig', subBuilder: TrainerGearIndexConfigPage.create)
    ..aOM<WifiConfigurationPage>(10, _omitFieldNames ? '' : 'wifiConfig', protoName: 'wifiConfig', subBuilder: WifiConfigurationPage.create)
    ..aOM<DateTimePage>(11, _omitFieldNames ? '' : 'dateTimeConfig', protoName: 'dateTimeConfig', subBuilder: DateTimePage.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  Set clone() => Set()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  Set copyWith(void Function(Set) updates) => super.copyWith((message) => updates(message as Set)) as Set;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Set create() => Set._();
  Set createEmptyInstance() => create();
  static $pb.PbList<Set> createRepeated() => $pb.PbList<Set>();
  @$core.pragma('dart2js:noInline')
  static Set getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Set>(create);
  static Set? _defaultInstance;

  Set_Set whichSet() => _Set_SetByTag[$_whichOneof(0)]!;
  void clearSet() => clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $core.int get options => $_getIZ(0);
  @$pb.TagNumber(1)
  set options($core.int v) { $_setUnsignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasOptions() => $_has(0);
  @$pb.TagNumber(1)
  void clearOptions() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get msgId => $_getIZ(1);
  @$pb.TagNumber(2)
  set msgId($core.int v) { $_setUnsignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMsgId() => $_has(1);
  @$pb.TagNumber(2)
  void clearMsgId() => clearField(2);

  @$pb.TagNumber(3)
  DevInfoSet get devInfo => $_getN(2);
  @$pb.TagNumber(3)
  set devInfo(DevInfoSet v) { setField(3, v); }
  @$pb.TagNumber(3)
  $core.bool hasDevInfo() => $_has(2);
  @$pb.TagNumber(3)
  void clearDevInfo() => clearField(3);
  @$pb.TagNumber(3)
  DevInfoSet ensureDevInfo() => $_ensure(2);

  @$pb.TagNumber(4)
  TrainerSimulationParam get trainerSimParam => $_getN(3);
  @$pb.TagNumber(4)
  set trainerSimParam(TrainerSimulationParam v) { setField(4, v); }
  @$pb.TagNumber(4)
  $core.bool hasTrainerSimParam() => $_has(3);
  @$pb.TagNumber(4)
  void clearTrainerSimParam() => clearField(4);
  @$pb.TagNumber(4)
  TrainerSimulationParam ensureTrainerSimParam() => $_ensure(3);

  @$pb.TagNumber(5)
  TrainerOptions get trainerOptions => $_getN(4);
  @$pb.TagNumber(5)
  set trainerOptions(TrainerOptions v) { setField(5, v); }
  @$pb.TagNumber(5)
  $core.bool hasTrainerOptions() => $_has(4);
  @$pb.TagNumber(5)
  void clearTrainerOptions() => clearField(5);
  @$pb.TagNumber(5)
  TrainerOptions ensureTrainerOptions() => $_ensure(4);

  @$pb.TagNumber(6)
  DeviceTiltConfigPage get deviceTiltConfig => $_getN(5);
  @$pb.TagNumber(6)
  set deviceTiltConfig(DeviceTiltConfigPage v) { setField(6, v); }
  @$pb.TagNumber(6)
  $core.bool hasDeviceTiltConfig() => $_has(5);
  @$pb.TagNumber(6)
  void clearDeviceTiltConfig() => clearField(6);
  @$pb.TagNumber(6)
  DeviceTiltConfigPage ensureDeviceTiltConfig() => $_ensure(5);

  @$pb.TagNumber(7)
  ControllerInputConfigPage get controllerInputConfig => $_getN(6);
  @$pb.TagNumber(7)
  set controllerInputConfig(ControllerInputConfigPage v) { setField(7, v); }
  @$pb.TagNumber(7)
  $core.bool hasControllerInputConfig() => $_has(6);
  @$pb.TagNumber(7)
  void clearControllerInputConfig() => clearField(7);
  @$pb.TagNumber(7)
  ControllerInputConfigPage ensureControllerInputConfig() => $_ensure(6);

  @$pb.TagNumber(8)
  TrainerGearIndexConfigPage get trainerGearIndexConfig => $_getN(7);
  @$pb.TagNumber(8)
  set trainerGearIndexConfig(TrainerGearIndexConfigPage v) { setField(8, v); }
  @$pb.TagNumber(8)
  $core.bool hasTrainerGearIndexConfig() => $_has(7);
  @$pb.TagNumber(8)
  void clearTrainerGearIndexConfig() => clearField(8);
  @$pb.TagNumber(8)
  TrainerGearIndexConfigPage ensureTrainerGearIndexConfig() => $_ensure(7);

  @$pb.TagNumber(10)
  WifiConfigurationPage get wifiConfig => $_getN(8);
  @$pb.TagNumber(10)
  set wifiConfig(WifiConfigurationPage v) { setField(10, v); }
  @$pb.TagNumber(10)
  $core.bool hasWifiConfig() => $_has(8);
  @$pb.TagNumber(10)
  void clearWifiConfig() => clearField(10);
  @$pb.TagNumber(10)
  WifiConfigurationPage ensureWifiConfig() => $_ensure(8);

  @$pb.TagNumber(11)
  DateTimePage get dateTimeConfig => $_getN(9);
  @$pb.TagNumber(11)
  set dateTimeConfig(DateTimePage v) { setField(11, v); }
  @$pb.TagNumber(11)
  $core.bool hasDateTimeConfig() => $_has(9);
  @$pb.TagNumber(11)
  void clearDateTimeConfig() => clearField(11);
  @$pb.TagNumber(11)
  DateTimePage ensureDateTimeConfig() => $_ensure(9);
}

enum SetResponse_Response_Page {
  devInfo, 
  trainerSimParam, 
  trainerOptions, 
  deviceTiltConfig, 
  controllerInputConfig, 
  trainerGearIndexConfig, 
  wifiConfig, 
  dateTimeConfig, 
  notSet
}

class SetResponse_Response extends $pb.GeneratedMessage {
  factory SetResponse_Response({
    DevInfoPage? devInfo,
    TrainerSimulationParam? trainerSimParam,
    TrainerOptions? trainerOptions,
    DeviceTiltConfigPage? deviceTiltConfig,
    ControllerInputConfigPage? controllerInputConfig,
    TrainerGearIndexConfigPage? trainerGearIndexConfig,
    WifiConfigurationPage? wifiConfig,
    DateTimePage? dateTimeConfig,
  }) {
    final $result = create();
    if (devInfo != null) {
      $result.devInfo = devInfo;
    }
    if (trainerSimParam != null) {
      $result.trainerSimParam = trainerSimParam;
    }
    if (trainerOptions != null) {
      $result.trainerOptions = trainerOptions;
    }
    if (deviceTiltConfig != null) {
      $result.deviceTiltConfig = deviceTiltConfig;
    }
    if (controllerInputConfig != null) {
      $result.controllerInputConfig = controllerInputConfig;
    }
    if (trainerGearIndexConfig != null) {
      $result.trainerGearIndexConfig = trainerGearIndexConfig;
    }
    if (wifiConfig != null) {
      $result.wifiConfig = wifiConfig;
    }
    if (dateTimeConfig != null) {
      $result.dateTimeConfig = dateTimeConfig;
    }
    return $result;
  }
  SetResponse_Response._() : super();
  factory SetResponse_Response.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SetResponse_Response.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static const $core.Map<$core.int, SetResponse_Response_Page> _SetResponse_Response_PageByTag = {
    1 : SetResponse_Response_Page.devInfo,
    2 : SetResponse_Response_Page.trainerSimParam,
    3 : SetResponse_Response_Page.trainerOptions,
    4 : SetResponse_Response_Page.deviceTiltConfig,
    5 : SetResponse_Response_Page.controllerInputConfig,
    6 : SetResponse_Response_Page.trainerGearIndexConfig,
    8 : SetResponse_Response_Page.wifiConfig,
    9 : SetResponse_Response_Page.dateTimeConfig,
    0 : SetResponse_Response_Page.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SetResponse.Response', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..oo(0, [1, 2, 3, 4, 5, 6, 8, 9])
    ..aOM<DevInfoPage>(1, _omitFieldNames ? '' : 'devInfo', protoName: 'devInfo', subBuilder: DevInfoPage.create)
    ..aOM<TrainerSimulationParam>(2, _omitFieldNames ? '' : 'trainerSimParam', protoName: 'trainerSimParam', subBuilder: TrainerSimulationParam.create)
    ..aOM<TrainerOptions>(3, _omitFieldNames ? '' : 'trainerOptions', protoName: 'trainerOptions', subBuilder: TrainerOptions.create)
    ..aOM<DeviceTiltConfigPage>(4, _omitFieldNames ? '' : 'deviceTiltConfig', protoName: 'deviceTiltConfig', subBuilder: DeviceTiltConfigPage.create)
    ..aOM<ControllerInputConfigPage>(5, _omitFieldNames ? '' : 'controllerInputConfig', protoName: 'controllerInputConfig', subBuilder: ControllerInputConfigPage.create)
    ..aOM<TrainerGearIndexConfigPage>(6, _omitFieldNames ? '' : 'trainerGearIndexConfig', protoName: 'trainerGearIndexConfig', subBuilder: TrainerGearIndexConfigPage.create)
    ..aOM<WifiConfigurationPage>(8, _omitFieldNames ? '' : 'wifiConfig', protoName: 'wifiConfig', subBuilder: WifiConfigurationPage.create)
    ..aOM<DateTimePage>(9, _omitFieldNames ? '' : 'dateTimeConfig', protoName: 'dateTimeConfig', subBuilder: DateTimePage.create)
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SetResponse_Response clone() => SetResponse_Response()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SetResponse_Response copyWith(void Function(SetResponse_Response) updates) => super.copyWith((message) => updates(message as SetResponse_Response)) as SetResponse_Response;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetResponse_Response create() => SetResponse_Response._();
  SetResponse_Response createEmptyInstance() => create();
  static $pb.PbList<SetResponse_Response> createRepeated() => $pb.PbList<SetResponse_Response>();
  @$core.pragma('dart2js:noInline')
  static SetResponse_Response getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SetResponse_Response>(create);
  static SetResponse_Response? _defaultInstance;

  SetResponse_Response_Page whichPage() => _SetResponse_Response_PageByTag[$_whichOneof(0)]!;
  void clearPage() => clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  DevInfoPage get devInfo => $_getN(0);
  @$pb.TagNumber(1)
  set devInfo(DevInfoPage v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasDevInfo() => $_has(0);
  @$pb.TagNumber(1)
  void clearDevInfo() => clearField(1);
  @$pb.TagNumber(1)
  DevInfoPage ensureDevInfo() => $_ensure(0);

  @$pb.TagNumber(2)
  TrainerSimulationParam get trainerSimParam => $_getN(1);
  @$pb.TagNumber(2)
  set trainerSimParam(TrainerSimulationParam v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasTrainerSimParam() => $_has(1);
  @$pb.TagNumber(2)
  void clearTrainerSimParam() => clearField(2);
  @$pb.TagNumber(2)
  TrainerSimulationParam ensureTrainerSimParam() => $_ensure(1);

  @$pb.TagNumber(3)
  TrainerOptions get trainerOptions => $_getN(2);
  @$pb.TagNumber(3)
  set trainerOptions(TrainerOptions v) { setField(3, v); }
  @$pb.TagNumber(3)
  $core.bool hasTrainerOptions() => $_has(2);
  @$pb.TagNumber(3)
  void clearTrainerOptions() => clearField(3);
  @$pb.TagNumber(3)
  TrainerOptions ensureTrainerOptions() => $_ensure(2);

  @$pb.TagNumber(4)
  DeviceTiltConfigPage get deviceTiltConfig => $_getN(3);
  @$pb.TagNumber(4)
  set deviceTiltConfig(DeviceTiltConfigPage v) { setField(4, v); }
  @$pb.TagNumber(4)
  $core.bool hasDeviceTiltConfig() => $_has(3);
  @$pb.TagNumber(4)
  void clearDeviceTiltConfig() => clearField(4);
  @$pb.TagNumber(4)
  DeviceTiltConfigPage ensureDeviceTiltConfig() => $_ensure(3);

  @$pb.TagNumber(5)
  ControllerInputConfigPage get controllerInputConfig => $_getN(4);
  @$pb.TagNumber(5)
  set controllerInputConfig(ControllerInputConfigPage v) { setField(5, v); }
  @$pb.TagNumber(5)
  $core.bool hasControllerInputConfig() => $_has(4);
  @$pb.TagNumber(5)
  void clearControllerInputConfig() => clearField(5);
  @$pb.TagNumber(5)
  ControllerInputConfigPage ensureControllerInputConfig() => $_ensure(4);

  @$pb.TagNumber(6)
  TrainerGearIndexConfigPage get trainerGearIndexConfig => $_getN(5);
  @$pb.TagNumber(6)
  set trainerGearIndexConfig(TrainerGearIndexConfigPage v) { setField(6, v); }
  @$pb.TagNumber(6)
  $core.bool hasTrainerGearIndexConfig() => $_has(5);
  @$pb.TagNumber(6)
  void clearTrainerGearIndexConfig() => clearField(6);
  @$pb.TagNumber(6)
  TrainerGearIndexConfigPage ensureTrainerGearIndexConfig() => $_ensure(5);

  @$pb.TagNumber(8)
  WifiConfigurationPage get wifiConfig => $_getN(6);
  @$pb.TagNumber(8)
  set wifiConfig(WifiConfigurationPage v) { setField(8, v); }
  @$pb.TagNumber(8)
  $core.bool hasWifiConfig() => $_has(6);
  @$pb.TagNumber(8)
  void clearWifiConfig() => clearField(8);
  @$pb.TagNumber(8)
  WifiConfigurationPage ensureWifiConfig() => $_ensure(6);

  @$pb.TagNumber(9)
  DateTimePage get dateTimeConfig => $_getN(7);
  @$pb.TagNumber(9)
  set dateTimeConfig(DateTimePage v) { setField(9, v); }
  @$pb.TagNumber(9)
  $core.bool hasDateTimeConfig() => $_has(7);
  @$pb.TagNumber(9)
  void clearDateTimeConfig() => clearField(9);
  @$pb.TagNumber(9)
  DateTimePage ensureDateTimeConfig() => $_ensure(7);
}

/// OpCode 0x40
class SetResponse extends $pb.GeneratedMessage {
  factory SetResponse({
    $core.int? status,
    $core.int? msgId,
    SetResponse_Response? response,
  }) {
    final $result = create();
    if (status != null) {
      $result.status = status;
    }
    if (msgId != null) {
      $result.msgId = msgId;
    }
    if (response != null) {
      $result.response = response;
    }
    return $result;
  }
  SetResponse._() : super();
  factory SetResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SetResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SetResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'status', $pb.PbFieldType.OU3)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'msgId', $pb.PbFieldType.OU3, protoName: 'msgId')
    ..aOM<SetResponse_Response>(3, _omitFieldNames ? '' : 'response', subBuilder: SetResponse_Response.create)
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SetResponse clone() => SetResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SetResponse copyWith(void Function(SetResponse) updates) => super.copyWith((message) => updates(message as SetResponse)) as SetResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetResponse create() => SetResponse._();
  SetResponse createEmptyInstance() => create();
  static $pb.PbList<SetResponse> createRepeated() => $pb.PbList<SetResponse>();
  @$core.pragma('dart2js:noInline')
  static SetResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SetResponse>(create);
  static SetResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get status => $_getIZ(0);
  @$pb.TagNumber(1)
  set status($core.int v) { $_setUnsignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearStatus() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get msgId => $_getIZ(1);
  @$pb.TagNumber(2)
  set msgId($core.int v) { $_setUnsignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMsgId() => $_has(1);
  @$pb.TagNumber(2)
  void clearMsgId() => clearField(2);

  @$pb.TagNumber(3)
  SetResponse_Response get response => $_getN(2);
  @$pb.TagNumber(3)
  set response(SetResponse_Response v) { setField(3, v); }
  @$pb.TagNumber(3)
  $core.bool hasResponse() => $_has(2);
  @$pb.TagNumber(3)
  void clearResponse() => clearField(3);
  @$pb.TagNumber(3)
  SetResponse_Response ensureResponse() => $_ensure(2);
}

/// OpCode 0x41
class LogLevelSet extends $pb.GeneratedMessage {
  factory LogLevelSet({
    LogLevel? logLevel,
  }) {
    final $result = create();
    if (logLevel != null) {
      $result.logLevel = logLevel;
    }
    return $result;
  }
  LogLevelSet._() : super();
  factory LogLevelSet.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory LogLevelSet.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'LogLevelSet', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..e<LogLevel>(1, _omitFieldNames ? '' : 'logLevel', $pb.PbFieldType.OE, protoName: 'logLevel', defaultOrMaker: LogLevel.LOGLEVEL_OFF, valueOf: LogLevel.valueOf, enumValues: LogLevel.values)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  LogLevelSet clone() => LogLevelSet()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  LogLevelSet copyWith(void Function(LogLevelSet) updates) => super.copyWith((message) => updates(message as LogLevelSet)) as LogLevelSet;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LogLevelSet create() => LogLevelSet._();
  LogLevelSet createEmptyInstance() => create();
  static $pb.PbList<LogLevelSet> createRepeated() => $pb.PbList<LogLevelSet>();
  @$core.pragma('dart2js:noInline')
  static LogLevelSet getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LogLevelSet>(create);
  static LogLevelSet? _defaultInstance;

  @$pb.TagNumber(1)
  LogLevel get logLevel => $_getN(0);
  @$pb.TagNumber(1)
  set logLevel(LogLevel v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasLogLevel() => $_has(0);
  @$pb.TagNumber(1)
  void clearLogLevel() => clearField(1);
}

enum DataChangeNotification_Notification {
  devInfo, 
  trainerSimParam, 
  trainerOptions, 
  deviceTiltConfig, 
  controllerInputConfig, 
  trainerGearIndexConfig, 
  wifiConfig, 
  deviceUpdatePage, 
  dateTimePage, 
  bleSecurityPage, 
  notSet
}

/// Opcode 0x42
class DataChangeNotification extends $pb.GeneratedMessage {
  factory DataChangeNotification({
    DevInfoPage? devInfo,
    TrainerSimulationParam? trainerSimParam,
    TrainerOptions? trainerOptions,
    DeviceTiltConfigPage? deviceTiltConfig,
    ControllerInputConfigPage? controllerInputConfig,
    TrainerGearIndexConfigPage? trainerGearIndexConfig,
    WifiConfigurationPage? wifiConfig,
    DeviceUpdatePage? deviceUpdatePage,
    DateTimePage? dateTimePage,
    BleSecurityPage? bleSecurityPage,
  }) {
    final $result = create();
    if (devInfo != null) {
      $result.devInfo = devInfo;
    }
    if (trainerSimParam != null) {
      $result.trainerSimParam = trainerSimParam;
    }
    if (trainerOptions != null) {
      $result.trainerOptions = trainerOptions;
    }
    if (deviceTiltConfig != null) {
      $result.deviceTiltConfig = deviceTiltConfig;
    }
    if (controllerInputConfig != null) {
      $result.controllerInputConfig = controllerInputConfig;
    }
    if (trainerGearIndexConfig != null) {
      $result.trainerGearIndexConfig = trainerGearIndexConfig;
    }
    if (wifiConfig != null) {
      $result.wifiConfig = wifiConfig;
    }
    if (deviceUpdatePage != null) {
      $result.deviceUpdatePage = deviceUpdatePage;
    }
    if (dateTimePage != null) {
      $result.dateTimePage = dateTimePage;
    }
    if (bleSecurityPage != null) {
      $result.bleSecurityPage = bleSecurityPage;
    }
    return $result;
  }
  DataChangeNotification._() : super();
  factory DataChangeNotification.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DataChangeNotification.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static const $core.Map<$core.int, DataChangeNotification_Notification> _DataChangeNotification_NotificationByTag = {
    1 : DataChangeNotification_Notification.devInfo,
    2 : DataChangeNotification_Notification.trainerSimParam,
    3 : DataChangeNotification_Notification.trainerOptions,
    4 : DataChangeNotification_Notification.deviceTiltConfig,
    5 : DataChangeNotification_Notification.controllerInputConfig,
    6 : DataChangeNotification_Notification.trainerGearIndexConfig,
    8 : DataChangeNotification_Notification.wifiConfig,
    9 : DataChangeNotification_Notification.deviceUpdatePage,
    10 : DataChangeNotification_Notification.dateTimePage,
    11 : DataChangeNotification_Notification.bleSecurityPage,
    0 : DataChangeNotification_Notification.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DataChangeNotification', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..oo(0, [1, 2, 3, 4, 5, 6, 8, 9, 10, 11])
    ..aOM<DevInfoPage>(1, _omitFieldNames ? '' : 'devInfo', protoName: 'devInfo', subBuilder: DevInfoPage.create)
    ..aOM<TrainerSimulationParam>(2, _omitFieldNames ? '' : 'trainerSimParam', protoName: 'trainerSimParam', subBuilder: TrainerSimulationParam.create)
    ..aOM<TrainerOptions>(3, _omitFieldNames ? '' : 'trainerOptions', protoName: 'trainerOptions', subBuilder: TrainerOptions.create)
    ..aOM<DeviceTiltConfigPage>(4, _omitFieldNames ? '' : 'deviceTiltConfig', protoName: 'deviceTiltConfig', subBuilder: DeviceTiltConfigPage.create)
    ..aOM<ControllerInputConfigPage>(5, _omitFieldNames ? '' : 'controllerInputConfig', protoName: 'controllerInputConfig', subBuilder: ControllerInputConfigPage.create)
    ..aOM<TrainerGearIndexConfigPage>(6, _omitFieldNames ? '' : 'trainerGearIndexConfig', protoName: 'trainerGearIndexConfig', subBuilder: TrainerGearIndexConfigPage.create)
    ..aOM<WifiConfigurationPage>(8, _omitFieldNames ? '' : 'wifiConfig', protoName: 'wifiConfig', subBuilder: WifiConfigurationPage.create)
    ..aOM<DeviceUpdatePage>(9, _omitFieldNames ? '' : 'deviceUpdatePage', protoName: 'deviceUpdatePage', subBuilder: DeviceUpdatePage.create)
    ..aOM<DateTimePage>(10, _omitFieldNames ? '' : 'dateTimePage', protoName: 'dateTimePage', subBuilder: DateTimePage.create)
    ..aOM<BleSecurityPage>(11, _omitFieldNames ? '' : 'bleSecurityPage', protoName: 'bleSecurityPage', subBuilder: BleSecurityPage.create)
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DataChangeNotification clone() => DataChangeNotification()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DataChangeNotification copyWith(void Function(DataChangeNotification) updates) => super.copyWith((message) => updates(message as DataChangeNotification)) as DataChangeNotification;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DataChangeNotification create() => DataChangeNotification._();
  DataChangeNotification createEmptyInstance() => create();
  static $pb.PbList<DataChangeNotification> createRepeated() => $pb.PbList<DataChangeNotification>();
  @$core.pragma('dart2js:noInline')
  static DataChangeNotification getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DataChangeNotification>(create);
  static DataChangeNotification? _defaultInstance;

  DataChangeNotification_Notification whichNotification() => _DataChangeNotification_NotificationByTag[$_whichOneof(0)]!;
  void clearNotification() => clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  DevInfoPage get devInfo => $_getN(0);
  @$pb.TagNumber(1)
  set devInfo(DevInfoPage v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasDevInfo() => $_has(0);
  @$pb.TagNumber(1)
  void clearDevInfo() => clearField(1);
  @$pb.TagNumber(1)
  DevInfoPage ensureDevInfo() => $_ensure(0);

  @$pb.TagNumber(2)
  TrainerSimulationParam get trainerSimParam => $_getN(1);
  @$pb.TagNumber(2)
  set trainerSimParam(TrainerSimulationParam v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasTrainerSimParam() => $_has(1);
  @$pb.TagNumber(2)
  void clearTrainerSimParam() => clearField(2);
  @$pb.TagNumber(2)
  TrainerSimulationParam ensureTrainerSimParam() => $_ensure(1);

  @$pb.TagNumber(3)
  TrainerOptions get trainerOptions => $_getN(2);
  @$pb.TagNumber(3)
  set trainerOptions(TrainerOptions v) { setField(3, v); }
  @$pb.TagNumber(3)
  $core.bool hasTrainerOptions() => $_has(2);
  @$pb.TagNumber(3)
  void clearTrainerOptions() => clearField(3);
  @$pb.TagNumber(3)
  TrainerOptions ensureTrainerOptions() => $_ensure(2);

  @$pb.TagNumber(4)
  DeviceTiltConfigPage get deviceTiltConfig => $_getN(3);
  @$pb.TagNumber(4)
  set deviceTiltConfig(DeviceTiltConfigPage v) { setField(4, v); }
  @$pb.TagNumber(4)
  $core.bool hasDeviceTiltConfig() => $_has(3);
  @$pb.TagNumber(4)
  void clearDeviceTiltConfig() => clearField(4);
  @$pb.TagNumber(4)
  DeviceTiltConfigPage ensureDeviceTiltConfig() => $_ensure(3);

  @$pb.TagNumber(5)
  ControllerInputConfigPage get controllerInputConfig => $_getN(4);
  @$pb.TagNumber(5)
  set controllerInputConfig(ControllerInputConfigPage v) { setField(5, v); }
  @$pb.TagNumber(5)
  $core.bool hasControllerInputConfig() => $_has(4);
  @$pb.TagNumber(5)
  void clearControllerInputConfig() => clearField(5);
  @$pb.TagNumber(5)
  ControllerInputConfigPage ensureControllerInputConfig() => $_ensure(4);

  @$pb.TagNumber(6)
  TrainerGearIndexConfigPage get trainerGearIndexConfig => $_getN(5);
  @$pb.TagNumber(6)
  set trainerGearIndexConfig(TrainerGearIndexConfigPage v) { setField(6, v); }
  @$pb.TagNumber(6)
  $core.bool hasTrainerGearIndexConfig() => $_has(5);
  @$pb.TagNumber(6)
  void clearTrainerGearIndexConfig() => clearField(6);
  @$pb.TagNumber(6)
  TrainerGearIndexConfigPage ensureTrainerGearIndexConfig() => $_ensure(5);

  @$pb.TagNumber(8)
  WifiConfigurationPage get wifiConfig => $_getN(6);
  @$pb.TagNumber(8)
  set wifiConfig(WifiConfigurationPage v) { setField(8, v); }
  @$pb.TagNumber(8)
  $core.bool hasWifiConfig() => $_has(6);
  @$pb.TagNumber(8)
  void clearWifiConfig() => clearField(8);
  @$pb.TagNumber(8)
  WifiConfigurationPage ensureWifiConfig() => $_ensure(6);

  @$pb.TagNumber(9)
  DeviceUpdatePage get deviceUpdatePage => $_getN(7);
  @$pb.TagNumber(9)
  set deviceUpdatePage(DeviceUpdatePage v) { setField(9, v); }
  @$pb.TagNumber(9)
  $core.bool hasDeviceUpdatePage() => $_has(7);
  @$pb.TagNumber(9)
  void clearDeviceUpdatePage() => clearField(9);
  @$pb.TagNumber(9)
  DeviceUpdatePage ensureDeviceUpdatePage() => $_ensure(7);

  @$pb.TagNumber(10)
  DateTimePage get dateTimePage => $_getN(8);
  @$pb.TagNumber(10)
  set dateTimePage(DateTimePage v) { setField(10, v); }
  @$pb.TagNumber(10)
  $core.bool hasDateTimePage() => $_has(8);
  @$pb.TagNumber(10)
  void clearDateTimePage() => clearField(10);
  @$pb.TagNumber(10)
  DateTimePage ensureDateTimePage() => $_ensure(8);

  @$pb.TagNumber(11)
  BleSecurityPage get bleSecurityPage => $_getN(9);
  @$pb.TagNumber(11)
  set bleSecurityPage(BleSecurityPage v) { setField(11, v); }
  @$pb.TagNumber(11)
  $core.bool hasBleSecurityPage() => $_has(9);
  @$pb.TagNumber(11)
  void clearBleSecurityPage() => clearField(11);
  @$pb.TagNumber(11)
  BleSecurityPage ensureBleSecurityPage() => $_ensure(9);
}

class GameStateNotification_GameSpeed extends $pb.GeneratedMessage {
  factory GameStateNotification_GameSpeed({
    $core.int? normalisedSpeed,
    $core.int? speed,
  }) {
    final $result = create();
    if (normalisedSpeed != null) {
      $result.normalisedSpeed = normalisedSpeed;
    }
    if (speed != null) {
      $result.speed = speed;
    }
    return $result;
  }
  GameStateNotification_GameSpeed._() : super();
  factory GameStateNotification_GameSpeed.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GameStateNotification_GameSpeed.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GameStateNotification.GameSpeed', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'normalisedSpeed', $pb.PbFieldType.OS3, protoName: 'normalisedSpeed')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'speed', $pb.PbFieldType.OS3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GameStateNotification_GameSpeed clone() => GameStateNotification_GameSpeed()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GameStateNotification_GameSpeed copyWith(void Function(GameStateNotification_GameSpeed) updates) => super.copyWith((message) => updates(message as GameStateNotification_GameSpeed)) as GameStateNotification_GameSpeed;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GameStateNotification_GameSpeed create() => GameStateNotification_GameSpeed._();
  GameStateNotification_GameSpeed createEmptyInstance() => create();
  static $pb.PbList<GameStateNotification_GameSpeed> createRepeated() => $pb.PbList<GameStateNotification_GameSpeed>();
  @$core.pragma('dart2js:noInline')
  static GameStateNotification_GameSpeed getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GameStateNotification_GameSpeed>(create);
  static GameStateNotification_GameSpeed? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get normalisedSpeed => $_getIZ(0);
  @$pb.TagNumber(1)
  set normalisedSpeed($core.int v) { $_setSignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasNormalisedSpeed() => $_has(0);
  @$pb.TagNumber(1)
  void clearNormalisedSpeed() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get speed => $_getIZ(1);
  @$pb.TagNumber(2)
  set speed($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasSpeed() => $_has(1);
  @$pb.TagNumber(2)
  void clearSpeed() => clearField(2);
}

class GameStateNotification_RoadSurface extends $pb.GeneratedMessage {
  factory GameStateNotification_RoadSurface({
    RoadSurfaceType? roadSurfaceType,
    $core.int? roughness,
  }) {
    final $result = create();
    if (roadSurfaceType != null) {
      $result.roadSurfaceType = roadSurfaceType;
    }
    if (roughness != null) {
      $result.roughness = roughness;
    }
    return $result;
  }
  GameStateNotification_RoadSurface._() : super();
  factory GameStateNotification_RoadSurface.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GameStateNotification_RoadSurface.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GameStateNotification.RoadSurface', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..e<RoadSurfaceType>(1, _omitFieldNames ? '' : 'roadSurfaceType', $pb.PbFieldType.OE, protoName: 'roadSurfaceType', defaultOrMaker: RoadSurfaceType.ROAD_SURFACE_SMOOTH_TARMAC, valueOf: RoadSurfaceType.valueOf, enumValues: RoadSurfaceType.values)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'roughness', $pb.PbFieldType.OU3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GameStateNotification_RoadSurface clone() => GameStateNotification_RoadSurface()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GameStateNotification_RoadSurface copyWith(void Function(GameStateNotification_RoadSurface) updates) => super.copyWith((message) => updates(message as GameStateNotification_RoadSurface)) as GameStateNotification_RoadSurface;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GameStateNotification_RoadSurface create() => GameStateNotification_RoadSurface._();
  GameStateNotification_RoadSurface createEmptyInstance() => create();
  static $pb.PbList<GameStateNotification_RoadSurface> createRepeated() => $pb.PbList<GameStateNotification_RoadSurface>();
  @$core.pragma('dart2js:noInline')
  static GameStateNotification_RoadSurface getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GameStateNotification_RoadSurface>(create);
  static GameStateNotification_RoadSurface? _defaultInstance;

  @$pb.TagNumber(1)
  RoadSurfaceType get roadSurfaceType => $_getN(0);
  @$pb.TagNumber(1)
  set roadSurfaceType(RoadSurfaceType v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasRoadSurfaceType() => $_has(0);
  @$pb.TagNumber(1)
  void clearRoadSurfaceType() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get roughness => $_getIZ(1);
  @$pb.TagNumber(2)
  set roughness($core.int v) { $_setUnsignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasRoughness() => $_has(1);
  @$pb.TagNumber(2)
  void clearRoughness() => clearField(2);
}

enum GameStateNotification_Notification {
  gameSpeed, 
  roadSurface, 
  notSet
}

/// Opcode 0x43 GAME_STATE_NOTIFICATION
class GameStateNotification extends $pb.GeneratedMessage {
  factory GameStateNotification({
    GameStateNotification_GameSpeed? gameSpeed,
    GameStateNotification_RoadSurface? roadSurface,
  }) {
    final $result = create();
    if (gameSpeed != null) {
      $result.gameSpeed = gameSpeed;
    }
    if (roadSurface != null) {
      $result.roadSurface = roadSurface;
    }
    return $result;
  }
  GameStateNotification._() : super();
  factory GameStateNotification.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GameStateNotification.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static const $core.Map<$core.int, GameStateNotification_Notification> _GameStateNotification_NotificationByTag = {
    1 : GameStateNotification_Notification.gameSpeed,
    2 : GameStateNotification_Notification.roadSurface,
    0 : GameStateNotification_Notification.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GameStateNotification', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..oo(0, [1, 2])
    ..aOM<GameStateNotification_GameSpeed>(1, _omitFieldNames ? '' : 'gameSpeed', protoName: 'gameSpeed', subBuilder: GameStateNotification_GameSpeed.create)
    ..aOM<GameStateNotification_RoadSurface>(2, _omitFieldNames ? '' : 'roadSurface', protoName: 'roadSurface', subBuilder: GameStateNotification_RoadSurface.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GameStateNotification clone() => GameStateNotification()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GameStateNotification copyWith(void Function(GameStateNotification) updates) => super.copyWith((message) => updates(message as GameStateNotification)) as GameStateNotification;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GameStateNotification create() => GameStateNotification._();
  GameStateNotification createEmptyInstance() => create();
  static $pb.PbList<GameStateNotification> createRepeated() => $pb.PbList<GameStateNotification>();
  @$core.pragma('dart2js:noInline')
  static GameStateNotification getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GameStateNotification>(create);
  static GameStateNotification? _defaultInstance;

  GameStateNotification_Notification whichNotification() => _GameStateNotification_NotificationByTag[$_whichOneof(0)]!;
  void clearNotification() => clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  GameStateNotification_GameSpeed get gameSpeed => $_getN(0);
  @$pb.TagNumber(1)
  set gameSpeed(GameStateNotification_GameSpeed v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasGameSpeed() => $_has(0);
  @$pb.TagNumber(1)
  void clearGameSpeed() => clearField(1);
  @$pb.TagNumber(1)
  GameStateNotification_GameSpeed ensureGameSpeed() => $_ensure(0);

  @$pb.TagNumber(2)
  GameStateNotification_RoadSurface get roadSurface => $_getN(1);
  @$pb.TagNumber(2)
  set roadSurface(GameStateNotification_RoadSurface v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasRoadSurface() => $_has(1);
  @$pb.TagNumber(2)
  void clearRoadSurface() => clearField(2);
  @$pb.TagNumber(2)
  GameStateNotification_RoadSurface ensureRoadSurface() => $_ensure(1);
}

enum SensorRelayConfig_Procedure {
  search, 
  connect, 
  disconnect, 
  clearAll, 
  disconnectAll, 
  notSet
}

/// Opcode 0x44   (SENSOR_RELAY_CONFIG)
class SensorRelayConfig extends $pb.GeneratedMessage {
  factory SensorRelayConfig({
    $core.bool? search,
    $core.int? connect,
    $core.int? disconnect,
    $core.bool? clearAll,
    $core.bool? disconnectAll,
  }) {
    final $result = create();
    if (search != null) {
      $result.search = search;
    }
    if (connect != null) {
      $result.connect = connect;
    }
    if (disconnect != null) {
      $result.disconnect = disconnect;
    }
    if (clearAll != null) {
      $result.clearAll = clearAll;
    }
    if (disconnectAll != null) {
      $result.disconnectAll = disconnectAll;
    }
    return $result;
  }
  SensorRelayConfig._() : super();
  factory SensorRelayConfig.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SensorRelayConfig.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static const $core.Map<$core.int, SensorRelayConfig_Procedure> _SensorRelayConfig_ProcedureByTag = {
    1 : SensorRelayConfig_Procedure.search,
    2 : SensorRelayConfig_Procedure.connect,
    3 : SensorRelayConfig_Procedure.disconnect,
    4 : SensorRelayConfig_Procedure.clearAll,
    5 : SensorRelayConfig_Procedure.disconnectAll,
    0 : SensorRelayConfig_Procedure.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SensorRelayConfig', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..oo(0, [1, 2, 3, 4, 5])
    ..aOB(1, _omitFieldNames ? '' : 'search')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'connect', $pb.PbFieldType.OU3)
    ..a<$core.int>(3, _omitFieldNames ? '' : 'disconnect', $pb.PbFieldType.OU3)
    ..aOB(4, _omitFieldNames ? '' : 'clearAll', protoName: 'clearAll')
    ..aOB(5, _omitFieldNames ? '' : 'disconnectAll', protoName: 'disconnectAll')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SensorRelayConfig clone() => SensorRelayConfig()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SensorRelayConfig copyWith(void Function(SensorRelayConfig) updates) => super.copyWith((message) => updates(message as SensorRelayConfig)) as SensorRelayConfig;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SensorRelayConfig create() => SensorRelayConfig._();
  SensorRelayConfig createEmptyInstance() => create();
  static $pb.PbList<SensorRelayConfig> createRepeated() => $pb.PbList<SensorRelayConfig>();
  @$core.pragma('dart2js:noInline')
  static SensorRelayConfig getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SensorRelayConfig>(create);
  static SensorRelayConfig? _defaultInstance;

  SensorRelayConfig_Procedure whichProcedure() => _SensorRelayConfig_ProcedureByTag[$_whichOneof(0)]!;
  void clearProcedure() => clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $core.bool get search => $_getBF(0);
  @$pb.TagNumber(1)
  set search($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSearch() => $_has(0);
  @$pb.TagNumber(1)
  void clearSearch() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get connect => $_getIZ(1);
  @$pb.TagNumber(2)
  set connect($core.int v) { $_setUnsignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasConnect() => $_has(1);
  @$pb.TagNumber(2)
  void clearConnect() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get disconnect => $_getIZ(2);
  @$pb.TagNumber(3)
  set disconnect($core.int v) { $_setUnsignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasDisconnect() => $_has(2);
  @$pb.TagNumber(3)
  void clearDisconnect() => clearField(3);

  @$pb.TagNumber(4)
  $core.bool get clearAll => $_getBF(3);
  @$pb.TagNumber(4)
  set clearAll($core.bool v) { $_setBool(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasClearAll() => $_has(3);
  @$pb.TagNumber(4)
  void clearClearAll() => clearField(4);

  @$pb.TagNumber(5)
  $core.bool get disconnectAll => $_getBF(4);
  @$pb.TagNumber(5)
  set disconnectAll($core.bool v) { $_setBool(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasDisconnectAll() => $_has(4);
  @$pb.TagNumber(5)
  void clearDisconnectAll() => clearField(5);
}

enum SensorRelayGet_Request {
  pairedSensorInfo, 
  notSet
}

/// Opcode 0x45   (SENSOR_RELAY_GET)
class SensorRelayGet extends $pb.GeneratedMessage {
  factory SensorRelayGet({
    $core.int? pairedSensorInfo,
  }) {
    final $result = create();
    if (pairedSensorInfo != null) {
      $result.pairedSensorInfo = pairedSensorInfo;
    }
    return $result;
  }
  SensorRelayGet._() : super();
  factory SensorRelayGet.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SensorRelayGet.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static const $core.Map<$core.int, SensorRelayGet_Request> _SensorRelayGet_RequestByTag = {
    1 : SensorRelayGet_Request.pairedSensorInfo,
    0 : SensorRelayGet_Request.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SensorRelayGet', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..oo(0, [1])
    ..a<$core.int>(1, _omitFieldNames ? '' : 'pairedSensorInfo', $pb.PbFieldType.OU3, protoName: 'pairedSensorInfo')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SensorRelayGet clone() => SensorRelayGet()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SensorRelayGet copyWith(void Function(SensorRelayGet) updates) => super.copyWith((message) => updates(message as SensorRelayGet)) as SensorRelayGet;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SensorRelayGet create() => SensorRelayGet._();
  SensorRelayGet createEmptyInstance() => create();
  static $pb.PbList<SensorRelayGet> createRepeated() => $pb.PbList<SensorRelayGet>();
  @$core.pragma('dart2js:noInline')
  static SensorRelayGet getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SensorRelayGet>(create);
  static SensorRelayGet? _defaultInstance;

  SensorRelayGet_Request whichRequest() => _SensorRelayGet_RequestByTag[$_whichOneof(0)]!;
  void clearRequest() => clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $core.int get pairedSensorInfo => $_getIZ(0);
  @$pb.TagNumber(1)
  set pairedSensorInfo($core.int v) { $_setUnsignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasPairedSensorInfo() => $_has(0);
  @$pb.TagNumber(1)
  void clearPairedSensorInfo() => clearField(1);
}

enum SensorRelayResponse_Response {
  pairedSensorInfoList, 
  notSet
}

/// Opcode 0x46   (SENSOR_RELAY_RESPONSE)
class SensorRelayResponse extends $pb.GeneratedMessage {
  factory SensorRelayResponse({
    SensorInfoList? pairedSensorInfoList,
  }) {
    final $result = create();
    if (pairedSensorInfoList != null) {
      $result.pairedSensorInfoList = pairedSensorInfoList;
    }
    return $result;
  }
  SensorRelayResponse._() : super();
  factory SensorRelayResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SensorRelayResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static const $core.Map<$core.int, SensorRelayResponse_Response> _SensorRelayResponse_ResponseByTag = {
    1 : SensorRelayResponse_Response.pairedSensorInfoList,
    0 : SensorRelayResponse_Response.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SensorRelayResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..oo(0, [1])
    ..aOM<SensorInfoList>(1, _omitFieldNames ? '' : 'pairedSensorInfoList', protoName: 'pairedSensorInfoList', subBuilder: SensorInfoList.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SensorRelayResponse clone() => SensorRelayResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SensorRelayResponse copyWith(void Function(SensorRelayResponse) updates) => super.copyWith((message) => updates(message as SensorRelayResponse)) as SensorRelayResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SensorRelayResponse create() => SensorRelayResponse._();
  SensorRelayResponse createEmptyInstance() => create();
  static $pb.PbList<SensorRelayResponse> createRepeated() => $pb.PbList<SensorRelayResponse>();
  @$core.pragma('dart2js:noInline')
  static SensorRelayResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SensorRelayResponse>(create);
  static SensorRelayResponse? _defaultInstance;

  SensorRelayResponse_Response whichResponse() => _SensorRelayResponse_ResponseByTag[$_whichOneof(0)]!;
  void clearResponse() => clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  SensorInfoList get pairedSensorInfoList => $_getN(0);
  @$pb.TagNumber(1)
  set pairedSensorInfoList(SensorInfoList v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasPairedSensorInfoList() => $_has(0);
  @$pb.TagNumber(1)
  void clearPairedSensorInfoList() => clearField(1);
  @$pb.TagNumber(1)
  SensorInfoList ensurePairedSensorInfoList() => $_ensure(0);
}

enum SensorRelayNotification_Notification {
  newSensor, 
  sensorStatus, 
  notSet
}

/// Opcode 0x47   (SENSOR_RELAY_NOTIFIATION)
class SensorRelayNotification extends $pb.GeneratedMessage {
  factory SensorRelayNotification({
    SensorInfo? newSensor,
    SensorInfo? sensorStatus,
  }) {
    final $result = create();
    if (newSensor != null) {
      $result.newSensor = newSensor;
    }
    if (sensorStatus != null) {
      $result.sensorStatus = sensorStatus;
    }
    return $result;
  }
  SensorRelayNotification._() : super();
  factory SensorRelayNotification.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SensorRelayNotification.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static const $core.Map<$core.int, SensorRelayNotification_Notification> _SensorRelayNotification_NotificationByTag = {
    1 : SensorRelayNotification_Notification.newSensor,
    2 : SensorRelayNotification_Notification.sensorStatus,
    0 : SensorRelayNotification_Notification.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SensorRelayNotification', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..oo(0, [1, 2])
    ..aOM<SensorInfo>(1, _omitFieldNames ? '' : 'newSensor', protoName: 'newSensor', subBuilder: SensorInfo.create)
    ..aOM<SensorInfo>(2, _omitFieldNames ? '' : 'sensorStatus', protoName: 'sensorStatus', subBuilder: SensorInfo.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SensorRelayNotification clone() => SensorRelayNotification()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SensorRelayNotification copyWith(void Function(SensorRelayNotification) updates) => super.copyWith((message) => updates(message as SensorRelayNotification)) as SensorRelayNotification;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SensorRelayNotification create() => SensorRelayNotification._();
  SensorRelayNotification createEmptyInstance() => create();
  static $pb.PbList<SensorRelayNotification> createRepeated() => $pb.PbList<SensorRelayNotification>();
  @$core.pragma('dart2js:noInline')
  static SensorRelayNotification getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SensorRelayNotification>(create);
  static SensorRelayNotification? _defaultInstance;

  SensorRelayNotification_Notification whichNotification() => _SensorRelayNotification_NotificationByTag[$_whichOneof(0)]!;
  void clearNotification() => clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  SensorInfo get newSensor => $_getN(0);
  @$pb.TagNumber(1)
  set newSensor(SensorInfo v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasNewSensor() => $_has(0);
  @$pb.TagNumber(1)
  void clearNewSensor() => clearField(1);
  @$pb.TagNumber(1)
  SensorInfo ensureNewSensor() => $_ensure(0);

  @$pb.TagNumber(2)
  SensorInfo get sensorStatus => $_getN(1);
  @$pb.TagNumber(2)
  set sensorStatus(SensorInfo v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasSensorStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearSensorStatus() => clearField(2);
  @$pb.TagNumber(2)
  SensorInfo ensureSensorStatus() => $_ensure(1);
}

/// Opcode 0x48   (HRM_DATA_NOTIFICATION)
class HrmDataNotification extends $pb.GeneratedMessage {
  factory HrmDataNotification({
    $core.int? sensorId,
    $core.int? hrm,
    $core.int? energyExpended,
    $core.Iterable<$core.int>? rrInterval,
  }) {
    final $result = create();
    if (sensorId != null) {
      $result.sensorId = sensorId;
    }
    if (hrm != null) {
      $result.hrm = hrm;
    }
    if (energyExpended != null) {
      $result.energyExpended = energyExpended;
    }
    if (rrInterval != null) {
      $result.rrInterval.addAll(rrInterval);
    }
    return $result;
  }
  HrmDataNotification._() : super();
  factory HrmDataNotification.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory HrmDataNotification.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'HrmDataNotification', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'sensorId', $pb.PbFieldType.OU3, protoName: 'sensorId')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'hrm', $pb.PbFieldType.OU3)
    ..a<$core.int>(3, _omitFieldNames ? '' : 'energyExpended', $pb.PbFieldType.OU3, protoName: 'energyExpended')
    ..p<$core.int>(4, _omitFieldNames ? '' : 'rrInterval', $pb.PbFieldType.PU3, protoName: 'rrInterval')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  HrmDataNotification clone() => HrmDataNotification()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  HrmDataNotification copyWith(void Function(HrmDataNotification) updates) => super.copyWith((message) => updates(message as HrmDataNotification)) as HrmDataNotification;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HrmDataNotification create() => HrmDataNotification._();
  HrmDataNotification createEmptyInstance() => create();
  static $pb.PbList<HrmDataNotification> createRepeated() => $pb.PbList<HrmDataNotification>();
  @$core.pragma('dart2js:noInline')
  static HrmDataNotification getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<HrmDataNotification>(create);
  static HrmDataNotification? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get sensorId => $_getIZ(0);
  @$pb.TagNumber(1)
  set sensorId($core.int v) { $_setUnsignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSensorId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSensorId() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get hrm => $_getIZ(1);
  @$pb.TagNumber(2)
  set hrm($core.int v) { $_setUnsignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasHrm() => $_has(1);
  @$pb.TagNumber(2)
  void clearHrm() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get energyExpended => $_getIZ(2);
  @$pb.TagNumber(3)
  set energyExpended($core.int v) { $_setUnsignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasEnergyExpended() => $_has(2);
  @$pb.TagNumber(3)
  void clearEnergyExpended() => clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get rrInterval => $_getList(3);
}

enum WifiConfigurationRequest_Request {
  startScan, 
  connect, 
  forget, 
  setRegionCode, 
  notSet
}

/// OpCode 0x49
class WifiConfigurationRequest extends $pb.GeneratedMessage {
  factory WifiConfigurationRequest({
    $core.bool? startScan,
    WifiNetwork? connect,
    $core.bool? forget,
    WifiRegionCode? setRegionCode,
  }) {
    final $result = create();
    if (startScan != null) {
      $result.startScan = startScan;
    }
    if (connect != null) {
      $result.connect = connect;
    }
    if (forget != null) {
      $result.forget = forget;
    }
    if (setRegionCode != null) {
      $result.setRegionCode = setRegionCode;
    }
    return $result;
  }
  WifiConfigurationRequest._() : super();
  factory WifiConfigurationRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory WifiConfigurationRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static const $core.Map<$core.int, WifiConfigurationRequest_Request> _WifiConfigurationRequest_RequestByTag = {
    1 : WifiConfigurationRequest_Request.startScan,
    2 : WifiConfigurationRequest_Request.connect,
    3 : WifiConfigurationRequest_Request.forget,
    4 : WifiConfigurationRequest_Request.setRegionCode,
    0 : WifiConfigurationRequest_Request.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'WifiConfigurationRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..oo(0, [1, 2, 3, 4])
    ..aOB(1, _omitFieldNames ? '' : 'startScan', protoName: 'startScan')
    ..aOM<WifiNetwork>(2, _omitFieldNames ? '' : 'connect', subBuilder: WifiNetwork.create)
    ..aOB(3, _omitFieldNames ? '' : 'forget')
    ..aOM<WifiRegionCode>(4, _omitFieldNames ? '' : 'setRegionCode', protoName: 'setRegionCode', subBuilder: WifiRegionCode.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  WifiConfigurationRequest clone() => WifiConfigurationRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  WifiConfigurationRequest copyWith(void Function(WifiConfigurationRequest) updates) => super.copyWith((message) => updates(message as WifiConfigurationRequest)) as WifiConfigurationRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WifiConfigurationRequest create() => WifiConfigurationRequest._();
  WifiConfigurationRequest createEmptyInstance() => create();
  static $pb.PbList<WifiConfigurationRequest> createRepeated() => $pb.PbList<WifiConfigurationRequest>();
  @$core.pragma('dart2js:noInline')
  static WifiConfigurationRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<WifiConfigurationRequest>(create);
  static WifiConfigurationRequest? _defaultInstance;

  WifiConfigurationRequest_Request whichRequest() => _WifiConfigurationRequest_RequestByTag[$_whichOneof(0)]!;
  void clearRequest() => clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $core.bool get startScan => $_getBF(0);
  @$pb.TagNumber(1)
  set startScan($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasStartScan() => $_has(0);
  @$pb.TagNumber(1)
  void clearStartScan() => clearField(1);

  @$pb.TagNumber(2)
  WifiNetwork get connect => $_getN(1);
  @$pb.TagNumber(2)
  set connect(WifiNetwork v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasConnect() => $_has(1);
  @$pb.TagNumber(2)
  void clearConnect() => clearField(2);
  @$pb.TagNumber(2)
  WifiNetwork ensureConnect() => $_ensure(1);

  @$pb.TagNumber(3)
  $core.bool get forget => $_getBF(2);
  @$pb.TagNumber(3)
  set forget($core.bool v) { $_setBool(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasForget() => $_has(2);
  @$pb.TagNumber(3)
  void clearForget() => clearField(3);

  @$pb.TagNumber(4)
  WifiRegionCode get setRegionCode => $_getN(3);
  @$pb.TagNumber(4)
  set setRegionCode(WifiRegionCode v) { setField(4, v); }
  @$pb.TagNumber(4)
  $core.bool hasSetRegionCode() => $_has(3);
  @$pb.TagNumber(4)
  void clearSetRegionCode() => clearField(4);
  @$pb.TagNumber(4)
  WifiRegionCode ensureSetRegionCode() => $_ensure(3);
}

class WifiNotification_WifiStatus extends $pb.GeneratedMessage {
  factory WifiNotification_WifiStatus({
    WifiStatusCode? wifiStatusCode,
    WifiErrorCode? wifiErrorCode,
  }) {
    final $result = create();
    if (wifiStatusCode != null) {
      $result.wifiStatusCode = wifiStatusCode;
    }
    if (wifiErrorCode != null) {
      $result.wifiErrorCode = wifiErrorCode;
    }
    return $result;
  }
  WifiNotification_WifiStatus._() : super();
  factory WifiNotification_WifiStatus.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory WifiNotification_WifiStatus.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'WifiNotification.WifiStatus', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..e<WifiStatusCode>(1, _omitFieldNames ? '' : 'wifiStatusCode', $pb.PbFieldType.OE, protoName: 'wifiStatusCode', defaultOrMaker: WifiStatusCode.WIFI_STATUS_DISABLED, valueOf: WifiStatusCode.valueOf, enumValues: WifiStatusCode.values)
    ..e<WifiErrorCode>(2, _omitFieldNames ? '' : 'wifiErrorCode', $pb.PbFieldType.OE, protoName: 'wifiErrorCode', defaultOrMaker: WifiErrorCode.WIFI_ERROR_UNKNOWN, valueOf: WifiErrorCode.valueOf, enumValues: WifiErrorCode.values)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  WifiNotification_WifiStatus clone() => WifiNotification_WifiStatus()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  WifiNotification_WifiStatus copyWith(void Function(WifiNotification_WifiStatus) updates) => super.copyWith((message) => updates(message as WifiNotification_WifiStatus)) as WifiNotification_WifiStatus;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WifiNotification_WifiStatus create() => WifiNotification_WifiStatus._();
  WifiNotification_WifiStatus createEmptyInstance() => create();
  static $pb.PbList<WifiNotification_WifiStatus> createRepeated() => $pb.PbList<WifiNotification_WifiStatus>();
  @$core.pragma('dart2js:noInline')
  static WifiNotification_WifiStatus getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<WifiNotification_WifiStatus>(create);
  static WifiNotification_WifiStatus? _defaultInstance;

  @$pb.TagNumber(1)
  WifiStatusCode get wifiStatusCode => $_getN(0);
  @$pb.TagNumber(1)
  set wifiStatusCode(WifiStatusCode v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasWifiStatusCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearWifiStatusCode() => clearField(1);

  @$pb.TagNumber(2)
  WifiErrorCode get wifiErrorCode => $_getN(1);
  @$pb.TagNumber(2)
  set wifiErrorCode(WifiErrorCode v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasWifiErrorCode() => $_has(1);
  @$pb.TagNumber(2)
  void clearWifiErrorCode() => clearField(2);
}

enum WifiNotification_Notification {
  discoveredNetwork, 
  wifiStatus, 
  notSet
}

/// OpCode 0x4A
class WifiNotification extends $pb.GeneratedMessage {
  factory WifiNotification({
    WifiNetworkDetails? discoveredNetwork,
    WifiNotification_WifiStatus? wifiStatus,
  }) {
    final $result = create();
    if (discoveredNetwork != null) {
      $result.discoveredNetwork = discoveredNetwork;
    }
    if (wifiStatus != null) {
      $result.wifiStatus = wifiStatus;
    }
    return $result;
  }
  WifiNotification._() : super();
  factory WifiNotification.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory WifiNotification.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static const $core.Map<$core.int, WifiNotification_Notification> _WifiNotification_NotificationByTag = {
    1 : WifiNotification_Notification.discoveredNetwork,
    2 : WifiNotification_Notification.wifiStatus,
    0 : WifiNotification_Notification.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'WifiNotification', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..oo(0, [1, 2])
    ..aOM<WifiNetworkDetails>(1, _omitFieldNames ? '' : 'discoveredNetwork', protoName: 'discoveredNetwork', subBuilder: WifiNetworkDetails.create)
    ..aOM<WifiNotification_WifiStatus>(2, _omitFieldNames ? '' : 'wifiStatus', protoName: 'wifiStatus', subBuilder: WifiNotification_WifiStatus.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  WifiNotification clone() => WifiNotification()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  WifiNotification copyWith(void Function(WifiNotification) updates) => super.copyWith((message) => updates(message as WifiNotification)) as WifiNotification;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WifiNotification create() => WifiNotification._();
  WifiNotification createEmptyInstance() => create();
  static $pb.PbList<WifiNotification> createRepeated() => $pb.PbList<WifiNotification>();
  @$core.pragma('dart2js:noInline')
  static WifiNotification getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<WifiNotification>(create);
  static WifiNotification? _defaultInstance;

  WifiNotification_Notification whichNotification() => _WifiNotification_NotificationByTag[$_whichOneof(0)]!;
  void clearNotification() => clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  WifiNetworkDetails get discoveredNetwork => $_getN(0);
  @$pb.TagNumber(1)
  set discoveredNetwork(WifiNetworkDetails v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasDiscoveredNetwork() => $_has(0);
  @$pb.TagNumber(1)
  void clearDiscoveredNetwork() => clearField(1);
  @$pb.TagNumber(1)
  WifiNetworkDetails ensureDiscoveredNetwork() => $_ensure(0);

  @$pb.TagNumber(2)
  WifiNotification_WifiStatus get wifiStatus => $_getN(1);
  @$pb.TagNumber(2)
  set wifiStatus(WifiNotification_WifiStatus v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasWifiStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearWifiStatus() => clearField(2);
  @$pb.TagNumber(2)
  WifiNotification_WifiStatus ensureWifiStatus() => $_ensure(1);
}

/// OpCode 0x4B
class PowerDataNotification extends $pb.GeneratedMessage {
  factory PowerDataNotification({
    $core.int? sensorId,
    $core.int? power,
  }) {
    final $result = create();
    if (sensorId != null) {
      $result.sensorId = sensorId;
    }
    if (power != null) {
      $result.power = power;
    }
    return $result;
  }
  PowerDataNotification._() : super();
  factory PowerDataNotification.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PowerDataNotification.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PowerDataNotification', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'sensorId', $pb.PbFieldType.OU3, protoName: 'sensorId')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'power', $pb.PbFieldType.OU3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PowerDataNotification clone() => PowerDataNotification()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PowerDataNotification copyWith(void Function(PowerDataNotification) updates) => super.copyWith((message) => updates(message as PowerDataNotification)) as PowerDataNotification;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PowerDataNotification create() => PowerDataNotification._();
  PowerDataNotification createEmptyInstance() => create();
  static $pb.PbList<PowerDataNotification> createRepeated() => $pb.PbList<PowerDataNotification>();
  @$core.pragma('dart2js:noInline')
  static PowerDataNotification getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PowerDataNotification>(create);
  static PowerDataNotification? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get sensorId => $_getIZ(0);
  @$pb.TagNumber(1)
  set sensorId($core.int v) { $_setUnsignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSensorId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSensorId() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get power => $_getIZ(1);
  @$pb.TagNumber(2)
  set power($core.int v) { $_setUnsignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasPower() => $_has(1);
  @$pb.TagNumber(2)
  void clearPower() => clearField(2);
}

/// OpCode 0x4C
class CadenceDataNotification extends $pb.GeneratedMessage {
  factory CadenceDataNotification({
    $core.int? sensorId,
    $core.int? cadence,
  }) {
    final $result = create();
    if (sensorId != null) {
      $result.sensorId = sensorId;
    }
    if (cadence != null) {
      $result.cadence = cadence;
    }
    return $result;
  }
  CadenceDataNotification._() : super();
  factory CadenceDataNotification.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory CadenceDataNotification.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CadenceDataNotification', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'sensorId', $pb.PbFieldType.OU3, protoName: 'sensorId')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'cadence', $pb.PbFieldType.OU3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  CadenceDataNotification clone() => CadenceDataNotification()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  CadenceDataNotification copyWith(void Function(CadenceDataNotification) updates) => super.copyWith((message) => updates(message as CadenceDataNotification)) as CadenceDataNotification;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CadenceDataNotification create() => CadenceDataNotification._();
  CadenceDataNotification createEmptyInstance() => create();
  static $pb.PbList<CadenceDataNotification> createRepeated() => $pb.PbList<CadenceDataNotification>();
  @$core.pragma('dart2js:noInline')
  static CadenceDataNotification getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CadenceDataNotification>(create);
  static CadenceDataNotification? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get sensorId => $_getIZ(0);
  @$pb.TagNumber(1)
  set sensorId($core.int v) { $_setUnsignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSensorId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSensorId() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get cadence => $_getIZ(1);
  @$pb.TagNumber(2)
  set cadence($core.int v) { $_setUnsignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasCadence() => $_has(1);
  @$pb.TagNumber(2)
  void clearCadence() => clearField(2);
}

enum DeviceUpdateRequest_Procedure {
  checkForUpdates, 
  activateUpdates, 
  notSet
}

/// OpCode 0x4D
class DeviceUpdateRequest extends $pb.GeneratedMessage {
  factory DeviceUpdateRequest({
    $core.bool? checkForUpdates,
    $core.bool? activateUpdates,
  }) {
    final $result = create();
    if (checkForUpdates != null) {
      $result.checkForUpdates = checkForUpdates;
    }
    if (activateUpdates != null) {
      $result.activateUpdates = activateUpdates;
    }
    return $result;
  }
  DeviceUpdateRequest._() : super();
  factory DeviceUpdateRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DeviceUpdateRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static const $core.Map<$core.int, DeviceUpdateRequest_Procedure> _DeviceUpdateRequest_ProcedureByTag = {
    1 : DeviceUpdateRequest_Procedure.checkForUpdates,
    2 : DeviceUpdateRequest_Procedure.activateUpdates,
    0 : DeviceUpdateRequest_Procedure.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DeviceUpdateRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..oo(0, [1, 2])
    ..aOB(1, _omitFieldNames ? '' : 'checkForUpdates', protoName: 'checkForUpdates')
    ..aOB(2, _omitFieldNames ? '' : 'activateUpdates', protoName: 'activateUpdates')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DeviceUpdateRequest clone() => DeviceUpdateRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DeviceUpdateRequest copyWith(void Function(DeviceUpdateRequest) updates) => super.copyWith((message) => updates(message as DeviceUpdateRequest)) as DeviceUpdateRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeviceUpdateRequest create() => DeviceUpdateRequest._();
  DeviceUpdateRequest createEmptyInstance() => create();
  static $pb.PbList<DeviceUpdateRequest> createRepeated() => $pb.PbList<DeviceUpdateRequest>();
  @$core.pragma('dart2js:noInline')
  static DeviceUpdateRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DeviceUpdateRequest>(create);
  static DeviceUpdateRequest? _defaultInstance;

  DeviceUpdateRequest_Procedure whichProcedure() => _DeviceUpdateRequest_ProcedureByTag[$_whichOneof(0)]!;
  void clearProcedure() => clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $core.bool get checkForUpdates => $_getBF(0);
  @$pb.TagNumber(1)
  set checkForUpdates($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasCheckForUpdates() => $_has(0);
  @$pb.TagNumber(1)
  void clearCheckForUpdates() => clearField(1);

  @$pb.TagNumber(2)
  $core.bool get activateUpdates => $_getBF(1);
  @$pb.TagNumber(2)
  set activateUpdates($core.bool v) { $_setBool(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasActivateUpdates() => $_has(1);
  @$pb.TagNumber(2)
  void clearActivateUpdates() => clearField(2);
}

/// Opcode 0x4E
class RelayZpMessage extends $pb.GeneratedMessage {
  factory RelayZpMessage({
    $core.int? relayAssignedId,
    $core.List<$core.int>? payload,
  }) {
    final $result = create();
    if (relayAssignedId != null) {
      $result.relayAssignedId = relayAssignedId;
    }
    if (payload != null) {
      $result.payload = payload;
    }
    return $result;
  }
  RelayZpMessage._() : super();
  factory RelayZpMessage.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory RelayZpMessage.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'RelayZpMessage', package: const $pb.PackageName(_omitMessageNames ? '' : 'Zp'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'relayAssignedId', $pb.PbFieldType.OU3, protoName: 'relayAssignedId')
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'payload', $pb.PbFieldType.OY)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  RelayZpMessage clone() => RelayZpMessage()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  RelayZpMessage copyWith(void Function(RelayZpMessage) updates) => super.copyWith((message) => updates(message as RelayZpMessage)) as RelayZpMessage;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RelayZpMessage create() => RelayZpMessage._();
  RelayZpMessage createEmptyInstance() => create();
  static $pb.PbList<RelayZpMessage> createRepeated() => $pb.PbList<RelayZpMessage>();
  @$core.pragma('dart2js:noInline')
  static RelayZpMessage getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RelayZpMessage>(create);
  static RelayZpMessage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get relayAssignedId => $_getIZ(0);
  @$pb.TagNumber(1)
  set relayAssignedId($core.int v) { $_setUnsignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasRelayAssignedId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRelayAssignedId() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get payload => $_getN(1);
  @$pb.TagNumber(2)
  set payload($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasPayload() => $_has(1);
  @$pb.TagNumber(2)
  void clearPayload() => clearField(2);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
