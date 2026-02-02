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

/// ///////////////////////////////////////////////////////////////
///  Enumerations
/// ///////////////////////////////////////////////////////////////
class Opcode extends $pb.ProtobufEnum {
  static const Opcode GET = Opcode._(0, _omitEnumNames ? '' : 'GET');
  static const Opcode DEV_INFO_STATUS = Opcode._(1, _omitEnumNames ? '' : 'DEV_INFO_STATUS');
  static const Opcode BLE_SECURITY_REQUEST = Opcode._(2, _omitEnumNames ? '' : 'BLE_SECURITY_REQUEST');
  static const Opcode TRAINER_NOTIF = Opcode._(3, _omitEnumNames ? '' : 'TRAINER_NOTIF');
  static const Opcode TRAINER_CONFIG_SET = Opcode._(4, _omitEnumNames ? '' : 'TRAINER_CONFIG_SET');
  static const Opcode TRAINER_CONFIG_STATUS = Opcode._(5, _omitEnumNames ? '' : 'TRAINER_CONFIG_STATUS');
  static const Opcode DEV_INFO_SET = Opcode._(12, _omitEnumNames ? '' : 'DEV_INFO_SET');
  static const Opcode POWER_OFF = Opcode._(15, _omitEnumNames ? '' : 'POWER_OFF');
  static const Opcode RESET = Opcode._(24, _omitEnumNames ? '' : 'RESET');
  static const Opcode BATTERY_NOTIF = Opcode._(25, _omitEnumNames ? '' : 'BATTERY_NOTIF');
  static const Opcode CONTROLLER_NOTIFICATION = Opcode._(35, _omitEnumNames ? '' : 'CONTROLLER_NOTIFICATION');
  static const Opcode LOG_DATA = Opcode._(42, _omitEnumNames ? '' : 'LOG_DATA');
  static const Opcode SPINDOWN_REQUEST = Opcode._(58, _omitEnumNames ? '' : 'SPINDOWN_REQUEST');
  static const Opcode SPINDOWN_NOTIFICATION = Opcode._(59, _omitEnumNames ? '' : 'SPINDOWN_NOTIFICATION');
  static const Opcode GET_RESPONSE = Opcode._(60, _omitEnumNames ? '' : 'GET_RESPONSE');
  static const Opcode STATUS_RESPONSE = Opcode._(62, _omitEnumNames ? '' : 'STATUS_RESPONSE');
  static const Opcode SET = Opcode._(63, _omitEnumNames ? '' : 'SET');
  static const Opcode SET_RESPONSE = Opcode._(64, _omitEnumNames ? '' : 'SET_RESPONSE');
  static const Opcode LOG_LEVEL_SET = Opcode._(65, _omitEnumNames ? '' : 'LOG_LEVEL_SET');
  static const Opcode DATA_CHANGE_NOTIFICATION = Opcode._(66, _omitEnumNames ? '' : 'DATA_CHANGE_NOTIFICATION');
  static const Opcode GAME_STATE_NOTIFICATION = Opcode._(67, _omitEnumNames ? '' : 'GAME_STATE_NOTIFICATION');
  static const Opcode SENSOR_RELAY_CONFIG = Opcode._(68, _omitEnumNames ? '' : 'SENSOR_RELAY_CONFIG');
  static const Opcode SENSOR_RELAY_GET = Opcode._(69, _omitEnumNames ? '' : 'SENSOR_RELAY_GET');
  static const Opcode SENSOR_RELAY_RESPONSE = Opcode._(70, _omitEnumNames ? '' : 'SENSOR_RELAY_RESPONSE');
  static const Opcode SENSOR_RELAY_NOTIFICATION = Opcode._(71, _omitEnumNames ? '' : 'SENSOR_RELAY_NOTIFICATION');
  static const Opcode HRM_DATA_NOTIFICATION = Opcode._(72, _omitEnumNames ? '' : 'HRM_DATA_NOTIFICATION');
  static const Opcode WIFI_CONFIG_REQUEST = Opcode._(73, _omitEnumNames ? '' : 'WIFI_CONFIG_REQUEST');
  static const Opcode WIFI_NOTIFICATION = Opcode._(74, _omitEnumNames ? '' : 'WIFI_NOTIFICATION');
  static const Opcode POWER_METER_NOTIFICATION = Opcode._(75, _omitEnumNames ? '' : 'POWER_METER_NOTIFICATION');
  static const Opcode CADENCE_SENSOR_NOTIFICATION = Opcode._(76, _omitEnumNames ? '' : 'CADENCE_SENSOR_NOTIFICATION');
  static const Opcode DEVICE_UPDATE_REQUEST = Opcode._(77, _omitEnumNames ? '' : 'DEVICE_UPDATE_REQUEST');
  static const Opcode RELAY_ZP_MESSAGE = Opcode._(78, _omitEnumNames ? '' : 'RELAY_ZP_MESSAGE');
  static const Opcode RIDE_ON = Opcode._(82, _omitEnumNames ? '' : 'RIDE_ON');
  static const Opcode RESERVED = Opcode._(253, _omitEnumNames ? '' : 'RESERVED');
  static const Opcode LOST_CONTROL = Opcode._(254, _omitEnumNames ? '' : 'LOST_CONTROL');
  static const Opcode VENDOR_MESSAGE = Opcode._(255, _omitEnumNames ? '' : 'VENDOR_MESSAGE');

