//
//  Generated code. Do not modify.
//  source: zp_vendor.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use vendorOpcodeDescriptor instead')
const VendorOpcode$json = {
  '1': 'VendorOpcode',
  '2': [
    {'1': 'UNDEFINED', '2': 0},
    {'1': 'CONTROLLER_SYNC', '2': 1},
    {'1': 'PAIR_DEVICES', '2': 2},
    {'1': 'ENABLE_TEST_MODE', '2': 65280},
    {'1': 'SET_DFU_TEST', '2': 65281},
    {'1': 'SET_TRAINER_TEST_DATA', '2': 65282},
    {'1': 'SET_INPUT_DEVICE_TEST_DATA', '2': 65283},
    {'1': 'SET_GEAR_TEST_DATA', '2': 65284},
    {'1': 'SET_HRM_TEST_DATA', '2': 65285},
    {'1': 'SET_TEST_DATA', '2': 65286},
  ],
};

/// Descriptor for `VendorOpcode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List vendorOpcodeDescriptor = $convert.base64Decode(
    'CgxWZW5kb3JPcGNvZGUSDQoJVU5ERUZJTkVEEAASEwoPQ09OVFJPTExFUl9TWU5DEAESEAoMUE'
    'FJUl9ERVZJQ0VTEAISFgoQRU5BQkxFX1RFU1RfTU9ERRCA/gMSEgoMU0VUX0RGVV9URVNUEIH+'
    'AxIbChVTRVRfVFJBSU5FUl9URVNUX0RBVEEQgv4DEiAKGlNFVF9JTlBVVF9ERVZJQ0VfVEVTVF'
    '9EQVRBEIP+AxIYChJTRVRfR0VBUl9URVNUX0RBVEEQhP4DEhcKEVNFVF9IUk1fVEVTVF9EQVRB'
    'EIX+AxITCg1TRVRfVEVTVF9EQVRBEIb+Aw==');

@$core.Deprecated('Use pairDeviceTypeDescriptor instead')
const PairDeviceType$json = {
  '1': 'PairDeviceType',
  '2': [
    {'1': 'BLE', '2': 0},
    {'1': 'ANT', '2': 1},
  ],
};

/// Descriptor for `PairDeviceType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List pairDeviceTypeDescriptor = $convert.base64Decode(
    'Cg5QYWlyRGV2aWNlVHlwZRIHCgNCTEUQABIHCgNBTlQQAQ==');

@$core.Deprecated('Use controllerSyncStatusDescriptor instead')
const ControllerSyncStatus$json = {
  '1': 'ControllerSyncStatus',
  '2': [
    {'1': 'NOT_CONNECTED', '2': 0},
    {'1': 'CONNECTED', '2': 1},
  ],
};

/// Descriptor for `ControllerSyncStatus`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List controllerSyncStatusDescriptor = $convert.base64Decode(
    'ChRDb250cm9sbGVyU3luY1N0YXR1cxIRCg1OT1RfQ09OTkVDVEVEEAASDQoJQ09OTkVDVEVEEA'
    'E=');

@$core.Deprecated('Use vendorDODescriptor instead')
const VendorDO$json = {
  '1': 'VendorDO',
  '2': [
    {'1': 'NO_CLUE', '2': 0},
    {'1': 'PAGE_DEVICE_PAIRING', '2': 61440},
    {'1': 'DEVICE_COUNT', '2': 61441},
    {'1': 'PAIRING_STATUS', '2': 61442},
    {'1': 'PAIRED_DEVICE', '2': 61443},
  ],
};

/// Descriptor for `VendorDO`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List vendorDODescriptor = $convert.base64Decode(
    'CghWZW5kb3JETxILCgdOT19DTFVFEAASGQoTUEFHRV9ERVZJQ0VfUEFJUklORxCA4AMSEgoMRE'
    'VWSUNFX0NPVU5UEIHgAxIUCg5QQUlSSU5HX1NUQVRVUxCC4AMSEwoNUEFJUkVEX0RFVklDRRCD'
    '4AM=');

