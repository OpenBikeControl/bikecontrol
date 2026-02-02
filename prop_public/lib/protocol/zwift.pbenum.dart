//
//  Generated code. Do not modify.
//  source: zwift.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class PlayButtonStatus extends $pb.ProtobufEnum {
  static const PlayButtonStatus ON = PlayButtonStatus._(0, _omitEnumNames ? '' : 'ON');
  static const PlayButtonStatus OFF = PlayButtonStatus._(1, _omitEnumNames ? '' : 'OFF');

  static const $core.List<PlayButtonStatus> values = <PlayButtonStatus> [
    ON,
    OFF,
  ];

  static final $core.Map<$core.int, PlayButtonStatus> _byValue = $pb.ProtobufEnum.initByValue(values);
  static PlayButtonStatus? valueOf($core.int value) => _byValue[value];

  const PlayButtonStatus._($core.int v, $core.String n) : super(v, n);
}

/// ----------------- Zwift Ride messages
class RideButtonMask extends $pb.ProtobufEnum {
  static const RideButtonMask LEFT_BTN = RideButtonMask._(1, _omitEnumNames ? '' : 'LEFT_BTN');
  static const RideButtonMask UP_BTN = RideButtonMask._(2, _omitEnumNames ? '' : 'UP_BTN');
  static const RideButtonMask RIGHT_BTN = RideButtonMask._(4, _omitEnumNames ? '' : 'RIGHT_BTN');
  static const RideButtonMask DOWN_BTN = RideButtonMask._(8, _omitEnumNames ? '' : 'DOWN_BTN');
  static const RideButtonMask A_BTN = RideButtonMask._(16, _omitEnumNames ? '' : 'A_BTN');
  static const RideButtonMask B_BTN = RideButtonMask._(32, _omitEnumNames ? '' : 'B_BTN');
  static const RideButtonMask Y_BTN = RideButtonMask._(64, _omitEnumNames ? '' : 'Y_BTN');
  static const RideButtonMask Z_BTN = RideButtonMask._(256, _omitEnumNames ? '' : 'Z_BTN');
  static const RideButtonMask SHFT_UP_L_BTN = RideButtonMask._(512, _omitEnumNames ? '' : 'SHFT_UP_L_BTN');
  static const RideButtonMask SHFT_DN_L_BTN = RideButtonMask._(1024, _omitEnumNames ? '' : 'SHFT_DN_L_BTN');
  static const RideButtonMask POWERUP_L_BTN = RideButtonMask._(2048, _omitEnumNames ? '' : 'POWERUP_L_BTN');
  static const RideButtonMask ONOFF_L_BTN = RideButtonMask._(4096, _omitEnumNames ? '' : 'ONOFF_L_BTN');
  static const RideButtonMask SHFT_UP_R_BTN = RideButtonMask._(8192, _omitEnumNames ? '' : 'SHFT_UP_R_BTN');
  static const RideButtonMask SHFT_DN_R_BTN = RideButtonMask._(16384, _omitEnumNames ? '' : 'SHFT_DN_R_BTN');
  static const RideButtonMask POWERUP_R_BTN = RideButtonMask._(65536, _omitEnumNames ? '' : 'POWERUP_R_BTN');
  static const RideButtonMask ONOFF_R_BTN = RideButtonMask._(131072, _omitEnumNames ? '' : 'ONOFF_R_BTN');

  static const $core.List<RideButtonMask> values = <RideButtonMask> [
    LEFT_BTN,
    UP_BTN,
    RIGHT_BTN,
    DOWN_BTN,
    A_BTN,
    B_BTN,
    Y_BTN,
    Z_BTN,
    SHFT_UP_L_BTN,
    SHFT_DN_L_BTN,
    POWERUP_L_BTN,
    ONOFF_L_BTN,
    SHFT_UP_R_BTN,
    SHFT_DN_R_BTN,
    POWERUP_R_BTN,
    ONOFF_R_BTN,
  ];

  static final $core.Map<$core.int, RideButtonMask> _byValue = $pb.ProtobufEnum.initByValue(values);
  static RideButtonMask? valueOf($core.int value) => _byValue[value];

  const RideButtonMask._($core.int v, $core.String n) : super(v, n);
}

class RideAnalogLocation extends $pb.ProtobufEnum {
  static const RideAnalogLocation LEFT = RideAnalogLocation._(0, _omitEnumNames ? '' : 'LEFT');
  static const RideAnalogLocation RIGHT = RideAnalogLocation._(1, _omitEnumNames ? '' : 'RIGHT');
  static const RideAnalogLocation UP = RideAnalogLocation._(2, _omitEnumNames ? '' : 'UP');
  static const RideAnalogLocation DOWN = RideAnalogLocation._(3, _omitEnumNames ? '' : 'DOWN');

  static const $core.List<RideAnalogLocation> values = <RideAnalogLocation> [
    LEFT,
    RIGHT,
    UP,
    DOWN,
  ];

  static final $core.Map<$core.int, RideAnalogLocation> _byValue = $pb.ProtobufEnum.initByValue(values);
  static RideAnalogLocation? valueOf($core.int value) => _byValue[value];

  const RideAnalogLocation._($core.int v, $core.String n) : super(v, n);
}


const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