  static const $core.List<Opcode> values = <Opcode> [
    GET,
    DEV_INFO_STATUS,
    BLE_SECURITY_REQUEST,
    TRAINER_NOTIF,
    TRAINER_CONFIG_SET,
    TRAINER_CONFIG_STATUS,
    DEV_INFO_SET,
    POWER_OFF,
    RESET,
    BATTERY_NOTIF,
    CONTROLLER_NOTIFICATION,
    LOG_DATA,
    SPINDOWN_REQUEST,
    SPINDOWN_NOTIFICATION,
    GET_RESPONSE,
    STATUS_RESPONSE,
    SET,
    SET_RESPONSE,
    LOG_LEVEL_SET,
    DATA_CHANGE_NOTIFICATION,
    GAME_STATE_NOTIFICATION,
    SENSOR_RELAY_CONFIG,
    SENSOR_RELAY_GET,
    SENSOR_RELAY_RESPONSE,
    SENSOR_RELAY_NOTIFICATION,
    HRM_DATA_NOTIFICATION,
    WIFI_CONFIG_REQUEST,
    WIFI_NOTIFICATION,
    POWER_METER_NOTIFICATION,
    CADENCE_SENSOR_NOTIFICATION,
    DEVICE_UPDATE_REQUEST,
    RELAY_ZP_MESSAGE,
    RIDE_ON,
    RESERVED,
    LOST_CONTROL,
    VENDOR_MESSAGE,
  ];

  static final $core.Map<$core.int, Opcode> _byValue = $pb.ProtobufEnum.initByValue(values);
  static Opcode? valueOf($core.int value) => _byValue[value];

  const Opcode._($core.int v, $core.String n) : super(v, n);
}

