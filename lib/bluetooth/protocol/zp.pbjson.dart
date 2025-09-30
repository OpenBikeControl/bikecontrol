//
//  Generated code. Do not modify.
//  source: zp.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use opcodeDescriptor instead')
const Opcode$json = {
  '1': 'Opcode',
  '2': [
    {'1': 'GET', '2': 0},
    {'1': 'DEV_INFO_STATUS', '2': 1},
    {'1': 'BLE_SECURITY_REQUEST', '2': 2},
    {'1': 'TRAINER_NOTIF', '2': 3},
    {'1': 'TRAINER_CONFIG_SET', '2': 4},
    {'1': 'TRAINER_CONFIG_STATUS', '2': 5},
    {'1': 'DEV_INFO_SET', '2': 12},
    {'1': 'POWER_OFF', '2': 15},
    {'1': 'RESET', '2': 24},
    {'1': 'BATTERY_NOTIF', '2': 25},
    {'1': 'CONTROLLER_NOTIFICATION', '2': 35},
    {'1': 'LOG_DATA', '2': 42},
    {'1': 'SPINDOWN_REQUEST', '2': 58},
    {'1': 'SPINDOWN_NOTIFICATION', '2': 59},
    {'1': 'GET_RESPONSE', '2': 60},
    {'1': 'STATUS_RESPONSE', '2': 62},
    {'1': 'SET', '2': 63},
    {'1': 'SET_RESPONSE', '2': 64},
    {'1': 'LOG_LEVEL_SET', '2': 65},
    {'1': 'DATA_CHANGE_NOTIFICATION', '2': 66},
    {'1': 'GAME_STATE_NOTIFICATION', '2': 67},
    {'1': 'SENSOR_RELAY_CONFIG', '2': 68},
    {'1': 'SENSOR_RELAY_GET', '2': 69},
    {'1': 'SENSOR_RELAY_RESPONSE', '2': 70},
    {'1': 'SENSOR_RELAY_NOTIFICATION', '2': 71},
    {'1': 'HRM_DATA_NOTIFICATION', '2': 72},
    {'1': 'WIFI_CONFIG_REQUEST', '2': 73},
    {'1': 'WIFI_NOTIFICATION', '2': 74},
    {'1': 'POWER_METER_NOTIFICATION', '2': 75},
    {'1': 'CADENCE_SENSOR_NOTIFICATION', '2': 76},
    {'1': 'DEVICE_UPDATE_REQUEST', '2': 77},
    {'1': 'RELAY_ZP_MESSAGE', '2': 78},
    {'1': 'RIDE_ON', '2': 82},
    {'1': 'RESERVED', '2': 253},
    {'1': 'LOST_CONTROL', '2': 254},
    {'1': 'VENDOR_MESSAGE', '2': 255},
  ],
};

/// Descriptor for `Opcode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List opcodeDescriptor = $convert.base64Decode(
    'CgZPcGNvZGUSBwoDR0VUEAASEwoPREVWX0lORk9fU1RBVFVTEAESGAoUQkxFX1NFQ1VSSVRZX1'
    'JFUVVFU1QQAhIRCg1UUkFJTkVSX05PVElGEAMSFgoSVFJBSU5FUl9DT05GSUdfU0VUEAQSGQoV'
    'VFJBSU5FUl9DT05GSUdfU1RBVFVTEAUSEAoMREVWX0lORk9fU0VUEAwSDQoJUE9XRVJfT0ZGEA'
    '8SCQoFUkVTRVQQGBIRCg1CQVRURVJZX05PVElGEBkSGwoXQ09OVFJPTExFUl9OT1RJRklDQVRJ'
    'T04QIxIMCghMT0dfREFUQRAqEhQKEFNQSU5ET1dOX1JFUVVFU1QQOhIZChVTUElORE9XTl9OT1'
    'RJRklDQVRJT04QOxIQCgxHRVRfUkVTUE9OU0UQPBITCg9TVEFUVVNfUkVTUE9OU0UQPhIHCgNT'
    'RVQQPxIQCgxTRVRfUkVTUE9OU0UQQBIRCg1MT0dfTEVWRUxfU0VUEEESHAoYREFUQV9DSEFOR0'
    'VfTk9USUZJQ0FUSU9OEEISGwoXR0FNRV9TVEFURV9OT1RJRklDQVRJT04QQxIXChNTRU5TT1Jf'
    'UkVMQVlfQ09ORklHEEQSFAoQU0VOU09SX1JFTEFZX0dFVBBFEhkKFVNFTlNPUl9SRUxBWV9SRV'
    'NQT05TRRBGEh0KGVNFTlNPUl9SRUxBWV9OT1RJRklDQVRJT04QRxIZChVIUk1fREFUQV9OT1RJ'
    'RklDQVRJT04QSBIXChNXSUZJX0NPTkZJR19SRVFVRVNUEEkSFQoRV0lGSV9OT1RJRklDQVRJT0'
    '4QShIcChhQT1dFUl9NRVRFUl9OT1RJRklDQVRJT04QSxIfChtDQURFTkNFX1NFTlNPUl9OT1RJ'
    'RklDQVRJT04QTBIZChVERVZJQ0VfVVBEQVRFX1JFUVVFU1QQTRIUChBSRUxBWV9aUF9NRVNTQU'
    'dFEE4SCwoHUklERV9PThBSEg0KCFJFU0VSVkVEEP0BEhEKDExPU1RfQ09OVFJPTBD+ARITCg5W'
    'RU5ET1JfTUVTU0FHRRD/AQ==');

@$core.Deprecated('Use dODescriptor instead')
const DO$json = {
  '1': 'DO',
  '2': [
    {'1': 'PAGE_DEV_INFO', '2': 0},
    {'1': 'PROTOCOL_VERSION', '2': 1},
    {'1': 'SYSTEM_FW_VERSION', '2': 2},
    {'1': 'DEVICE_NAME', '2': 3},
    {'1': 'SERIAL_NUMBER', '2': 5},
    {'1': 'SYSTEM_HW_REVISION', '2': 6},
    {'1': 'DEVICE_CAPABILITIES', '2': 7},
    {'1': 'MANUFACTURER_ID', '2': 8},
    {'1': 'PRODUCT_ID', '2': 9},
    {'1': 'DEVICE_UID', '2': 10},
    {'1': 'PAGE_CLIENT_SERVER_CONFIGURATION', '2': 16},
    {'1': 'CLIENT_SERVER_NOTIFICATIONS', '2': 17},
    {'1': 'PAGE_DEVICE_UPDATE_INFO', '2': 32},
    {'1': 'DEVICE_UPDATE_STATUS', '2': 33},
    {'1': 'DEVICE_UPDATE_NEW_VERSION', '2': 34},
    {'1': 'PAGE_DATE_TIME', '2': 48},
    {'1': 'UTC_DATE_TIME', '2': 49},
    {'1': 'PAGE_BLE_SECURITY', '2': 64},
    {'1': 'BLE_SECURE_CONNECTION_STATUS', '2': 65},
    {'1': 'BLE_SECURE_CONNECTION_WINDOW_STATUS', '2': 66},
    {'1': 'PAGE_TRAINER_CONFIG', '2': 512},
    {'1': 'TRAINER_MODE', '2': 513},
    {'1': 'CFG_RESISTANCE', '2': 514},
    {'1': 'ERG_POWER', '2': 515},
    {'1': 'AVERAGING_WINDOW', '2': 516},
    {'1': 'SIM_WIND', '2': 517},
    {'1': 'SIM_GRADE', '2': 518},
    {'1': 'SIM_REAL_GEAR_RATIO', '2': 519},
    {'1': 'SIM_VIRT_GEAR_RATIO', '2': 520},
    {'1': 'SIM_CW', '2': 521},
    {'1': 'SIM_WHEEL_DIAMETER', '2': 522},
    {'1': 'SIM_BIKE_MASS', '2': 523},
    {'1': 'SIM_RIDER_MASS', '2': 524},
    {'1': 'SIM_CRR', '2': 525},
    {'1': 'SIM_RESERVED_FRONTAL_AREA', '2': 526},
    {'1': 'SIM_EBRAKE', '2': 527},
    {'1': 'PAGE_TRAINER_GEAR_INDEX_CONFIG', '2': 528},
    {'1': 'FRONT_GEAR_INDEX', '2': 529},
    {'1': 'FRONT_GEAR_INDEX_MAX', '2': 530},
    {'1': 'FRONT_GEAR_INDEX_MIN', '2': 531},
    {'1': 'REAR_GEAR_INDEX', '2': 532},
    {'1': 'REAR_GEAR_INDEX_MAX', '2': 533},
    {'1': 'REAR_GEAR_INDEX_MIN', '2': 534},
    {'1': 'PAGE_TRAINER_CONFIG2', '2': 544},
    {'1': 'HIGH_SPEED_DATA', '2': 545},
    {'1': 'ERG_POWER_SMOOTHING', '2': 546},
    {'1': 'VIRTUAL_SHIFTING_MODE', '2': 547},
    {'1': 'PAGE_DEVICE_TILT_CONFIG', '2': 560},
    {'1': 'DEVICE_TILT_ENABLED', '2': 561},
    {'1': 'DEVICE_TILT_GRADIENT_MIN', '2': 562},
    {'1': 'DEVICE_TILT_GRADIENT_MAX', '2': 563},
    {'1': 'DEVICE_TILT_GRADIENT', '2': 564},
    {'1': 'BATTERY_STATE', '2': 771},
    {'1': 'PAGE_CONTROLLER_INPUT_CONFIG', '2': 1024},
    {'1': 'INPUT_SUPPORTED_DIGITAL_INPUTS', '2': 1025},
    {'1': 'INPUT_SUPPORTED_ANALOG_INPUTS', '2': 1026},
    {'1': 'INPUT_ANALOG_INPUT_RANGE', '2': 1027},
    {'1': 'INPUT_ANALOG_INPUT_DEADZONE', '2': 1028},
    {'1': 'PAGE_WIFI_CONFIGURATION', '2': 1056},
    {'1': 'WIFI_ENABLED', '2': 1057},
    {'1': 'WIFI_STATUS', '2': 1058},
    {'1': 'WIFI_SSID', '2': 1059},
    {'1': 'WIFI_BAND', '2': 1060},
    {'1': 'WIFI_RSSI', '2': 1061},
    {'1': 'WIFI_REGION_CODE', '2': 1062},
    {'1': 'SENSOR_RELAY_DATA_PAGE', '2': 1280},
    {'1': 'SENSOR_RELAY_SUPPORTED_SENSORS', '2': 1281},
    {'1': 'SENSOR_RELAY_PAIRED_SENSORS', '2': 1282},
  ],
};

/// Descriptor for `DO`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List dODescriptor = $convert.base64Decode(
    'CgJETxIRCg1QQUdFX0RFVl9JTkZPEAASFAoQUFJPVE9DT0xfVkVSU0lPThABEhUKEVNZU1RFTV'
    '9GV19WRVJTSU9OEAISDwoLREVWSUNFX05BTUUQAxIRCg1TRVJJQUxfTlVNQkVSEAUSFgoSU1lT'
    'VEVNX0hXX1JFVklTSU9OEAYSFwoTREVWSUNFX0NBUEFCSUxJVElFUxAHEhMKD01BTlVGQUNUVV'
    'JFUl9JRBAIEg4KClBST0RVQ1RfSUQQCRIOCgpERVZJQ0VfVUlEEAoSJAogUEFHRV9DTElFTlRf'
    'U0VSVkVSX0NPTkZJR1VSQVRJT04QEBIfChtDTElFTlRfU0VSVkVSX05PVElGSUNBVElPTlMQER'
    'IbChdQQUdFX0RFVklDRV9VUERBVEVfSU5GTxAgEhgKFERFVklDRV9VUERBVEVfU1RBVFVTECES'
    'HQoZREVWSUNFX1VQREFURV9ORVdfVkVSU0lPThAiEhIKDlBBR0VfREFURV9USU1FEDASEQoNVV'
    'RDX0RBVEVfVElNRRAxEhUKEVBBR0VfQkxFX1NFQ1VSSVRZEEASIAocQkxFX1NFQ1VSRV9DT05O'
    'RUNUSU9OX1NUQVRVUxBBEicKI0JMRV9TRUNVUkVfQ09OTkVDVElPTl9XSU5ET1dfU1RBVFVTEE'
    'ISGAoTUEFHRV9UUkFJTkVSX0NPTkZJRxCABBIRCgxUUkFJTkVSX01PREUQgQQSEwoOQ0ZHX1JF'
    'U0lTVEFOQ0UQggQSDgoJRVJHX1BPV0VSEIMEEhUKEEFWRVJBR0lOR19XSU5ET1cQhAQSDQoIU0'
    'lNX1dJTkQQhQQSDgoJU0lNX0dSQURFEIYEEhgKE1NJTV9SRUFMX0dFQVJfUkFUSU8QhwQSGAoT'
    'U0lNX1ZJUlRfR0VBUl9SQVRJTxCIBBILCgZTSU1fQ1cQiQQSFwoSU0lNX1dIRUVMX0RJQU1FVE'
    'VSEIoEEhIKDVNJTV9CSUtFX01BU1MQiwQSEwoOU0lNX1JJREVSX01BU1MQjAQSDAoHU0lNX0NS'
    'UhCNBBIeChlTSU1fUkVTRVJWRURfRlJPTlRBTF9BUkVBEI4EEg8KClNJTV9FQlJBS0UQjwQSIw'
    'oeUEFHRV9UUkFJTkVSX0dFQVJfSU5ERVhfQ09ORklHEJAEEhUKEEZST05UX0dFQVJfSU5ERVgQ'
    'kQQSGQoURlJPTlRfR0VBUl9JTkRFWF9NQVgQkgQSGQoURlJPTlRfR0VBUl9JTkRFWF9NSU4Qkw'
    'QSFAoPUkVBUl9HRUFSX0lOREVYEJQEEhgKE1JFQVJfR0VBUl9JTkRFWF9NQVgQlQQSGAoTUkVB'
    'Ul9HRUFSX0lOREVYX01JThCWBBIZChRQQUdFX1RSQUlORVJfQ09ORklHMhCgBBIUCg9ISUdIX1'
    'NQRUVEX0RBVEEQoQQSGAoTRVJHX1BPV0VSX1NNT09USElORxCiBBIaChVWSVJUVUFMX1NISUZU'
    'SU5HX01PREUQowQSHAoXUEFHRV9ERVZJQ0VfVElMVF9DT05GSUcQsAQSGAoTREVWSUNFX1RJTF'
    'RfRU5BQkxFRBCxBBIdChhERVZJQ0VfVElMVF9HUkFESUVOVF9NSU4QsgQSHQoYREVWSUNFX1RJ'
    'TFRfR1JBRElFTlRfTUFYELMEEhkKFERFVklDRV9USUxUX0dSQURJRU5UELQEEhIKDUJBVFRFUl'
    'lfU1RBVEUQgwYSIQocUEFHRV9DT05UUk9MTEVSX0lOUFVUX0NPTkZJRxCACBIjCh5JTlBVVF9T'
    'VVBQT1JURURfRElHSVRBTF9JTlBVVFMQgQgSIgodSU5QVVRfU1VQUE9SVEVEX0FOQUxPR19JTl'
    'BVVFMQgggSHQoYSU5QVVRfQU5BTE9HX0lOUFVUX1JBTkdFEIMIEiAKG0lOUFVUX0FOQUxPR19J'
    'TlBVVF9ERUFEWk9ORRCECBIcChdQQUdFX1dJRklfQ09ORklHVVJBVElPThCgCBIRCgxXSUZJX0'
    'VOQUJMRUQQoQgSEAoLV0lGSV9TVEFUVVMQoggSDgoJV0lGSV9TU0lEEKMIEg4KCVdJRklfQkFO'
    'RBCkCBIOCglXSUZJX1JTU0kQpQgSFQoQV0lGSV9SRUdJT05fQ09ERRCmCBIbChZTRU5TT1JfUk'
    'VMQVlfREFUQV9QQUdFEIAKEiMKHlNFTlNPUl9SRUxBWV9TVVBQT1JURURfU0VOU09SUxCBChIg'
    'ChtTRU5TT1JfUkVMQVlfUEFJUkVEX1NFTlNPUlMQggo=');

@$core.Deprecated('Use statusDescriptor instead')
const Status$json = {
  '1': 'Status',
  '2': [
    {'1': 'SUCCESS', '2': 0},
    {'1': 'FAILURE', '2': 1},
    {'1': 'BUSY', '2': 2},
    {'1': 'INVALID_PARAM', '2': 3},
    {'1': 'NOT_PERMITTED', '2': 4},
    {'1': 'NOT_SUPPORTED', '2': 5},
    {'1': 'INVALID_MODE', '2': 6},
  ],
};

