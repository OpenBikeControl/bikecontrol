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

class VendorOpcode extends $pb.ProtobufEnum {
  static const VendorOpcode UNDEFINED = VendorOpcode._(0, _omitEnumNames ? '' : 'UNDEFINED');
  static const VendorOpcode CONTROLLER_SYNC = VendorOpcode._(1, _omitEnumNames ? '' : 'CONTROLLER_SYNC');
  static const VendorOpcode PAIR_DEVICES = VendorOpcode._(2, _omitEnumNames ? '' : 'PAIR_DEVICES');
  static const VendorOpcode ENABLE_TEST_MODE = VendorOpcode._(65280, _omitEnumNames ? '' : 'ENABLE_TEST_MODE');
  static const VendorOpcode SET_DFU_TEST = VendorOpcode._(65281, _omitEnumNames ? '' : 'SET_DFU_TEST');
  static const VendorOpcode SET_TRAINER_TEST_DATA = VendorOpcode._(65282, _omitEnumNames ? '' : 'SET_TRAINER_TEST_DATA');
  static const VendorOpcode SET_INPUT_DEVICE_TEST_DATA = VendorOpcode._(65283, _omitEnumNames ? '' : 'SET_INPUT_DEVICE_TEST_DATA');
  static const VendorOpcode SET_GEAR_TEST_DATA = VendorOpcode._(65284, _omitEnumNames ? '' : 'SET_GEAR_TEST_DATA');
  static const VendorOpcode SET_HRM_TEST_DATA = VendorOpcode._(65285, _omitEnumNames ? '' : 'SET_HRM_TEST_DATA');
  static const VendorOpcode SET_TEST_DATA = VendorOpcode._(65286, _omitEnumNames ? '' : 'SET_TEST_DATA');

  static const $core.List<VendorOpcode> values = <VendorOpcode> [
    UNDEFINED,
    CONTROLLER_SYNC,
    PAIR_DEVICES,
    ENABLE_TEST_MODE,
    SET_DFU_TEST,
    SET_TRAINER_TEST_DATA,
    SET_INPUT_DEVICE_TEST_DATA,
    SET_GEAR_TEST_DATA,
    SET_HRM_TEST_DATA,
    SET_TEST_DATA,
  ];

  static final $core.Map<$core.int, VendorOpcode> _byValue = $pb.ProtobufEnum.initByValue(values);
  static VendorOpcode? valueOf($core.int value) => _byValue[value];

  const VendorOpcode._($core.int v, $core.String n) : super(v, n);
}

class PairDeviceType extends $pb.ProtobufEnum {
  static const PairDeviceType BLE = PairDeviceType._(0, _omitEnumNames ? '' : 'BLE');
  static const PairDeviceType ANT = PairDeviceType._(1, _omitEnumNames ? '' : 'ANT');

  static const $core.List<PairDeviceType> values = <PairDeviceType> [
    BLE,
    ANT,
  ];

  static final $core.Map<$core.int, PairDeviceType> _byValue = $pb.ProtobufEnum.initByValue(values);
  static PairDeviceType? valueOf($core.int value) => _byValue[value];

  const PairDeviceType._($core.int v, $core.String n) : super(v, n);
}

/// Status used by ControllerSync
class ControllerSyncStatus extends $pb.ProtobufEnum {
  static const ControllerSyncStatus NOT_CONNECTED = ControllerSyncStatus._(0, _omitEnumNames ? '' : 'NOT_CONNECTED');
  static const ControllerSyncStatus CONNECTED = ControllerSyncStatus._(1, _omitEnumNames ? '' : 'CONNECTED');

  static const $core.List<ControllerSyncStatus> values = <ControllerSyncStatus> [
    NOT_CONNECTED,
    CONNECTED,
  ];

  static final $core.Map<$core.int, ControllerSyncStatus> _byValue = $pb.ProtobufEnum.initByValue(values);
  static ControllerSyncStatus? valueOf($core.int value) => _byValue[value];

  const ControllerSyncStatus._($core.int v, $core.String n) : super(v, n);
}

/// Looks like “data object / page” IDs used with pairing pages
class VendorDO extends $pb.ProtobufEnum {
  static const VendorDO NO_CLUE = VendorDO._(0, _omitEnumNames ? '' : 'NO_CLUE');
  static const VendorDO PAGE_DEVICE_PAIRING = VendorDO._(61440, _omitEnumNames ? '' : 'PAGE_DEVICE_PAIRING');
  static const VendorDO DEVICE_COUNT = VendorDO._(61441, _omitEnumNames ? '' : 'DEVICE_COUNT');
  static const VendorDO PAIRING_STATUS = VendorDO._(61442, _omitEnumNames ? '' : 'PAIRING_STATUS');
  static const VendorDO PAIRED_DEVICE = VendorDO._(61443, _omitEnumNames ? '' : 'PAIRED_DEVICE');

  static const $core.List<VendorDO> values = <VendorDO> [
    NO_CLUE,
    PAGE_DEVICE_PAIRING,
    DEVICE_COUNT,
    PAIRING_STATUS,
    PAIRED_DEVICE,
  ];

  static final $core.Map<$core.int, VendorDO> _byValue = $pb.ProtobufEnum.initByValue(values);
  static VendorDO? valueOf($core.int value) => _byValue[value];

  const VendorDO._($core.int v, $core.String n) : super(v, n);
}


const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