/// Data Objects
class DO extends $pb.ProtobufEnum {
  static const DO PAGE_DEV_INFO = DO._(0, _omitEnumNames ? '' : 'PAGE_DEV_INFO');
  static const DO PROTOCOL_VERSION = DO._(1, _omitEnumNames ? '' : 'PROTOCOL_VERSION');
  static const DO SYSTEM_FW_VERSION = DO._(2, _omitEnumNames ? '' : 'SYSTEM_FW_VERSION');
  static const DO DEVICE_NAME = DO._(3, _omitEnumNames ? '' : 'DEVICE_NAME');
  static const DO SERIAL_NUMBER = DO._(5, _omitEnumNames ? '' : 'SERIAL_NUMBER');
  static const DO SYSTEM_HW_REVISION = DO._(6, _omitEnumNames ? '' : 'SYSTEM_HW_REVISION');
  static const DO DEVICE_CAPABILITIES = DO._(7, _omitEnumNames ? '' : 'DEVICE_CAPABILITIES');
  static const DO MANUFACTURER_ID = DO._(8, _omitEnumNames ? '' : 'MANUFACTURER_ID');
  static const DO PRODUCT_ID = DO._(9, _omitEnumNames ? '' : 'PRODUCT_ID');
  static const DO DEVICE_UID = DO._(10, _omitEnumNames ? '' : 'DEVICE_UID');
  static const DO PAGE_CLIENT_SERVER_CONFIGURATION = DO._(16, _omitEnumNames ? '' : 'PAGE_CLIENT_SERVER_CONFIGURATION');
  static const DO CLIENT_SERVER_NOTIFICATIONS = DO._(17, _omitEnumNames ? '' : 'CLIENT_SERVER_NOTIFICATIONS');
  static const DO PAGE_DEVICE_UPDATE_INFO = DO._(32, _omitEnumNames ? '' : 'PAGE_DEVICE_UPDATE_INFO');
  static const DO DEVICE_UPDATE_STATUS = DO._(33, _omitEnumNames ? '' : 'DEVICE_UPDATE_STATUS');
  static const DO DEVICE_UPDATE_NEW_VERSION = DO._(34, _omitEnumNames ? '' : 'DEVICE_UPDATE_NEW_VERSION');
  static const DO PAGE_DATE_TIME = DO._(48, _omitEnumNames ? '' : 'PAGE_DATE_TIME');
  static const DO UTC_DATE_TIME = DO._(49, _omitEnumNames ? '' : 'UTC_DATE_TIME');
  static const DO PAGE_BLE_SECURITY = DO._(64, _omitEnumNames ? '' : 'PAGE_BLE_SECURITY');
  static const DO BLE_SECURE_CONNECTION_STATUS = DO._(65, _omitEnumNames ? '' : 'BLE_SECURE_CONNECTION_STATUS');
  static const DO BLE_SECURE_CONNECTION_WINDOW_STATUS = DO._(66, _omitEnumNames ? '' : 'BLE_SECURE_CONNECTION_WINDOW_STATUS');
  static const DO PAGE_TRAINER_CONFIG = DO._(512, _omitEnumNames ? '' : 'PAGE_TRAINER_CONFIG');
  static const DO TRAINER_MODE = DO._(513, _omitEnumNames ? '' : 'TRAINER_MODE');
  static const DO CFG_RESISTANCE = DO._(514, _omitEnumNames ? '' : 'CFG_RESISTANCE');
  static const DO ERG_POWER = DO._(515, _omitEnumNames ? '' : 'ERG_POWER');
  static const DO AVERAGING_WINDOW = DO._(516, _omitEnumNames ? '' : 'AVERAGING_WINDOW');
  static const DO SIM_WIND = DO._(517, _omitEnumNames ? '' : 'SIM_WIND');
  static const DO SIM_GRADE = DO._(518, _omitEnumNames ? '' : 'SIM_GRADE');
  static const DO SIM_REAL_GEAR_RATIO = DO._(519, _omitEnumNames ? '' : 'SIM_REAL_GEAR_RATIO');
  static const DO SIM_VIRT_GEAR_RATIO = DO._(520, _omitEnumNames ? '' : 'SIM_VIRT_GEAR_RATIO');
  static const DO SIM_CW = DO._(521, _omitEnumNames ? '' : 'SIM_CW');
  static const DO SIM_WHEEL_DIAMETER = DO._(522, _omitEnumNames ? '' : 'SIM_WHEEL_DIAMETER');
  static const DO SIM_BIKE_MASS = DO._(523, _omitEnumNames ? '' : 'SIM_BIKE_MASS');
  static const DO SIM_RIDER_MASS = DO._(524, _omitEnumNames ? '' : 'SIM_RIDER_MASS');
  static const DO SIM_CRR = DO._(525, _omitEnumNames ? '' : 'SIM_CRR');
  static const DO SIM_RESERVED_FRONTAL_AREA = DO._(526, _omitEnumNames ? '' : 'SIM_RESERVED_FRONTAL_AREA');
  static const DO SIM_EBRAKE = DO._(527, _omitEnumNames ? '' : 'SIM_EBRAKE');
  static const DO PAGE_TRAINER_GEAR_INDEX_CONFIG = DO._(528, _omitEnumNames ? '' : 'PAGE_TRAINER_GEAR_INDEX_CONFIG');
  static const DO FRONT_GEAR_INDEX = DO._(529, _omitEnumNames ? '' : 'FRONT_GEAR_INDEX');
  static const DO FRONT_GEAR_INDEX_MAX = DO._(530, _omitEnumNames ? '' : 'FRONT_GEAR_INDEX_MAX');
  static const DO FRONT_GEAR_INDEX_MIN = DO._(531, _omitEnumNames ? '' : 'FRONT_GEAR_INDEX_MIN');
  static const DO REAR_GEAR_INDEX = DO._(532, _omitEnumNames ? '' : 'REAR_GEAR_INDEX');
  static const DO REAR_GEAR_INDEX_MAX = DO._(533, _omitEnumNames ? '' : 'REAR_GEAR_INDEX_MAX');
  static const DO REAR_GEAR_INDEX_MIN = DO._(534, _omitEnumNames ? '' : 'REAR_GEAR_INDEX_MIN');
  static const DO PAGE_TRAINER_CONFIG2 = DO._(544, _omitEnumNames ? '' : 'PAGE_TRAINER_CONFIG2');
  static const DO HIGH_SPEED_DATA = DO._(545, _omitEnumNames ? '' : 'HIGH_SPEED_DATA');
  static const DO ERG_POWER_SMOOTHING = DO._(546, _omitEnumNames ? '' : 'ERG_POWER_SMOOTHING');
  static const DO VIRTUAL_SHIFTING_MODE = DO._(547, _omitEnumNames ? '' : 'VIRTUAL_SHIFTING_MODE');
  static const DO PAGE_DEVICE_TILT_CONFIG = DO._(560, _omitEnumNames ? '' : 'PAGE_DEVICE_TILT_CONFIG');
  static const DO DEVICE_TILT_ENABLED = DO._(561, _omitEnumNames ? '' : 'DEVICE_TILT_ENABLED');
  static const DO DEVICE_TILT_GRADIENT_MIN = DO._(562, _omitEnumNames ? '' : 'DEVICE_TILT_GRADIENT_MIN');
  static const DO DEVICE_TILT_GRADIENT_MAX = DO._(563, _omitEnumNames ? '' : 'DEVICE_TILT_GRADIENT_MAX');
  static const DO DEVICE_TILT_GRADIENT = DO._(564, _omitEnumNames ? '' : 'DEVICE_TILT_GRADIENT');
  static const DO BATTERY_STATE = DO._(771, _omitEnumNames ? '' : 'BATTERY_STATE');
  static const DO PAGE_CONTROLLER_INPUT_CONFIG = DO._(1024, _omitEnumNames ? '' : 'PAGE_CONTROLLER_INPUT_CONFIG');
  static const DO INPUT_SUPPORTED_DIGITAL_INPUTS = DO._(1025, _omitEnumNames ? '' : 'INPUT_SUPPORTED_DIGITAL_INPUTS');
  static const DO INPUT_SUPPORTED_ANALOG_INPUTS = DO._(1026, _omitEnumNames ? '' : 'INPUT_SUPPORTED_ANALOG_INPUTS');
  static const DO INPUT_ANALOG_INPUT_RANGE = DO._(1027, _omitEnumNames ? '' : 'INPUT_ANALOG_INPUT_RANGE');
  static const DO INPUT_ANALOG_INPUT_DEADZONE = DO._(1028, _omitEnumNames ? '' : 'INPUT_ANALOG_INPUT_DEADZONE');
  static const DO PAGE_WIFI_CONFIGURATION = DO._(1056, _omitEnumNames ? '' : 'PAGE_WIFI_CONFIGURATION');
  static const DO WIFI_ENABLED = DO._(1057, _omitEnumNames ? '' : 'WIFI_ENABLED');
  static const DO WIFI_STATUS = DO._(1058, _omitEnumNames ? '' : 'WIFI_STATUS');
  static const DO WIFI_SSID = DO._(1059, _omitEnumNames ? '' : 'WIFI_SSID');
  static const DO WIFI_BAND = DO._(1060, _omitEnumNames ? '' : 'WIFI_BAND');
  static const DO WIFI_RSSI = DO._(1061, _omitEnumNames ? '' : 'WIFI_RSSI');
  static const DO WIFI_REGION_CODE = DO._(1062, _omitEnumNames ? '' : 'WIFI_REGION_CODE');
  static const DO SENSOR_RELAY_DATA_PAGE = DO._(1280, _omitEnumNames ? '' : 'SENSOR_RELAY_DATA_PAGE');
  static const DO SENSOR_RELAY_SUPPORTED_SENSORS = DO._(1281, _omitEnumNames ? '' : 'SENSOR_RELAY_SUPPORTED_SENSORS');
  static const DO SENSOR_RELAY_PAIRED_SENSORS = DO._(1282, _omitEnumNames ? '' : 'SENSOR_RELAY_PAIRED_SENSORS');