/// Descriptor for `Status`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List statusDescriptor = $convert.base64Decode(
    'CgZTdGF0dXMSCwoHU1VDQ0VTUxAAEgsKB0ZBSUxVUkUQARIICgRCVVNZEAISEQoNSU5WQUxJRF'
    '9QQVJBTRADEhEKDU5PVF9QRVJNSVRURUQQBBIRCg1OT1RfU1VQUE9SVEVEEAUSEAoMSU5WQUxJ'
    'RF9NT0RFEAY=');

@$core.Deprecated('Use deviceTypeDescriptor instead')
const DeviceType$json = {
  '1': 'DeviceType',
  '2': [
    {'1': 'UNDEFINED', '2': 0},
    {'1': 'CYCLING_TURBO_TRAINER', '2': 1},
    {'1': 'USER_INPUT_DEVICE', '2': 2},
    {'1': 'TREADMILL', '2': 3},
    {'1': 'SENSOR_RELAY', '2': 4},
    {'1': 'HEART_RATE_MONITOR', '2': 5},
    {'1': 'POWER_METER', '2': 6},
    {'1': 'CADENCE_SENSOR', '2': 7},
    {'1': 'WIFI', '2': 8},
  ],
};

/// Descriptor for `DeviceType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List deviceTypeDescriptor = $convert.base64Decode(
    'CgpEZXZpY2VUeXBlEg0KCVVOREVGSU5FRBAAEhkKFUNZQ0xJTkdfVFVSQk9fVFJBSU5FUhABEh'
    'UKEVVTRVJfSU5QVVRfREVWSUNFEAISDQoJVFJFQURNSUxMEAMSEAoMU0VOU09SX1JFTEFZEAQS'
    'FgoSSEVBUlRfUkFURV9NT05JVE9SEAUSDwoLUE9XRVJfTUVURVIQBhISCg5DQURFTkNFX1NFTl'
    'NPUhAHEggKBFdJRkkQCA==');

@$core.Deprecated('Use trainerModeDescriptor instead')
const TrainerMode$json = {
  '1': 'TrainerMode',
  '2': [
    {'1': 'MODE_UNKNOWN', '2': 0},
    {'1': 'MODE_ERG', '2': 1},
    {'1': 'MODE_RESISTANCE', '2': 2},
    {'1': 'MODE_SIM', '2': 3},
  ],
};

/// Descriptor for `TrainerMode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List trainerModeDescriptor = $convert.base64Decode(
    'CgtUcmFpbmVyTW9kZRIQCgxNT0RFX1VOS05PV04QABIMCghNT0RFX0VSRxABEhMKD01PREVfUk'
    'VTSVNUQU5DRRACEgwKCE1PREVfU0lNEAM=');

@$core.Deprecated('Use chargingStateDescriptor instead')
const ChargingState$json = {
  '1': 'ChargingState',
  '2': [
    {'1': 'CHARGING_IDLE', '2': 0},
    {'1': 'CHARGING_PROGRESS', '2': 1},
    {'1': 'CHARGING_DONE', '2': 2},
  ],
};

/// Descriptor for `ChargingState`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List chargingStateDescriptor = $convert.base64Decode(
    'Cg1DaGFyZ2luZ1N0YXRlEhEKDUNIQVJHSU5HX0lETEUQABIVChFDSEFSR0lOR19QUk9HUkVTUx'
    'ABEhEKDUNIQVJHSU5HX0RPTkUQAg==');

@$core.Deprecated('Use spindownStatusDescriptor instead')
const SpindownStatus$json = {
  '1': 'SpindownStatus',
  '2': [
    {'1': 'SPINDOWN_IDLE', '2': 0},
    {'1': 'SPINDOWN_REQUESTED', '2': 1},
    {'1': 'SPINDOWN_SUCCESS', '2': 2},
    {'1': 'SPINDOWN_ERROR', '2': 3},
    {'1': 'SPINDOWN_STOP_PEDALLING', '2': 4},
    {'1': 'SPINDOWN_ERROR_TIMEOUT', '2': 5},
    {'1': 'SPINDOWN_ERROR_TOSHORT', '2': 6},
    {'1': 'SPINDOWN_ERROR_TOSLOW', '2': 7},
    {'1': 'SPINDOWN_ERROR_TOFAST', '2': 8},
    {'1': 'SPINDOWN_ERROR_SAMPLEERROR', '2': 9},
    {'1': 'SPINDOWN_ERROR_ABORT', '2': 10},
  ],
};

/// Descriptor for `SpindownStatus`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List spindownStatusDescriptor = $convert.base64Decode(
    'Cg5TcGluZG93blN0YXR1cxIRCg1TUElORE9XTl9JRExFEAASFgoSU1BJTkRPV05fUkVRVUVTVE'
    'VEEAESFAoQU1BJTkRPV05fU1VDQ0VTUxACEhIKDlNQSU5ET1dOX0VSUk9SEAMSGwoXU1BJTkRP'
    'V05fU1RPUF9QRURBTExJTkcQBBIaChZTUElORE9XTl9FUlJPUl9USU1FT1VUEAUSGgoWU1BJTk'
    'RPV05fRVJST1JfVE9TSE9SVBAGEhkKFVNQSU5ET1dOX0VSUk9SX1RPU0xPVxAHEhkKFVNQSU5E'
    'T1dOX0VSUk9SX1RPRkFTVBAIEh4KGlNQSU5ET1dOX0VSUk9SX1NBTVBMRUVSUk9SEAkSGAoUU1'
    'BJTkRPV05fRVJST1JfQUJPUlQQCg==');

@$core.Deprecated('Use logLevelDescriptor instead')
const LogLevel$json = {
  '1': 'LogLevel',
  '2': [
    {'1': 'LOGLEVEL_OFF', '2': 0},
    {'1': 'LOGLEVEL_ERROR', '2': 1},
    {'1': 'LOGLEVEL_WARNING', '2': 2},
    {'1': 'LOGLEVEL_INFO', '2': 3},
    {'1': 'LOGLEVEL_DEBUG', '2': 4},
    {'1': 'LOGLEVEL_TRACE', '2': 5},
  ],
};

/// Descriptor for `LogLevel`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List logLevelDescriptor = $convert.base64Decode(
    'CghMb2dMZXZlbBIQCgxMT0dMRVZFTF9PRkYQABISCg5MT0dMRVZFTF9FUlJPUhABEhQKEExPR0'
    'xFVkVMX1dBUk5JTkcQAhIRCg1MT0dMRVZFTF9JTkZPEAMSEgoOTE9HTEVWRUxfREVCVUcQBBIS'
    'Cg5MT0dMRVZFTF9UUkFDRRAF');

@$core.Deprecated('Use roadSurfaceTypeDescriptor instead')
const RoadSurfaceType$json = {
  '1': 'RoadSurfaceType',
  '2': [
    {'1': 'ROAD_SURFACE_SMOOTH_TARMAC', '2': 0},
    {'1': 'ROAD_SURFACE_BRICK_ROAD', '2': 1},
    {'1': 'ROAD_SURFACE_HARD_COBBLES', '2': 2},
    {'1': 'ROAD_SURFACE_SOFT_COBBLES', '2': 3},
    {'1': 'ROAD_SURFACE_NARROW_WOODEN_PLANKS', '2': 4},
    {'1': 'ROAD_SURFACE_WIDE_WOODEN_PLANKS', '2': 5},
    {'1': 'ROAD_SURFACE_DIRT', '2': 6},
    {'1': 'ROAD_SURFACE_GRAVEL', '2': 7},
    {'1': 'ROAD_SURFACE_CATTLE_GRID', '2': 8},
    {'1': 'ROAD_SURFACE_CONCRETE_FLAG_STONES', '2': 9},
    {'1': 'ROAD_SURFACE_ICE', '2': 10},
  ],
};

/// Descriptor for `RoadSurfaceType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List roadSurfaceTypeDescriptor = $convert.base64Decode(
    'Cg9Sb2FkU3VyZmFjZVR5cGUSHgoaUk9BRF9TVVJGQUNFX1NNT09USF9UQVJNQUMQABIbChdST0'
    'FEX1NVUkZBQ0VfQlJJQ0tfUk9BRBABEh0KGVJPQURfU1VSRkFDRV9IQVJEX0NPQkJMRVMQAhId'
    'ChlST0FEX1NVUkZBQ0VfU09GVF9DT0JCTEVTEAMSJQohUk9BRF9TVVJGQUNFX05BUlJPV19XT0'
    '9ERU5fUExBTktTEAQSIwofUk9BRF9TVVJGQUNFX1dJREVfV09PREVOX1BMQU5LUxAFEhUKEVJP'
    'QURfU1VSRkFDRV9ESVJUEAYSFwoTUk9BRF9TVVJGQUNFX0dSQVZFTBAHEhwKGFJPQURfU1VSRk'
    'FDRV9DQVRUTEVfR1JJRBAIEiUKIVJPQURfU1VSRkFDRV9DT05DUkVURV9GTEFHX1NUT05FUxAJ'
    'EhQKEFJPQURfU1VSRkFDRV9JQ0UQCg==');

@$core.Deprecated('Use wifiStatusCodeDescriptor instead')
const WifiStatusCode$json = {
  '1': 'WifiStatusCode',
  '2': [
    {'1': 'WIFI_STATUS_DISABLED', '2': 0},
    {'1': 'WIFI_STATUS_NOT_PROVISIONED', '2': 1},
    {'1': 'WIFI_STATUS_SCANNING', '2': 2},
    {'1': 'WIFI_STATUS_DISCONNECTED', '2': 3},
    {'1': 'WIFI_STATUS_CONNECTING', '2': 4},
    {'1': 'WIFI_STATUS_CONNECTED', '2': 5},
    {'1': 'WIFI_STATUS_ERROR', '2': 6},
  ],
};

/// Descriptor for `WifiStatusCode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List wifiStatusCodeDescriptor = $convert.base64Decode(
    'Cg5XaWZpU3RhdHVzQ29kZRIYChRXSUZJX1NUQVRVU19ESVNBQkxFRBAAEh8KG1dJRklfU1RBVF'
    'VTX05PVF9QUk9WSVNJT05FRBABEhgKFFdJRklfU1RBVFVTX1NDQU5OSU5HEAISHAoYV0lGSV9T'
    'VEFUVVNfRElTQ09OTkVDVEVEEAMSGgoWV0lGSV9TVEFUVVNfQ09OTkVDVElORxAEEhkKFVdJRk'
    'lfU1RBVFVTX0NPTk5FQ1RFRBAFEhUKEVdJRklfU1RBVFVTX0VSUk9SEAY=');

@$core.Deprecated('Use wifiErrorCodeDescriptor instead')
const WifiErrorCode$json = {
  '1': 'WifiErrorCode',
  '2': [
    {'1': 'WIFI_ERROR_UNKNOWN', '2': 0},
    {'1': 'WIFI_ERROR_NO_MEMORY', '2': 1},
    {'1': 'WIFI_ERROR_INVALID_PARAMETERS', '2': 2},
    {'1': 'WIFI_ERROR_INVALID_STATE', '2': 3},
    {'1': 'WIFI_ERROR_NOT_FOUND', '2': 4},
    {'1': 'WIFI_ERROR_NOT_SUPPORTED', '2': 5},
    {'1': 'WIFI_ERROR_NOT_ALLOWED', '2': 6},
    {'1': 'WIFI_ERROR_NOT_INITIALISED', '2': 7},
    {'1': 'WIFI_ERROR_NOT_STARTED', '2': 8},
    {'1': 'WIFI_ERROR_TIMEOUT', '2': 9},
    {'1': 'WIFI_ERROR_MODE', '2': 10},
    {'1': 'WIFI_ERROR_SSID_INVALID', '2': 11},
  ],
};

/// Descriptor for `WifiErrorCode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List wifiErrorCodeDescriptor = $convert.base64Decode(
    'Cg1XaWZpRXJyb3JDb2RlEhYKEldJRklfRVJST1JfVU5LTk9XThAAEhgKFFdJRklfRVJST1JfTk'
    '9fTUVNT1JZEAESIQodV0lGSV9FUlJPUl9JTlZBTElEX1BBUkFNRVRFUlMQAhIcChhXSUZJX0VS'
    'Uk9SX0lOVkFMSURfU1RBVEUQAxIYChRXSUZJX0VSUk9SX05PVF9GT1VORBAEEhwKGFdJRklfRV'
    'JST1JfTk9UX1NVUFBPUlRFRBAFEhoKFldJRklfRVJST1JfTk9UX0FMTE9XRUQQBhIeChpXSUZJ'
    'X0VSUk9SX05PVF9JTklUSUFMSVNFRBAHEhoKFldJRklfRVJST1JfTk9UX1NUQVJURUQQCBIWCh'
    'JXSUZJX0VSUk9SX1RJTUVPVVQQCRITCg9XSUZJX0VSUk9SX01PREUQChIbChdXSUZJX0VSUk9S'
    'X1NTSURfSU5WQUxJRBAL');

@$core.Deprecated('Use interfaceTypeDescriptor instead')
const InterfaceType$json = {
  '1': 'InterfaceType',
  '2': [
    {'1': 'INTERFACE_BLE', '2': 1},
    {'1': 'INTERFACE_ANT', '2': 2},
    {'1': 'INTERFACE_USB', '2': 3},
    {'1': 'INTERFACE_ETH', '2': 4},
    {'1': 'INTERFACE_WIFI', '2': 5},
  ],
};

/// Descriptor for `InterfaceType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List interfaceTypeDescriptor = $convert.base64Decode(
    'Cg1JbnRlcmZhY2VUeXBlEhEKDUlOVEVSRkFDRV9CTEUQARIRCg1JTlRFUkZBQ0VfQU5UEAISEQ'
    'oNSU5URVJGQUNFX1VTQhADEhEKDUlOVEVSRkFDRV9FVEgQBBISCg5JTlRFUkZBQ0VfV0lGSRAF');

@$core.Deprecated('Use sensorConnectionStatusDescriptor instead')
const SensorConnectionStatus$json = {
  '1': 'SensorConnectionStatus',
  '2': [
    {'1': 'SENSOR_STATUS_DISCOVERED', '2': 1},
    {'1': 'SENSOR_STATUS_DISCONNECTED', '2': 2},
    {'1': 'SENSOR_STATUS_PAIRING', '2': 3},
    {'1': 'SENSOR_STATUS_CONNECTED', '2': 4},
  ],
};

/// Descriptor for `SensorConnectionStatus`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List sensorConnectionStatusDescriptor = $convert.base64Decode(
    'ChZTZW5zb3JDb25uZWN0aW9uU3RhdHVzEhwKGFNFTlNPUl9TVEFUVVNfRElTQ09WRVJFRBABEh'
    '4KGlNFTlNPUl9TVEFUVVNfRElTQ09OTkVDVEVEEAISGQoVU0VOU09SX1NUQVRVU19QQUlSSU5H'
    'EAMSGwoXU0VOU09SX1NUQVRVU19DT05ORUNURUQQBA==');

@$core.Deprecated('Use bleSecureConnectionStatusDescriptor instead')
const BleSecureConnectionStatus$json = {
  '1': 'BleSecureConnectionStatus',
  '2': [
    {'1': 'BLE_CONNECTION_SECURITY_STATUS_NONE', '2': 0},
    {'1': 'BLE_CONNECTION_SECURITY_STATUS_INPROGRESS', '2': 1},
    {'1': 'BLE_CONNECTION_SECURITY_STATUS_ACTIVE', '2': 2},
    {'1': 'BLE_CONNECTION_SECURITY_STATUS_REJECTED', '2': 3},
  ],
};

/// Descriptor for `BleSecureConnectionStatus`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List bleSecureConnectionStatusDescriptor = $convert.base64Decode(
    'ChlCbGVTZWN1cmVDb25uZWN0aW9uU3RhdHVzEicKI0JMRV9DT05ORUNUSU9OX1NFQ1VSSVRZX1'
    'NUQVRVU19OT05FEAASLQopQkxFX0NPTk5FQ1RJT05fU0VDVVJJVFlfU1RBVFVTX0lOUFJPR1JF'
    'U1MQARIpCiVCTEVfQ09OTkVDVElPTl9TRUNVUklUWV9TVEFUVVNfQUNUSVZFEAISKwonQkxFX0'
    'NPTk5FQ1RJT05fU0VDVVJJVFlfU1RBVFVTX1JFSkVDVEVEEAM=');

