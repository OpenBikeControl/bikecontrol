//
//  Generated code. Do not modify.
//  source: zwift.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use playButtonStatusDescriptor instead')
const PlayButtonStatus$json = {
  '1': 'PlayButtonStatus',
  '2': [
    {'1': 'ON', '2': 0},
    {'1': 'OFF', '2': 1},
  ],
};

/// Descriptor for `PlayButtonStatus`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List playButtonStatusDescriptor = $convert.base64Decode(
    'ChBQbGF5QnV0dG9uU3RhdHVzEgYKAk9OEAASBwoDT0ZGEAE=');

@$core.Deprecated('Use rideButtonMaskDescriptor instead')
const RideButtonMask$json = {
  '1': 'RideButtonMask',
  '2': [
    {'1': 'LEFT_BTN', '2': 1},
    {'1': 'UP_BTN', '2': 2},
    {'1': 'RIGHT_BTN', '2': 4},
    {'1': 'DOWN_BTN', '2': 8},
    {'1': 'A_BTN', '2': 16},
    {'1': 'B_BTN', '2': 32},
    {'1': 'Y_BTN', '2': 64},
    {'1': 'Z_BTN', '2': 256},
    {'1': 'SHFT_UP_L_BTN', '2': 512},
    {'1': 'SHFT_DN_L_BTN', '2': 1024},
    {'1': 'POWERUP_L_BTN', '2': 2048},
    {'1': 'ONOFF_L_BTN', '2': 4096},
    {'1': 'SHFT_UP_R_BTN', '2': 8192},
    {'1': 'SHFT_DN_R_BTN', '2': 16384},
    {'1': 'POWERUP_R_BTN', '2': 65536},
    {'1': 'ONOFF_R_BTN', '2': 131072},
  ],
};

/// Descriptor for `RideButtonMask`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List rideButtonMaskDescriptor = $convert.base64Decode(
    'Cg5SaWRlQnV0dG9uTWFzaxIMCghMRUZUX0JUThABEgoKBlVQX0JUThACEg0KCVJJR0hUX0JUTh'
    'AEEgwKCERPV05fQlROEAgSCQoFQV9CVE4QEBIJCgVCX0JUThAgEgkKBVlfQlROEEASCgoFWl9C'
    'VE4QgAISEgoNU0hGVF9VUF9MX0JUThCABBISCg1TSEZUX0ROX0xfQlROEIAIEhIKDVBPV0VSVV'
    'BfTF9CVE4QgBASEAoLT05PRkZfTF9CVE4QgCASEgoNU0hGVF9VUF9SX0JUThCAQBITCg1TSEZU'
    'X0ROX1JfQlROEICAARITCg1QT1dFUlVQX1JfQlROEICABBIRCgtPTk9GRl9SX0JUThCAgAg=');

@$core.Deprecated('Use rideAnalogLocationDescriptor instead')
const RideAnalogLocation$json = {
  '1': 'RideAnalogLocation',
  '2': [
    {'1': 'LEFT', '2': 0},
    {'1': 'RIGHT', '2': 1},
    {'1': 'UP', '2': 2},
    {'1': 'DOWN', '2': 3},
  ],
};

/// Descriptor for `RideAnalogLocation`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List rideAnalogLocationDescriptor = $convert.base64Decode(
    'ChJSaWRlQW5hbG9nTG9jYXRpb24SCAoETEVGVBAAEgkKBVJJR0hUEAESBgoCVVAQAhIICgRET1'
    'dOEAM=');

@$core.Deprecated('Use playKeyPadStatusDescriptor instead')
const PlayKeyPadStatus$json = {
  '1': 'PlayKeyPadStatus',
  '2': [
    {'1': 'RightPad', '3': 1, '4': 1, '5': 14, '6': '.de.jonasbark.PlayButtonStatus', '10': 'RightPad'},
    {'1': 'Button_Y_Up', '3': 2, '4': 1, '5': 14, '6': '.de.jonasbark.PlayButtonStatus', '10': 'ButtonYUp'},
    {'1': 'Button_Z_Left', '3': 3, '4': 1, '5': 14, '6': '.de.jonasbark.PlayButtonStatus', '10': 'ButtonZLeft'},
    {'1': 'Button_A_Right', '3': 4, '4': 1, '5': 14, '6': '.de.jonasbark.PlayButtonStatus', '10': 'ButtonARight'},
    {'1': 'Button_B_Down', '3': 5, '4': 1, '5': 14, '6': '.de.jonasbark.PlayButtonStatus', '10': 'ButtonBDown'},
    {'1': 'Button_On', '3': 6, '4': 1, '5': 14, '6': '.de.jonasbark.PlayButtonStatus', '10': 'ButtonOn'},
    {'1': 'Button_Shift', '3': 7, '4': 1, '5': 14, '6': '.de.jonasbark.PlayButtonStatus', '10': 'ButtonShift'},
    {'1': 'Analog_LR', '3': 8, '4': 1, '5': 17, '10': 'AnalogLR'},
    {'1': 'Analog_UD', '3': 9, '4': 1, '5': 17, '10': 'AnalogUD'},
  ],
};