  static const $core.List<DO> values = <DO> [
    PAGE_DEV_INFO,
    PROTOCOL_VERSION,
    SYSTEM_FW_VERSION,
    DEVICE_NAME,
    SERIAL_NUMBER,
    SYSTEM_HW_REVISION,
    DEVICE_CAPABILITIES,
    MANUFACTURER_ID,
    PRODUCT_ID,
    DEVICE_UID,
    PAGE_CLIENT_SERVER_CONFIGURATION,
    CLIENT_SERVER_NOTIFICATIONS,
    PAGE_DEVICE_UPDATE_INFO,
    DEVICE_UPDATE_STATUS,
    DEVICE_UPDATE_NEW_VERSION,
    PAGE_DATE_TIME,
    UTC_DATE_TIME,
    PAGE_BLE_SECURITY,
    BLE_SECURE_CONNECTION_STATUS,
    BLE_SECURE_CONNECTION_WINDOW_STATUS,
    PAGE_TRAINER_CONFIG,
    TRAINER_MODE,
    CFG_RESISTANCE,
    ERG_POWER,
    AVERAGING_WINDOW,
    SIM_WIND,
    SIM_GRADE,
    SIM_REAL_GEAR_RATIO,
    SIM_VIRT_GEAR_RATIO,
    SIM_CW,
    SIM_WHEEL_DIAMETER,
    SIM_BIKE_MASS,
    SIM_RIDER_MASS,
    SIM_CRR,
    SIM_RESERVED_FRONTAL_AREA,
    SIM_EBRAKE,
    PAGE_TRAINER_GEAR_INDEX_CONFIG,
    FRONT_GEAR_INDEX,
    FRONT_GEAR_INDEX_MAX,
    FRONT_GEAR_INDEX_MIN,
    REAR_GEAR_INDEX,
    REAR_GEAR_INDEX_MAX,
    REAR_GEAR_INDEX_MIN,
    PAGE_TRAINER_CONFIG2,
    HIGH_SPEED_DATA,
    ERG_POWER_SMOOTHING,
    VIRTUAL_SHIFTING_MODE,
    PAGE_DEVICE_TILT_CONFIG,
    DEVICE_TILT_ENABLED,
    DEVICE_TILT_GRADIENT_MIN,
    DEVICE_TILT_GRADIENT_MAX,
    DEVICE_TILT_GRADIENT,
    BATTERY_STATE,
    PAGE_CONTROLLER_INPUT_CONFIG,
    INPUT_SUPPORTED_DIGITAL_INPUTS,
    INPUT_SUPPORTED_ANALOG_INPUTS,
    INPUT_ANALOG_INPUT_RANGE,
    INPUT_ANALOG_INPUT_DEADZONE,
    PAGE_WIFI_CONFIGURATION,
    WIFI_ENABLED,
    WIFI_STATUS,
    WIFI_SSID,
    WIFI_BAND,
    WIFI_RSSI,
    WIFI_REGION_CODE,
    SENSOR_RELAY_DATA_PAGE,
    SENSOR_RELAY_SUPPORTED_SENSORS,
    SENSOR_RELAY_PAIRED_SENSORS,
  ];

  static final $core.Map<$core.int, DO> _byValue = $pb.ProtobufEnum.initByValue(values);
  static DO? valueOf($core.int value) => _byValue[value];

  const DO._($core.int v, $core.String n) : super(v, n);
}

class Status extends $pb.ProtobufEnum {
  static const Status SUCCESS = Status._(0, _omitEnumNames ? '' : 'SUCCESS');
  static const Status FAILURE = Status._(1, _omitEnumNames ? '' : 'FAILURE');
  static const Status BUSY = Status._(2, _omitEnumNames ? '' : 'BUSY');
  static const Status INVALID_PARAM = Status._(3, _omitEnumNames ? '' : 'INVALID_PARAM');
  static const Status NOT_PERMITTED = Status._(4, _omitEnumNames ? '' : 'NOT_PERMITTED');
  static const Status NOT_SUPPORTED = Status._(5, _omitEnumNames ? '' : 'NOT_SUPPORTED');
  static const Status INVALID_MODE = Status._(6, _omitEnumNames ? '' : 'INVALID_MODE');

  static const $core.List<Status> values = <Status> [
    SUCCESS,
    FAILURE,
    BUSY,
    INVALID_PARAM,
    NOT_PERMITTED,
    NOT_SUPPORTED,
    INVALID_MODE,
  ];

  static final $core.Map<$core.int, Status> _byValue = $pb.ProtobufEnum.initByValue(values);
  static Status? valueOf($core.int value) => _byValue[value];

  const Status._($core.int v, $core.String n) : super(v, n);
}

class DeviceType extends $pb.ProtobufEnum {
  static const DeviceType UNDEFINED = DeviceType._(0, _omitEnumNames ? '' : 'UNDEFINED');
  static const DeviceType CYCLING_TURBO_TRAINER = DeviceType._(1, _omitEnumNames ? '' : 'CYCLING_TURBO_TRAINER');
  static const DeviceType USER_INPUT_DEVICE = DeviceType._(2, _omitEnumNames ? '' : 'USER_INPUT_DEVICE');
  static const DeviceType TREADMILL = DeviceType._(3, _omitEnumNames ? '' : 'TREADMILL');
  static const DeviceType SENSOR_RELAY = DeviceType._(4, _omitEnumNames ? '' : 'SENSOR_RELAY');
  static const DeviceType HEART_RATE_MONITOR = DeviceType._(5, _omitEnumNames ? '' : 'HEART_RATE_MONITOR');
  static const DeviceType POWER_METER = DeviceType._(6, _omitEnumNames ? '' : 'POWER_METER');
  static const DeviceType CADENCE_SENSOR = DeviceType._(7, _omitEnumNames ? '' : 'CADENCE_SENSOR');
  static const DeviceType WIFI = DeviceType._(8, _omitEnumNames ? '' : 'WIFI');