@$core.Deprecated('Use bleSecureConnectionWindowStatusDescriptor instead')
const BleSecureConnectionWindowStatus$json = {
  '1': 'BleSecureConnectionWindowStatus',
  '2': [
    {'1': 'BLE_SECURE_CONNECTION_WINDOW_STATUS_CLOSED', '2': 0},
    {'1': 'BLE_SECURE_CONNECTION_WINDOW_STATUS_OPEN', '2': 1},
  ],
};

/// Descriptor for `BleSecureConnectionWindowStatus`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List bleSecureConnectionWindowStatusDescriptor = $convert.base64Decode(
    'Ch9CbGVTZWN1cmVDb25uZWN0aW9uV2luZG93U3RhdHVzEi4KKkJMRV9TRUNVUkVfQ09OTkVDVE'
    'lPTl9XSU5ET1dfU1RBVFVTX0NMT1NFRBAAEiwKKEJMRV9TRUNVUkVfQ09OTkVDVElPTl9XSU5E'
    'T1dfU1RBVFVTX09QRU4QAQ==');

@$core.Deprecated('Use trainerEnvSimDescriptor instead')
const TrainerEnvSim$json = {
  '1': 'TrainerEnvSim',
  '2': [
    {'1': 'simulatedWind', '3': 1, '4': 1, '5': 17, '8': {}, '10': 'simulatedWind'},
    {'1': 'simulatedGrade', '3': 2, '4': 1, '5': 17, '8': {}, '10': 'simulatedGrade'},
    {'1': 'simulatedCW', '3': 3, '4': 1, '5': 13, '8': {}, '10': 'simulatedCW'},
    {'1': 'simulatedCRR', '3': 4, '4': 1, '5': 13, '8': {}, '10': 'simulatedCRR'},
  ],
};

/// Descriptor for `TrainerEnvSim`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List trainerEnvSimDescriptor = $convert.base64Decode(
    'Cg1UcmFpbmVyRW52U2ltEisKDXNpbXVsYXRlZFdpbmQYASABKBFCBZI/AjgQUg1zaW11bGF0ZW'
    'RXaW5kEi0KDnNpbXVsYXRlZEdyYWRlGAIgASgRQgWSPwI4EFIOc2ltdWxhdGVkR3JhZGUSJwoL'
    'c2ltdWxhdGVkQ1cYAyABKA1CBZI/AjgQUgtzaW11bGF0ZWRDVxIpCgxzaW11bGF0ZWRDUlIYBC'
    'ABKA1CBZI/AjgQUgxzaW11bGF0ZWRDUlI=');

@$core.Deprecated('Use trainerBikeSimDescriptor instead')
const TrainerBikeSim$json = {
  '1': 'TrainerBikeSim',
  '2': [
    {'1': 'simulatedRealGearRatio', '3': 1, '4': 1, '5': 13, '8': {}, '10': 'simulatedRealGearRatio'},
    {'1': 'simulatedVirtualGearRatio', '3': 2, '4': 1, '5': 13, '8': {}, '10': 'simulatedVirtualGearRatio'},
    {'1': 'simulatedWheelDiameter', '3': 3, '4': 1, '5': 13, '8': {}, '10': 'simulatedWheelDiameter'},
    {'1': 'simulatedBikeMass', '3': 4, '4': 1, '5': 13, '8': {}, '10': 'simulatedBikeMass'},
    {'1': 'simulatedRiderMass', '3': 5, '4': 1, '5': 13, '8': {}, '10': 'simulatedRiderMass'},
    {'1': 'simulatedFrontalArea', '3': 6, '4': 1, '5': 13, '8': {}, '10': 'simulatedFrontalArea'},
    {'1': 'eBrake', '3': 7, '4': 1, '5': 13, '8': {}, '10': 'eBrake'},
  ],
};

/// Descriptor for `TrainerBikeSim`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List trainerBikeSimDescriptor = $convert.base64Decode(
    'Cg5UcmFpbmVyQmlrZVNpbRI9ChZzaW11bGF0ZWRSZWFsR2VhclJhdGlvGAEgASgNQgWSPwI4EF'
    'IWc2ltdWxhdGVkUmVhbEdlYXJSYXRpbxJDChlzaW11bGF0ZWRWaXJ0dWFsR2VhclJhdGlvGAIg'
    'ASgNQgWSPwI4EFIZc2ltdWxhdGVkVmlydHVhbEdlYXJSYXRpbxI9ChZzaW11bGF0ZWRXaGVlbE'
    'RpYW1ldGVyGAMgASgNQgWSPwI4EFIWc2ltdWxhdGVkV2hlZWxEaWFtZXRlchIzChFzaW11bGF0'
    'ZWRCaWtlTWFzcxgEIAEoDUIFkj8COBBSEXNpbXVsYXRlZEJpa2VNYXNzEjUKEnNpbXVsYXRlZF'
    'JpZGVyTWFzcxgFIAEoDUIFkj8COBBSEnNpbXVsYXRlZFJpZGVyTWFzcxI5ChRzaW11bGF0ZWRG'
    'cm9udGFsQXJlYRgGIAEoDUIFkj8COBBSFHNpbXVsYXRlZEZyb250YWxBcmVhEh0KBmVCcmFrZR'
    'gHIAEoDUIFkj8COBBSBmVCcmFrZQ==');

@$core.Deprecated('Use controllerAnalogEventDescriptor instead')
const ControllerAnalogEvent$json = {
  '1': 'ControllerAnalogEvent',
  '2': [
    {'1': 'sensorId', '3': 1, '4': 1, '5': 13, '8': {}, '10': 'sensorId'},
    {'1': 'value', '3': 2, '4': 1, '5': 17, '8': {}, '10': 'value'},
  ],
};

/// Descriptor for `ControllerAnalogEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List controllerAnalogEventDescriptor = $convert.base64Decode(
    'ChVDb250cm9sbGVyQW5hbG9nRXZlbnQSIQoIc2Vuc29ySWQYASABKA1CBZI/AjgIUghzZW5zb3'
    'JJZBIbCgV2YWx1ZRgCIAEoEUIFkj8COBBSBXZhbHVl');

@$core.Deprecated('Use inputAnalogRangeDescriptor instead')
const InputAnalogRange$json = {
  '1': 'InputAnalogRange',
  '2': [
    {'1': 'sensorId', '3': 1, '4': 1, '5': 13, '8': {}, '10': 'sensorId'},
    {'1': 'minAnalogValue', '3': 2, '4': 1, '5': 17, '8': {}, '10': 'minAnalogValue'},
    {'1': 'maxAnalogValue', '3': 3, '4': 1, '5': 17, '8': {}, '10': 'maxAnalogValue'},
  ],
};

/// Descriptor for `InputAnalogRange`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List inputAnalogRangeDescriptor = $convert.base64Decode(
    'ChBJbnB1dEFuYWxvZ1JhbmdlEiEKCHNlbnNvcklkGAEgASgNQgWSPwI4CFIIc2Vuc29ySWQSLQ'
    'oObWluQW5hbG9nVmFsdWUYAiABKBFCBZI/AjgQUg5taW5BbmFsb2dWYWx1ZRItCg5tYXhBbmFs'
    'b2dWYWx1ZRgDIAEoEUIFkj8COBBSDm1heEFuYWxvZ1ZhbHVl');

@$core.Deprecated('Use inputAnalogDeadzoneDescriptor instead')
const InputAnalogDeadzone$json = {
  '1': 'InputAnalogDeadzone',
  '2': [
    {'1': 'sensorId', '3': 1, '4': 1, '5': 13, '8': {}, '10': 'sensorId'},
    {'1': 'negDeadzoneValue', '3': 2, '4': 1, '5': 17, '8': {}, '10': 'negDeadzoneValue'},
    {'1': 'posDeadzoneValue', '3': 3, '4': 1, '5': 17, '8': {}, '10': 'posDeadzoneValue'},
  ],
};

/// Descriptor for `InputAnalogDeadzone`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List inputAnalogDeadzoneDescriptor = $convert.base64Decode(
    'ChNJbnB1dEFuYWxvZ0RlYWR6b25lEiEKCHNlbnNvcklkGAEgASgNQgWSPwI4CFIIc2Vuc29ySW'
    'QSMQoQbmVnRGVhZHpvbmVWYWx1ZRgCIAEoEUIFkj8COBBSEG5lZ0RlYWR6b25lVmFsdWUSMQoQ'
    'cG9zRGVhZHpvbmVWYWx1ZRgDIAEoEUIFkj8COBBSEHBvc0RlYWR6b25lVmFsdWU=');

@$core.Deprecated('Use wifiNetworkDescriptor instead')
const WifiNetwork$json = {
  '1': 'WifiNetwork',
  '2': [
    {'1': 'networkId', '3': 1, '4': 1, '5': 13, '8': {}, '10': 'networkId'},
    {'1': 'ssid', '3': 2, '4': 1, '5': 12, '8': {}, '10': 'ssid'},
    {'1': 'password', '3': 3, '4': 1, '5': 12, '8': {}, '10': 'password'},
  ],
};

/// Descriptor for `WifiNetwork`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List wifiNetworkDescriptor = $convert.base64Decode(
    'CgtXaWZpTmV0d29yaxIjCgluZXR3b3JrSWQYASABKA1CBZI/AjgIUgluZXR3b3JrSWQSGQoEc3'
    'NpZBgCIAEoDEIFkj8CCCBSBHNzaWQSIQoIcGFzc3dvcmQYAyABKAxCBZI/AghAUghwYXNzd29y'
    'ZA==');

@$core.Deprecated('Use wifiRegionCodeDescriptor instead')
const WifiRegionCode$json = {
  '1': 'WifiRegionCode',
  '2': [
    {'1': 'regionCodeType', '3': 1, '4': 1, '5': 14, '6': '.Zp.WifiRegionCode.RegionCodeType', '10': 'regionCodeType'},
    {'1': 'regionCode', '3': 2, '4': 1, '5': 12, '8': {}, '10': 'regionCode'},
  ],
  '4': [WifiRegionCode_RegionCodeType$json],
};

@$core.Deprecated('Use wifiRegionCodeDescriptor instead')
const WifiRegionCode_RegionCodeType$json = {
  '1': 'RegionCodeType',
  '2': [
    {'1': 'ALPHA_2', '2': 0},
    {'1': 'ALPHA_3', '2': 1},
    {'1': 'NUMERIC', '2': 2},
    {'1': 'UNKNOWN', '2': 3},
  ],
};

/// Descriptor for `WifiRegionCode`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List wifiRegionCodeDescriptor = $convert.base64Decode(
    'Cg5XaWZpUmVnaW9uQ29kZRJJCg5yZWdpb25Db2RlVHlwZRgBIAEoDjIhLlpwLldpZmlSZWdpb2'
    '5Db2RlLlJlZ2lvbkNvZGVUeXBlUg5yZWdpb25Db2RlVHlwZRIlCgpyZWdpb25Db2RlGAIgASgM'
    'QgWSPwIIA1IKcmVnaW9uQ29kZSJECg5SZWdpb25Db2RlVHlwZRILCgdBTFBIQV8yEAASCwoHQU'
    'xQSEFfMxABEgsKB05VTUVSSUMQAhILCgdVTktOT1dOEAM=');

@$core.Deprecated('Use wifiNetworkDetailsDescriptor instead')
const WifiNetworkDetails$json = {
  '1': 'WifiNetworkDetails',
  '2': [
    {'1': 'networkId', '3': 1, '4': 1, '5': 13, '8': {}, '10': 'networkId'},
    {'1': 'bssid', '3': 2, '4': 1, '5': 12, '8': {}, '10': 'bssid'},
    {'1': 'ssid', '3': 3, '4': 1, '5': 12, '8': {}, '10': 'ssid'},
    {'1': 'securityType', '3': 4, '4': 1, '5': 13, '8': {}, '10': 'securityType'},
    {'1': 'band', '3': 5, '4': 1, '5': 13, '8': {}, '10': 'band'},
    {'1': 'rssi', '3': 6, '4': 1, '5': 17, '8': {}, '10': 'rssi'},
  ],
};

/// Descriptor for `WifiNetworkDetails`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List wifiNetworkDetailsDescriptor = $convert.base64Decode(
    'ChJXaWZpTmV0d29ya0RldGFpbHMSIwoJbmV0d29ya0lkGAEgASgNQgWSPwI4CFIJbmV0d29ya0'
    'lkEh0KBWJzc2lkGAIgASgMQgeSPwQIBngBUgVic3NpZBIZCgRzc2lkGAMgASgMQgWSPwIIIFIE'
    'c3NpZBIpCgxzZWN1cml0eVR5cGUYBCABKA1CBZI/AjgIUgxzZWN1cml0eVR5cGUSGQoEYmFuZB'
    'gFIAEoDUIFkj8COAhSBGJhbmQSGQoEcnNzaRgGIAEoEUIFkj8COAhSBHJzc2k=');

@$core.Deprecated('Use sensorInfoDescriptor instead')
const SensorInfo$json = {
  '1': 'SensorInfo',
  '2': [
    {'1': 'relayAssignedId', '3': 1, '4': 1, '5': 13, '8': {}, '10': 'relayAssignedId'},
    {'1': 'sensorName', '3': 2, '4': 1, '5': 12, '8': {}, '10': 'sensorName'},
    {'1': 'sensorAddress', '3': 4, '4': 1, '5': 12, '8': {}, '10': 'sensorAddress'},
    {'1': 'interfaceType', '3': 5, '4': 1, '5': 14, '6': '.Zp.InterfaceType', '10': 'interfaceType'},
    {'1': 'connectionStatus', '3': 6, '4': 1, '5': 14, '6': '.Zp.SensorConnectionStatus', '10': 'connectionStatus'},
    {'1': 'deviceTypes', '3': 7, '4': 3, '5': 14, '6': '.Zp.DeviceType', '8': {}, '10': 'deviceTypes'},
    {'1': 'supportsZp', '3': 8, '4': 1, '5': 8, '10': 'supportsZp'},
  ],
  '9': [
    {'1': 3, '2': 4},
  ],
};

/// Descriptor for `SensorInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sensorInfoDescriptor = $convert.base64Decode(
    'CgpTZW5zb3JJbmZvEi8KD3JlbGF5QXNzaWduZWRJZBgBIAEoDUIFkj8COAhSD3JlbGF5QXNzaW'
    'duZWRJZBIlCgpzZW5zb3JOYW1lGAIgASgMQgWSPwIIIFIKc2Vuc29yTmFtZRItCg1zZW5zb3JB'
    'ZGRyZXNzGAQgASgMQgeSPwQIBngBUg1zZW5zb3JBZGRyZXNzEjcKDWludGVyZmFjZVR5cGUYBS'
    'ABKA4yES5acC5JbnRlcmZhY2VUeXBlUg1pbnRlcmZhY2VUeXBlEkYKEGNvbm5lY3Rpb25TdGF0'
    'dXMYBiABKA4yGi5acC5TZW5zb3JDb25uZWN0aW9uU3RhdHVzUhBjb25uZWN0aW9uU3RhdHVzEj'
    'cKC2RldmljZVR5cGVzGAcgAygOMg4uWnAuRGV2aWNlVHlwZUIFkj8CEAhSC2RldmljZVR5cGVz'
    'Eh4KCnN1cHBvcnRzWnAYCCABKAhSCnN1cHBvcnRzWnBKBAgDEAQ=');

@$core.Deprecated('Use sensorInfoListDescriptor instead')
const SensorInfoList$json = {
  '1': 'SensorInfoList',
  '2': [
    {'1': 'sensorInfo', '3': 1, '4': 3, '5': 11, '6': '.Zp.SensorInfo', '8': {}, '10': 'sensorInfo'},
  ],
};

/// Descriptor for `SensorInfoList`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sensorInfoListDescriptor = $convert.base64Decode(
    'Cg5TZW5zb3JJbmZvTGlzdBI1CgpzZW5zb3JJbmZvGAEgAygLMg4uWnAuU2Vuc29ySW5mb0IFkj'
    '8CEA9SCnNlbnNvckluZm8=');

@$core.Deprecated('Use deviceUpdatePageDescriptor instead')
const DeviceUpdatePage$json = {
  '1': 'DeviceUpdatePage',
  '2': [
    {'1': 'updateStatus', '3': 1, '4': 1, '5': 13, '8': {}, '10': 'updateStatus'},
    {'1': 'newVersion', '3': 2, '4': 1, '5': 13, '10': 'newVersion'},
  ],
};