/// Descriptor for `PlayKeyPadStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playKeyPadStatusDescriptor = $convert.base64Decode(
    'ChBQbGF5S2V5UGFkU3RhdHVzEjoKCFJpZ2h0UGFkGAEgASgOMh4uZGUuam9uYXNiYXJrLlBsYX'
    'lCdXR0b25TdGF0dXNSCFJpZ2h0UGFkEj4KC0J1dHRvbl9ZX1VwGAIgASgOMh4uZGUuam9uYXNi'
    'YXJrLlBsYXlCdXR0b25TdGF0dXNSCUJ1dHRvbllVcBJCCg1CdXR0b25fWl9MZWZ0GAMgASgOMh'
    '4uZGUuam9uYXNiYXJrLlBsYXlCdXR0b25TdGF0dXNSC0J1dHRvblpMZWZ0EkQKDkJ1dHRvbl9B'
    'X1JpZ2h0GAQgASgOMh4uZGUuam9uYXNiYXJrLlBsYXlCdXR0b25TdGF0dXNSDEJ1dHRvbkFSaW'
    'dodBJCCg1CdXR0b25fQl9Eb3duGAUgASgOMh4uZGUuam9uYXNiYXJrLlBsYXlCdXR0b25TdGF0'
    'dXNSC0J1dHRvbkJEb3duEjsKCUJ1dHRvbl9PbhgGIAEoDjIeLmRlLmpvbmFzYmFyay5QbGF5Qn'
    'V0dG9uU3RhdHVzUghCdXR0b25PbhJBCgxCdXR0b25fU2hpZnQYByABKA4yHi5kZS5qb25hc2Jh'
    'cmsuUGxheUJ1dHRvblN0YXR1c1ILQnV0dG9uU2hpZnQSGwoJQW5hbG9nX0xSGAggASgRUghBbm'
    'Fsb2dMUhIbCglBbmFsb2dfVUQYCSABKBFSCEFuYWxvZ1VE');

@$core.Deprecated('Use playCommandParametersDescriptor instead')
const PlayCommandParameters$json = {
  '1': 'PlayCommandParameters',
  '2': [
    {'1': 'param1', '3': 1, '4': 1, '5': 13, '10': 'param1'},
    {'1': 'param2', '3': 2, '4': 1, '5': 13, '10': 'param2'},
    {'1': 'HapticPattern', '3': 3, '4': 1, '5': 13, '10': 'HapticPattern'},
  ],
};

/// Descriptor for `PlayCommandParameters`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playCommandParametersDescriptor = $convert.base64Decode(
    'ChVQbGF5Q29tbWFuZFBhcmFtZXRlcnMSFgoGcGFyYW0xGAEgASgNUgZwYXJhbTESFgoGcGFyYW'
    '0yGAIgASgNUgZwYXJhbTISJAoNSGFwdGljUGF0dGVybhgDIAEoDVINSGFwdGljUGF0dGVybg==');

@$core.Deprecated('Use playCommandContentsDescriptor instead')
const PlayCommandContents$json = {
  '1': 'PlayCommandContents',
  '2': [
    {'1': 'CommandParameters', '3': 1, '4': 1, '5': 11, '6': '.de.jonasbark.PlayCommandParameters', '10': 'CommandParameters'},
  ],
};

/// Descriptor for `PlayCommandContents`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playCommandContentsDescriptor = $convert.base64Decode(
    'ChNQbGF5Q29tbWFuZENvbnRlbnRzElEKEUNvbW1hbmRQYXJhbWV0ZXJzGAEgASgLMiMuZGUuam'
    '9uYXNiYXJrLlBsYXlDb21tYW5kUGFyYW1ldGVyc1IRQ29tbWFuZFBhcmFtZXRlcnM=');

@$core.Deprecated('Use playCommandDescriptor instead')
const PlayCommand$json = {
  '1': 'PlayCommand',
  '2': [
    {'1': 'CommandContents', '3': 2, '4': 1, '5': 11, '6': '.de.jonasbark.PlayCommandContents', '10': 'CommandContents'},
  ],
};

/// Descriptor for `PlayCommand`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playCommandDescriptor = $convert.base64Decode(
    'CgtQbGF5Q29tbWFuZBJLCg9Db21tYW5kQ29udGVudHMYAiABKAsyIS5kZS5qb25hc2JhcmsuUG'
    'xheUNvbW1hbmRDb250ZW50c1IPQ29tbWFuZENvbnRlbnRz');