@$core.Deprecated('Use controllerSyncDescriptor instead')
const ControllerSync$json = {
  '1': 'ControllerSync',
  '2': [
    {'1': 'status', '3': 1, '4': 1, '5': 14, '6': '.com.zwift.protobuf.ControllerSyncStatus', '10': 'status'},
    {'1': 'timeStamp', '3': 2, '4': 1, '5': 5, '10': 'timeStamp'},
  ],
};

/// Descriptor for `ControllerSync`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List controllerSyncDescriptor = $convert.base64Decode(
    'Cg5Db250cm9sbGVyU3luYxJACgZzdGF0dXMYASABKA4yKC5jb20uendpZnQucHJvdG9idWYuQ2'
    '9udHJvbGxlclN5bmNTdGF0dXNSBnN0YXR1cxIcCgl0aW1lU3RhbXAYAiABKAVSCXRpbWVTdGFt'
    'cA==');

@$core.Deprecated('Use enableTestModeDescriptor instead')
const EnableTestMode$json = {
  '1': 'EnableTestMode',
  '2': [
    {'1': 'enable', '3': 1, '4': 1, '5': 8, '10': 'enable'},
  ],
};

/// Descriptor for `EnableTestMode`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List enableTestModeDescriptor = $convert.base64Decode(
    'Cg5FbmFibGVUZXN0TW9kZRIWCgZlbmFibGUYASABKAhSBmVuYWJsZQ==');

@$core.Deprecated('Use pairDevicesDescriptor instead')
const PairDevices$json = {
  '1': 'PairDevices',
  '2': [
    {'1': 'pair', '3': 1, '4': 1, '5': 8, '10': 'pair'},
    {'1': 'type', '3': 2, '4': 1, '5': 14, '6': '.com.zwift.protobuf.PairDeviceType', '10': 'type'},
    {'1': 'deviceId', '3': 3, '4': 1, '5': 12, '10': 'deviceId'},
  ],
};

/// Descriptor for `PairDevices`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pairDevicesDescriptor = $convert.base64Decode(
    'CgtQYWlyRGV2aWNlcxISCgRwYWlyGAEgASgIUgRwYWlyEjYKBHR5cGUYAiABKA4yIi5jb20uen'
    'dpZnQucHJvdG9idWYuUGFpckRldmljZVR5cGVSBHR5cGUSGgoIZGV2aWNlSWQYAyABKAxSCGRl'
    'dmljZUlk');

@$core.Deprecated('Use devicePairingDataPageDescriptor instead')
const DevicePairingDataPage$json = {
  '1': 'DevicePairingDataPage',
  '2': [
    {'1': 'devicesCount', '3': 1, '4': 1, '5': 5, '10': 'devicesCount'},
    {'1': 'pairingStatus', '3': 2, '4': 1, '5': 5, '10': 'pairingStatus'},
    {'1': 'pairingDevList', '3': 3, '4': 3, '5': 11, '6': '.com.zwift.protobuf.DevicePairingDataPage.PairedDevice', '10': 'pairingDevList'},
  ],
  '3': [DevicePairingDataPage_PairedDevice$json],
};

@$core.Deprecated('Use devicePairingDataPageDescriptor instead')
const DevicePairingDataPage_PairedDevice$json = {
  '1': 'PairedDevice',
  '2': [
    {'1': 'device', '3': 1, '4': 1, '5': 12, '10': 'device'},
  ],
};

/// Descriptor for `DevicePairingDataPage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List devicePairingDataPageDescriptor = $convert.base64Decode(
    'ChVEZXZpY2VQYWlyaW5nRGF0YVBhZ2USIgoMZGV2aWNlc0NvdW50GAEgASgFUgxkZXZpY2VzQ2'
    '91bnQSJAoNcGFpcmluZ1N0YXR1cxgCIAEoBVINcGFpcmluZ1N0YXR1cxJeCg5wYWlyaW5nRGV2'
    'TGlzdBgDIAMoCzI2LmNvbS56d2lmdC5wcm90b2J1Zi5EZXZpY2VQYWlyaW5nRGF0YVBhZ2UuUG'
    'FpcmVkRGV2aWNlUg5wYWlyaW5nRGV2TGlzdBomCgxQYWlyZWREZXZpY2USFgoGZGV2aWNlGAEg'
    'ASgMUgZkZXZpY2U=');