/// Descriptor for `DeviceUpdatePage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deviceUpdatePageDescriptor = $convert.base64Decode(
    'ChBEZXZpY2VVcGRhdGVQYWdlEikKDHVwZGF0ZVN0YXR1cxgBIAEoDUIFkj8COAhSDHVwZGF0ZV'
    'N0YXR1cxIeCgpuZXdWZXJzaW9uGAIgASgNUgpuZXdWZXJzaW9u');

@$core.Deprecated('Use dateTimePageDescriptor instead')
const DateTimePage$json = {
  '1': 'DateTimePage',
  '2': [
    {'1': 'utcDateTime', '3': 1, '4': 1, '5': 13, '10': 'utcDateTime'},
  ],
};

/// Descriptor for `DateTimePage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dateTimePageDescriptor = $convert.base64Decode(
    'CgxEYXRlVGltZVBhZ2USIAoLdXRjRGF0ZVRpbWUYASABKA1SC3V0Y0RhdGVUaW1l');

@$core.Deprecated('Use bleSecurityPageDescriptor instead')
const BleSecurityPage$json = {
  '1': 'BleSecurityPage',
  '2': [
    {'1': 'secureConnectionStatus', '3': 1, '4': 1, '5': 14, '6': '.Zp.BleSecureConnectionStatus', '10': 'secureConnectionStatus'},
    {'1': 'secureConnectionWindowStatus', '3': 2, '4': 1, '5': 14, '6': '.Zp.BleSecureConnectionWindowStatus', '10': 'secureConnectionWindowStatus'},
  ],
};

/// Descriptor for `BleSecurityPage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List bleSecurityPageDescriptor = $convert.base64Decode(
    'Cg9CbGVTZWN1cml0eVBhZ2USVQoWc2VjdXJlQ29ubmVjdGlvblN0YXR1cxgBIAEoDjIdLlpwLk'
    'JsZVNlY3VyZUNvbm5lY3Rpb25TdGF0dXNSFnNlY3VyZUNvbm5lY3Rpb25TdGF0dXMSZwocc2Vj'
    'dXJlQ29ubmVjdGlvbldpbmRvd1N0YXR1cxgCIAEoDjIjLlpwLkJsZVNlY3VyZUNvbm5lY3Rpb2'
    '5XaW5kb3dTdGF0dXNSHHNlY3VyZUNvbm5lY3Rpb25XaW5kb3dTdGF0dXM=');

@$core.Deprecated('Use devInfoPageDescriptor instead')
const DevInfoPage$json = {
  '1': 'DevInfoPage',
  '2': [
    {'1': 'protocolVersion', '3': 1, '4': 1, '5': 13, '8': {}, '10': 'protocolVersion'},
    {'1': 'systemFwVersion', '3': 2, '4': 1, '5': 12, '8': {}, '10': 'systemFwVersion'},
    {'1': 'deviceName', '3': 3, '4': 1, '5': 12, '8': {}, '10': 'deviceName'},
    {'1': 'serialNumber', '3': 6, '4': 1, '5': 12, '8': {}, '10': 'serialNumber'},
    {'1': 'systemHwRevision', '3': 7, '4': 1, '5': 12, '8': {}, '10': 'systemHwRevision'},
    {'1': 'deviceCapabilities', '3': 8, '4': 3, '5': 11, '6': '.Zp.DevInfoPage.DeviceCapabilities', '8': {}, '10': 'deviceCapabilities'},
    {'1': 'manufacturerId', '3': 9, '4': 1, '5': 13, '8': {}, '10': 'manufacturerId'},
    {'1': 'productId', '3': 10, '4': 1, '5': 13, '8': {}, '10': 'productId'},
    {'1': 'deviceUid', '3': 11, '4': 1, '5': 12, '8': {}, '10': 'deviceUid'},
  ],
  '3': [DevInfoPage_DeviceCapabilities$json],
  '9': [
    {'1': 4, '2': 5},
    {'1': 5, '2': 6},
  ],
};

@$core.Deprecated('Use devInfoPageDescriptor instead')
const DevInfoPage_DeviceCapabilities$json = {
  '1': 'DeviceCapabilities',
  '2': [
    {'1': 'deviceType', '3': 1, '4': 2, '5': 13, '8': {}, '10': 'deviceType'},
    {'1': 'capabilities', '3': 2, '4': 2, '5': 13, '10': 'capabilities'},
  ],
};

/// Descriptor for `DevInfoPage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List devInfoPageDescriptor = $convert.base64Decode(
    'CgtEZXZJbmZvUGFnZRIvCg9wcm90b2NvbFZlcnNpb24YASABKA1CBZI/AjgQUg9wcm90b2NvbF'
    'ZlcnNpb24SMQoPc3lzdGVtRndWZXJzaW9uGAIgASgMQgeSPwQIBHgBUg9zeXN0ZW1Gd1ZlcnNp'
    'b24SJQoKZGV2aWNlTmFtZRgDIAEoDEIFkj8CCAxSCmRldmljZU5hbWUSKwoMc2VyaWFsTnVtYm'
    'VyGAYgASgMQgeSPwQID3gBUgxzZXJpYWxOdW1iZXISMQoQc3lzdGVtSHdSZXZpc2lvbhgHIAEo'
    'DEIFkj8CCAVSEHN5c3RlbUh3UmV2aXNpb24SWQoSZGV2aWNlQ2FwYWJpbGl0aWVzGAggAygLMi'
    'IuWnAuRGV2SW5mb1BhZ2UuRGV2aWNlQ2FwYWJpbGl0aWVzQgWSPwIQD1ISZGV2aWNlQ2FwYWJp'
    'bGl0aWVzEi0KDm1hbnVmYWN0dXJlcklkGAkgASgNQgWSPwI4EFIObWFudWZhY3R1cmVySWQSIw'
    'oJcHJvZHVjdElkGAogASgNQgWSPwI4EFIJcHJvZHVjdElkEiUKCWRldmljZVVpZBgLIAEoDEIH'
    'kj8ECAx4AVIJZGV2aWNlVWlkGl8KEkRldmljZUNhcGFiaWxpdGllcxIlCgpkZXZpY2VUeXBlGA'
    'EgAigNQgWSPwI4CFIKZGV2aWNlVHlwZRIiCgxjYXBhYmlsaXRpZXMYAiACKA1SDGNhcGFiaWxp'
    'dGllc0oECAQQBUoECAUQBg==');

@$core.Deprecated('Use clientServerCfgPageDescriptor instead')
const ClientServerCfgPage$json = {
  '1': 'ClientServerCfgPage',
  '2': [
    {'1': 'notifications', '3': 1, '4': 1, '5': 13, '10': 'notifications'},
  ],
};

/// Descriptor for `ClientServerCfgPage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clientServerCfgPageDescriptor = $convert.base64Decode(
    'ChNDbGllbnRTZXJ2ZXJDZmdQYWdlEiQKDW5vdGlmaWNhdGlvbnMYASABKA1SDW5vdGlmaWNhdG'
    'lvbnM=');

@$core.Deprecated('Use trainerSimulationParamDescriptor instead')
const TrainerSimulationParam$json = {
  '1': 'TrainerSimulationParam',
  '2': [
    {'1': 'configuredResistance', '3': 1, '4': 1, '5': 13, '8': {}, '10': 'configuredResistance'},
    {'1': 'ergPower', '3': 2, '4': 1, '5': 13, '8': {}, '10': 'ergPower'},
    {'1': 'averagingWindow', '3': 3, '4': 1, '5': 13, '8': {}, '10': 'averagingWindow'},
    {'1': 'simulatedWind', '3': 4, '4': 1, '5': 17, '8': {}, '10': 'simulatedWind'},
    {'1': 'simulatedGrade', '3': 5, '4': 1, '5': 17, '8': {}, '10': 'simulatedGrade'},
    {'1': 'simulatedRealGearRatio', '3': 6, '4': 1, '5': 13, '8': {}, '10': 'simulatedRealGearRatio'},
    {'1': 'simulatedVirtualGearRatio', '3': 7, '4': 1, '5': 13, '8': {}, '10': 'simulatedVirtualGearRatio'},
    {'1': 'simulatedCW', '3': 8, '4': 1, '5': 13, '8': {}, '10': 'simulatedCW'},
    {'1': 'simulatedWheelDiameter', '3': 9, '4': 1, '5': 13, '8': {}, '10': 'simulatedWheelDiameter'},
    {'1': 'simulatedBikeMass', '3': 10, '4': 1, '5': 13, '8': {}, '10': 'simulatedBikeMass'},
    {'1': 'simulatedRiderMass', '3': 11, '4': 1, '5': 13, '8': {}, '10': 'simulatedRiderMass'},
    {'1': 'simulatedCRR', '3': 12, '4': 1, '5': 13, '8': {}, '10': 'simulatedCRR'},
    {'1': 'simulatedFrontalArea', '3': 13, '4': 1, '5': 13, '8': {}, '10': 'simulatedFrontalArea'},
    {'1': 'simulatedEBrake', '3': 14, '4': 1, '5': 13, '8': {}, '10': 'simulatedEBrake'},
  ],
};

/// Descriptor for `TrainerSimulationParam`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List trainerSimulationParamDescriptor = $convert.base64Decode(
    'ChZUcmFpbmVyU2ltdWxhdGlvblBhcmFtEjkKFGNvbmZpZ3VyZWRSZXNpc3RhbmNlGAEgASgNQg'
    'WSPwI4EFIUY29uZmlndXJlZFJlc2lzdGFuY2USIQoIZXJnUG93ZXIYAiABKA1CBZI/AjgQUghl'
    'cmdQb3dlchIvCg9hdmVyYWdpbmdXaW5kb3cYAyABKA1CBZI/AjgQUg9hdmVyYWdpbmdXaW5kb3'
    'cSKwoNc2ltdWxhdGVkV2luZBgEIAEoEUIFkj8COBBSDXNpbXVsYXRlZFdpbmQSLQoOc2ltdWxh'
    'dGVkR3JhZGUYBSABKBFCBZI/AjgQUg5zaW11bGF0ZWRHcmFkZRI9ChZzaW11bGF0ZWRSZWFsR2'
    'VhclJhdGlvGAYgASgNQgWSPwI4EFIWc2ltdWxhdGVkUmVhbEdlYXJSYXRpbxJDChlzaW11bGF0'
    'ZWRWaXJ0dWFsR2VhclJhdGlvGAcgASgNQgWSPwI4EFIZc2ltdWxhdGVkVmlydHVhbEdlYXJSYX'
    'RpbxInCgtzaW11bGF0ZWRDVxgIIAEoDUIFkj8COBBSC3NpbXVsYXRlZENXEj0KFnNpbXVsYXRl'
    'ZFdoZWVsRGlhbWV0ZXIYCSABKA1CBZI/AjgQUhZzaW11bGF0ZWRXaGVlbERpYW1ldGVyEjMKEX'
    'NpbXVsYXRlZEJpa2VNYXNzGAogASgNQgWSPwI4EFIRc2ltdWxhdGVkQmlrZU1hc3MSNQoSc2lt'
    'dWxhdGVkUmlkZXJNYXNzGAsgASgNQgWSPwI4EFISc2ltdWxhdGVkUmlkZXJNYXNzEikKDHNpbX'
    'VsYXRlZENSUhgMIAEoDUIFkj8COBBSDHNpbXVsYXRlZENSUhI5ChRzaW11bGF0ZWRGcm9udGFs'
    'QXJlYRgNIAEoDUIFkj8COBBSFHNpbXVsYXRlZEZyb250YWxBcmVhEi8KD3NpbXVsYXRlZEVCcm'
    'FrZRgOIAEoDUIFkj8COBBSD3NpbXVsYXRlZEVCcmFrZQ==');

@$core.Deprecated('Use trainerOptionsDescriptor instead')
const TrainerOptions$json = {
  '1': 'TrainerOptions',
  '2': [
    {'1': 'highSpeedDataEnabled', '3': 1, '4': 1, '5': 8, '10': 'highSpeedDataEnabled'},
    {'1': 'ergPowerSmoothingEnabled', '3': 2, '4': 1, '5': 8, '10': 'ergPowerSmoothingEnabled'},
    {'1': 'virtualShiftingMode', '3': 3, '4': 1, '5': 13, '8': {}, '10': 'virtualShiftingMode'},
  ],
};

/// Descriptor for `TrainerOptions`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List trainerOptionsDescriptor = $convert.base64Decode(
    'Cg5UcmFpbmVyT3B0aW9ucxIyChRoaWdoU3BlZWREYXRhRW5hYmxlZBgBIAEoCFIUaGlnaFNwZW'
    'VkRGF0YUVuYWJsZWQSOgoYZXJnUG93ZXJTbW9vdGhpbmdFbmFibGVkGAIgASgIUhhlcmdQb3dl'
    'clNtb290aGluZ0VuYWJsZWQSNwoTdmlydHVhbFNoaWZ0aW5nTW9kZRgDIAEoDUIFkj8COAhSE3'
    'ZpcnR1YWxTaGlmdGluZ01vZGU=');

@$core.Deprecated('Use trainerCfgPageDescriptor instead')
const TrainerCfgPage$json = {
  '1': 'TrainerCfgPage',
  '2': [
    {'1': 'trainerMode', '3': 1, '4': 1, '5': 14, '6': '.Zp.TrainerMode', '10': 'trainerMode'},
    {'1': 'configuredResistance', '3': 2, '4': 1, '5': 13, '8': {}, '10': 'configuredResistance'},
    {'1': 'ergPower', '3': 3, '4': 1, '5': 13, '8': {}, '10': 'ergPower'},
    {'1': 'averagingWindow', '3': 4, '4': 1, '5': 13, '8': {}, '10': 'averagingWindow'},
    {'1': 'simulatedWind', '3': 5, '4': 1, '5': 17, '8': {}, '10': 'simulatedWind'},
    {'1': 'simulatedGrade', '3': 6, '4': 1, '5': 17, '8': {}, '10': 'simulatedGrade'},
    {'1': 'simulatedRealGearRatio', '3': 7, '4': 1, '5': 13, '8': {}, '10': 'simulatedRealGearRatio'},
    {'1': 'simulatedVirtualGearRatio', '3': 8, '4': 1, '5': 13, '8': {}, '10': 'simulatedVirtualGearRatio'},
    {'1': 'simulatedCW', '3': 9, '4': 1, '5': 13, '8': {}, '10': 'simulatedCW'},
    {'1': 'simulatedWheelDiameter', '3': 10, '4': 1, '5': 13, '8': {}, '10': 'simulatedWheelDiameter'},
    {'1': 'simulatedBikeMass', '3': 11, '4': 1, '5': 13, '8': {}, '10': 'simulatedBikeMass'},
    {'1': 'simulatedRiderMass', '3': 12, '4': 1, '5': 13, '8': {}, '10': 'simulatedRiderMass'},
    {'1': 'simulatedCRR', '3': 13, '4': 1, '5': 13, '8': {}, '10': 'simulatedCRR'},
    {'1': 'simulatedFrontalArea', '3': 14, '4': 1, '5': 13, '8': {}, '10': 'simulatedFrontalArea'},
    {'1': 'simulatedEBrake', '3': 15, '4': 1, '5': 13, '8': {}, '10': 'simulatedEBrake'},
    {'1': 'highSpeedDataEnabled', '3': 16, '4': 1, '5': 8, '10': 'highSpeedDataEnabled'},
    {'1': 'ergPowerSmoothingEnabled', '3': 17, '4': 1, '5': 8, '10': 'ergPowerSmoothingEnabled'},
    {'1': 'virtualShiftingMode', '3': 18, '4': 1, '5': 13, '8': {}, '10': 'virtualShiftingMode'},
  ],
};