  static const $core.List<DeviceType> values = <DeviceType> [
    UNDEFINED,
    CYCLING_TURBO_TRAINER,
    USER_INPUT_DEVICE,
    TREADMILL,
    SENSOR_RELAY,
    HEART_RATE_MONITOR,
    POWER_METER,
    CADENCE_SENSOR,
    WIFI,
  ];

  static final $core.Map<$core.int, DeviceType> _byValue = $pb.ProtobufEnum.initByValue(values);
  static DeviceType? valueOf($core.int value) => _byValue[value];

  const DeviceType._($core.int v, $core.String n) : super(v, n);
}

class TrainerMode extends $pb.ProtobufEnum {
  static const TrainerMode MODE_UNKNOWN = TrainerMode._(0, _omitEnumNames ? '' : 'MODE_UNKNOWN');
  static const TrainerMode MODE_ERG = TrainerMode._(1, _omitEnumNames ? '' : 'MODE_ERG');
  static const TrainerMode MODE_RESISTANCE = TrainerMode._(2, _omitEnumNames ? '' : 'MODE_RESISTANCE');
  static const TrainerMode MODE_SIM = TrainerMode._(3, _omitEnumNames ? '' : 'MODE_SIM');

  static const $core.List<TrainerMode> values = <TrainerMode> [
    MODE_UNKNOWN,
    MODE_ERG,
    MODE_RESISTANCE,
    MODE_SIM,
  ];

  static final $core.Map<$core.int, TrainerMode> _byValue = $pb.ProtobufEnum.initByValue(values);
  static TrainerMode? valueOf($core.int value) => _byValue[value];

  const TrainerMode._($core.int v, $core.String n) : super(v, n);
}

class ChargingState extends $pb.ProtobufEnum {
  static const ChargingState CHARGING_IDLE = ChargingState._(0, _omitEnumNames ? '' : 'CHARGING_IDLE');
  static const ChargingState CHARGING_PROGRESS = ChargingState._(1, _omitEnumNames ? '' : 'CHARGING_PROGRESS');
  static const ChargingState CHARGING_DONE = ChargingState._(2, _omitEnumNames ? '' : 'CHARGING_DONE');

  static const $core.List<ChargingState> values = <ChargingState> [
    CHARGING_IDLE,
    CHARGING_PROGRESS,
    CHARGING_DONE,
  ];

  static final $core.Map<$core.int, ChargingState> _byValue = $pb.ProtobufEnum.initByValue(values);
  static ChargingState? valueOf($core.int value) => _byValue[value];

  const ChargingState._($core.int v, $core.String n) : super(v, n);
}

class SpindownStatus extends $pb.ProtobufEnum {
  static const SpindownStatus SPINDOWN_IDLE = SpindownStatus._(0, _omitEnumNames ? '' : 'SPINDOWN_IDLE');
  static const SpindownStatus SPINDOWN_REQUESTED = SpindownStatus._(1, _omitEnumNames ? '' : 'SPINDOWN_REQUESTED');
  static const SpindownStatus SPINDOWN_SUCCESS = SpindownStatus._(2, _omitEnumNames ? '' : 'SPINDOWN_SUCCESS');
  static const SpindownStatus SPINDOWN_ERROR = SpindownStatus._(3, _omitEnumNames ? '' : 'SPINDOWN_ERROR');
  static const SpindownStatus SPINDOWN_STOP_PEDALLING = SpindownStatus._(4, _omitEnumNames ? '' : 'SPINDOWN_STOP_PEDALLING');
  static const SpindownStatus SPINDOWN_ERROR_TIMEOUT = SpindownStatus._(5, _omitEnumNames ? '' : 'SPINDOWN_ERROR_TIMEOUT');
  static const SpindownStatus SPINDOWN_ERROR_TOSHORT = SpindownStatus._(6, _omitEnumNames ? '' : 'SPINDOWN_ERROR_TOSHORT');
  static const SpindownStatus SPINDOWN_ERROR_TOSLOW = SpindownStatus._(7, _omitEnumNames ? '' : 'SPINDOWN_ERROR_TOSLOW');
  static const SpindownStatus SPINDOWN_ERROR_TOFAST = SpindownStatus._(8, _omitEnumNames ? '' : 'SPINDOWN_ERROR_TOFAST');
  static const SpindownStatus SPINDOWN_ERROR_SAMPLEERROR = SpindownStatus._(9, _omitEnumNames ? '' : 'SPINDOWN_ERROR_SAMPLEERROR');
  static const SpindownStatus SPINDOWN_ERROR_ABORT = SpindownStatus._(10, _omitEnumNames ? '' : 'SPINDOWN_ERROR_ABORT');

  static const $core.List<SpindownStatus> values = <SpindownStatus> [
    SPINDOWN_IDLE,
    SPINDOWN_REQUESTED,
    SPINDOWN_SUCCESS,
    SPINDOWN_ERROR,
    SPINDOWN_STOP_PEDALLING,
    SPINDOWN_ERROR_TIMEOUT,
    SPINDOWN_ERROR_TOSHORT,
    SPINDOWN_ERROR_TOSLOW,
    SPINDOWN_ERROR_TOFAST,
    SPINDOWN_ERROR_SAMPLEERROR,
    SPINDOWN_ERROR_ABORT,
  ];

  static final $core.Map<$core.int, SpindownStatus> _byValue = $pb.ProtobufEnum.initByValue(values);
  static SpindownStatus? valueOf($core.int value) => _byValue[value];

  const SpindownStatus._($core.int v, $core.String n) : super(v, n);
}