@$core.Deprecated('Use setDfuTestDescriptor instead')
const SetDfuTest$json = {
  '1': 'SetDfuTest',
  '2': [
    {'1': 'failedEnterDfu', '3': 1, '4': 1, '5': 8, '9': 0, '10': 'failedEnterDfu'},
    {'1': 'failedStartAdvertising', '3': 2, '4': 1, '5': 8, '9': 0, '10': 'failedStartAdvertising'},
    {'1': 'crcFailure', '3': 3, '4': 1, '5': 5, '9': 0, '10': 'crcFailure'},
  ],
  '8': [
    {'1': 'test_case'},
  ],
};

/// Descriptor for `SetDfuTest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setDfuTestDescriptor = $convert.base64Decode(
    'CgpTZXREZnVUZXN0EigKDmZhaWxlZEVudGVyRGZ1GAEgASgISABSDmZhaWxlZEVudGVyRGZ1Ej'
    'gKFmZhaWxlZFN0YXJ0QWR2ZXJ0aXNpbmcYAiABKAhIAFIWZmFpbGVkU3RhcnRBZHZlcnRpc2lu'
    'ZxIgCgpjcmNGYWlsdXJlGAMgASgFSABSCmNyY0ZhaWx1cmVCCwoJdGVzdF9jYXNl');

@$core.Deprecated('Use setGearTestDataDescriptor instead')
const SetGearTestData$json = {
  '1': 'SetGearTestData',
  '2': [
    {'1': 'frontGearIdx', '3': 1, '4': 1, '5': 5, '10': 'frontGearIdx'},
    {'1': 'rearGearIdx', '3': 2, '4': 1, '5': 5, '10': 'rearGearIdx'},
  ],
};

/// Descriptor for `SetGearTestData`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setGearTestDataDescriptor = $convert.base64Decode(
    'Cg9TZXRHZWFyVGVzdERhdGESIgoMZnJvbnRHZWFySWR4GAEgASgFUgxmcm9udEdlYXJJZHgSIA'
    'oLcmVhckdlYXJJZHgYAiABKAVSC3JlYXJHZWFySWR4');

@$core.Deprecated('Use setHrmTestDataDescriptor instead')
const SetHrmTestData$json = {
  '1': 'SetHrmTestData',
  '2': [
    {'1': 'hrmPresent', '3': 1, '4': 1, '5': 8, '10': 'hrmPresent'},
    {'1': 'heartRate', '3': 2, '4': 1, '5': 5, '10': 'heartRate'},
  ],
};

/// Descriptor for `SetHrmTestData`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setHrmTestDataDescriptor = $convert.base64Decode(
    'Cg5TZXRIcm1UZXN0RGF0YRIeCgpocm1QcmVzZW50GAEgASgIUgpocm1QcmVzZW50EhwKCWhlYX'
    'J0UmF0ZRgCIAEoBVIJaGVhcnRSYXRl');

@$core.Deprecated('Use setInputDeviceTestDataDescriptor instead')
const SetInputDeviceTestData$json = {
  '1': 'SetInputDeviceTestData',
  '2': [
    {'1': 'duration', '3': 1, '4': 1, '5': 5, '10': 'duration'},
    {'1': 'buttonEvent', '3': 2, '4': 1, '5': 5, '10': 'buttonEvent'},
    {'1': 'analogEventList', '3': 3, '4': 3, '5': 11, '6': '.com.zwift.protobuf.SetInputDeviceTestData.ControllerAnalogEvent', '10': 'analogEventList'},
  ],
  '3': [SetInputDeviceTestData_ControllerAnalogEvent$json],
};

@$core.Deprecated('Use setInputDeviceTestDataDescriptor instead')
const SetInputDeviceTestData_ControllerAnalogEvent$json = {
  '1': 'ControllerAnalogEvent',
  '2': [
    {'1': 'sensorId', '3': 1, '4': 1, '5': 5, '10': 'sensorId'},
    {'1': 'value', '3': 2, '4': 1, '5': 5, '10': 'value'},
  ],
};