/// Descriptor for `TrainerCfgPage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List trainerCfgPageDescriptor = $convert.base64Decode(
    'Cg5UcmFpbmVyQ2ZnUGFnZRIxCgt0cmFpbmVyTW9kZRgBIAEoDjIPLlpwLlRyYWluZXJNb2RlUg'
    't0cmFpbmVyTW9kZRI5ChRjb25maWd1cmVkUmVzaXN0YW5jZRgCIAEoDUIFkj8COBBSFGNvbmZp'
    'Z3VyZWRSZXNpc3RhbmNlEiEKCGVyZ1Bvd2VyGAMgASgNQgWSPwI4EFIIZXJnUG93ZXISLwoPYX'
    'ZlcmFnaW5nV2luZG93GAQgASgNQgWSPwI4EFIPYXZlcmFnaW5nV2luZG93EisKDXNpbXVsYXRl'
    'ZFdpbmQYBSABKBFCBZI/AjgQUg1zaW11bGF0ZWRXaW5kEi0KDnNpbXVsYXRlZEdyYWRlGAYgAS'
    'gRQgWSPwI4EFIOc2ltdWxhdGVkR3JhZGUSPQoWc2ltdWxhdGVkUmVhbEdlYXJSYXRpbxgHIAEo'
    'DUIFkj8COBBSFnNpbXVsYXRlZFJlYWxHZWFyUmF0aW8SQwoZc2ltdWxhdGVkVmlydHVhbEdlYX'
    'JSYXRpbxgIIAEoDUIFkj8COBBSGXNpbXVsYXRlZFZpcnR1YWxHZWFyUmF0aW8SJwoLc2ltdWxh'
    'dGVkQ1cYCSABKA1CBZI/AjgQUgtzaW11bGF0ZWRDVxI9ChZzaW11bGF0ZWRXaGVlbERpYW1ldG'
    'VyGAogASgNQgWSPwI4EFIWc2ltdWxhdGVkV2hlZWxEaWFtZXRlchIzChFzaW11bGF0ZWRCaWtl'
    'TWFzcxgLIAEoDUIFkj8COBBSEXNpbXVsYXRlZEJpa2VNYXNzEjUKEnNpbXVsYXRlZFJpZGVyTW'
    'FzcxgMIAEoDUIFkj8COBBSEnNpbXVsYXRlZFJpZGVyTWFzcxIpCgxzaW11bGF0ZWRDUlIYDSAB'
    'KA1CBZI/AjgQUgxzaW11bGF0ZWRDUlISOQoUc2ltdWxhdGVkRnJvbnRhbEFyZWEYDiABKA1CBZ'
    'I/AjgQUhRzaW11bGF0ZWRGcm9udGFsQXJlYRIvCg9zaW11bGF0ZWRFQnJha2UYDyABKA1CBZI/'
    'AjgQUg9zaW11bGF0ZWRFQnJha2USMgoUaGlnaFNwZWVkRGF0YUVuYWJsZWQYECABKAhSFGhpZ2'
    'hTcGVlZERhdGFFbmFibGVkEjoKGGVyZ1Bvd2VyU21vb3RoaW5nRW5hYmxlZBgRIAEoCFIYZXJn'
    'UG93ZXJTbW9vdGhpbmdFbmFibGVkEjcKE3ZpcnR1YWxTaGlmdGluZ01vZGUYEiABKA1CBZI/Aj'
    'gIUhN2aXJ0dWFsU2hpZnRpbmdNb2Rl');

@$core.Deprecated('Use trainerGearIndexConfigPageDescriptor instead')
const TrainerGearIndexConfigPage$json = {
  '1': 'TrainerGearIndexConfigPage',
  '2': [
    {'1': 'frontGearIdx', '3': 1, '4': 1, '5': 13, '8': {}, '10': 'frontGearIdx'},
    {'1': 'frontGearIdxMax', '3': 2, '4': 1, '5': 13, '8': {}, '10': 'frontGearIdxMax'},
    {'1': 'frontGearIdxMin', '3': 3, '4': 1, '5': 13, '8': {}, '10': 'frontGearIdxMin'},
    {'1': 'rearGearIdx', '3': 4, '4': 1, '5': 13, '8': {}, '10': 'rearGearIdx'},
    {'1': 'rearGearIdxMax', '3': 5, '4': 1, '5': 13, '8': {}, '10': 'rearGearIdxMax'},
    {'1': 'rearGearIdxMin', '3': 6, '4': 1, '5': 13, '8': {}, '10': 'rearGearIdxMin'},
  ],
};

/// Descriptor for `TrainerGearIndexConfigPage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List trainerGearIndexConfigPageDescriptor = $convert.base64Decode(
    'ChpUcmFpbmVyR2VhckluZGV4Q29uZmlnUGFnZRIpCgxmcm9udEdlYXJJZHgYASABKA1CBZI/Aj'
    'gIUgxmcm9udEdlYXJJZHgSLwoPZnJvbnRHZWFySWR4TWF4GAIgASgNQgWSPwI4CFIPZnJvbnRH'
    'ZWFySWR4TWF4Ei8KD2Zyb250R2VhcklkeE1pbhgDIAEoDUIFkj8COAhSD2Zyb250R2VhcklkeE'
    '1pbhInCgtyZWFyR2VhcklkeBgEIAEoDUIFkj8COAhSC3JlYXJHZWFySWR4Ei0KDnJlYXJHZWFy'
    'SWR4TWF4GAUgASgNQgWSPwI4CFIOcmVhckdlYXJJZHhNYXgSLQoOcmVhckdlYXJJZHhNaW4YBi'
    'ABKA1CBZI/AjgIUg5yZWFyR2VhcklkeE1pbg==');

@$core.Deprecated('Use deviceTiltConfigPageDescriptor instead')
const DeviceTiltConfigPage$json = {
  '1': 'DeviceTiltConfigPage',
  '2': [
    {'1': 'tiltEnabled', '3': 1, '4': 1, '5': 8, '10': 'tiltEnabled'},
    {'1': 'tiltGradientMin', '3': 2, '4': 1, '5': 17, '8': {}, '10': 'tiltGradientMin'},
    {'1': 'tiltGradientMax', '3': 3, '4': 1, '5': 17, '8': {}, '10': 'tiltGradientMax'},
    {'1': 'tiltGradient', '3': 4, '4': 1, '5': 17, '8': {}, '10': 'tiltGradient'},
  ],
};

/// Descriptor for `DeviceTiltConfigPage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deviceTiltConfigPageDescriptor = $convert.base64Decode(
    'ChREZXZpY2VUaWx0Q29uZmlnUGFnZRIgCgt0aWx0RW5hYmxlZBgBIAEoCFILdGlsdEVuYWJsZW'
    'QSLwoPdGlsdEdyYWRpZW50TWluGAIgASgRQgWSPwI4EFIPdGlsdEdyYWRpZW50TWluEi8KD3Rp'
    'bHRHcmFkaWVudE1heBgDIAEoEUIFkj8COBBSD3RpbHRHcmFkaWVudE1heBIpCgx0aWx0R3JhZG'
    'llbnQYBCABKBFCBZI/AjgQUgx0aWx0R3JhZGllbnQ=');

@$core.Deprecated('Use controllerInputConfigPageDescriptor instead')
const ControllerInputConfigPage$json = {
  '1': 'ControllerInputConfigPage',
  '2': [
    {'1': 'supportedDigitalInputs', '3': 1, '4': 1, '5': 13, '10': 'supportedDigitalInputs'},
    {'1': 'supportedAnalogInputs', '3': 2, '4': 1, '5': 13, '8': {}, '10': 'supportedAnalogInputs'},
    {'1': 'analogInputRange', '3': 3, '4': 3, '5': 11, '6': '.Zp.InputAnalogRange', '8': {}, '10': 'analogInputRange'},
    {'1': 'analogDeadZone', '3': 4, '4': 3, '5': 11, '6': '.Zp.InputAnalogDeadzone', '8': {}, '10': 'analogDeadZone'},
  ],
};

/// Descriptor for `ControllerInputConfigPage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List controllerInputConfigPageDescriptor = $convert.base64Decode(
    'ChlDb250cm9sbGVySW5wdXRDb25maWdQYWdlEjYKFnN1cHBvcnRlZERpZ2l0YWxJbnB1dHMYAS'
    'ABKA1SFnN1cHBvcnRlZERpZ2l0YWxJbnB1dHMSOwoVc3VwcG9ydGVkQW5hbG9nSW5wdXRzGAIg'
    'ASgNQgWSPwI4EFIVc3VwcG9ydGVkQW5hbG9nSW5wdXRzEkcKEGFuYWxvZ0lucHV0UmFuZ2UYAy'
    'ADKAsyFC5acC5JbnB1dEFuYWxvZ1JhbmdlQgWSPwIQCFIQYW5hbG9nSW5wdXRSYW5nZRJGCg5h'
    'bmFsb2dEZWFkWm9uZRgEIAMoCzIXLlpwLklucHV0QW5hbG9nRGVhZHpvbmVCBZI/AhAIUg5hbm'
    'Fsb2dEZWFkWm9uZQ==');

@$core.Deprecated('Use ipTransportPageDescriptor instead')
const IpTransportPage$json = {
  '1': 'IpTransportPage',
  '2': [
    {'1': 'ipv4Address', '3': 1, '4': 1, '5': 13, '10': 'ipv4Address'},
    {'1': 'tcpPort', '3': 2, '4': 1, '5': 13, '8': {}, '10': 'tcpPort'},
  ],
};

/// Descriptor for `IpTransportPage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List ipTransportPageDescriptor = $convert.base64Decode(
    'Cg9JcFRyYW5zcG9ydFBhZ2USIAoLaXB2NEFkZHJlc3MYASABKA1SC2lwdjRBZGRyZXNzEh8KB3'
    'RjcFBvcnQYAiABKA1CBZI/AjgQUgd0Y3BQb3J0');

@$core.Deprecated('Use wifiConfigurationPageDescriptor instead')
const WifiConfigurationPage$json = {
  '1': 'WifiConfigurationPage',
  '2': [
    {'1': 'wifiEnabled', '3': 1, '4': 1, '5': 8, '10': 'wifiEnabled'},
    {'1': 'wifiStatus', '3': 2, '4': 1, '5': 13, '8': {}, '10': 'wifiStatus'},
    {'1': 'wifiSsid', '3': 3, '4': 1, '5': 12, '8': {}, '10': 'wifiSsid'},
    {'1': 'wifiBand', '3': 4, '4': 1, '5': 13, '8': {}, '10': 'wifiBand'},
    {'1': 'wifiRssi', '3': 5, '4': 1, '5': 17, '8': {}, '10': 'wifiRssi'},
    {'1': 'wifiRegionCode', '3': 6, '4': 1, '5': 12, '8': {}, '10': 'wifiRegionCode'},
  ],
};

/// Descriptor for `WifiConfigurationPage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List wifiConfigurationPageDescriptor = $convert.base64Decode(
    'ChVXaWZpQ29uZmlndXJhdGlvblBhZ2USIAoLd2lmaUVuYWJsZWQYASABKAhSC3dpZmlFbmFibG'
    'VkEiUKCndpZmlTdGF0dXMYAiABKA1CBZI/AjgIUgp3aWZpU3RhdHVzEiEKCHdpZmlTc2lkGAMg'
    'ASgMQgWSPwIIIFIId2lmaVNzaWQSIQoId2lmaUJhbmQYBCABKA1CBZI/AjgIUgh3aWZpQmFuZB'
    'IhCgh3aWZpUnNzaRgFIAEoEUIFkj8COAhSCHdpZmlSc3NpEi0KDndpZmlSZWdpb25Db2RlGAYg'
    'ASgMQgWSPwIIA1IOd2lmaVJlZ2lvbkNvZGU=');

@$core.Deprecated('Use sensorRelayDataPageDescriptor instead')
const SensorRelayDataPage$json = {
  '1': 'SensorRelayDataPage',
  '2': [
    {'1': 'supportedSensors', '3': 1, '4': 3, '5': 13, '8': {}, '10': 'supportedSensors'},
    {'1': 'pairedSensors', '3': 2, '4': 3, '5': 13, '8': {}, '10': 'pairedSensors'},
  ],
};

/// Descriptor for `SensorRelayDataPage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sensorRelayDataPageDescriptor = $convert.base64Decode(
    'ChNTZW5zb3JSZWxheURhdGFQYWdlEjMKEHN1cHBvcnRlZFNlbnNvcnMYASADKA1CB5I/BBAPOA'
    'hSEHN1cHBvcnRlZFNlbnNvcnMSLQoNcGFpcmVkU2Vuc29ycxgCIAMoDUIHkj8EEA84CFINcGFp'
    'cmVkU2Vuc29ycw==');

@$core.Deprecated('Use getDescriptor instead')
const Get$json = {
  '1': 'Get',
  '2': [
    {'1': 'dataObjectId', '3': 1, '4': 2, '5': 13, '8': {}, '10': 'dataObjectId'},
  ],
};

/// Descriptor for `Get`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getDescriptor = $convert.base64Decode(
    'CgNHZXQSKQoMZGF0YU9iamVjdElkGAEgAigNQgWSPwI4EFIMZGF0YU9iamVjdElk');

@$core.Deprecated('Use devInfoDescriptor instead')
const DevInfo$json = {
  '1': 'DevInfo',
  '2': [
    {'1': 'devInfo', '3': 1, '4': 2, '5': 11, '6': '.Zp.DevInfoPage', '10': 'devInfo'},
  ],
};

/// Descriptor for `DevInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List devInfoDescriptor = $convert.base64Decode(
    'CgdEZXZJbmZvEikKB2RldkluZm8YASACKAsyDy5acC5EZXZJbmZvUGFnZVIHZGV2SW5mbw==');

@$core.Deprecated('Use bleSecurityRequestDescriptor instead')
const BleSecurityRequest$json = {
  '1': 'BleSecurityRequest',
  '2': [
    {'1': 'startSecureConnection', '3': 1, '4': 1, '5': 8, '9': 0, '10': 'startSecureConnection'},
  ],
  '8': [
    {'1': 'request'},
  ],
};

/// Descriptor for `BleSecurityRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List bleSecurityRequestDescriptor = $convert.base64Decode(
    'ChJCbGVTZWN1cml0eVJlcXVlc3QSNgoVc3RhcnRTZWN1cmVDb25uZWN0aW9uGAEgASgISABSFX'
    'N0YXJ0U2VjdXJlQ29ubmVjdGlvbkIJCgdyZXF1ZXN0');

@$core.Deprecated('Use trainerNotificationDescriptor instead')
const TrainerNotification$json = {
  '1': 'TrainerNotification',
  '2': [
    {'1': 'power', '3': 1, '4': 2, '5': 13, '8': {}, '10': 'power'},
    {'1': 'cadence', '3': 2, '4': 2, '5': 13, '8': {}, '10': 'cadence'},
    {'1': 'bikeSpeed', '3': 3, '4': 2, '5': 13, '8': {}, '10': 'bikeSpeed'},
    {'1': 'averagedPower', '3': 4, '4': 2, '5': 13, '8': {}, '10': 'averagedPower'},
    {'1': 'wheelSpeed', '3': 5, '4': 2, '5': 13, '8': {}, '10': 'wheelSpeed'},
    {'1': 'calculatedRealGearRatio', '3': 6, '4': 1, '5': 13, '8': {}, '10': 'calculatedRealGearRatio'},
  ],
};

/// Descriptor for `TrainerNotification`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List trainerNotificationDescriptor = $convert.base64Decode(
    'ChNUcmFpbmVyTm90aWZpY2F0aW9uEhsKBXBvd2VyGAEgAigNQgWSPwI4EFIFcG93ZXISHwoHY2'
    'FkZW5jZRgCIAIoDUIFkj8COBBSB2NhZGVuY2USIwoJYmlrZVNwZWVkGAMgAigNQgWSPwI4EFIJ'
    'YmlrZVNwZWVkEisKDWF2ZXJhZ2VkUG93ZXIYBCACKA1CBZI/AjgQUg1hdmVyYWdlZFBvd2VyEi'
    'UKCndoZWVsU3BlZWQYBSACKA1CBZI/AjgQUgp3aGVlbFNwZWVkEj8KF2NhbGN1bGF0ZWRSZWFs'
    'R2VhclJhdGlvGAYgASgNQgWSPwI4EFIXY2FsY3VsYXRlZFJlYWxHZWFyUmF0aW8=');

@$core.Deprecated('Use trainerConfigSetDescriptor instead')
const TrainerConfigSet$json = {
  '1': 'TrainerConfigSet',
  '2': [
    {'1': 'configuredResistance', '3': 2, '4': 1, '5': 13, '8': {}, '9': 0, '10': 'configuredResistance'},
    {'1': 'ergPower', '3': 3, '4': 1, '5': 13, '8': {}, '9': 0, '10': 'ergPower'},
    {'1': 'envSim', '3': 4, '4': 1, '5': 11, '6': '.Zp.TrainerEnvSim', '9': 0, '10': 'envSim'},
    {'1': 'bikeSim', '3': 5, '4': 1, '5': 11, '6': '.Zp.TrainerBikeSim', '9': 0, '10': 'bikeSim'},
    {'1': 'averagingWindow', '3': 6, '4': 1, '5': 13, '8': {}, '9': 0, '10': 'averagingWindow'},
    {'1': 'trainerOptions', '3': 7, '4': 1, '5': 11, '6': '.Zp.TrainerOptions', '9': 0, '10': 'trainerOptions'},
  ],
  '8': [
    {'1': 'config'},
  ],
  '9': [
    {'1': 1, '2': 2},
  ],
};