class LogLevel extends $pb.ProtobufEnum {
  static const LogLevel LOGLEVEL_OFF = LogLevel._(0, _omitEnumNames ? '' : 'LOGLEVEL_OFF');
  static const LogLevel LOGLEVEL_ERROR = LogLevel._(1, _omitEnumNames ? '' : 'LOGLEVEL_ERROR');
  static const LogLevel LOGLEVEL_WARNING = LogLevel._(2, _omitEnumNames ? '' : 'LOGLEVEL_WARNING');
  static const LogLevel LOGLEVEL_INFO = LogLevel._(3, _omitEnumNames ? '' : 'LOGLEVEL_INFO');
  static const LogLevel LOGLEVEL_DEBUG = LogLevel._(4, _omitEnumNames ? '' : 'LOGLEVEL_DEBUG');
  static const LogLevel LOGLEVEL_TRACE = LogLevel._(5, _omitEnumNames ? '' : 'LOGLEVEL_TRACE');

  static const $core.List<LogLevel> values = <LogLevel> [
    LOGLEVEL_OFF,
    LOGLEVEL_ERROR,
    LOGLEVEL_WARNING,
    LOGLEVEL_INFO,
    LOGLEVEL_DEBUG,
    LOGLEVEL_TRACE,
  ];

  static final $core.Map<$core.int, LogLevel> _byValue = $pb.ProtobufEnum.initByValue(values);
  static LogLevel? valueOf($core.int value) => _byValue[value];

  const LogLevel._($core.int v, $core.String n) : super(v, n);
}

class RoadSurfaceType extends $pb.ProtobufEnum {
  static const RoadSurfaceType ROAD_SURFACE_SMOOTH_TARMAC = RoadSurfaceType._(0, _omitEnumNames ? '' : 'ROAD_SURFACE_SMOOTH_TARMAC');
  static const RoadSurfaceType ROAD_SURFACE_BRICK_ROAD = RoadSurfaceType._(1, _omitEnumNames ? '' : 'ROAD_SURFACE_BRICK_ROAD');
  static const RoadSurfaceType ROAD_SURFACE_HARD_COBBLES = RoadSurfaceType._(2, _omitEnumNames ? '' : 'ROAD_SURFACE_HARD_COBBLES');
  static const RoadSurfaceType ROAD_SURFACE_SOFT_COBBLES = RoadSurfaceType._(3, _omitEnumNames ? '' : 'ROAD_SURFACE_SOFT_COBBLES');
  static const RoadSurfaceType ROAD_SURFACE_NARROW_WOODEN_PLANKS = RoadSurfaceType._(4, _omitEnumNames ? '' : 'ROAD_SURFACE_NARROW_WOODEN_PLANKS');
  static const RoadSurfaceType ROAD_SURFACE_WIDE_WOODEN_PLANKS = RoadSurfaceType._(5, _omitEnumNames ? '' : 'ROAD_SURFACE_WIDE_WOODEN_PLANKS');
  static const RoadSurfaceType ROAD_SURFACE_DIRT = RoadSurfaceType._(6, _omitEnumNames ? '' : 'ROAD_SURFACE_DIRT');
  static const RoadSurfaceType ROAD_SURFACE_GRAVEL = RoadSurfaceType._(7, _omitEnumNames ? '' : 'ROAD_SURFACE_GRAVEL');
  static const RoadSurfaceType ROAD_SURFACE_CATTLE_GRID = RoadSurfaceType._(8, _omitEnumNames ? '' : 'ROAD_SURFACE_CATTLE_GRID');
  static const RoadSurfaceType ROAD_SURFACE_CONCRETE_FLAG_STONES = RoadSurfaceType._(9, _omitEnumNames ? '' : 'ROAD_SURFACE_CONCRETE_FLAG_STONES');
  static const RoadSurfaceType ROAD_SURFACE_ICE = RoadSurfaceType._(10, _omitEnumNames ? '' : 'ROAD_SURFACE_ICE');

  static const $core.List<RoadSurfaceType> values = <RoadSurfaceType> [
    ROAD_SURFACE_SMOOTH_TARMAC,
    ROAD_SURFACE_BRICK_ROAD,
    ROAD_SURFACE_HARD_COBBLES,
    ROAD_SURFACE_SOFT_COBBLES,
    ROAD_SURFACE_NARROW_WOODEN_PLANKS,
    ROAD_SURFACE_WIDE_WOODEN_PLANKS,
    ROAD_SURFACE_DIRT,
    ROAD_SURFACE_GRAVEL,
    ROAD_SURFACE_CATTLE_GRID,
    ROAD_SURFACE_CONCRETE_FLAG_STONES,
    ROAD_SURFACE_ICE,
  ];

  static final $core.Map<$core.int, RoadSurfaceType> _byValue = $pb.ProtobufEnum.initByValue(values);
  static RoadSurfaceType? valueOf($core.int value) => _byValue[value];

  const RoadSurfaceType._($core.int v, $core.String n) : super(v, n);
}

class WifiStatusCode extends $pb.ProtobufEnum {
  static const WifiStatusCode WIFI_STATUS_DISABLED = WifiStatusCode._(0, _omitEnumNames ? '' : 'WIFI_STATUS_DISABLED');
  static const WifiStatusCode WIFI_STATUS_NOT_PROVISIONED = WifiStatusCode._(1, _omitEnumNames ? '' : 'WIFI_STATUS_NOT_PROVISIONED');
  static const WifiStatusCode WIFI_STATUS_SCANNING = WifiStatusCode._(2, _omitEnumNames ? '' : 'WIFI_STATUS_SCANNING');
  static const WifiStatusCode WIFI_STATUS_DISCONNECTED = WifiStatusCode._(3, _omitEnumNames ? '' : 'WIFI_STATUS_DISCONNECTED');
  static const WifiStatusCode WIFI_STATUS_CONNECTING = WifiStatusCode._(4, _omitEnumNames ? '' : 'WIFI_STATUS_CONNECTING');
  static const WifiStatusCode WIFI_STATUS_CONNECTED = WifiStatusCode._(5, _omitEnumNames ? '' : 'WIFI_STATUS_CONNECTED');
  static const WifiStatusCode WIFI_STATUS_ERROR = WifiStatusCode._(6, _omitEnumNames ? '' : 'WIFI_STATUS_ERROR');

