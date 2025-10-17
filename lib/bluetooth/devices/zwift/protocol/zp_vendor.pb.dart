//
//  Generated code. Do not modify.
//  source: zp_vendor.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'zp_vendor.pbenum.dart';

export 'zp_vendor.pbenum.dart';

class ControllerSync extends $pb.GeneratedMessage {
  factory ControllerSync({
    ControllerSyncStatus? status,
    $core.int? timeStamp,
  }) {
    final $result = create();
    if (status != null) {
      $result.status = status;
    }
    if (timeStamp != null) {
      $result.timeStamp = timeStamp;
    }
    return $result;
  }
  ControllerSync._() : super();
  factory ControllerSync.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ControllerSync.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ControllerSync', package: const $pb.PackageName(_omitMessageNames ? '' : 'com.zwift.protobuf'), createEmptyInstance: create)
    ..e<ControllerSyncStatus>(1, _omitFieldNames ? '' : 'status', $pb.PbFieldType.OE, defaultOrMaker: ControllerSyncStatus.NOT_CONNECTED, valueOf: ControllerSyncStatus.valueOf, enumValues: ControllerSyncStatus.values)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'timeStamp', $pb.PbFieldType.O3, protoName: 'timeStamp')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ControllerSync clone() => ControllerSync()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ControllerSync copyWith(void Function(ControllerSync) updates) => super.copyWith((message) => updates(message as ControllerSync)) as ControllerSync;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ControllerSync create() => ControllerSync._();
  ControllerSync createEmptyInstance() => create();
  static $pb.PbList<ControllerSync> createRepeated() => $pb.PbList<ControllerSync>();
  @$core.pragma('dart2js:noInline')
  static ControllerSync getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ControllerSync>(create);
  static ControllerSync? _defaultInstance;

  /// optional in code; proto3 treats as present when non-zero
  @$pb.TagNumber(1)
  ControllerSyncStatus get status => $_getN(0);
  @$pb.TagNumber(1)
  set status(ControllerSyncStatus v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearStatus() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get timeStamp => $_getIZ(1);
  @$pb.TagNumber(2)
  set timeStamp($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasTimeStamp() => $_has(1);
  @$pb.TagNumber(2)
  void clearTimeStamp() => clearField(2);
}

class EnableTestMode extends $pb.GeneratedMessage {
  factory EnableTestMode({
    $core.bool? enable,
  }) {
    final $result = create();
    if (enable != null) {
      $result.enable = enable;
    }
    return $result;
  }
  EnableTestMode._() : super();
  factory EnableTestMode.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory EnableTestMode.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'EnableTestMode', package: const $pb.PackageName(_omitMessageNames ? '' : 'com.zwift.protobuf'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'enable')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  EnableTestMode clone() => EnableTestMode()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  EnableTestMode copyWith(void Function(EnableTestMode) updates) => super.copyWith((message) => updates(message as EnableTestMode)) as EnableTestMode;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EnableTestMode create() => EnableTestMode._();
  EnableTestMode createEmptyInstance() => create();
  static $pb.PbList<EnableTestMode> createRepeated() => $pb.PbList<EnableTestMode>();
  @$core.pragma('dart2js:noInline')
  static EnableTestMode getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<EnableTestMode>(create);
  static EnableTestMode? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get enable => $_getBF(0);
  @$pb.TagNumber(1)
  set enable($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasEnable() => $_has(0);
  @$pb.TagNumber(1)
  void clearEnable() => clearField(1);
}

class PairDevices extends $pb.GeneratedMessage {
  factory PairDevices({
    $core.bool? pair,
    PairDeviceType? type,
    $core.List<$core.int>? deviceId,
  }) {
    final $result = create();
    if (pair != null) {
      $result.pair = pair;
    }
    if (type != null) {
      $result.type = type;
    }
    if (deviceId != null) {
      $result.deviceId = deviceId;
    }
    return $result;
  }
  PairDevices._() : super();
  factory PairDevices.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PairDevices.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PairDevices', package: const $pb.PackageName(_omitMessageNames ? '' : 'com.zwift.protobuf'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'pair')
    ..e<PairDeviceType>(2, _omitFieldNames ? '' : 'type', $pb.PbFieldType.OE, defaultOrMaker: PairDeviceType.BLE, valueOf: PairDeviceType.valueOf, enumValues: PairDeviceType.values)
    ..a<$core.List<$core.int>>(3, _omitFieldNames ? '' : 'deviceId', $pb.PbFieldType.OY, protoName: 'deviceId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PairDevices clone() => PairDevices()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PairDevices copyWith(void Function(PairDevices) updates) => super.copyWith((message) => updates(message as PairDevices)) as PairDevices;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PairDevices create() => PairDevices._();
  PairDevices createEmptyInstance() => create();
  static $pb.PbList<PairDevices> createRepeated() => $pb.PbList<PairDevices>();
  @$core.pragma('dart2js:noInline')
  static PairDevices getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PairDevices>(create);
  static PairDevices? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get pair => $_getBF(0);
  @$pb.TagNumber(1)
  set pair($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasPair() => $_has(0);
  @$pb.TagNumber(1)
  void clearPair() => clearField(1);

  @$pb.TagNumber(2)
  PairDeviceType get type => $_getN(1);
  @$pb.TagNumber(2)
  set type(PairDeviceType v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasType() => $_has(1);
  @$pb.TagNumber(2)
  void clearType() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get deviceId => $_getN(2);
  @$pb.TagNumber(3)
  set deviceId($core.List<$core.int> v) { $_setBytes(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasDeviceId() => $_has(2);
  @$pb.TagNumber(3)
  void clearDeviceId() => clearField(3);
}

class DevicePairingDataPage_PairedDevice extends $pb.GeneratedMessage {
  factory DevicePairingDataPage_PairedDevice({
    $core.List<$core.int>? device,
  }) {
    final $result = create();
    if (device != null) {
      $result.device = device;
    }
    return $result;
  }
  DevicePairingDataPage_PairedDevice._() : super();
  factory DevicePairingDataPage_PairedDevice.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DevicePairingDataPage_PairedDevice.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DevicePairingDataPage.PairedDevice', package: const $pb.PackageName(_omitMessageNames ? '' : 'com.zwift.protobuf'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'device', $pb.PbFieldType.OY)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DevicePairingDataPage_PairedDevice clone() => DevicePairingDataPage_PairedDevice()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DevicePairingDataPage_PairedDevice copyWith(void Function(DevicePairingDataPage_PairedDevice) updates) => super.copyWith((message) => updates(message as DevicePairingDataPage_PairedDevice)) as DevicePairingDataPage_PairedDevice;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DevicePairingDataPage_PairedDevice create() => DevicePairingDataPage_PairedDevice._();
  DevicePairingDataPage_PairedDevice createEmptyInstance() => create();
  static $pb.PbList<DevicePairingDataPage_PairedDevice> createRepeated() => $pb.PbList<DevicePairingDataPage_PairedDevice>();
  @$core.pragma('dart2js:noInline')
  static DevicePairingDataPage_PairedDevice getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DevicePairingDataPage_PairedDevice>(create);
  static DevicePairingDataPage_PairedDevice? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get device => $_getN(0);
  @$pb.TagNumber(1)
  set device($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasDevice() => $_has(0);
  @$pb.TagNumber(1)
  void clearDevice() => clearField(1);
}

class DevicePairingDataPage extends $pb.GeneratedMessage {
  factory DevicePairingDataPage({
    $core.int? devicesCount,
    $core.int? pairingStatus,
    $core.Iterable<DevicePairingDataPage_PairedDevice>? pairingDevList,
  }) {
    final $result = create();
    if (devicesCount != null) {
      $result.devicesCount = devicesCount;
    }
    if (pairingStatus != null) {
      $result.pairingStatus = pairingStatus;
    }
    if (pairingDevList != null) {
      $result.pairingDevList.addAll(pairingDevList);
    }
    return $result;
  }
  DevicePairingDataPage._() : super();
  factory DevicePairingDataPage.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DevicePairingDataPage.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DevicePairingDataPage', package: const $pb.PackageName(_omitMessageNames ? '' : 'com.zwift.protobuf'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'devicesCount', $pb.PbFieldType.O3, protoName: 'devicesCount')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'pairingStatus', $pb.PbFieldType.O3, protoName: 'pairingStatus')
    ..pc<DevicePairingDataPage_PairedDevice>(3, _omitFieldNames ? '' : 'pairingDevList', $pb.PbFieldType.PM, protoName: 'pairingDevList', subBuilder: DevicePairingDataPage_PairedDevice.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DevicePairingDataPage clone() => DevicePairingDataPage()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DevicePairingDataPage copyWith(void Function(DevicePairingDataPage) updates) => super.copyWith((message) => updates(message as DevicePairingDataPage)) as DevicePairingDataPage;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DevicePairingDataPage create() => DevicePairingDataPage._();
  DevicePairingDataPage createEmptyInstance() => create();
  static $pb.PbList<DevicePairingDataPage> createRepeated() => $pb.PbList<DevicePairingDataPage>();
  @$core.pragma('dart2js:noInline')
  static DevicePairingDataPage getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DevicePairingDataPage>(create);
  static DevicePairingDataPage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get devicesCount => $_getIZ(0);
  @$pb.TagNumber(1)
  set devicesCount($core.int v) { $_setSignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasDevicesCount() => $_has(0);
  @$pb.TagNumber(1)
  void clearDevicesCount() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get pairingStatus => $_getIZ(1);
  @$pb.TagNumber(2)
  set pairingStatus($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasPairingStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearPairingStatus() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<DevicePairingDataPage_PairedDevice> get pairingDevList => $_getList(2);
}

enum SetDfuTest_TestCase {
  failedEnterDfu, 
  failedStartAdvertising, 
  crcFailure, 
  notSet
}

class SetDfuTest extends $pb.GeneratedMessage {
  factory SetDfuTest({
    $core.bool? failedEnterDfu,
    $core.bool? failedStartAdvertising,
    $core.int? crcFailure,
  }) {
    final $result = create();
    if (failedEnterDfu != null) {
      $result.failedEnterDfu = failedEnterDfu;
    }
    if (failedStartAdvertising != null) {
      $result.failedStartAdvertising = failedStartAdvertising;
    }
    if (crcFailure != null) {
      $result.crcFailure = crcFailure;
    }
    return $result;
  }
  SetDfuTest._() : super();
  factory SetDfuTest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SetDfuTest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static const $core.Map<$core.int, SetDfuTest_TestCase> _SetDfuTest_TestCaseByTag = {
    1 : SetDfuTest_TestCase.failedEnterDfu,
    2 : SetDfuTest_TestCase.failedStartAdvertising,
    3 : SetDfuTest_TestCase.crcFailure,
    0 : SetDfuTest_TestCase.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SetDfuTest', package: const $pb.PackageName(_omitMessageNames ? '' : 'com.zwift.protobuf'), createEmptyInstance: create)
    ..oo(0, [1, 2, 3])
    ..aOB(1, _omitFieldNames ? '' : 'failedEnterDfu', protoName: 'failedEnterDfu')
    ..aOB(2, _omitFieldNames ? '' : 'failedStartAdvertising', protoName: 'failedStartAdvertising')
    ..a<$core.int>(3, _omitFieldNames ? '' : 'crcFailure', $pb.PbFieldType.O3, protoName: 'crcFailure')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SetDfuTest clone() => SetDfuTest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SetDfuTest copyWith(void Function(SetDfuTest) updates) => super.copyWith((message) => updates(message as SetDfuTest)) as SetDfuTest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetDfuTest create() => SetDfuTest._();
  SetDfuTest createEmptyInstance() => create();
  static $pb.PbList<SetDfuTest> createRepeated() => $pb.PbList<SetDfuTest>();
  @$core.pragma('dart2js:noInline')
  static SetDfuTest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SetDfuTest>(create);
  static SetDfuTest? _defaultInstance;

  SetDfuTest_TestCase whichTestCase() => _SetDfuTest_TestCaseByTag[$_whichOneof(0)]!;
  void clearTestCase() => clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $core.bool get failedEnterDfu => $_getBF(0);
  @$pb.TagNumber(1)
  set failedEnterDfu($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasFailedEnterDfu() => $_has(0);
  @$pb.TagNumber(1)
  void clearFailedEnterDfu() => clearField(1);

  @$pb.TagNumber(2)
  $core.bool get failedStartAdvertising => $_getBF(1);
  @$pb.TagNumber(2)
  set failedStartAdvertising($core.bool v) { $_setBool(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasFailedStartAdvertising() => $_has(1);
  @$pb.TagNumber(2)
  void clearFailedStartAdvertising() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get crcFailure => $_getIZ(2);
  @$pb.TagNumber(3)
  set crcFailure($core.int v) { $_setSignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasCrcFailure() => $_has(2);
  @$pb.TagNumber(3)
  void clearCrcFailure() => clearField(3);
}

class SetGearTestData extends $pb.GeneratedMessage {
  factory SetGearTestData({
    $core.int? frontGearIdx,
    $core.int? rearGearIdx,
  }) {
    final $result = create();
    if (frontGearIdx != null) {
      $result.frontGearIdx = frontGearIdx;
    }
    if (rearGearIdx != null) {
      $result.rearGearIdx = rearGearIdx;
    }
    return $result;
  }
  SetGearTestData._() : super();
  factory SetGearTestData.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SetGearTestData.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SetGearTestData', package: const $pb.PackageName(_omitMessageNames ? '' : 'com.zwift.protobuf'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'frontGearIdx', $pb.PbFieldType.O3, protoName: 'frontGearIdx')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'rearGearIdx', $pb.PbFieldType.O3, protoName: 'rearGearIdx')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SetGearTestData clone() => SetGearTestData()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SetGearTestData copyWith(void Function(SetGearTestData) updates) => super.copyWith((message) => updates(message as SetGearTestData)) as SetGearTestData;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetGearTestData create() => SetGearTestData._();
  SetGearTestData createEmptyInstance() => create();
  static $pb.PbList<SetGearTestData> createRepeated() => $pb.PbList<SetGearTestData>();
  @$core.pragma('dart2js:noInline')
  static SetGearTestData getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SetGearTestData>(create);
  static SetGearTestData? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get frontGearIdx => $_getIZ(0);
  @$pb.TagNumber(1)
  set frontGearIdx($core.int v) { $_setSignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasFrontGearIdx() => $_has(0);
  @$pb.TagNumber(1)
  void clearFrontGearIdx() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get rearGearIdx => $_getIZ(1);
  @$pb.TagNumber(2)
  set rearGearIdx($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasRearGearIdx() => $_has(1);
  @$pb.TagNumber(2)
  void clearRearGearIdx() => clearField(2);
}

class SetHrmTestData extends $pb.GeneratedMessage {
  factory SetHrmTestData({
    $core.bool? hrmPresent,
    $core.int? heartRate,
  }) {
    final $result = create();
    if (hrmPresent != null) {
      $result.hrmPresent = hrmPresent;
    }
    if (heartRate != null) {
      $result.heartRate = heartRate;
    }
    return $result;
  }
  SetHrmTestData._() : super();
  factory SetHrmTestData.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SetHrmTestData.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SetHrmTestData', package: const $pb.PackageName(_omitMessageNames ? '' : 'com.zwift.protobuf'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'hrmPresent', protoName: 'hrmPresent')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'heartRate', $pb.PbFieldType.O3, protoName: 'heartRate')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SetHrmTestData clone() => SetHrmTestData()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SetHrmTestData copyWith(void Function(SetHrmTestData) updates) => super.copyWith((message) => updates(message as SetHrmTestData)) as SetHrmTestData;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetHrmTestData create() => SetHrmTestData._();
  SetHrmTestData createEmptyInstance() => create();
  static $pb.PbList<SetHrmTestData> createRepeated() => $pb.PbList<SetHrmTestData>();
  @$core.pragma('dart2js:noInline')
  static SetHrmTestData getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SetHrmTestData>(create);
  static SetHrmTestData? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get hrmPresent => $_getBF(0);
  @$pb.TagNumber(1)
  set hrmPresent($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasHrmPresent() => $_has(0);
  @$pb.TagNumber(1)
  void clearHrmPresent() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get heartRate => $_getIZ(1);
  @$pb.TagNumber(2)
  set heartRate($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasHeartRate() => $_has(1);
  @$pb.TagNumber(2)
  void clearHeartRate() => clearField(2);
}

class SetInputDeviceTestData_ControllerAnalogEvent extends $pb.GeneratedMessage {
  factory SetInputDeviceTestData_ControllerAnalogEvent({
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
  SetInputDeviceTestData_ControllerAnalogEvent._() : super();
  factory SetInputDeviceTestData_ControllerAnalogEvent.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SetInputDeviceTestData_ControllerAnalogEvent.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SetInputDeviceTestData.ControllerAnalogEvent', package: const $pb.PackageName(_omitMessageNames ? '' : 'com.zwift.protobuf'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'sensorId', $pb.PbFieldType.O3, protoName: 'sensorId')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'value', $pb.PbFieldType.O3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SetInputDeviceTestData_ControllerAnalogEvent clone() => SetInputDeviceTestData_ControllerAnalogEvent()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SetInputDeviceTestData_ControllerAnalogEvent copyWith(void Function(SetInputDeviceTestData_ControllerAnalogEvent) updates) => super.copyWith((message) => updates(message as SetInputDeviceTestData_ControllerAnalogEvent)) as SetInputDeviceTestData_ControllerAnalogEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetInputDeviceTestData_ControllerAnalogEvent create() => SetInputDeviceTestData_ControllerAnalogEvent._();
  SetInputDeviceTestData_ControllerAnalogEvent createEmptyInstance() => create();
  static $pb.PbList<SetInputDeviceTestData_ControllerAnalogEvent> createRepeated() => $pb.PbList<SetInputDeviceTestData_ControllerAnalogEvent>();
  @$core.pragma('dart2js:noInline')
  static SetInputDeviceTestData_ControllerAnalogEvent getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SetInputDeviceTestData_ControllerAnalogEvent>(create);
  static SetInputDeviceTestData_ControllerAnalogEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get sensorId => $_getIZ(0);
  @$pb.TagNumber(1)
  set sensorId($core.int v) { $_setSignedInt32(0, v); }
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

class SetInputDeviceTestData extends $pb.GeneratedMessage {
  factory SetInputDeviceTestData({
    $core.int? duration,
    $core.int? buttonEvent,
    $core.Iterable<SetInputDeviceTestData_ControllerAnalogEvent>? analogEventList,
  }) {
    final $result = create();
    if (duration != null) {
      $result.duration = duration;
    }
    if (buttonEvent != null) {
      $result.buttonEvent = buttonEvent;
    }
    if (analogEventList != null) {
      $result.analogEventList.addAll(analogEventList);
    }
    return $result;
  }
  SetInputDeviceTestData._() : super();
  factory SetInputDeviceTestData.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SetInputDeviceTestData.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SetInputDeviceTestData', package: const $pb.PackageName(_omitMessageNames ? '' : 'com.zwift.protobuf'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'duration', $pb.PbFieldType.O3)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'buttonEvent', $pb.PbFieldType.O3, protoName: 'buttonEvent')
    ..pc<SetInputDeviceTestData_ControllerAnalogEvent>(3, _omitFieldNames ? '' : 'analogEventList', $pb.PbFieldType.PM, protoName: 'analogEventList', subBuilder: SetInputDeviceTestData_ControllerAnalogEvent.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SetInputDeviceTestData clone() => SetInputDeviceTestData()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SetInputDeviceTestData copyWith(void Function(SetInputDeviceTestData) updates) => super.copyWith((message) => updates(message as SetInputDeviceTestData)) as SetInputDeviceTestData;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetInputDeviceTestData create() => SetInputDeviceTestData._();
  SetInputDeviceTestData createEmptyInstance() => create();
  static $pb.PbList<SetInputDeviceTestData> createRepeated() => $pb.PbList<SetInputDeviceTestData>();
  @$core.pragma('dart2js:noInline')
  static SetInputDeviceTestData getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SetInputDeviceTestData>(create);
  static SetInputDeviceTestData? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get duration => $_getIZ(0);
  @$pb.TagNumber(1)
  set duration($core.int v) { $_setSignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasDuration() => $_has(0);
  @$pb.TagNumber(1)
  void clearDuration() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get buttonEvent => $_getIZ(1);
  @$pb.TagNumber(2)
  set buttonEvent($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasButtonEvent() => $_has(1);
  @$pb.TagNumber(2)
  void clearButtonEvent() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<SetInputDeviceTestData_ControllerAnalogEvent> get analogEventList => $_getList(2);
}

class SetTrainerTestData extends $pb.GeneratedMessage {
  factory SetTrainerTestData({
    $core.int? dataMode,
    $core.int? interfaces,
    TestTrainerData? testTrainerData,
  }) {
    final $result = create();
    if (dataMode != null) {
      $result.dataMode = dataMode;
    }
    if (interfaces != null) {
      $result.interfaces = interfaces;
    }
    if (testTrainerData != null) {
      $result.testTrainerData = testTrainerData;
    }
    return $result;
  }
  SetTrainerTestData._() : super();
  factory SetTrainerTestData.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SetTrainerTestData.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SetTrainerTestData', package: const $pb.PackageName(_omitMessageNames ? '' : 'com.zwift.protobuf'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'dataMode', $pb.PbFieldType.O3, protoName: 'dataMode')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'interfaces', $pb.PbFieldType.O3)
    ..aOM<TestTrainerData>(3, _omitFieldNames ? '' : 'testTrainerData', protoName: 'testTrainerData', subBuilder: TestTrainerData.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SetTrainerTestData clone() => SetTrainerTestData()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SetTrainerTestData copyWith(void Function(SetTrainerTestData) updates) => super.copyWith((message) => updates(message as SetTrainerTestData)) as SetTrainerTestData;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetTrainerTestData create() => SetTrainerTestData._();
  SetTrainerTestData createEmptyInstance() => create();
  static $pb.PbList<SetTrainerTestData> createRepeated() => $pb.PbList<SetTrainerTestData>();
  @$core.pragma('dart2js:noInline')
  static SetTrainerTestData getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SetTrainerTestData>(create);
  static SetTrainerTestData? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get dataMode => $_getIZ(0);
  @$pb.TagNumber(1)
  set dataMode($core.int v) { $_setSignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasDataMode() => $_has(0);
  @$pb.TagNumber(1)
  void clearDataMode() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get interfaces => $_getIZ(1);
  @$pb.TagNumber(2)
  set interfaces($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasInterfaces() => $_has(1);
  @$pb.TagNumber(2)
  void clearInterfaces() => clearField(2);

  @$pb.TagNumber(3)
  TestTrainerData get testTrainerData => $_getN(2);
  @$pb.TagNumber(3)
  set testTrainerData(TestTrainerData v) { setField(3, v); }
  @$pb.TagNumber(3)
  $core.bool hasTestTrainerData() => $_has(2);
  @$pb.TagNumber(3)
  void clearTestTrainerData() => clearField(3);
  @$pb.TagNumber(3)
  TestTrainerData ensureTestTrainerData() => $_ensure(2);
}

class TestTrainerData extends $pb.GeneratedMessage {
  factory TestTrainerData({
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
  TestTrainerData._() : super();
  factory TestTrainerData.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory TestTrainerData.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'TestTrainerData', package: const $pb.PackageName(_omitMessageNames ? '' : 'com.zwift.protobuf'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'power', $pb.PbFieldType.O3)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'cadence', $pb.PbFieldType.O3)
    ..a<$core.int>(3, _omitFieldNames ? '' : 'bikeSpeed', $pb.PbFieldType.O3, protoName: 'bikeSpeed')
    ..a<$core.int>(4, _omitFieldNames ? '' : 'averagedPower', $pb.PbFieldType.O3, protoName: 'averagedPower')
    ..a<$core.int>(5, _omitFieldNames ? '' : 'wheelSpeed', $pb.PbFieldType.O3, protoName: 'wheelSpeed')
    ..a<$core.int>(6, _omitFieldNames ? '' : 'calculatedRealGearRatio', $pb.PbFieldType.O3, protoName: 'calculatedRealGearRatio')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  TestTrainerData clone() => TestTrainerData()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  TestTrainerData copyWith(void Function(TestTrainerData) updates) => super.copyWith((message) => updates(message as TestTrainerData)) as TestTrainerData;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TestTrainerData create() => TestTrainerData._();
  TestTrainerData createEmptyInstance() => create();
  static $pb.PbList<TestTrainerData> createRepeated() => $pb.PbList<TestTrainerData>();
  @$core.pragma('dart2js:noInline')
  static TestTrainerData getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TestTrainerData>(create);
  static TestTrainerData? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get power => $_getIZ(0);
  @$pb.TagNumber(1)
  set power($core.int v) { $_setSignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasPower() => $_has(0);
  @$pb.TagNumber(1)
  void clearPower() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get cadence => $_getIZ(1);
  @$pb.TagNumber(2)
  set cadence($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasCadence() => $_has(1);
  @$pb.TagNumber(2)
  void clearCadence() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get bikeSpeed => $_getIZ(2);
  @$pb.TagNumber(3)
  set bikeSpeed($core.int v) { $_setSignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasBikeSpeed() => $_has(2);
  @$pb.TagNumber(3)
  void clearBikeSpeed() => clearField(3);

  @$pb.TagNumber(4)
  $core.int get averagedPower => $_getIZ(3);
  @$pb.TagNumber(4)
  set averagedPower($core.int v) { $_setSignedInt32(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasAveragedPower() => $_has(3);
  @$pb.TagNumber(4)
  void clearAveragedPower() => clearField(4);

  @$pb.TagNumber(5)
  $core.int get wheelSpeed => $_getIZ(4);
  @$pb.TagNumber(5)
  set wheelSpeed($core.int v) { $_setSignedInt32(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasWheelSpeed() => $_has(4);
  @$pb.TagNumber(5)
  void clearWheelSpeed() => clearField(5);

  @$pb.TagNumber(6)
  $core.int get calculatedRealGearRatio => $_getIZ(5);
  @$pb.TagNumber(6)
  set calculatedRealGearRatio($core.int v) { $_setSignedInt32(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasCalculatedRealGearRatio() => $_has(5);
  @$pb.TagNumber(6)
  void clearCalculatedRealGearRatio() => clearField(6);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