/// Descriptor for `TrainerConfigSet`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List trainerConfigSetDescriptor = $convert.base64Decode(
    'ChBUcmFpbmVyQ29uZmlnU2V0EjsKFGNvbmZpZ3VyZWRSZXNpc3RhbmNlGAIgASgNQgWSPwI4EE'
    'gAUhRjb25maWd1cmVkUmVzaXN0YW5jZRIjCghlcmdQb3dlchgDIAEoDUIFkj8COBBIAFIIZXJn'
    'UG93ZXISKwoGZW52U2ltGAQgASgLMhEuWnAuVHJhaW5lckVudlNpbUgAUgZlbnZTaW0SLgoHYm'
    'lrZVNpbRgFIAEoCzISLlpwLlRyYWluZXJCaWtlU2ltSABSB2Jpa2VTaW0SMQoPYXZlcmFnaW5n'
    'V2luZG93GAYgASgNQgWSPwI4EEgAUg9hdmVyYWdpbmdXaW5kb3cSPAoOdHJhaW5lck9wdGlvbn'
    'MYByABKAsyEi5acC5UcmFpbmVyT3B0aW9uc0gAUg50cmFpbmVyT3B0aW9uc0IICgZjb25maWdK'
    'BAgBEAI=');

@$core.Deprecated('Use trainerConfigStatusDescriptor instead')
const TrainerConfigStatus$json = {
  '1': 'TrainerConfigStatus',
  '2': [
    {'1': 'trainerCfg', '3': 1, '4': 2, '5': 11, '6': '.Zp.TrainerCfgPage', '10': 'trainerCfg'},
  ],
};

/// Descriptor for `TrainerConfigStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List trainerConfigStatusDescriptor = $convert.base64Decode(
    'ChNUcmFpbmVyQ29uZmlnU3RhdHVzEjIKCnRyYWluZXJDZmcYASACKAsyEi5acC5UcmFpbmVyQ2'
    'ZnUGFnZVIKdHJhaW5lckNmZw==');

@$core.Deprecated('Use devInfoSetDescriptor instead')
const DevInfoSet$json = {
  '1': 'DevInfoSet',
  '2': [
    {'1': 'deviceName', '3': 1, '4': 1, '5': 12, '8': {}, '9': 0, '10': 'deviceName'},
  ],
  '8': [
    {'1': 'devInfo'},
  ],
};

/// Descriptor for `DevInfoSet`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List devInfoSetDescriptor = $convert.base64Decode(
    'CgpEZXZJbmZvU2V0EicKCmRldmljZU5hbWUYASABKAxCBZI/AggMSABSCmRldmljZU5hbWVCCQ'
    'oHZGV2SW5mbw==');

@$core.Deprecated('Use resetDescriptor instead')
const Reset$json = {
  '1': 'Reset',
  '2': [
    {'1': 'resetProcedure', '3': 1, '4': 1, '5': 13, '8': {}, '10': 'resetProcedure'},
  ],
};

/// Descriptor for `Reset`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List resetDescriptor = $convert.base64Decode(
    'CgVSZXNldBItCg5yZXNldFByb2NlZHVyZRgBIAEoDUIFkj8COAhSDnJlc2V0UHJvY2VkdXJl');

@$core.Deprecated('Use batteryNotificationDescriptor instead')
const BatteryNotification$json = {
  '1': 'BatteryNotification',
  '2': [
    {'1': 'newChgState', '3': 1, '4': 1, '5': 14, '6': '.Zp.ChargingState', '9': 0, '10': 'newChgState'},
    {'1': 'newPercLevel', '3': 2, '4': 1, '5': 13, '8': {}, '9': 0, '10': 'newPercLevel'},
    {'1': 'source', '3': 3, '4': 1, '5': 13, '8': {}, '10': 'source'},
  ],
  '8': [
    {'1': 'alert'},
  ],
};

/// Descriptor for `BatteryNotification`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List batteryNotificationDescriptor = $convert.base64Decode(
    'ChNCYXR0ZXJ5Tm90aWZpY2F0aW9uEjUKC25ld0NoZ1N0YXRlGAEgASgOMhEuWnAuQ2hhcmdpbm'
    'dTdGF0ZUgAUgtuZXdDaGdTdGF0ZRIrCgxuZXdQZXJjTGV2ZWwYAiABKA1CBZI/AjgISABSDG5l'
    'd1BlcmNMZXZlbBIdCgZzb3VyY2UYAyABKA1CBZI/AjgIUgZzb3VyY2VCBwoFYWxlcnQ=');

@$core.Deprecated('Use batteryStatusDescriptor instead')
const BatteryStatus$json = {
  '1': 'BatteryStatus',
  '2': [
    {'1': 'chgState', '3': 1, '4': 2, '5': 14, '6': '.Zp.ChargingState', '10': 'chgState'},
    {'1': 'percLevel', '3': 2, '4': 2, '5': 13, '8': {}, '10': 'percLevel'},
    {'1': 'timeToEmpty', '3': 3, '4': 2, '5': 13, '8': {}, '10': 'timeToEmpty'},
    {'1': 'timeToFull', '3': 4, '4': 2, '5': 13, '8': {}, '10': 'timeToFull'},
  ],
};

/// Descriptor for `BatteryStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List batteryStatusDescriptor = $convert.base64Decode(
    'Cg1CYXR0ZXJ5U3RhdHVzEi0KCGNoZ1N0YXRlGAEgAigOMhEuWnAuQ2hhcmdpbmdTdGF0ZVIIY2'
    'hnU3RhdGUSIwoJcGVyY0xldmVsGAIgAigNQgWSPwI4CFIJcGVyY0xldmVsEicKC3RpbWVUb0Vt'
    'cHR5GAMgAigNQgWSPwI4EFILdGltZVRvRW1wdHkSJQoKdGltZVRvRnVsbBgEIAIoDUIFkj8COB'
    'BSCnRpbWVUb0Z1bGw=');

@$core.Deprecated('Use controllerNotificationDescriptor instead')
const ControllerNotification$json = {
  '1': 'ControllerNotification',
  '2': [
    {'1': 'buttonEvent', '3': 1, '4': 1, '5': 13, '10': 'buttonEvent'},
    {'1': 'analogEventList', '3': 3, '4': 3, '5': 11, '6': '.Zp.ControllerAnalogEvent', '8': {}, '10': 'analogEventList'},
  ],
  '9': [
    {'1': 2, '2': 3},
  ],
};

/// Descriptor for `ControllerNotification`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List controllerNotificationDescriptor = $convert.base64Decode(
    'ChZDb250cm9sbGVyTm90aWZpY2F0aW9uEiAKC2J1dHRvbkV2ZW50GAEgASgNUgtidXR0b25Fdm'
    'VudBJKCg9hbmFsb2dFdmVudExpc3QYAyADKAsyGS5acC5Db250cm9sbGVyQW5hbG9nRXZlbnRC'
    'BZI/AhAIUg9hbmFsb2dFdmVudExpc3RKBAgCEAM=');

@$core.Deprecated('Use logDataNotificationDescriptor instead')
const LogDataNotification$json = {
  '1': 'LogDataNotification',
  '2': [
    {'1': 'logLevel', '3': 1, '4': 2, '5': 14, '6': '.Zp.LogLevel', '10': 'logLevel'},
    {'1': 'dataLogObject', '3': 2, '4': 2, '5': 11, '6': '.Zp.LogDataNotification.DataLogObject', '10': 'dataLogObject'},
  ],
  '3': [LogDataNotification_ConnectionParameters$json, LogDataNotification_EnergySurveySummary$json, LogDataNotification_DataLogObject$json],
};

@$core.Deprecated('Use logDataNotificationDescriptor instead')
const LogDataNotification_ConnectionParameters$json = {
  '1': 'ConnectionParameters',
  '2': [
    {'1': 'interval', '3': 1, '4': 2, '5': 13, '8': {}, '10': 'interval'},
    {'1': 'latency', '3': 2, '4': 2, '5': 13, '8': {}, '10': 'latency'},
    {'1': 'supervisorTimeout', '3': 3, '4': 2, '5': 13, '8': {}, '10': 'supervisorTimeout'},
    {'1': 'bleChannelMap', '3': 4, '4': 2, '5': 12, '8': {}, '10': 'bleChannelMap'},
    {'1': 'mtuSize', '3': 5, '4': 1, '5': 13, '8': {}, '10': 'mtuSize'},
  ],
};

@$core.Deprecated('Use logDataNotificationDescriptor instead')
const LogDataNotification_EnergySurveySummary$json = {
  '1': 'EnergySurveySummary',
  '2': [
    {'1': 'samples', '3': 1, '4': 2, '5': 13, '8': {}, '10': 'samples'},
    {'1': 'averageEnergy', '3': 2, '4': 2, '5': 12, '8': {}, '10': 'averageEnergy'},
  ],
};

@$core.Deprecated('Use logDataNotificationDescriptor instead')
const LogDataNotification_DataLogObject$json = {
  '1': 'DataLogObject',
  '2': [
    {'1': 'logData', '3': 1, '4': 1, '5': 12, '8': {}, '9': 0, '10': 'logData'},
    {'1': 'connectionParam', '3': 2, '4': 1, '5': 11, '6': '.Zp.LogDataNotification.ConnectionParameters', '9': 0, '10': 'connectionParam'},
    {'1': 'energySurvey', '3': 3, '4': 1, '5': 11, '6': '.Zp.LogDataNotification.EnergySurveySummary', '9': 0, '10': 'energySurvey'},
    {'1': 'logString', '3': 4, '4': 1, '5': 12, '8': {}, '9': 0, '10': 'logString'},
  ],
  '8': [
    {'1': 'event'},
  ],
};

/// Descriptor for `LogDataNotification`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List logDataNotificationDescriptor = $convert.base64Decode(
    'ChNMb2dEYXRhTm90aWZpY2F0aW9uEigKCGxvZ0xldmVsGAEgAigOMgwuWnAuTG9nTGV2ZWxSCG'
    'xvZ0xldmVsEksKDWRhdGFMb2dPYmplY3QYAiACKAsyJS5acC5Mb2dEYXRhTm90aWZpY2F0aW9u'
    'LkRhdGFMb2dPYmplY3RSDWRhdGFMb2dPYmplY3Qa3wEKFENvbm5lY3Rpb25QYXJhbWV0ZXJzEi'
    'EKCGludGVydmFsGAEgAigNQgWSPwI4EFIIaW50ZXJ2YWwSHwoHbGF0ZW5jeRgCIAIoDUIFkj8C'
    'OBBSB2xhdGVuY3kSMwoRc3VwZXJ2aXNvclRpbWVvdXQYAyACKA1CBZI/AjgQUhFzdXBlcnZpc2'
    '9yVGltZW91dBItCg1ibGVDaGFubmVsTWFwGAQgAigMQgeSPwQIBXgBUg1ibGVDaGFubmVsTWFw'
    'Eh8KB210dVNpemUYBSABKA1CBZI/AjgQUgdtdHVTaXplGmUKE0VuZXJneVN1cnZleVN1bW1hcn'
    'kSHwoHc2FtcGxlcxgBIAIoDUIFkj8COBBSB3NhbXBsZXMSLQoNYXZlcmFnZUVuZXJneRgCIAIo'
    'DEIHkj8ECCh4AVINYXZlcmFnZUVuZXJneRqRAgoNRGF0YUxvZ09iamVjdBIiCgdsb2dEYXRhGA'
    'EgASgMQgaSPwMIgAFIAFIHbG9nRGF0YRJYCg9jb25uZWN0aW9uUGFyYW0YAiABKAsyLC5acC5M'
    'b2dEYXRhTm90aWZpY2F0aW9uLkNvbm5lY3Rpb25QYXJhbWV0ZXJzSABSD2Nvbm5lY3Rpb25QYX'
    'JhbRJRCgxlbmVyZ3lTdXJ2ZXkYAyABKAsyKy5acC5Mb2dEYXRhTm90aWZpY2F0aW9uLkVuZXJn'
    'eVN1cnZleVN1bW1hcnlIAFIMZW5lcmd5U3VydmV5EiYKCWxvZ1N0cmluZxgEIAEoDEIGkj8DCO'
    '0BSABSCWxvZ1N0cmluZ0IHCgVldmVudA==');

@$core.Deprecated('Use spindownRequestDescriptor instead')
const SpindownRequest$json = {
  '1': 'SpindownRequest',
  '2': [
    {'1': 'startSpindown', '3': 1, '4': 1, '5': 11, '6': '.Zp.SpindownRequest.StartSpindown', '9': 0, '10': 'startSpindown'},
    {'1': 'ignoreSpindown', '3': 2, '4': 1, '5': 11, '6': '.Zp.SpindownRequest.IgnoreSpindown', '9': 0, '10': 'ignoreSpindown'},
  ],
  '3': [SpindownRequest_StartSpindown$json, SpindownRequest_IgnoreSpindown$json],
  '8': [
    {'1': 'request'},
  ],
};

@$core.Deprecated('Use spindownRequestDescriptor instead')
const SpindownRequest_StartSpindown$json = {
  '1': 'StartSpindown',
  '2': [
    {'1': 'enable', '3': 1, '4': 2, '5': 8, '10': 'enable'},
  ],
};

@$core.Deprecated('Use spindownRequestDescriptor instead')
const SpindownRequest_IgnoreSpindown$json = {
  '1': 'IgnoreSpindown',
  '2': [
    {'1': 'enable', '3': 1, '4': 2, '5': 8, '10': 'enable'},
  ],
};

/// Descriptor for `SpindownRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List spindownRequestDescriptor = $convert.base64Decode(
    'Cg9TcGluZG93blJlcXVlc3QSSQoNc3RhcnRTcGluZG93bhgBIAEoCzIhLlpwLlNwaW5kb3duUm'
    'VxdWVzdC5TdGFydFNwaW5kb3duSABSDXN0YXJ0U3BpbmRvd24STAoOaWdub3JlU3BpbmRvd24Y'
    'AiABKAsyIi5acC5TcGluZG93blJlcXVlc3QuSWdub3JlU3BpbmRvd25IAFIOaWdub3JlU3Bpbm'
    'Rvd24aJwoNU3RhcnRTcGluZG93bhIWCgZlbmFibGUYASACKAhSBmVuYWJsZRooCg5JZ25vcmVT'
    'cGluZG93bhIWCgZlbmFibGUYASACKAhSBmVuYWJsZUIJCgdyZXF1ZXN0');

@$core.Deprecated('Use spindownNotificationDescriptor instead')
const SpindownNotification$json = {
  '1': 'SpindownNotification',
  '2': [
    {'1': 'manualSpindownStatus', '3': 1, '4': 1, '5': 11, '6': '.Zp.SpindownNotification.ManualSpindownStatus', '9': 0, '10': 'manualSpindownStatus'},
    {'1': 'autoSpindownStatus', '3': 2, '4': 1, '5': 11, '6': '.Zp.SpindownNotification.AutoSpindownStatus', '9': 0, '10': 'autoSpindownStatus'},
  ],
  '3': [SpindownNotification_ManualSpindownStatus$json, SpindownNotification_AutoSpindownStatus$json],
  '8': [
    {'1': 'event'},
  ],
};

@$core.Deprecated('Use spindownNotificationDescriptor instead')
const SpindownNotification_ManualSpindownStatus$json = {
  '1': 'ManualSpindownStatus',
  '2': [
    {'1': 'spindownStatus', '3': 1, '4': 2, '5': 14, '6': '.Zp.SpindownStatus', '10': 'spindownStatus'},
    {'1': 'targetSpeedLow', '3': 2, '4': 1, '5': 13, '8': {}, '10': 'targetSpeedLow'},
    {'1': 'targetSpeedHigh', '3': 3, '4': 1, '5': 13, '8': {}, '10': 'targetSpeedHigh'},
  ],
};

@$core.Deprecated('Use spindownNotificationDescriptor instead')
const SpindownNotification_AutoSpindownStatus$json = {
  '1': 'AutoSpindownStatus',
  '2': [
    {'1': 'completed', '3': 1, '4': 2, '5': 8, '10': 'completed'},
  ],
};