  static const $core.List<WifiStatusCode> values = <WifiStatusCode> [
    WIFI_STATUS_DISABLED,
    WIFI_STATUS_NOT_PROVISIONED,
    WIFI_STATUS_SCANNING,
    WIFI_STATUS_DISCONNECTED,
    WIFI_STATUS_CONNECTING,
    WIFI_STATUS_CONNECTED,
    WIFI_STATUS_ERROR,
  ];

  static final $core.Map<$core.int, WifiStatusCode> _byValue = $pb.ProtobufEnum.initByValue(values);
  static WifiStatusCode? valueOf($core.int value) => _byValue[value];

  const WifiStatusCode._($core.int v, $core.String n) : super(v, n);
}

class WifiErrorCode extends $pb.ProtobufEnum {
  static const WifiErrorCode WIFI_ERROR_UNKNOWN = WifiErrorCode._(0, _omitEnumNames ? '' : 'WIFI_ERROR_UNKNOWN');
  static const WifiErrorCode WIFI_ERROR_NO_MEMORY = WifiErrorCode._(1, _omitEnumNames ? '' : 'WIFI_ERROR_NO_MEMORY');
  static const WifiErrorCode WIFI_ERROR_INVALID_PARAMETERS = WifiErrorCode._(2, _omitEnumNames ? '' : 'WIFI_ERROR_INVALID_PARAMETERS');
  static const WifiErrorCode WIFI_ERROR_INVALID_STATE = WifiErrorCode._(3, _omitEnumNames ? '' : 'WIFI_ERROR_INVALID_STATE');
  static const WifiErrorCode WIFI_ERROR_NOT_FOUND = WifiErrorCode._(4, _omitEnumNames ? '' : 'WIFI_ERROR_NOT_FOUND');
  static const WifiErrorCode WIFI_ERROR_NOT_SUPPORTED = WifiErrorCode._(5, _omitEnumNames ? '' : 'WIFI_ERROR_NOT_SUPPORTED');
  static const WifiErrorCode WIFI_ERROR_NOT_ALLOWED = WifiErrorCode._(6, _omitEnumNames ? '' : 'WIFI_ERROR_NOT_ALLOWED');
  static const WifiErrorCode WIFI_ERROR_NOT_INITIALISED = WifiErrorCode._(7, _omitEnumNames ? '' : 'WIFI_ERROR_NOT_INITIALISED');
  static const WifiErrorCode WIFI_ERROR_NOT_STARTED = WifiErrorCode._(8, _omitEnumNames ? '' : 'WIFI_ERROR_NOT_STARTED');
  static const WifiErrorCode WIFI_ERROR_TIMEOUT = WifiErrorCode._(9, _omitEnumNames ? '' : 'WIFI_ERROR_TIMEOUT');
  static const WifiErrorCode WIFI_ERROR_MODE = WifiErrorCode._(10, _omitEnumNames ? '' : 'WIFI_ERROR_MODE');
  static const WifiErrorCode WIFI_ERROR_SSID_INVALID = WifiErrorCode._(11, _omitEnumNames ? '' : 'WIFI_ERROR_SSID_INVALID');

  static const $core.List<WifiErrorCode> values = <WifiErrorCode> [
    WIFI_ERROR_UNKNOWN,
    WIFI_ERROR_NO_MEMORY,
    WIFI_ERROR_INVALID_PARAMETERS,
    WIFI_ERROR_INVALID_STATE,
    WIFI_ERROR_NOT_FOUND,
    WIFI_ERROR_NOT_SUPPORTED,
    WIFI_ERROR_NOT_ALLOWED,
    WIFI_ERROR_NOT_INITIALISED,
    WIFI_ERROR_NOT_STARTED,
    WIFI_ERROR_TIMEOUT,
    WIFI_ERROR_MODE,
    WIFI_ERROR_SSID_INVALID,
  ];

  static final $core.Map<$core.int, WifiErrorCode> _byValue = $pb.ProtobufEnum.initByValue(values);
  static WifiErrorCode? valueOf($core.int value) => _byValue[value];

  const WifiErrorCode._($core.int v, $core.String n) : super(v, n);
}

class InterfaceType extends $pb.ProtobufEnum {
  static const InterfaceType INTERFACE_BLE = InterfaceType._(1, _omitEnumNames ? '' : 'INTERFACE_BLE');
  static const InterfaceType INTERFACE_ANT = InterfaceType._(2, _omitEnumNames ? '' : 'INTERFACE_ANT');
  static const InterfaceType INTERFACE_USB = InterfaceType._(3, _omitEnumNames ? '' : 'INTERFACE_USB');
  static const InterfaceType INTERFACE_ETH = InterfaceType._(4, _omitEnumNames ? '' : 'INTERFACE_ETH');
  static const InterfaceType INTERFACE_WIFI = InterfaceType._(5, _omitEnumNames ? '' : 'INTERFACE_WIFI');

  static const $core.List<InterfaceType> values = <InterfaceType> [
    INTERFACE_BLE,
    INTERFACE_ANT,
    INTERFACE_USB,
    INTERFACE_ETH,
    INTERFACE_WIFI,
  ];

  static final $core.Map<$core.int, InterfaceType> _byValue = $pb.ProtobufEnum.initByValue(values);
  static InterfaceType? valueOf($core.int value) => _byValue[value];

  const InterfaceType._($core.int v, $core.String n) : super(v, n);
}