@$core.Deprecated('Use idleDescriptor instead')
const Idle$json = {
  '1': 'Idle',
  '2': [
    {'1': 'Unknown2', '3': 2, '4': 1, '5': 13, '10': 'Unknown2'},
  ],
};

/// Descriptor for `Idle`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List idleDescriptor = $convert.base64Decode(
    'CgRJZGxlEhoKCFVua25vd24yGAIgASgNUghVbmtub3duMg==');

@$core.Deprecated('Use rideAnalogKeyPressDescriptor instead')
const RideAnalogKeyPress$json = {
  '1': 'RideAnalogKeyPress',
  '2': [
    {'1': 'Location', '3': 1, '4': 1, '5': 14, '6': '.de.jonasbark.RideAnalogLocation', '10': 'Location'},
    {'1': 'AnalogValue', '3': 2, '4': 1, '5': 17, '10': 'AnalogValue'},
  ],
};

/// Descriptor for `RideAnalogKeyPress`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rideAnalogKeyPressDescriptor = $convert.base64Decode(
    'ChJSaWRlQW5hbG9nS2V5UHJlc3MSPAoITG9jYXRpb24YASABKA4yIC5kZS5qb25hc2JhcmsuUm'
    'lkZUFuYWxvZ0xvY2F0aW9uUghMb2NhdGlvbhIgCgtBbmFsb2dWYWx1ZRgCIAEoEVILQW5hbG9n'
    'VmFsdWU=');

@$core.Deprecated('Use rideAnalogKeyGroupDescriptor instead')
const RideAnalogKeyGroup$json = {
  '1': 'RideAnalogKeyGroup',
  '2': [
    {'1': 'GroupStatus', '3': 1, '4': 3, '5': 11, '6': '.de.jonasbark.RideAnalogKeyPress', '10': 'GroupStatus'},
  ],
};

/// Descriptor for `RideAnalogKeyGroup`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rideAnalogKeyGroupDescriptor = $convert.base64Decode(
    'ChJSaWRlQW5hbG9nS2V5R3JvdXASQgoLR3JvdXBTdGF0dXMYASADKAsyIC5kZS5qb25hc2Jhcm'
    'suUmlkZUFuYWxvZ0tleVByZXNzUgtHcm91cFN0YXR1cw==');

@$core.Deprecated('Use rideKeyPadStatusDescriptor instead')
const RideKeyPadStatus$json = {
  '1': 'RideKeyPadStatus',
  '2': [
    {'1': 'ButtonMap', '3': 1, '4': 1, '5': 13, '10': 'ButtonMap'},
    {'1': 'AnalogButtons', '3': 2, '4': 1, '5': 11, '6': '.de.jonasbark.RideAnalogKeyGroup', '10': 'AnalogButtons'},
  ],
};

/// Descriptor for `RideKeyPadStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rideKeyPadStatusDescriptor = $convert.base64Decode(
    'ChBSaWRlS2V5UGFkU3RhdHVzEhwKCUJ1dHRvbk1hcBgBIAEoDVIJQnV0dG9uTWFwEkYKDUFuYW'
    'xvZ0J1dHRvbnMYAiABKAsyIC5kZS5qb25hc2JhcmsuUmlkZUFuYWxvZ0tleUdyb3VwUg1BbmFs'
    'b2dCdXR0b25z');

@$core.Deprecated('Use clickKeyPadStatusDescriptor instead')
const ClickKeyPadStatus$json = {
  '1': 'ClickKeyPadStatus',
  '2': [
    {'1': 'Button_Plus', '3': 1, '4': 1, '5': 14, '6': '.de.jonasbark.PlayButtonStatus', '10': 'ButtonPlus'},
    {'1': 'Button_Minus', '3': 2, '4': 1, '5': 14, '6': '.de.jonasbark.PlayButtonStatus', '10': 'ButtonMinus'},
  ],
};

/// Descriptor for `ClickKeyPadStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clickKeyPadStatusDescriptor = $convert.base64Decode(
    'ChFDbGlja0tleVBhZFN0YXR1cxI/CgtCdXR0b25fUGx1cxgBIAEoDjIeLmRlLmpvbmFzYmFyay'
    '5QbGF5QnV0dG9uU3RhdHVzUgpCdXR0b25QbHVzEkEKDEJ1dHRvbl9NaW51cxgCIAEoDjIeLmRl'
    'LmpvbmFzYmFyay5QbGF5QnV0dG9uU3RhdHVzUgtCdXR0b25NaW51cw==');

