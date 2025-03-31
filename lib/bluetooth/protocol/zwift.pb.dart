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

import 'zwift.pbenum.dart';

export 'zwift.pbenum.dart';

/// The command code prepending this message is 0x07
class PlayKeyPadStatus extends $pb.GeneratedMessage {
  factory PlayKeyPadStatus({
    PlayButtonStatus? rightPad,
    PlayButtonStatus? buttonYUp,
    PlayButtonStatus? buttonZLeft,
    PlayButtonStatus? buttonARight,
    PlayButtonStatus? buttonBDown,
    PlayButtonStatus? buttonShift,
    PlayButtonStatus? buttonOn,
    $core.int? analogLR,
    $core.int? analogUD,
  }) {
    final $result = create();
    if (rightPad != null) {
      $result.rightPad = rightPad;
    }
    if (buttonYUp != null) {
      $result.buttonYUp = buttonYUp;
    }
    if (buttonZLeft != null) {
      $result.buttonZLeft = buttonZLeft;
    }
    if (buttonARight != null) {
      $result.buttonARight = buttonARight;
    }
    if (buttonBDown != null) {
      $result.buttonBDown = buttonBDown;
    }
    if (buttonShift != null) {
      $result.buttonShift = buttonShift;
    }
    if (buttonOn != null) {
      $result.buttonOn = buttonOn;
    }
    if (analogLR != null) {
      $result.analogLR = analogLR;
    }
    if (analogUD != null) {
      $result.analogUD = analogUD;
    }
    return $result;
  }
  PlayKeyPadStatus._() : super();
  factory PlayKeyPadStatus.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PlayKeyPadStatus.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PlayKeyPadStatus', package: const $pb.PackageName(_omitMessageNames ? '' : 'de.jonasbark'), createEmptyInstance: create)
    ..e<PlayButtonStatus>(1, _omitFieldNames ? '' : 'RightPad', $pb.PbFieldType.OE, protoName: 'RightPad', defaultOrMaker: PlayButtonStatus.ON, valueOf: PlayButtonStatus.valueOf, enumValues: PlayButtonStatus.values)
    ..e<PlayButtonStatus>(2, _omitFieldNames ? '' : 'ButtonYUp', $pb.PbFieldType.OE, protoName: 'Button_Y_Up', defaultOrMaker: PlayButtonStatus.ON, valueOf: PlayButtonStatus.valueOf, enumValues: PlayButtonStatus.values)
    ..e<PlayButtonStatus>(3, _omitFieldNames ? '' : 'ButtonZLeft', $pb.PbFieldType.OE, protoName: 'Button_Z_Left', defaultOrMaker: PlayButtonStatus.ON, valueOf: PlayButtonStatus.valueOf, enumValues: PlayButtonStatus.values)
    ..e<PlayButtonStatus>(4, _omitFieldNames ? '' : 'ButtonARight', $pb.PbFieldType.OE, protoName: 'Button_A_Right', defaultOrMaker: PlayButtonStatus.ON, valueOf: PlayButtonStatus.valueOf, enumValues: PlayButtonStatus.values)
    ..e<PlayButtonStatus>(5, _omitFieldNames ? '' : 'ButtonBDown', $pb.PbFieldType.OE, protoName: 'Button_B_Down', defaultOrMaker: PlayButtonStatus.ON, valueOf: PlayButtonStatus.valueOf, enumValues: PlayButtonStatus.values)
    ..e<PlayButtonStatus>(6, _omitFieldNames ? '' : 'ButtonShift', $pb.PbFieldType.OE, protoName: 'Button_Shift', defaultOrMaker: PlayButtonStatus.ON, valueOf: PlayButtonStatus.valueOf, enumValues: PlayButtonStatus.values)
    ..e<PlayButtonStatus>(7, _omitFieldNames ? '' : 'ButtonOn', $pb.PbFieldType.OE, protoName: 'Button_On', defaultOrMaker: PlayButtonStatus.ON, valueOf: PlayButtonStatus.valueOf, enumValues: PlayButtonStatus.values)
    ..a<$core.int>(8, _omitFieldNames ? '' : 'AnalogLR', $pb.PbFieldType.OS3, protoName: 'Analog_LR')
    ..a<$core.int>(9, _omitFieldNames ? '' : 'AnalogUD', $pb.PbFieldType.OS3, protoName: 'Analog_UD')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PlayKeyPadStatus clone() => PlayKeyPadStatus()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PlayKeyPadStatus copyWith(void Function(PlayKeyPadStatus) updates) => super.copyWith((message) => updates(message as PlayKeyPadStatus)) as PlayKeyPadStatus;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PlayKeyPadStatus create() => PlayKeyPadStatus._();
  PlayKeyPadStatus createEmptyInstance() => create();
  static $pb.PbList<PlayKeyPadStatus> createRepeated() => $pb.PbList<PlayKeyPadStatus>();
  @$core.pragma('dart2js:noInline')
  static PlayKeyPadStatus getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PlayKeyPadStatus>(create);
  static PlayKeyPadStatus? _defaultInstance;