/// Descriptor for `SpindownNotification`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List spindownNotificationDescriptor = $convert.base64Decode(
    'ChRTcGluZG93bk5vdGlmaWNhdGlvbhJjChRtYW51YWxTcGluZG93blN0YXR1cxgBIAEoCzItLl'
    'pwLlNwaW5kb3duTm90aWZpY2F0aW9uLk1hbnVhbFNwaW5kb3duU3RhdHVzSABSFG1hbnVhbFNw'
    'aW5kb3duU3RhdHVzEl0KEmF1dG9TcGluZG93blN0YXR1cxgCIAEoCzIrLlpwLlNwaW5kb3duTm'
    '90aWZpY2F0aW9uLkF1dG9TcGluZG93blN0YXR1c0gAUhJhdXRvU3BpbmRvd25TdGF0dXMasgEK'
    'FE1hbnVhbFNwaW5kb3duU3RhdHVzEjoKDnNwaW5kb3duU3RhdHVzGAEgAigOMhIuWnAuU3Bpbm'
    'Rvd25TdGF0dXNSDnNwaW5kb3duU3RhdHVzEi0KDnRhcmdldFNwZWVkTG93GAIgASgNQgWSPwI4'
    'EFIOdGFyZ2V0U3BlZWRMb3cSLwoPdGFyZ2V0U3BlZWRIaWdoGAMgASgNQgWSPwI4EFIPdGFyZ2'
    'V0U3BlZWRIaWdoGjIKEkF1dG9TcGluZG93blN0YXR1cxIcCgljb21wbGV0ZWQYASACKAhSCWNv'
    'bXBsZXRlZEIHCgVldmVudA==');

@$core.Deprecated('Use getResponseDescriptor instead')
const GetResponse$json = {
  '1': 'GetResponse',
  '2': [
    {'1': 'dataObjectId', '3': 1, '4': 2, '5': 13, '8': {}, '10': 'dataObjectId'},
    {'1': 'dataObjectData', '3': 2, '4': 1, '5': 12, '8': {}, '10': 'dataObjectData'},
  ],
};

/// Descriptor for `GetResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getResponseDescriptor = $convert.base64Decode(
    'CgtHZXRSZXNwb25zZRIpCgxkYXRhT2JqZWN0SWQYASACKA1CBZI/AjgQUgxkYXRhT2JqZWN0SW'
    'QSLgoOZGF0YU9iamVjdERhdGEYAiABKAxCBpI/AwjtAVIOZGF0YU9iamVjdERhdGE=');

@$core.Deprecated('Use statusResponseDescriptor instead')
const StatusResponse$json = {
  '1': 'StatusResponse',
  '2': [
    {'1': 'command', '3': 1, '4': 2, '5': 13, '8': {}, '10': 'command'},
    {'1': 'status', '3': 2, '4': 2, '5': 13, '8': {}, '10': 'status'},
  ],
};

/// Descriptor for `StatusResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List statusResponseDescriptor = $convert.base64Decode(
    'Cg5TdGF0dXNSZXNwb25zZRIfCgdjb21tYW5kGAEgAigNQgWSPwI4CFIHY29tbWFuZBIdCgZzdG'
    'F0dXMYAiACKA1CBZI/AjgIUgZzdGF0dXM=');

@$core.Deprecated('Use setDescriptor instead')
const Set$json = {
  '1': 'Set',
  '2': [
    {'1': 'options', '3': 1, '4': 1, '5': 13, '8': {}, '10': 'options'},
    {'1': 'msgId', '3': 2, '4': 1, '5': 13, '8': {}, '10': 'msgId'},
    {'1': 'devInfo', '3': 3, '4': 1, '5': 11, '6': '.Zp.DevInfoSet', '9': 0, '10': 'devInfo'},
    {'1': 'trainerSimParam', '3': 4, '4': 1, '5': 11, '6': '.Zp.TrainerSimulationParam', '9': 0, '10': 'trainerSimParam'},
    {'1': 'trainerOptions', '3': 5, '4': 1, '5': 11, '6': '.Zp.TrainerOptions', '9': 0, '10': 'trainerOptions'},
    {'1': 'deviceTiltConfig', '3': 6, '4': 1, '5': 11, '6': '.Zp.DeviceTiltConfigPage', '9': 0, '10': 'deviceTiltConfig'},
    {'1': 'controllerInputConfig', '3': 7, '4': 1, '5': 11, '6': '.Zp.ControllerInputConfigPage', '9': 0, '10': 'controllerInputConfig'},
    {'1': 'trainerGearIndexConfig', '3': 8, '4': 1, '5': 11, '6': '.Zp.TrainerGearIndexConfigPage', '9': 0, '10': 'trainerGearIndexConfig'},
    {'1': 'wifiConfig', '3': 10, '4': 1, '5': 11, '6': '.Zp.WifiConfigurationPage', '9': 0, '10': 'wifiConfig'},
    {'1': 'dateTimeConfig', '3': 11, '4': 1, '5': 11, '6': '.Zp.DateTimePage', '9': 0, '10': 'dateTimeConfig'},
  ],
  '8': [
    {'1': 'set'},
  ],
  '9': [
    {'1': 9, '2': 10},
  ],
};

/// Descriptor for `Set`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setDescriptor = $convert.base64Decode(
    'CgNTZXQSHwoHb3B0aW9ucxgBIAEoDUIFkj8COAhSB29wdGlvbnMSGwoFbXNnSWQYAiABKA1CBZ'
    'I/AjgIUgVtc2dJZBIqCgdkZXZJbmZvGAMgASgLMg4uWnAuRGV2SW5mb1NldEgAUgdkZXZJbmZv'
    'EkYKD3RyYWluZXJTaW1QYXJhbRgEIAEoCzIaLlpwLlRyYWluZXJTaW11bGF0aW9uUGFyYW1IAF'
    'IPdHJhaW5lclNpbVBhcmFtEjwKDnRyYWluZXJPcHRpb25zGAUgASgLMhIuWnAuVHJhaW5lck9w'
    'dGlvbnNIAFIOdHJhaW5lck9wdGlvbnMSRgoQZGV2aWNlVGlsdENvbmZpZxgGIAEoCzIYLlpwLk'
    'RldmljZVRpbHRDb25maWdQYWdlSABSEGRldmljZVRpbHRDb25maWcSVQoVY29udHJvbGxlcklu'
    'cHV0Q29uZmlnGAcgASgLMh0uWnAuQ29udHJvbGxlcklucHV0Q29uZmlnUGFnZUgAUhVjb250cm'
    '9sbGVySW5wdXRDb25maWcSWAoWdHJhaW5lckdlYXJJbmRleENvbmZpZxgIIAEoCzIeLlpwLlRy'
    'YWluZXJHZWFySW5kZXhDb25maWdQYWdlSABSFnRyYWluZXJHZWFySW5kZXhDb25maWcSOwoKd2'
    'lmaUNvbmZpZxgKIAEoCzIZLlpwLldpZmlDb25maWd1cmF0aW9uUGFnZUgAUgp3aWZpQ29uZmln'
    'EjoKDmRhdGVUaW1lQ29uZmlnGAsgASgLMhAuWnAuRGF0ZVRpbWVQYWdlSABSDmRhdGVUaW1lQ2'
    '9uZmlnQgUKA3NldEoECAkQCg==');

@$core.Deprecated('Use setResponseDescriptor instead')
const SetResponse$json = {
  '1': 'SetResponse',
  '2': [
    {'1': 'status', '3': 1, '4': 1, '5': 13, '8': {}, '10': 'status'},
    {'1': 'msgId', '3': 2, '4': 1, '5': 13, '8': {}, '10': 'msgId'},
    {'1': 'response', '3': 3, '4': 1, '5': 11, '6': '.Zp.SetResponse.Response', '10': 'response'},
  ],
  '3': [SetResponse_Response$json],
  '9': [
    {'1': 7, '2': 8},
  ],
};

@$core.Deprecated('Use setResponseDescriptor instead')
const SetResponse_Response$json = {
  '1': 'Response',
  '2': [
    {'1': 'devInfo', '3': 1, '4': 1, '5': 11, '6': '.Zp.DevInfoPage', '9': 0, '10': 'devInfo'},
    {'1': 'trainerSimParam', '3': 2, '4': 1, '5': 11, '6': '.Zp.TrainerSimulationParam', '9': 0, '10': 'trainerSimParam'},
    {'1': 'trainerOptions', '3': 3, '4': 1, '5': 11, '6': '.Zp.TrainerOptions', '9': 0, '10': 'trainerOptions'},
    {'1': 'deviceTiltConfig', '3': 4, '4': 1, '5': 11, '6': '.Zp.DeviceTiltConfigPage', '9': 0, '10': 'deviceTiltConfig'},
    {'1': 'controllerInputConfig', '3': 5, '4': 1, '5': 11, '6': '.Zp.ControllerInputConfigPage', '9': 0, '10': 'controllerInputConfig'},
    {'1': 'trainerGearIndexConfig', '3': 6, '4': 1, '5': 11, '6': '.Zp.TrainerGearIndexConfigPage', '9': 0, '10': 'trainerGearIndexConfig'},
    {'1': 'wifiConfig', '3': 8, '4': 1, '5': 11, '6': '.Zp.WifiConfigurationPage', '9': 0, '10': 'wifiConfig'},
    {'1': 'dateTimeConfig', '3': 9, '4': 1, '5': 11, '6': '.Zp.DateTimePage', '9': 0, '10': 'dateTimeConfig'},
  ],
  '8': [
    {'1': 'page'},
  ],
};

/// Descriptor for `SetResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setResponseDescriptor = $convert.base64Decode(
    'CgtTZXRSZXNwb25zZRIdCgZzdGF0dXMYASABKA1CBZI/AjgIUgZzdGF0dXMSGwoFbXNnSWQYAi'
    'ABKA1CBZI/AjgIUgVtc2dJZBI0CghyZXNwb25zZRgDIAEoCzIYLlpwLlNldFJlc3BvbnNlLlJl'
    'c3BvbnNlUghyZXNwb25zZRq3BAoIUmVzcG9uc2USKwoHZGV2SW5mbxgBIAEoCzIPLlpwLkRldk'
    'luZm9QYWdlSABSB2RldkluZm8SRgoPdHJhaW5lclNpbVBhcmFtGAIgASgLMhouWnAuVHJhaW5l'
    'clNpbXVsYXRpb25QYXJhbUgAUg90cmFpbmVyU2ltUGFyYW0SPAoOdHJhaW5lck9wdGlvbnMYAy'
    'ABKAsyEi5acC5UcmFpbmVyT3B0aW9uc0gAUg50cmFpbmVyT3B0aW9ucxJGChBkZXZpY2VUaWx0'
    'Q29uZmlnGAQgASgLMhguWnAuRGV2aWNlVGlsdENvbmZpZ1BhZ2VIAFIQZGV2aWNlVGlsdENvbm'
    'ZpZxJVChVjb250cm9sbGVySW5wdXRDb25maWcYBSABKAsyHS5acC5Db250cm9sbGVySW5wdXRD'
    'b25maWdQYWdlSABSFWNvbnRyb2xsZXJJbnB1dENvbmZpZxJYChZ0cmFpbmVyR2VhckluZGV4Q2'
    '9uZmlnGAYgASgLMh4uWnAuVHJhaW5lckdlYXJJbmRleENvbmZpZ1BhZ2VIAFIWdHJhaW5lckdl'
    'YXJJbmRleENvbmZpZxI7Cgp3aWZpQ29uZmlnGAggASgLMhkuWnAuV2lmaUNvbmZpZ3VyYXRpb2'
    '5QYWdlSABSCndpZmlDb25maWcSOgoOZGF0ZVRpbWVDb25maWcYCSABKAsyEC5acC5EYXRlVGlt'
    'ZVBhZ2VIAFIOZGF0ZVRpbWVDb25maWdCBgoEcGFnZUoECAcQCA==');

@$core.Deprecated('Use logLevelSetDescriptor instead')
const LogLevelSet$json = {
  '1': 'LogLevelSet',
  '2': [
    {'1': 'logLevel', '3': 1, '4': 1, '5': 14, '6': '.Zp.LogLevel', '10': 'logLevel'},
  ],
};

/// Descriptor for `LogLevelSet`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List logLevelSetDescriptor = $convert.base64Decode(
    'CgtMb2dMZXZlbFNldBIoCghsb2dMZXZlbBgBIAEoDjIMLlpwLkxvZ0xldmVsUghsb2dMZXZlbA'
    '==');

@$core.Deprecated('Use dataChangeNotificationDescriptor instead')
const DataChangeNotification$json = {
  '1': 'DataChangeNotification',
  '2': [
    {'1': 'devInfo', '3': 1, '4': 1, '5': 11, '6': '.Zp.DevInfoPage', '9': 0, '10': 'devInfo'},
    {'1': 'trainerSimParam', '3': 2, '4': 1, '5': 11, '6': '.Zp.TrainerSimulationParam', '9': 0, '10': 'trainerSimParam'},
    {'1': 'trainerOptions', '3': 3, '4': 1, '5': 11, '6': '.Zp.TrainerOptions', '9': 0, '10': 'trainerOptions'},
    {'1': 'deviceTiltConfig', '3': 4, '4': 1, '5': 11, '6': '.Zp.DeviceTiltConfigPage', '9': 0, '10': 'deviceTiltConfig'},
    {'1': 'controllerInputConfig', '3': 5, '4': 1, '5': 11, '6': '.Zp.ControllerInputConfigPage', '9': 0, '10': 'controllerInputConfig'},
    {'1': 'trainerGearIndexConfig', '3': 6, '4': 1, '5': 11, '6': '.Zp.TrainerGearIndexConfigPage', '9': 0, '10': 'trainerGearIndexConfig'},
    {'1': 'wifiConfig', '3': 8, '4': 1, '5': 11, '6': '.Zp.WifiConfigurationPage', '9': 0, '10': 'wifiConfig'},
    {'1': 'deviceUpdatePage', '3': 9, '4': 1, '5': 11, '6': '.Zp.DeviceUpdatePage', '9': 0, '10': 'deviceUpdatePage'},
    {'1': 'dateTimePage', '3': 10, '4': 1, '5': 11, '6': '.Zp.DateTimePage', '9': 0, '10': 'dateTimePage'},
    {'1': 'bleSecurityPage', '3': 11, '4': 1, '5': 11, '6': '.Zp.BleSecurityPage', '9': 0, '10': 'bleSecurityPage'},
  ],
  '8': [
    {'1': 'notification'},
  ],
  '9': [
    {'1': 7, '2': 8},
  ],
};

/// Descriptor for `DataChangeNotification`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dataChangeNotificationDescriptor = $convert.base64Decode(
    'ChZEYXRhQ2hhbmdlTm90aWZpY2F0aW9uEisKB2RldkluZm8YASABKAsyDy5acC5EZXZJbmZvUG'
    'FnZUgAUgdkZXZJbmZvEkYKD3RyYWluZXJTaW1QYXJhbRgCIAEoCzIaLlpwLlRyYWluZXJTaW11'
    'bGF0aW9uUGFyYW1IAFIPdHJhaW5lclNpbVBhcmFtEjwKDnRyYWluZXJPcHRpb25zGAMgASgLMh'
    'IuWnAuVHJhaW5lck9wdGlvbnNIAFIOdHJhaW5lck9wdGlvbnMSRgoQZGV2aWNlVGlsdENvbmZp'
    'ZxgEIAEoCzIYLlpwLkRldmljZVRpbHRDb25maWdQYWdlSABSEGRldmljZVRpbHRDb25maWcSVQ'
    'oVY29udHJvbGxlcklucHV0Q29uZmlnGAUgASgLMh0uWnAuQ29udHJvbGxlcklucHV0Q29uZmln'
    'UGFnZUgAUhVjb250cm9sbGVySW5wdXRDb25maWcSWAoWdHJhaW5lckdlYXJJbmRleENvbmZpZx'
    'gGIAEoCzIeLlpwLlRyYWluZXJHZWFySW5kZXhDb25maWdQYWdlSABSFnRyYWluZXJHZWFySW5k'
    'ZXhDb25maWcSOwoKd2lmaUNvbmZpZxgIIAEoCzIZLlpwLldpZmlDb25maWd1cmF0aW9uUGFnZU'
    'gAUgp3aWZpQ29uZmlnEkIKEGRldmljZVVwZGF0ZVBhZ2UYCSABKAsyFC5acC5EZXZpY2VVcGRh'
    'dGVQYWdlSABSEGRldmljZVVwZGF0ZVBhZ2USNgoMZGF0ZVRpbWVQYWdlGAogASgLMhAuWnAuRG'
    'F0ZVRpbWVQYWdlSABSDGRhdGVUaW1lUGFnZRI/Cg9ibGVTZWN1cml0eVBhZ2UYCyABKAsyEy5a'
    'cC5CbGVTZWN1cml0eVBhZ2VIAFIPYmxlU2VjdXJpdHlQYWdlQg4KDG5vdGlmaWNhdGlvbkoECA'
    'cQCA==');