@$core.Deprecated('Use deviceInformationContentDescriptor instead')
const DeviceInformationContent$json = {
  '1': 'DeviceInformationContent',
  '2': [
    {'1': 'Unknown1', '3': 1, '4': 1, '5': 13, '10': 'Unknown1'},
    {'1': 'SoftwareVersion', '3': 2, '4': 3, '5': 13, '10': 'SoftwareVersion'},
    {'1': 'DeviceName', '3': 3, '4': 1, '5': 9, '10': 'DeviceName'},
    {'1': 'Unknown4', '3': 4, '4': 1, '5': 13, '10': 'Unknown4'},
    {'1': 'Unknown5', '3': 5, '4': 1, '5': 13, '10': 'Unknown5'},
    {'1': 'SerialNumber', '3': 6, '4': 1, '5': 9, '10': 'SerialNumber'},
    {'1': 'HardwareVersion', '3': 7, '4': 1, '5': 9, '10': 'HardwareVersion'},
    {'1': 'ReplyData', '3': 8, '4': 3, '5': 13, '10': 'ReplyData'},
    {'1': 'Unknown9', '3': 9, '4': 1, '5': 13, '10': 'Unknown9'},
    {'1': 'Unknown10', '3': 10, '4': 1, '5': 13, '10': 'Unknown10'},
    {'1': 'Unknown13', '3': 13, '4': 1, '5': 13, '10': 'Unknown13'},
  ],
};

/// Descriptor for `DeviceInformationContent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deviceInformationContentDescriptor = $convert.base64Decode(
    'ChhEZXZpY2VJbmZvcm1hdGlvbkNvbnRlbnQSGgoIVW5rbm93bjEYASABKA1SCFVua25vd24xEi'
    'gKD1NvZnR3YXJlVmVyc2lvbhgCIAMoDVIPU29mdHdhcmVWZXJzaW9uEh4KCkRldmljZU5hbWUY'
    'AyABKAlSCkRldmljZU5hbWUSGgoIVW5rbm93bjQYBCABKA1SCFVua25vd240EhoKCFVua25vd2'
    '41GAUgASgNUghVbmtub3duNRIiCgxTZXJpYWxOdW1iZXIYBiABKAlSDFNlcmlhbE51bWJlchIo'
    'Cg9IYXJkd2FyZVZlcnNpb24YByABKAlSD0hhcmR3YXJlVmVyc2lvbhIcCglSZXBseURhdGEYCC'
    'ADKA1SCVJlcGx5RGF0YRIaCghVbmtub3duORgJIAEoDVIIVW5rbm93bjkSHAoJVW5rbm93bjEw'
    'GAogASgNUglVbmtub3duMTASHAoJVW5rbm93bjEzGA0gASgNUglVbmtub3duMTM=');

@$core.Deprecated('Use subContentDescriptor instead')
const SubContent$json = {
  '1': 'SubContent',
  '2': [
    {'1': 'Content', '3': 1, '4': 1, '5': 11, '6': '.de.jonasbark.DeviceInformationContent', '10': 'Content'},
    {'1': 'Unknown2', '3': 2, '4': 1, '5': 13, '10': 'Unknown2'},
    {'1': 'Unknown4', '3': 4, '4': 1, '5': 13, '10': 'Unknown4'},
    {'1': 'Unknown5', '3': 5, '4': 1, '5': 13, '10': 'Unknown5'},
    {'1': 'Unknown6', '3': 6, '4': 1, '5': 13, '10': 'Unknown6'},
  ],
};

/// Descriptor for `SubContent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List subContentDescriptor = $convert.base64Decode(
    'CgpTdWJDb250ZW50EkAKB0NvbnRlbnQYASABKAsyJi5kZS5qb25hc2JhcmsuRGV2aWNlSW5mb3'
    'JtYXRpb25Db250ZW50UgdDb250ZW50EhoKCFVua25vd24yGAIgASgNUghVbmtub3duMhIaCghV'
    'bmtub3duNBgEIAEoDVIIVW5rbm93bjQSGgoIVW5rbm93bjUYBSABKA1SCFVua25vd241EhoKCF'
    'Vua25vd242GAYgASgNUghVbmtub3duNg==');

@$core.Deprecated('Use deviceInformationDescriptor instead')
const DeviceInformation$json = {
  '1': 'DeviceInformation',
  '2': [
    {'1': 'InformationId', '3': 1, '4': 1, '5': 13, '10': 'InformationId'},
    {'1': 'SubContent', '3': 2, '4': 1, '5': 11, '6': '.de.jonasbark.SubContent', '10': 'SubContent'},
  ],
};

/// Descriptor for `DeviceInformation`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deviceInformationDescriptor = $convert.base64Decode(
    'ChFEZXZpY2VJbmZvcm1hdGlvbhIkCg1JbmZvcm1hdGlvbklkGAEgASgNUg1JbmZvcm1hdGlvbk'
    'lkEjgKClN1YkNvbnRlbnQYAiABKAsyGC5kZS5qb25hc2JhcmsuU3ViQ29udGVudFIKU3ViQ29u'
    'dGVudA==');