  @$pb.TagNumber(1)
  PlayButtonStatus get rightPad => $_getN(0);
  @$pb.TagNumber(1)
  set rightPad(PlayButtonStatus v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasRightPad() => $_has(0);
  @$pb.TagNumber(1)
  void clearRightPad() => clearField(1);

  @$pb.TagNumber(2)
  PlayButtonStatus get buttonYUp => $_getN(1);
  @$pb.TagNumber(2)
  set buttonYUp(PlayButtonStatus v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasButtonYUp() => $_has(1);
  @$pb.TagNumber(2)
  void clearButtonYUp() => clearField(2);

  @$pb.TagNumber(3)
  PlayButtonStatus get buttonZLeft => $_getN(2);
  @$pb.TagNumber(3)
  set buttonZLeft(PlayButtonStatus v) { setField(3, v); }
  @$pb.TagNumber(3)
  $core.bool hasButtonZLeft() => $_has(2);
  @$pb.TagNumber(3)
  void clearButtonZLeft() => clearField(3);

  @$pb.TagNumber(4)
  PlayButtonStatus get buttonARight => $_getN(3);
  @$pb.TagNumber(4)
  set buttonARight(PlayButtonStatus v) { setField(4, v); }
  @$pb.TagNumber(4)
  $core.bool hasButtonARight() => $_has(3);
  @$pb.TagNumber(4)
  void clearButtonARight() => clearField(4);

  @$pb.TagNumber(5)
  PlayButtonStatus get buttonBDown => $_getN(4);
  @$pb.TagNumber(5)
  set buttonBDown(PlayButtonStatus v) { setField(5, v); }
  @$pb.TagNumber(5)
  $core.bool hasButtonBDown() => $_has(4);
  @$pb.TagNumber(5)
  void clearButtonBDown() => clearField(5);

  @$pb.TagNumber(6)
  PlayButtonStatus get buttonShift => $_getN(5);
  @$pb.TagNumber(6)
  set buttonShift(PlayButtonStatus v) { setField(6, v); }
  @$pb.TagNumber(6)
  $core.bool hasButtonShift() => $_has(5);
  @$pb.TagNumber(6)
  void clearButtonShift() => clearField(6);

  @$pb.TagNumber(7)
  PlayButtonStatus get buttonOn => $_getN(6);
  @$pb.TagNumber(7)
  set buttonOn(PlayButtonStatus v) { setField(7, v); }
  @$pb.TagNumber(7)
  $core.bool hasButtonOn() => $_has(6);
  @$pb.TagNumber(7)
  void clearButtonOn() => clearField(7);

  @$pb.TagNumber(8)
  $core.int get analogLR => $_getIZ(7);
  @$pb.TagNumber(8)
  set analogLR($core.int v) { $_setSignedInt32(7, v); }
  @$pb.TagNumber(8)
  $core.bool hasAnalogLR() => $_has(7);
  @$pb.TagNumber(8)
  void clearAnalogLR() => clearField(8);

  @$pb.TagNumber(9)
  $core.int get analogUD => $_getIZ(8);
  @$pb.TagNumber(9)
  set analogUD($core.int v) { $_setSignedInt32(8, v); }
  @$pb.TagNumber(9)
  $core.bool hasAnalogUD() => $_has(8);
  @$pb.TagNumber(9)
  void clearAnalogUD() => clearField(9);
}

class PlayCommandParameters extends $pb.GeneratedMessage {
  factory PlayCommandParameters({
    $core.int? param1,
    $core.int? param2,
    $core.int? hapticPattern,
  }) {
    final $result = create();
    if (param1 != null) {
      $result.param1 = param1;
    }
    if (param2 != null) {
      $result.param2 = param2;
    }
    if (hapticPattern != null) {
      $result.hapticPattern = hapticPattern;
    }
    return $result;
  }
  PlayCommandParameters._() : super();
  factory PlayCommandParameters.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PlayCommandParameters.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PlayCommandParameters', package: const $pb.PackageName(_omitMessageNames ? '' : 'de.jonasbark'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'param1', $pb.PbFieldType.OU3)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'param2', $pb.PbFieldType.OU3)
    ..a<$core.int>(3, _omitFieldNames ? '' : 'HapticPattern', $pb.PbFieldType.OU3, protoName: 'HapticPattern')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PlayCommandParameters clone() => PlayCommandParameters()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PlayCommandParameters copyWith(void Function(PlayCommandParameters) updates) => super.copyWith((message) => updates(message as PlayCommandParameters)) as PlayCommandParameters;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PlayCommandParameters create() => PlayCommandParameters._();
  PlayCommandParameters createEmptyInstance() => create();
  static $pb.PbList<PlayCommandParameters> createRepeated() => $pb.PbList<PlayCommandParameters>();
  @$core.pragma('dart2js:noInline')
  static PlayCommandParameters getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PlayCommandParameters>(create);
  static PlayCommandParameters? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get param1 => $_getIZ(0);
  @$pb.TagNumber(1)
  set param1($core.int v) { $_setUnsignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasParam1() => $_has(0);
  @$pb.TagNumber(1)
  void clearParam1() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get param2 => $_getIZ(1);
  @$pb.TagNumber(2)
  set param2($core.int v) { $_setUnsignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasParam2() => $_has(1);
  @$pb.TagNumber(2)
  void clearParam2() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get hapticPattern => $_getIZ(2);
  @$pb.TagNumber(3)
  set hapticPattern($core.int v) { $_setUnsignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasHapticPattern() => $_has(2);
  @$pb.TagNumber(3)
  void clearHapticPattern() => clearField(3);
}

class PlayCommandContents extends $pb.GeneratedMessage {
  factory PlayCommandContents({
    PlayCommandParameters? commandParameters,
  }) {
    final $result = create();
    if (commandParameters != null) {
      $result.commandParameters = commandParameters;
    }
    return $result;
  }
  PlayCommandContents._() : super();
  factory PlayCommandContents.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PlayCommandContents.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PlayCommandContents', package: const $pb.PackageName(_omitMessageNames ? '' : 'de.jonasbark'), createEmptyInstance: create)
    ..aOM<PlayCommandParameters>(1, _omitFieldNames ? '' : 'CommandParameters', protoName: 'CommandParameters', subBuilder: PlayCommandParameters.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PlayCommandContents clone() => PlayCommandContents()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PlayCommandContents copyWith(void Function(PlayCommandContents) updates) => super.copyWith((message) => updates(message as PlayCommandContents)) as PlayCommandContents;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PlayCommandContents create() => PlayCommandContents._();
  PlayCommandContents createEmptyInstance() => create();
  static $pb.PbList<PlayCommandContents> createRepeated() => $pb.PbList<PlayCommandContents>();
  @$core.pragma('dart2js:noInline')
  static PlayCommandContents getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PlayCommandContents>(create);
  static PlayCommandContents? _defaultInstance;

  @$pb.TagNumber(1)
  PlayCommandParameters get commandParameters => $_getN(0);
  @$pb.TagNumber(1)
  set commandParameters(PlayCommandParameters v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasCommandParameters() => $_has(0);
  @$pb.TagNumber(1)
  void clearCommandParameters() => clearField(1);
  @$pb.TagNumber(1)
  PlayCommandParameters ensureCommandParameters() => $_ensure(0);
}

/// The command code prepending this message is 0x12
/// This is sent to the control point to configure and make the controller vibrate
class PlayCommand extends $pb.GeneratedMessage {
  factory PlayCommand({
    PlayCommandContents? commandContents,
  }) {
    final $result = create();
    if (commandContents != null) {
      $result.commandContents = commandContents;
    }
    return $result;
  }
  PlayCommand._() : super();
  factory PlayCommand.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PlayCommand.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PlayCommand', package: const $pb.PackageName(_omitMessageNames ? '' : 'de.jonasbark'), createEmptyInstance: create)
    ..aOM<PlayCommandContents>(2, _omitFieldNames ? '' : 'CommandContents', protoName: 'CommandContents', subBuilder: PlayCommandContents.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PlayCommand clone() => PlayCommand()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PlayCommand copyWith(void Function(PlayCommand) updates) => super.copyWith((message) => updates(message as PlayCommand)) as PlayCommand;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PlayCommand create() => PlayCommand._();
  PlayCommand createEmptyInstance() => create();
  static $pb.PbList<PlayCommand> createRepeated() => $pb.PbList<PlayCommand>();
  @$core.pragma('dart2js:noInline')
  static PlayCommand getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PlayCommand>(create);
  static PlayCommand? _defaultInstance;

  @$pb.TagNumber(2)
  PlayCommandContents get commandContents => $_getN(0);
  @$pb.TagNumber(2)
  set commandContents(PlayCommandContents v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasCommandContents() => $_has(0);
  @$pb.TagNumber(2)
  void clearCommandContents() => clearField(2);
  @$pb.TagNumber(2)
  PlayCommandContents ensureCommandContents() => $_ensure(0);
}

/// The command code prepending this message is 0x19
/// This is sent periodically when there are no button presses
class Idle extends $pb.GeneratedMessage {
  factory Idle({
    $core.int? unknown2,
  }) {
    final $result = create();
    if (unknown2 != null) {
      $result.unknown2 = unknown2;
    }
    return $result;
  }
  Idle._() : super();
  factory Idle.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Idle.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Idle', package: const $pb.PackageName(_omitMessageNames ? '' : 'de.jonasbark'), createEmptyInstance: create)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'Unknown2', $pb.PbFieldType.OU3, protoName: 'Unknown2')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  Idle clone() => Idle()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  Idle copyWith(void Function(Idle) updates) => super.copyWith((message) => updates(message as Idle)) as Idle;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Idle create() => Idle._();
  Idle createEmptyInstance() => create();
  static $pb.PbList<Idle> createRepeated() => $pb.PbList<Idle>();
  @$core.pragma('dart2js:noInline')
  static Idle getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Idle>(create);
  static Idle? _defaultInstance;

  @$pb.TagNumber(2)
  $core.int get unknown2 => $_getIZ(0);
  @$pb.TagNumber(2)
  set unknown2($core.int v) { $_setUnsignedInt32(0, v); }
  @$pb.TagNumber(2)
  $core.bool hasUnknown2() => $_has(0);
  @$pb.TagNumber(2)
  void clearUnknown2() => clearField(2);
}

class RideAnalogKeyPress extends $pb.GeneratedMessage {
  factory RideAnalogKeyPress({
    RideAnalogLocation? location,
    $core.int? analogValue,
  }) {
    final $result = create();
    if (location != null) {
      $result.location = location;
    }
    if (analogValue != null) {
      $result.analogValue = analogValue;
    }
    return $result;
  }
  RideAnalogKeyPress._() : super();
  factory RideAnalogKeyPress.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory RideAnalogKeyPress.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'RideAnalogKeyPress', package: const $pb.PackageName(_omitMessageNames ? '' : 'de.jonasbark'), createEmptyInstance: create)
    ..e<RideAnalogLocation>(1, _omitFieldNames ? '' : 'Location', $pb.PbFieldType.OE, protoName: 'Location', defaultOrMaker: RideAnalogLocation.LEFT, valueOf: RideAnalogLocation.valueOf, enumValues: RideAnalogLocation.values)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'AnalogValue', $pb.PbFieldType.OS3, protoName: 'AnalogValue')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  RideAnalogKeyPress clone() => RideAnalogKeyPress()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  RideAnalogKeyPress copyWith(void Function(RideAnalogKeyPress) updates) => super.copyWith((message) => updates(message as RideAnalogKeyPress)) as RideAnalogKeyPress;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RideAnalogKeyPress create() => RideAnalogKeyPress._();
  RideAnalogKeyPress createEmptyInstance() => create();
  static $pb.PbList<RideAnalogKeyPress> createRepeated() => $pb.PbList<RideAnalogKeyPress>();
  @$core.pragma('dart2js:noInline')
  static RideAnalogKeyPress getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RideAnalogKeyPress>(create);
  static RideAnalogKeyPress? _defaultInstance;

  @$pb.TagNumber(1)
  RideAnalogLocation get location => $_getN(0);
  @$pb.TagNumber(1)
  set location(RideAnalogLocation v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasLocation() => $_has(0);
  @$pb.TagNumber(1)
  void clearLocation() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get analogValue => $_getIZ(1);
  @$pb.TagNumber(2)
  set analogValue($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasAnalogValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearAnalogValue() => clearField(2);
}

class RideAnalogKeyGroup extends $pb.GeneratedMessage {
  factory RideAnalogKeyGroup({
    $core.Iterable<RideAnalogKeyPress>? groupStatus,
  }) {
    final $result = create();
    if (groupStatus != null) {
      $result.groupStatus.addAll(groupStatus);
    }
    return $result;
  }
  RideAnalogKeyGroup._() : super();
  factory RideAnalogKeyGroup.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory RideAnalogKeyGroup.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'RideAnalogKeyGroup', package: const $pb.PackageName(_omitMessageNames ? '' : 'de.jonasbark'), createEmptyInstance: create)
    ..pc<RideAnalogKeyPress>(1, _omitFieldNames ? '' : 'GroupStatus', $pb.PbFieldType.PM, protoName: 'GroupStatus', subBuilder: RideAnalogKeyPress.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  RideAnalogKeyGroup clone() => RideAnalogKeyGroup()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  RideAnalogKeyGroup copyWith(void Function(RideAnalogKeyGroup) updates) => super.copyWith((message) => updates(message as RideAnalogKeyGroup)) as RideAnalogKeyGroup;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RideAnalogKeyGroup create() => RideAnalogKeyGroup._();
  RideAnalogKeyGroup createEmptyInstance() => create();
  static $pb.PbList<RideAnalogKeyGroup> createRepeated() => $pb.PbList<RideAnalogKeyGroup>();
  @$core.pragma('dart2js:noInline')
  static RideAnalogKeyGroup getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RideAnalogKeyGroup>(create);
  static RideAnalogKeyGroup? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<RideAnalogKeyPress> get groupStatus => $_getList(0);
}

/// The command code prepending this message is 0x23
class RideKeyPadStatus extends $pb.GeneratedMessage {
  factory RideKeyPadStatus({
    $core.int? buttonMap,
    RideAnalogKeyGroup? analogButtons,
  }) {
    final $result = create();
    if (buttonMap != null) {
      $result.buttonMap = buttonMap;
    }
    if (analogButtons != null) {
      $result.analogButtons = analogButtons;
    }
    return $result;
  }
  RideKeyPadStatus._() : super();
  factory RideKeyPadStatus.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory RideKeyPadStatus.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'RideKeyPadStatus', package: const $pb.PackageName(_omitMessageNames ? '' : 'de.jonasbark'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'ButtonMap', $pb.PbFieldType.OU3, protoName: 'ButtonMap')
    ..aOM<RideAnalogKeyGroup>(2, _omitFieldNames ? '' : 'AnalogButtons', protoName: 'AnalogButtons', subBuilder: RideAnalogKeyGroup.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  RideKeyPadStatus clone() => RideKeyPadStatus()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  RideKeyPadStatus copyWith(void Function(RideKeyPadStatus) updates) => super.copyWith((message) => updates(message as RideKeyPadStatus)) as RideKeyPadStatus;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RideKeyPadStatus create() => RideKeyPadStatus._();
  RideKeyPadStatus createEmptyInstance() => create();
  static $pb.PbList<RideKeyPadStatus> createRepeated() => $pb.PbList<RideKeyPadStatus>();
  @$core.pragma('dart2js:noInline')
  static RideKeyPadStatus getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RideKeyPadStatus>(create);
  static RideKeyPadStatus? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get buttonMap => $_getIZ(0);
  @$pb.TagNumber(1)
  set buttonMap($core.int v) { $_setUnsignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasButtonMap() => $_has(0);
  @$pb.TagNumber(1)
  void clearButtonMap() => clearField(1);

  @$pb.TagNumber(2)
  RideAnalogKeyGroup get analogButtons => $_getN(1);
  @$pb.TagNumber(2)
  set analogButtons(RideAnalogKeyGroup v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasAnalogButtons() => $_has(1);
  @$pb.TagNumber(2)
  void clearAnalogButtons() => clearField(2);
  @$pb.TagNumber(2)
  RideAnalogKeyGroup ensureAnalogButtons() => $_ensure(1);
}

/// ------------------ Zwift Click messages
///  The command code prepending this message is 0x37
class ClickKeyPadStatus extends $pb.GeneratedMessage {
  factory ClickKeyPadStatus({
    PlayButtonStatus? buttonPlus,
    PlayButtonStatus? buttonMinus,
  }) {
    final $result = create();
    if (buttonPlus != null) {
      $result.buttonPlus = buttonPlus;
    }
    if (buttonMinus != null) {
      $result.buttonMinus = buttonMinus;
    }
    return $result;
  }
  ClickKeyPadStatus._() : super();
  factory ClickKeyPadStatus.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ClickKeyPadStatus.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ClickKeyPadStatus', package: const $pb.PackageName(_omitMessageNames ? '' : 'de.jonasbark'), createEmptyInstance: create)
    ..e<PlayButtonStatus>(1, _omitFieldNames ? '' : 'ButtonPlus', $pb.PbFieldType.OE, protoName: 'Button_Plus', defaultOrMaker: PlayButtonStatus.ON, valueOf: PlayButtonStatus.valueOf, enumValues: PlayButtonStatus.values)
    ..e<PlayButtonStatus>(2, _omitFieldNames ? '' : 'ButtonMinus', $pb.PbFieldType.OE, protoName: 'Button_Minus', defaultOrMaker: PlayButtonStatus.ON, valueOf: PlayButtonStatus.valueOf, enumValues: PlayButtonStatus.values)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ClickKeyPadStatus clone() => ClickKeyPadStatus()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ClickKeyPadStatus copyWith(void Function(ClickKeyPadStatus) updates) => super.copyWith((message) => updates(message as ClickKeyPadStatus)) as ClickKeyPadStatus;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClickKeyPadStatus create() => ClickKeyPadStatus._();
  ClickKeyPadStatus createEmptyInstance() => create();
  static $pb.PbList<ClickKeyPadStatus> createRepeated() => $pb.PbList<ClickKeyPadStatus>();
  @$core.pragma('dart2js:noInline')
  static ClickKeyPadStatus getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ClickKeyPadStatus>(create);
  static ClickKeyPadStatus? _defaultInstance;

  @$pb.TagNumber(1)
  PlayButtonStatus get buttonPlus => $_getN(0);
  @$pb.TagNumber(1)
  set buttonPlus(PlayButtonStatus v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasButtonPlus() => $_has(0);
  @$pb.TagNumber(1)
  void clearButtonPlus() => clearField(1);

  @$pb.TagNumber(2)
  PlayButtonStatus get buttonMinus => $_getN(1);
  @$pb.TagNumber(2)
  set buttonMinus(PlayButtonStatus v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasButtonMinus() => $_has(1);
  @$pb.TagNumber(2)
  void clearButtonMinus() => clearField(2);
}

/// ------------------ Device Information requested after connection
///  The command code prepending this message is 0x3c
class DeviceInformationContent extends $pb.GeneratedMessage {
  factory DeviceInformationContent({
    $core.int? unknown1,
    $core.Iterable<$core.int>? softwareVersion,
    $core.String? deviceName,
    $core.int? unknown4,
    $core.int? unknown5,
    $core.String? serialNumber,
    $core.String? hardwareVersion,
    $core.Iterable<$core.int>? replyData,
    $core.int? unknown9,
    $core.int? unknown10,
    $core.int? unknown13,
  }) {
    final $result = create();
    if (unknown1 != null) {
      $result.unknown1 = unknown1;
    }
    if (softwareVersion != null) {
      $result.softwareVersion.addAll(softwareVersion);
    }
    if (deviceName != null) {
      $result.deviceName = deviceName;
    }
    if (unknown4 != null) {
      $result.unknown4 = unknown4;
    }
    if (unknown5 != null) {
      $result.unknown5 = unknown5;
    }
    if (serialNumber != null) {
      $result.serialNumber = serialNumber;
    }
    if (hardwareVersion != null) {
      $result.hardwareVersion = hardwareVersion;
    }
    if (replyData != null) {
      $result.replyData.addAll(replyData);
    }
    if (unknown9 != null) {
      $result.unknown9 = unknown9;
    }
    if (unknown10 != null) {
      $result.unknown10 = unknown10;
    }
    if (unknown13 != null) {
      $result.unknown13 = unknown13;
    }
    return $result;
  }
  DeviceInformationContent._() : super();
  factory DeviceInformationContent.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DeviceInformationContent.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DeviceInformationContent', package: const $pb.PackageName(_omitMessageNames ? '' : 'de.jonasbark'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'Unknown1', $pb.PbFieldType.OU3, protoName: 'Unknown1')
    ..p<$core.int>(2, _omitFieldNames ? '' : 'SoftwareVersion', $pb.PbFieldType.PU3, protoName: 'SoftwareVersion')
    ..aOS(3, _omitFieldNames ? '' : 'DeviceName', protoName: 'DeviceName')
    ..a<$core.int>(4, _omitFieldNames ? '' : 'Unknown4', $pb.PbFieldType.OU3, protoName: 'Unknown4')
    ..a<$core.int>(5, _omitFieldNames ? '' : 'Unknown5', $pb.PbFieldType.OU3, protoName: 'Unknown5')
    ..aOS(6, _omitFieldNames ? '' : 'SerialNumber', protoName: 'SerialNumber')
    ..aOS(7, _omitFieldNames ? '' : 'HardwareVersion', protoName: 'HardwareVersion')
    ..p<$core.int>(8, _omitFieldNames ? '' : 'ReplyData', $pb.PbFieldType.PU3, protoName: 'ReplyData')
    ..a<$core.int>(9, _omitFieldNames ? '' : 'Unknown9', $pb.PbFieldType.OU3, protoName: 'Unknown9')
    ..a<$core.int>(10, _omitFieldNames ? '' : 'Unknown10', $pb.PbFieldType.OU3, protoName: 'Unknown10')
    ..a<$core.int>(13, _omitFieldNames ? '' : 'Unknown13', $pb.PbFieldType.OU3, protoName: 'Unknown13')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DeviceInformationContent clone() => DeviceInformationContent()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DeviceInformationContent copyWith(void Function(DeviceInformationContent) updates) => super.copyWith((message) => updates(message as DeviceInformationContent)) as DeviceInformationContent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeviceInformationContent create() => DeviceInformationContent._();
  DeviceInformationContent createEmptyInstance() => create();
  static $pb.PbList<DeviceInformationContent> createRepeated() => $pb.PbList<DeviceInformationContent>();
  @$core.pragma('dart2js:noInline')
  static DeviceInformationContent getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DeviceInformationContent>(create);
  static DeviceInformationContent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get unknown1 => $_getIZ(0);
  @$pb.TagNumber(1)
  set unknown1($core.int v) { $_setUnsignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUnknown1() => $_has(0);
  @$pb.TagNumber(1)
  void clearUnknown1() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get softwareVersion => $_getList(1);

  @$pb.TagNumber(3)
  $core.String get deviceName => $_getSZ(2);
  @$pb.TagNumber(3)
  set deviceName($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasDeviceName() => $_has(2);
  @$pb.TagNumber(3)
  void clearDeviceName() => clearField(3);

  @$pb.TagNumber(4)
  $core.int get unknown4 => $_getIZ(3);
  @$pb.TagNumber(4)
  set unknown4($core.int v) { $_setUnsignedInt32(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasUnknown4() => $_has(3);
  @$pb.TagNumber(4)
  void clearUnknown4() => clearField(4);

  @$pb.TagNumber(5)
  $core.int get unknown5 => $_getIZ(4);
  @$pb.TagNumber(5)
  set unknown5($core.int v) { $_setUnsignedInt32(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasUnknown5() => $_has(4);
  @$pb.TagNumber(5)
  void clearUnknown5() => clearField(5);

  @$pb.TagNumber(6)
  $core.String get serialNumber => $_getSZ(5);
  @$pb.TagNumber(6)
  set serialNumber($core.String v) { $_setString(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasSerialNumber() => $_has(5);
  @$pb.TagNumber(6)
  void clearSerialNumber() => clearField(6);

  @$pb.TagNumber(7)
  $core.String get hardwareVersion => $_getSZ(6);
  @$pb.TagNumber(7)
  set hardwareVersion($core.String v) { $_setString(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasHardwareVersion() => $_has(6);
  @$pb.TagNumber(7)
  void clearHardwareVersion() => clearField(7);

  @$pb.TagNumber(8)
  $core.List<$core.int> get replyData => $_getList(7);

  @$pb.TagNumber(9)
  $core.int get unknown9 => $_getIZ(8);
  @$pb.TagNumber(9)
  set unknown9($core.int v) { $_setUnsignedInt32(8, v); }
  @$pb.TagNumber(9)
  $core.bool hasUnknown9() => $_has(8);
  @$pb.TagNumber(9)
  void clearUnknown9() => clearField(9);

  @$pb.TagNumber(10)
  $core.int get unknown10 => $_getIZ(9);
  @$pb.TagNumber(10)
  set unknown10($core.int v) { $_setUnsignedInt32(9, v); }
  @$pb.TagNumber(10)
  $core.bool hasUnknown10() => $_has(9);
  @$pb.TagNumber(10)
  void clearUnknown10() => clearField(10);

  @$pb.TagNumber(13)
  $core.int get unknown13 => $_getIZ(10);
  @$pb.TagNumber(13)
  set unknown13($core.int v) { $_setUnsignedInt32(10, v); }
  @$pb.TagNumber(13)
  $core.bool hasUnknown13() => $_has(10);
  @$pb.TagNumber(13)
  void clearUnknown13() => clearField(13);
}

class SubContent extends $pb.GeneratedMessage {
  factory SubContent({
    DeviceInformationContent? content,
    $core.int? unknown2,
    $core.int? unknown4,
    $core.int? unknown5,
    $core.int? unknown6,
  }) {
    final $result = create();
    if (content != null) {
      $result.content = content;
    }
    if (unknown2 != null) {
      $result.unknown2 = unknown2;
    }
    if (unknown4 != null) {
      $result.unknown4 = unknown4;
    }
    if (unknown5 != null) {
      $result.unknown5 = unknown5;
    }
    if (unknown6 != null) {
      $result.unknown6 = unknown6;
    }
    return $result;
  }
  SubContent._() : super();
  factory SubContent.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SubContent.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SubContent', package: const $pb.PackageName(_omitMessageNames ? '' : 'de.jonasbark'), createEmptyInstance: create)
    ..aOM<DeviceInformationContent>(1, _omitFieldNames ? '' : 'Content', protoName: 'Content', subBuilder: DeviceInformationContent.create)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'Unknown2', $pb.PbFieldType.OU3, protoName: 'Unknown2')
    ..a<$core.int>(4, _omitFieldNames ? '' : 'Unknown4', $pb.PbFieldType.OU3, protoName: 'Unknown4')
    ..a<$core.int>(5, _omitFieldNames ? '' : 'Unknown5', $pb.PbFieldType.OU3, protoName: 'Unknown5')
    ..a<$core.int>(6, _omitFieldNames ? '' : 'Unknown6', $pb.PbFieldType.OU3, protoName: 'Unknown6')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SubContent clone() => SubContent()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SubContent copyWith(void Function(SubContent) updates) => super.copyWith((message) => updates(message as SubContent)) as SubContent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SubContent create() => SubContent._();
  SubContent createEmptyInstance() => create();
  static $pb.PbList<SubContent> createRepeated() => $pb.PbList<SubContent>();
  @$core.pragma('dart2js:noInline')
  static SubContent getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SubContent>(create);
  static SubContent? _defaultInstance;

  @$pb.TagNumber(1)
  DeviceInformationContent get content => $_getN(0);
  @$pb.TagNumber(1)
  set content(DeviceInformationContent v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasContent() => $_has(0);
  @$pb.TagNumber(1)
  void clearContent() => clearField(1);
  @$pb.TagNumber(1)
  DeviceInformationContent ensureContent() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.int get unknown2 => $_getIZ(1);
  @$pb.TagNumber(2)
  set unknown2($core.int v) { $_setUnsignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasUnknown2() => $_has(1);
  @$pb.TagNumber(2)
  void clearUnknown2() => clearField(2);

  @$pb.TagNumber(4)
  $core.int get unknown4 => $_getIZ(2);
  @$pb.TagNumber(4)
  set unknown4($core.int v) { $_setUnsignedInt32(2, v); }
  @$pb.TagNumber(4)
  $core.bool hasUnknown4() => $_has(2);
  @$pb.TagNumber(4)
  void clearUnknown4() => clearField(4);

  @$pb.TagNumber(5)
  $core.int get unknown5 => $_getIZ(3);
  @$pb.TagNumber(5)
  set unknown5($core.int v) { $_setUnsignedInt32(3, v); }
  @$pb.TagNumber(5)
  $core.bool hasUnknown5() => $_has(3);
  @$pb.TagNumber(5)
  void clearUnknown5() => clearField(5);

  @$pb.TagNumber(6)
  $core.int get unknown6 => $_getIZ(4);
  @$pb.TagNumber(6)
  set unknown6($core.int v) { $_setUnsignedInt32(4, v); }
  @$pb.TagNumber(6)
  $core.bool hasUnknown6() => $_has(4);
  @$pb.TagNumber(6)
  void clearUnknown6() => clearField(6);
}

class DeviceInformation extends $pb.GeneratedMessage {
  factory DeviceInformation({
    $core.int? informationId,
    SubContent? subContent,
  }) {
    final $result = create();
    if (informationId != null) {
      $result.informationId = informationId;
    }
    if (subContent != null) {
      $result.subContent = subContent;
    }
    return $result;
  }
  DeviceInformation._() : super();
  factory DeviceInformation.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DeviceInformation.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DeviceInformation', package: const $pb.PackageName(_omitMessageNames ? '' : 'de.jonasbark'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'InformationId', $pb.PbFieldType.OU3, protoName: 'InformationId')
    ..aOM<SubContent>(2, _omitFieldNames ? '' : 'SubContent', protoName: 'SubContent', subBuilder: SubContent.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DeviceInformation clone() => DeviceInformation()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DeviceInformation copyWith(void Function(DeviceInformation) updates) => super.copyWith((message) => updates(message as DeviceInformation)) as DeviceInformation;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeviceInformation create() => DeviceInformation._();
  DeviceInformation createEmptyInstance() => create();
  static $pb.PbList<DeviceInformation> createRepeated() => $pb.PbList<DeviceInformation>();
  @$core.pragma('dart2js:noInline')
  static DeviceInformation getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DeviceInformation>(create);
  static DeviceInformation? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get informationId => $_getIZ(0);
  @$pb.TagNumber(1)
  set informationId($core.int v) { $_setUnsignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasInformationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearInformationId() => clearField(1);

  @$pb.TagNumber(2)
  SubContent get subContent => $_getN(1);
  @$pb.TagNumber(2)
  set subContent(SubContent v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasSubContent() => $_has(1);
  @$pb.TagNumber(2)
  void clearSubContent() => clearField(2);
  @$pb.TagNumber(2)
  SubContent ensureSubContent() => $_ensure(1);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