class SensorConnectionStatus extends $pb.ProtobufEnum {
  static const SensorConnectionStatus SENSOR_STATUS_DISCOVERED = SensorConnectionStatus._(1, _omitEnumNames ? '' : 'SENSOR_STATUS_DISCOVERED');
  static const SensorConnectionStatus SENSOR_STATUS_DISCONNECTED = SensorConnectionStatus._(2, _omitEnumNames ? '' : 'SENSOR_STATUS_DISCONNECTED');
  static const SensorConnectionStatus SENSOR_STATUS_PAIRING = SensorConnectionStatus._(3, _omitEnumNames ? '' : 'SENSOR_STATUS_PAIRING');
  static const SensorConnectionStatus SENSOR_STATUS_CONNECTED = SensorConnectionStatus._(4, _omitEnumNames ? '' : 'SENSOR_STATUS_CONNECTED');

  static const $core.List<SensorConnectionStatus> values = <SensorConnectionStatus> [
    SENSOR_STATUS_DISCOVERED,
    SENSOR_STATUS_DISCONNECTED,
    SENSOR_STATUS_PAIRING,
    SENSOR_STATUS_CONNECTED,
  ];

  static final $core.Map<$core.int, SensorConnectionStatus> _byValue = $pb.ProtobufEnum.initByValue(values);
  static SensorConnectionStatus? valueOf($core.int value) => _byValue[value];

  const SensorConnectionStatus._($core.int v, $core.String n) : super(v, n);
}

class BleSecureConnectionStatus extends $pb.ProtobufEnum {
  static const BleSecureConnectionStatus BLE_CONNECTION_SECURITY_STATUS_NONE = BleSecureConnectionStatus._(0, _omitEnumNames ? '' : 'BLE_CONNECTION_SECURITY_STATUS_NONE');
  static const BleSecureConnectionStatus BLE_CONNECTION_SECURITY_STATUS_INPROGRESS = BleSecureConnectionStatus._(1, _omitEnumNames ? '' : 'BLE_CONNECTION_SECURITY_STATUS_INPROGRESS');
  static const BleSecureConnectionStatus BLE_CONNECTION_SECURITY_STATUS_ACTIVE = BleSecureConnectionStatus._(2, _omitEnumNames ? '' : 'BLE_CONNECTION_SECURITY_STATUS_ACTIVE');
  static const BleSecureConnectionStatus BLE_CONNECTION_SECURITY_STATUS_REJECTED = BleSecureConnectionStatus._(3, _omitEnumNames ? '' : 'BLE_CONNECTION_SECURITY_STATUS_REJECTED');

  static const $core.List<BleSecureConnectionStatus> values = <BleSecureConnectionStatus> [
    BLE_CONNECTION_SECURITY_STATUS_NONE,
    BLE_CONNECTION_SECURITY_STATUS_INPROGRESS,
    BLE_CONNECTION_SECURITY_STATUS_ACTIVE,
    BLE_CONNECTION_SECURITY_STATUS_REJECTED,
  ];

  static final $core.Map<$core.int, BleSecureConnectionStatus> _byValue = $pb.ProtobufEnum.initByValue(values);
  static BleSecureConnectionStatus? valueOf($core.int value) => _byValue[value];

  const BleSecureConnectionStatus._($core.int v, $core.String n) : super(v, n);
}

class BleSecureConnectionWindowStatus extends $pb.ProtobufEnum {
  static const BleSecureConnectionWindowStatus BLE_SECURE_CONNECTION_WINDOW_STATUS_CLOSED = BleSecureConnectionWindowStatus._(0, _omitEnumNames ? '' : 'BLE_SECURE_CONNECTION_WINDOW_STATUS_CLOSED');
  static const BleSecureConnectionWindowStatus BLE_SECURE_CONNECTION_WINDOW_STATUS_OPEN = BleSecureConnectionWindowStatus._(1, _omitEnumNames ? '' : 'BLE_SECURE_CONNECTION_WINDOW_STATUS_OPEN');

  static const $core.List<BleSecureConnectionWindowStatus> values = <BleSecureConnectionWindowStatus> [
    BLE_SECURE_CONNECTION_WINDOW_STATUS_CLOSED,
    BLE_SECURE_CONNECTION_WINDOW_STATUS_OPEN,
  ];

  static final $core.Map<$core.int, BleSecureConnectionWindowStatus> _byValue = $pb.ProtobufEnum.initByValue(values);
  static BleSecureConnectionWindowStatus? valueOf($core.int value) => _byValue[value];

  const BleSecureConnectionWindowStatus._($core.int v, $core.String n) : super(v, n);
}

class WifiRegionCode_RegionCodeType extends $pb.ProtobufEnum {
  static const WifiRegionCode_RegionCodeType ALPHA_2 = WifiRegionCode_RegionCodeType._(0, _omitEnumNames ? '' : 'ALPHA_2');
  static const WifiRegionCode_RegionCodeType ALPHA_3 = WifiRegionCode_RegionCodeType._(1, _omitEnumNames ? '' : 'ALPHA_3');
  static const WifiRegionCode_RegionCodeType NUMERIC = WifiRegionCode_RegionCodeType._(2, _omitEnumNames ? '' : 'NUMERIC');
  static const WifiRegionCode_RegionCodeType UNKNOWN = WifiRegionCode_RegionCodeType._(3, _omitEnumNames ? '' : 'UNKNOWN');

  static const $core.List<WifiRegionCode_RegionCodeType> values = <WifiRegionCode_RegionCodeType> [
    ALPHA_2,
    ALPHA_3,
    NUMERIC,
    UNKNOWN,
  ];

  static final $core.Map<$core.int, WifiRegionCode_RegionCodeType> _byValue = $pb.ProtobufEnum.initByValue(values);
  static WifiRegionCode_RegionCodeType? valueOf($core.int value) => _byValue[value];

  const WifiRegionCode_RegionCodeType._($core.int v, $core.String n) : super(v, n);
}


const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