/// Descriptor for `SetInputDeviceTestData`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setInputDeviceTestDataDescriptor = $convert.base64Decode(
    'ChZTZXRJbnB1dERldmljZVRlc3REYXRhEhoKCGR1cmF0aW9uGAEgASgFUghkdXJhdGlvbhIgCg'
    'tidXR0b25FdmVudBgCIAEoBVILYnV0dG9uRXZlbnQSagoPYW5hbG9nRXZlbnRMaXN0GAMgAygL'
    'MkAuY29tLnp3aWZ0LnByb3RvYnVmLlNldElucHV0RGV2aWNlVGVzdERhdGEuQ29udHJvbGxlck'
    'FuYWxvZ0V2ZW50Ug9hbmFsb2dFdmVudExpc3QaSQoVQ29udHJvbGxlckFuYWxvZ0V2ZW50EhoK'
    'CHNlbnNvcklkGAEgASgFUghzZW5zb3JJZBIUCgV2YWx1ZRgCIAEoBVIFdmFsdWU=');

@$core.Deprecated('Use setTrainerTestDataDescriptor instead')
const SetTrainerTestData$json = {
  '1': 'SetTrainerTestData',
  '2': [
    {'1': 'dataMode', '3': 1, '4': 1, '5': 5, '10': 'dataMode'},
    {'1': 'interfaces', '3': 2, '4': 1, '5': 5, '10': 'interfaces'},
    {'1': 'testTrainerData', '3': 3, '4': 1, '5': 11, '6': '.com.zwift.protobuf.TestTrainerData', '10': 'testTrainerData'},
  ],
};

/// Descriptor for `SetTrainerTestData`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setTrainerTestDataDescriptor = $convert.base64Decode(
    'ChJTZXRUcmFpbmVyVGVzdERhdGESGgoIZGF0YU1vZGUYASABKAVSCGRhdGFNb2RlEh4KCmludG'
    'VyZmFjZXMYAiABKAVSCmludGVyZmFjZXMSTQoPdGVzdFRyYWluZXJEYXRhGAMgASgLMiMuY29t'
    'Lnp3aWZ0LnByb3RvYnVmLlRlc3RUcmFpbmVyRGF0YVIPdGVzdFRyYWluZXJEYXRh');

@$core.Deprecated('Use testTrainerDataDescriptor instead')
const TestTrainerData$json = {
  '1': 'TestTrainerData',
  '2': [
    {'1': 'power', '3': 1, '4': 1, '5': 5, '10': 'power'},
    {'1': 'cadence', '3': 2, '4': 1, '5': 5, '10': 'cadence'},
    {'1': 'bikeSpeed', '3': 3, '4': 1, '5': 5, '10': 'bikeSpeed'},
    {'1': 'averagedPower', '3': 4, '4': 1, '5': 5, '10': 'averagedPower'},
    {'1': 'wheelSpeed', '3': 5, '4': 1, '5': 5, '10': 'wheelSpeed'},
    {'1': 'calculatedRealGearRatio', '3': 6, '4': 1, '5': 5, '10': 'calculatedRealGearRatio'},
  ],
};

/// Descriptor for `TestTrainerData`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List testTrainerDataDescriptor = $convert.base64Decode(
    'Cg9UZXN0VHJhaW5lckRhdGESFAoFcG93ZXIYASABKAVSBXBvd2VyEhgKB2NhZGVuY2UYAiABKA'
    'VSB2NhZGVuY2USHAoJYmlrZVNwZWVkGAMgASgFUgliaWtlU3BlZWQSJAoNYXZlcmFnZWRQb3dl'
    'chgEIAEoBVINYXZlcmFnZWRQb3dlchIeCgp3aGVlbFNwZWVkGAUgASgFUgp3aGVlbFNwZWVkEj'
    'gKF2NhbGN1bGF0ZWRSZWFsR2VhclJhdGlvGAYgASgFUhdjYWxjdWxhdGVkUmVhbEdlYXJSYXRp'
    'bw==');