@$core.Deprecated('Use gameStateNotificationDescriptor instead')
const GameStateNotification$json = {
  '1': 'GameStateNotification',
  '2': [
    {'1': 'gameSpeed', '3': 1, '4': 1, '5': 11, '6': '.Zp.GameStateNotification.GameSpeed', '9': 0, '10': 'gameSpeed'},
    {'1': 'roadSurface', '3': 2, '4': 1, '5': 11, '6': '.Zp.GameStateNotification.RoadSurface', '9': 0, '10': 'roadSurface'},
  ],
  '3': [GameStateNotification_GameSpeed$json, GameStateNotification_RoadSurface$json],
  '8': [
    {'1': 'notification'},
  ],
};

@$core.Deprecated('Use gameStateNotificationDescriptor instead')
const GameStateNotification_GameSpeed$json = {
  '1': 'GameSpeed',
  '2': [
    {'1': 'normalisedSpeed', '3': 1, '4': 1, '5': 17, '8': {}, '10': 'normalisedSpeed'},
    {'1': 'speed', '3': 2, '4': 1, '5': 17, '8': {}, '10': 'speed'},
  ],
};

@$core.Deprecated('Use gameStateNotificationDescriptor instead')
const GameStateNotification_RoadSurface$json = {
  '1': 'RoadSurface',
  '2': [
    {'1': 'roadSurfaceType', '3': 1, '4': 1, '5': 14, '6': '.Zp.RoadSurfaceType', '10': 'roadSurfaceType'},
    {'1': 'roughness', '3': 2, '4': 1, '5': 13, '8': {}, '10': 'roughness'},
  ],
};

/// Descriptor for `GameStateNotification`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List gameStateNotificationDescriptor = $convert.base64Decode(
    'ChVHYW1lU3RhdGVOb3RpZmljYXRpb24SQwoJZ2FtZVNwZWVkGAEgASgLMiMuWnAuR2FtZVN0YX'
    'RlTm90aWZpY2F0aW9uLkdhbWVTcGVlZEgAUglnYW1lU3BlZWQSSQoLcm9hZFN1cmZhY2UYAiAB'
    'KAsyJS5acC5HYW1lU3RhdGVOb3RpZmljYXRpb24uUm9hZFN1cmZhY2VIAFILcm9hZFN1cmZhY2'
    'UaWQoJR2FtZVNwZWVkEi8KD25vcm1hbGlzZWRTcGVlZBgBIAEoEUIFkj8COAhSD25vcm1hbGlz'
    'ZWRTcGVlZBIbCgVzcGVlZBgCIAEoEUIFkj8COBBSBXNwZWVkGnEKC1JvYWRTdXJmYWNlEj0KD3'
    'JvYWRTdXJmYWNlVHlwZRgBIAEoDjITLlpwLlJvYWRTdXJmYWNlVHlwZVIPcm9hZFN1cmZhY2VU'
    'eXBlEiMKCXJvdWdobmVzcxgCIAEoDUIFkj8COAhSCXJvdWdobmVzc0IOCgxub3RpZmljYXRpb2'
    '4=');

@$core.Deprecated('Use sensorRelayConfigDescriptor instead')
const SensorRelayConfig$json = {
  '1': 'SensorRelayConfig',
  '2': [
    {'1': 'search', '3': 1, '4': 1, '5': 8, '9': 0, '10': 'search'},
    {'1': 'connect', '3': 2, '4': 1, '5': 13, '8': {}, '9': 0, '10': 'connect'},
    {'1': 'disconnect', '3': 3, '4': 1, '5': 13, '8': {}, '9': 0, '10': 'disconnect'},
    {'1': 'clearAll', '3': 4, '4': 1, '5': 8, '9': 0, '10': 'clearAll'},
    {'1': 'disconnectAll', '3': 5, '4': 1, '5': 8, '9': 0, '10': 'disconnectAll'},
  ],
  '8': [
    {'1': 'procedure'},
  ],
};

/// Descriptor for `SensorRelayConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sensorRelayConfigDescriptor = $convert.base64Decode(
    'ChFTZW5zb3JSZWxheUNvbmZpZxIYCgZzZWFyY2gYASABKAhIAFIGc2VhcmNoEiEKB2Nvbm5lY3'
    'QYAiABKA1CBZI/AjgISABSB2Nvbm5lY3QSJwoKZGlzY29ubmVjdBgDIAEoDUIFkj8COAhIAFIK'
    'ZGlzY29ubmVjdBIcCghjbGVhckFsbBgEIAEoCEgAUghjbGVhckFsbBImCg1kaXNjb25uZWN0QW'
    'xsGAUgASgISABSDWRpc2Nvbm5lY3RBbGxCCwoJcHJvY2VkdXJl');

@$core.Deprecated('Use sensorRelayGetDescriptor instead')
const SensorRelayGet$json = {
  '1': 'SensorRelayGet',
  '2': [
    {'1': 'pairedSensorInfo', '3': 1, '4': 1, '5': 13, '8': {}, '9': 0, '10': 'pairedSensorInfo'},
  ],
  '8': [
    {'1': 'request'},
  ],
};

/// Descriptor for `SensorRelayGet`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sensorRelayGetDescriptor = $convert.base64Decode(
    'Cg5TZW5zb3JSZWxheUdldBIzChBwYWlyZWRTZW5zb3JJbmZvGAEgASgNQgWSPwI4CEgAUhBwYW'
    'lyZWRTZW5zb3JJbmZvQgkKB3JlcXVlc3Q=');

@$core.Deprecated('Use sensorRelayResponseDescriptor instead')
const SensorRelayResponse$json = {
  '1': 'SensorRelayResponse',
  '2': [
    {'1': 'pairedSensorInfoList', '3': 1, '4': 1, '5': 11, '6': '.Zp.SensorInfoList', '9': 0, '10': 'pairedSensorInfoList'},
  ],
  '8': [
    {'1': 'response'},
  ],
};

/// Descriptor for `SensorRelayResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sensorRelayResponseDescriptor = $convert.base64Decode(
    'ChNTZW5zb3JSZWxheVJlc3BvbnNlEkgKFHBhaXJlZFNlbnNvckluZm9MaXN0GAEgASgLMhIuWn'
    'AuU2Vuc29ySW5mb0xpc3RIAFIUcGFpcmVkU2Vuc29ySW5mb0xpc3RCCgoIcmVzcG9uc2U=');

@$core.Deprecated('Use sensorRelayNotificationDescriptor instead')
const SensorRelayNotification$json = {
  '1': 'SensorRelayNotification',
  '2': [
    {'1': 'newSensor', '3': 1, '4': 1, '5': 11, '6': '.Zp.SensorInfo', '9': 0, '10': 'newSensor'},
    {'1': 'sensorStatus', '3': 2, '4': 1, '5': 11, '6': '.Zp.SensorInfo', '9': 0, '10': 'sensorStatus'},
  ],
  '8': [
    {'1': 'notification'},
  ],
};

/// Descriptor for `SensorRelayNotification`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sensorRelayNotificationDescriptor = $convert.base64Decode(
    'ChdTZW5zb3JSZWxheU5vdGlmaWNhdGlvbhIuCgluZXdTZW5zb3IYASABKAsyDi5acC5TZW5zb3'
    'JJbmZvSABSCW5ld1NlbnNvchI0CgxzZW5zb3JTdGF0dXMYAiABKAsyDi5acC5TZW5zb3JJbmZv'
    'SABSDHNlbnNvclN0YXR1c0IOCgxub3RpZmljYXRpb24=');

@$core.Deprecated('Use hrmDataNotificationDescriptor instead')
const HrmDataNotification$json = {
  '1': 'HrmDataNotification',
  '2': [
    {'1': 'sensorId', '3': 1, '4': 1, '5': 13, '8': {}, '10': 'sensorId'},
    {'1': 'hrm', '3': 2, '4': 1, '5': 13, '8': {}, '10': 'hrm'},
    {'1': 'energyExpended', '3': 3, '4': 1, '5': 13, '8': {}, '10': 'energyExpended'},
    {'1': 'rrInterval', '3': 4, '4': 3, '5': 13, '8': {}, '10': 'rrInterval'},
  ],
};

/// Descriptor for `HrmDataNotification`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List hrmDataNotificationDescriptor = $convert.base64Decode(
    'ChNIcm1EYXRhTm90aWZpY2F0aW9uEiEKCHNlbnNvcklkGAEgASgNQgWSPwI4CFIIc2Vuc29ySW'
    'QSFwoDaHJtGAIgASgNQgWSPwI4EFIDaHJtEi0KDmVuZXJneUV4cGVuZGVkGAMgASgNQgWSPwI4'
    'EFIOZW5lcmd5RXhwZW5kZWQSJQoKcnJJbnRlcnZhbBgEIAMoDUIFkj8CEA9SCnJySW50ZXJ2YW'
    'w=');

@$core.Deprecated('Use wifiConfigurationRequestDescriptor instead')
const WifiConfigurationRequest$json = {
  '1': 'WifiConfigurationRequest',
  '2': [
    {'1': 'startScan', '3': 1, '4': 1, '5': 8, '9': 0, '10': 'startScan'},
    {'1': 'connect', '3': 2, '4': 1, '5': 11, '6': '.Zp.WifiNetwork', '9': 0, '10': 'connect'},
    {'1': 'forget', '3': 3, '4': 1, '5': 8, '9': 0, '10': 'forget'},
    {'1': 'setRegionCode', '3': 4, '4': 1, '5': 11, '6': '.Zp.WifiRegionCode', '9': 0, '10': 'setRegionCode'},
  ],
  '8': [
    {'1': 'request'},
  ],
};

/// Descriptor for `WifiConfigurationRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List wifiConfigurationRequestDescriptor = $convert.base64Decode(
    'ChhXaWZpQ29uZmlndXJhdGlvblJlcXVlc3QSHgoJc3RhcnRTY2FuGAEgASgISABSCXN0YXJ0U2'
    'NhbhIrCgdjb25uZWN0GAIgASgLMg8uWnAuV2lmaU5ldHdvcmtIAFIHY29ubmVjdBIYCgZmb3Jn'
    'ZXQYAyABKAhIAFIGZm9yZ2V0EjoKDXNldFJlZ2lvbkNvZGUYBCABKAsyEi5acC5XaWZpUmVnaW'
    '9uQ29kZUgAUg1zZXRSZWdpb25Db2RlQgkKB3JlcXVlc3Q=');

@$core.Deprecated('Use wifiNotificationDescriptor instead')
const WifiNotification$json = {
  '1': 'WifiNotification',
  '2': [
    {'1': 'discoveredNetwork', '3': 1, '4': 1, '5': 11, '6': '.Zp.WifiNetworkDetails', '9': 0, '10': 'discoveredNetwork'},
    {'1': 'wifiStatus', '3': 2, '4': 1, '5': 11, '6': '.Zp.WifiNotification.WifiStatus', '9': 0, '10': 'wifiStatus'},
  ],
  '3': [WifiNotification_WifiStatus$json],
  '8': [
    {'1': 'notification'},
  ],
};

@$core.Deprecated('Use wifiNotificationDescriptor instead')
const WifiNotification_WifiStatus$json = {
  '1': 'WifiStatus',
  '2': [
    {'1': 'wifiStatusCode', '3': 1, '4': 1, '5': 14, '6': '.Zp.WifiStatusCode', '10': 'wifiStatusCode'},
    {'1': 'wifiErrorCode', '3': 2, '4': 1, '5': 14, '6': '.Zp.WifiErrorCode', '10': 'wifiErrorCode'},
  ],
};

/// Descriptor for `WifiNotification`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List wifiNotificationDescriptor = $convert.base64Decode(
    'ChBXaWZpTm90aWZpY2F0aW9uEkYKEWRpc2NvdmVyZWROZXR3b3JrGAEgASgLMhYuWnAuV2lmaU'
    '5ldHdvcmtEZXRhaWxzSABSEWRpc2NvdmVyZWROZXR3b3JrEkEKCndpZmlTdGF0dXMYAiABKAsy'
    'Hy5acC5XaWZpTm90aWZpY2F0aW9uLldpZmlTdGF0dXNIAFIKd2lmaVN0YXR1cxqBAQoKV2lmaV'
    'N0YXR1cxI6Cg53aWZpU3RhdHVzQ29kZRgBIAEoDjISLlpwLldpZmlTdGF0dXNDb2RlUg53aWZp'
    'U3RhdHVzQ29kZRI3Cg13aWZpRXJyb3JDb2RlGAIgASgOMhEuWnAuV2lmaUVycm9yQ29kZVINd2'
    'lmaUVycm9yQ29kZUIOCgxub3RpZmljYXRpb24=');

@$core.Deprecated('Use powerDataNotificationDescriptor instead')
const PowerDataNotification$json = {
  '1': 'PowerDataNotification',
  '2': [
    {'1': 'sensorId', '3': 1, '4': 1, '5': 13, '8': {}, '10': 'sensorId'},
    {'1': 'power', '3': 2, '4': 1, '5': 13, '8': {}, '10': 'power'},
  ],
};

/// Descriptor for `PowerDataNotification`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List powerDataNotificationDescriptor = $convert.base64Decode(
    'ChVQb3dlckRhdGFOb3RpZmljYXRpb24SIQoIc2Vuc29ySWQYASABKA1CBZI/AjgIUghzZW5zb3'
    'JJZBIbCgVwb3dlchgCIAEoDUIFkj8COBBSBXBvd2Vy');

@$core.Deprecated('Use cadenceDataNotificationDescriptor instead')
const CadenceDataNotification$json = {
  '1': 'CadenceDataNotification',
  '2': [
    {'1': 'sensorId', '3': 1, '4': 1, '5': 13, '8': {}, '10': 'sensorId'},
    {'1': 'cadence', '3': 2, '4': 1, '5': 13, '8': {}, '10': 'cadence'},
  ],
};

/// Descriptor for `CadenceDataNotification`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cadenceDataNotificationDescriptor = $convert.base64Decode(
    'ChdDYWRlbmNlRGF0YU5vdGlmaWNhdGlvbhIhCghzZW5zb3JJZBgBIAEoDUIFkj8COAhSCHNlbn'
    'NvcklkEh8KB2NhZGVuY2UYAiABKA1CBZI/AjgQUgdjYWRlbmNl');

@$core.Deprecated('Use deviceUpdateRequestDescriptor instead')
const DeviceUpdateRequest$json = {
  '1': 'DeviceUpdateRequest',
  '2': [
    {'1': 'checkForUpdates', '3': 1, '4': 1, '5': 8, '9': 0, '10': 'checkForUpdates'},
    {'1': 'activateUpdates', '3': 2, '4': 1, '5': 8, '9': 0, '10': 'activateUpdates'},
  ],
  '8': [
    {'1': 'procedure'},
  ],
};

/// Descriptor for `DeviceUpdateRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deviceUpdateRequestDescriptor = $convert.base64Decode(
    'ChNEZXZpY2VVcGRhdGVSZXF1ZXN0EioKD2NoZWNrRm9yVXBkYXRlcxgBIAEoCEgAUg9jaGVja0'
    'ZvclVwZGF0ZXMSKgoPYWN0aXZhdGVVcGRhdGVzGAIgASgISABSD2FjdGl2YXRlVXBkYXRlc0IL'
    'Cglwcm9jZWR1cmU=');

@$core.Deprecated('Use relayZpMessageDescriptor instead')
const RelayZpMessage$json = {
  '1': 'RelayZpMessage',
  '2': [
    {'1': 'relayAssignedId', '3': 1, '4': 1, '5': 13, '8': {}, '10': 'relayAssignedId'},
    {'1': 'payload', '3': 2, '4': 1, '5': 12, '8': {}, '10': 'payload'},
  ],
};

/// Descriptor for `RelayZpMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List relayZpMessageDescriptor = $convert.base64Decode(
    'Cg5SZWxheVpwTWVzc2FnZRIvCg9yZWxheUFzc2lnbmVkSWQYASABKA1CBZI/AjgIUg9yZWxheU'
    'Fzc2lnbmVkSWQSIAoHcGF5bG9hZBgCIAEoDEIGkj8DCO4BUgdwYXlsb2Fk');

