import 'dart:math' as math;

import 'package:bike_control/bluetooth/devices/smart_bike/smart_bike_trainer.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/prop.dart' show Logger;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../bluetooth_device.dart';

/// A Tacx NEO Bike (Smart / Plus): one peripheral that is both a smart
/// trainer and the host of its own shifters. The shifters are read from the
/// bike's vendor service; its trainer services are listed a second time as a
/// [SmartBikeTrainer] over the same link.
///
/// The bike reports the gear it is in, not the lever presses, so a shift is
/// a change of the reported gear. Beta: decoded without the hardware, every
/// vendor frame is logged for the support bundle.
class TacxNeoBike extends BluetoothDevice with SmartBikeHost {
  TacxNeoBike(super.scanResult) : super(availableButtons: TacxNeoBikeButtons.values, isBeta: true);

  /// Test seam for control point writes.
  @visibleForTesting
  Future<void> Function(Uint8List bytes)? debugControlPointSink;

  int? _features;
  BleCharacteristic? _controlPoint;
  String? _serviceUuid;

  final TacxShiftDetector _shifts = TacxShiftDetector();
  Set<ControllerButton> _held = const {};

  int _gearConfigRequests = 0;
  int _gearFramesWithoutTables = 0;

  /// Per characteristic: frames seen, and the last frame, for logging.
  final Map<String, int> _frameCounts = {};
  final Map<String, String> _lastFrames = {};

  static const _maxGearConfigRequests = 3;

  /// The first frames of every characteristic always reach the log; after
  /// that only the ones that differ from the last.
  static const _alwaysLoggedFrames = 20;

  @override
  Set<String> get controllerServiceUuids => {TacxNeoBikeConstants.SERVICE_UUID};

  @override
  Set<String> get controllerCharacteristicUuids => TacxNeoBikeConstants.characteristicNames.keys.toSet();

  @visibleForTesting
  TacxShiftDetector get shiftDetector => _shifts;

  void _log(String message) => actionStreamInternal.add(LogNotification('$this [Tacx beta]: $message'));

  @override
  Future<void> handleServices(List<BleService> services) async {
    final service = services.firstOrNullWhere((e) => e.uuid.toLowerCase() == TacxNeoBikeConstants.SERVICE_UUID);

    if (service != null) {
      _serviceUuid = service.uuid;
      _log(
        'vendor service found: ${service.characteristics.map((c) => '${TacxNeoBikeConstants.describe(c.uuid)}[${c.properties.map((p) => p.name).join(',')}]').join(' ')}',
      );
      await _subscribe(service);
      await _readFeatures(service);
      await _requestGearConfiguration(reason: 'connect');
    }

    await attachTrainer(services);

    if (service == null) {
      final missing = 'Service not found: ${TacxNeoBikeConstants.SERVICE_UUID}';
      _log(
        '$missing (firmware older than 4.5.0?). Services: ${services.map((s) => s.uuid).join(', ')}',
      );
      // Nothing to offer without the shifters unless the bike is a trainer.
      if (trainer == null) throw Exception(missing);
      _log('trainer only');
    }
  }

  Future<void> _subscribe(BleService service) async {
    for (final characteristic in service.characteristics) {
      final uuid = characteristic.uuid.toLowerCase();
      if (!TacxNeoBikeConstants.characteristicNames.containsKey(uuid)) continue;
      final props = characteristic.properties;
      try {
        if (props.contains(CharacteristicProperty.notify)) {
          await UniversalBle.subscribeNotifications(device.deviceId, service.uuid, characteristic.uuid);
          _log('subscribed (notify) ${TacxNeoBikeConstants.describe(uuid)}');
        } else if (props.contains(CharacteristicProperty.indicate)) {
          await UniversalBle.subscribeIndications(device.deviceId, service.uuid, characteristic.uuid);
          _log('subscribed (indicate) ${TacxNeoBikeConstants.describe(uuid)}');
        }
      } catch (e, s) {
        _log('subscribe ${TacxNeoBikeConstants.describe(uuid)} failed: $e');
        await recordError(e, s, context: 'TacxNeoBike: subscribe $uuid');
      }
      if (uuid == TacxNeoBikeConstants.CONTROL_POINT_UUID) _controlPoint = characteristic;
    }
  }

  Future<void> _readFeatures(BleService service) async {
    final characteristic = service.characteristics.firstOrNullWhere(
      (c) => c.uuid.toLowerCase() == TacxNeoBikeConstants.FEATURES_UUID,
    );
    if (characteristic == null) {
      _log('no features characteristic');
      return;
    }
    if (!characteristic.properties.contains(CharacteristicProperty.read)) return;
    try {
      final bytes = await UniversalBle.read(device.deviceId, service.uuid, characteristic.uuid);
      await processCharacteristic(characteristic.uuid, bytes);
    } catch (e, s) {
      _log('read features failed: $e');
      await recordError(e, s, context: 'TacxNeoBike: read features');
    }
  }

  /// Asks for the front and rear gear tables. Without them a shift still
  /// counts, just always as one gear.
  Future<void> _requestGearConfiguration({required String reason}) async {
    final features = _features;
    if (features != null && features & TacxNeoBikeConstants.FEATURE_GEAR_CONFIGURATION == 0) return;
    if (_gearConfigRequests >= _maxGearConfigRequests) return;
    _gearConfigRequests++;
    _log('requesting gear tables ($reason, attempt $_gearConfigRequests)');
    await _writeControlPoint(Uint8List.fromList([TacxNeoBikeConstants.OPCODE_FRONT_GEARS]));
    await _writeControlPoint(Uint8List.fromList([TacxNeoBikeConstants.OPCODE_REAR_GEARS]));
  }

  Future<void> _writeControlPoint(Uint8List bytes) async {
    Logger.trace(
      () => '$this tacx> ${TacxNeoBikeConstants.describe(TacxNeoBikeConstants.CONTROL_POINT_UUID)} ${_hex(bytes)}',
    );
    try {
      if (debugControlPointSink != null) {
        await debugControlPointSink!(bytes);
        return;
      }
      final cp = _controlPoint;
      final serviceUuid = _serviceUuid;
      if (cp == null || serviceUuid == null) {
        _log('no control point, cannot write ${_hex(bytes)}');
        return;
      }
      final withoutResponse =
          !cp.properties.contains(CharacteristicProperty.write) &&
          cp.properties.contains(CharacteristicProperty.writeWithoutResponse);
      await UniversalBle.write(device.deviceId, serviceUuid, cp.uuid, bytes, withoutResponse: withoutResponse);
    } catch (e, s) {
      _log('control point write ${_hex(bytes)} failed: $e');
      await recordError(e, s, context: 'TacxNeoBike: control point write');
    }
  }

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) async {
    if (!isControllerCharacteristic(characteristic)) {
      return forwardToTrainer(characteristic, bytes);
    }
    final uuid = characteristic.toLowerCase();
    _logFrame(uuid, bytes);

    switch (uuid) {
      case TacxNeoBikeConstants.FEATURES_UUID:
        _handleFeatures(bytes);
      case TacxNeoBikeConstants.ERRORS_UUID:
        _log('error/diagnostic frame ${_hex(bytes)}');
      case TacxNeoBikeConstants.GEAR_STATUS_UUID:
        await _handleGearStatus(bytes);
      case TacxNeoBikeConstants.BUTTONS_UUID:
        await _handleButtons(bytes);
      case TacxNeoBikeConstants.CONTROL_POINT_UUID:
        _handleControlPointResponse(bytes);
      default:
        break;
    }
  }

  void _logFrame(String uuid, Uint8List bytes) {
    final hex = _hex(bytes);
    final name = TacxNeoBikeConstants.describe(uuid);
    Logger.trace(() => '$this tacx< $name $hex');
    final count = (_frameCounts[uuid] ?? 0) + 1;
    _frameCounts[uuid] = count;
    final changed = _lastFrames[uuid] != hex;
    _lastFrames[uuid] = hex;
    if (count <= _alwaysLoggedFrames || changed) {
      _log('$name #$count $hex');
    }
  }

  void _handleFeatures(Uint8List bytes) {
    if (bytes.isEmpty) return;
    final features = bytes.length >= 2 ? bytes[0] | (bytes[1] << 8) : bytes[0];
    _features = features;
    _log('features 0x${features.toRadixString(16)}: ${TacxNeoBikeConstants.describeFeatures(features)}');
  }

  void _handleControlPointResponse(Uint8List bytes) {
    final response = TacxControlPointResponse.parse(bytes);
    if (response == null) {
      _log('control point frame not understood: ${_hex(bytes)}');
      return;
    }
    if (!response.isSuccess) {
      _log('request ${response.opcode} failed with result ${response.result}');
      return;
    }
    switch (response.opcode) {
      case TacxNeoBikeConstants.OPCODE_FRONT_GEARS:
        final table = response.gearTable;
        _shifts.frontTable = table;
        _log('front gear table: $table');
      case TacxNeoBikeConstants.OPCODE_REAR_GEARS:
        final table = response.gearTable;
        _shifts.rearTable = table;
        _log('rear gear table: $table');
      default:
        _log('response to request ${response.opcode}: ${_hex(response.payload)}');
    }
  }

  Future<void> _handleGearStatus(Uint8List bytes) async {
    final status = TacxGearStatus.parse(bytes);
    if (status == null) {
      _log('gear status not understood: ${_hex(bytes)}');
      return;
    }
    if (_shifts.frontTable == null || _shifts.rearTable == null) {
      // The bike may not answer right after connecting; ask again later.
      if (++_gearFramesWithoutTables % 10 == 0) {
        await _requestGearConfiguration(reason: 'no tables after $_gearFramesWithoutTables gear frames');
      }
    }
    final shifts = _shifts.update(front: status.front, rear: status.rear);
    if (shifts.isEmpty) return;
    _log(
      'gear ${_shifts.describe()} → ${shifts.map((b) => b.name).join(', ')}',
    );
    for (final button in shifts) {
      await handleButtonsClicked([button]);
      await handleButtonsClicked([]);
    }
  }

  Future<void> _handleButtons(Uint8List bytes) async {
    final status = TacxButtonStatus.parse(bytes);
    if (status == null) {
      _log('button frame not understood: ${_hex(bytes)}');
      return;
    }
    final held = {..._held};
    void apply(bool? pressed, ControllerButton button) {
      if (pressed == null) return;
      if (pressed) {
        held.add(button);
      } else {
        held.remove(button);
      }
    }

    apply(status.left, TacxNeoBikeButtons.leftButton);
    apply(status.right, TacxNeoBikeButtons.rightButton);
    if (held.length == _held.length && held.containsAll(_held)) return;
    _held = held;
    _log('buttons held: ${held.isEmpty ? 'none' : held.map((b) => b.name).join(', ')}');
    await handleButtonsClicked(held.toList());
  }

  @override
  Future<void> disconnect() {
    _held = const {};
    _shifts.reset();
    _features = null;
    _controlPoint = null;
    _serviceUuid = null;
    _gearConfigRequests = 0;
    _gearFramesWithoutTables = 0;
    _frameCounts.clear();
    _lastFrames.clear();
    return super.disconnect();
  }

  static String _hex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
}

/// Turns the gear the bike reports into shift presses.
///
/// Gear values are teeth counts: fewer teeth at the rear, or more at the
/// front, is a harder gear. With the bike's gear tables a jump of several
/// gears is several presses; without them every change is one.
class TacxShiftDetector {
  List<int>? frontTable;
  List<int>? rearTable;

  int? _front;
  int? _rear;

  /// Never more presses than this for one frame — a bogus value must not
  /// fire a burst of shifts.
  static const maxStepsPerFrame = 12;

  void reset() {
    frontTable = null;
    rearTable = null;
    _front = null;
    _rear = null;
  }

  String describe() => 'front=${_front ?? '-'} rear=${_rear ?? '-'}';

  /// The presses the change to [front] / [rear] means; a null value is one
  /// the frame did not carry. The first values seen only set the start.
  List<ControllerButton> update({int? front, int? rear}) {
    final presses = <ControllerButton>[];
    if (front != null) {
      final previous = _front;
      _front = front;
      if (previous != null && previous != front) {
        final harder = front > previous;
        final steps = _steps(frontTable, previous, front);
        presses.addAll(
          List.filled(steps, harder ? TacxNeoBikeButtons.frontUp : TacxNeoBikeButtons.frontDown),
        );
      }
    }
    if (rear != null) {
      final previous = _rear;
      _rear = rear;
      if (previous != null && previous != rear) {
        final harder = rear < previous;
        final steps = _steps(rearTable, previous, rear);
        presses.addAll(
          List.filled(steps, harder ? TacxNeoBikeButtons.rearUp : TacxNeoBikeButtons.rearDown),
        );
      }
    }
    return presses;
  }

  static int _steps(List<int>? table, int from, int to) {
    if (table == null) return 1;
    final a = table.indexOf(from);
    final b = table.indexOf(to);
    if (a < 0 || b < 0) return 1;
    return math.min((a - b).abs(), maxStepsPerFrame).clamp(1, maxStepsPerFrame);
  }
}

/// A gear status frame: a flags byte, then the front gear (flag 0x01, byte 1)
/// and the rear gear (flag 0x02, last byte).
class TacxGearStatus {
  const TacxGearStatus({this.front, this.rear});

  final int? front;
  final int? rear;

  static TacxGearStatus? parse(Uint8List bytes) {
    if (bytes.isEmpty) return null;
    final flags = bytes[0];
    int? front;
    int? rear;
    if (flags & 0x01 != 0) {
      if (bytes.length < 2) return null;
      front = bytes[1];
    }
    if (flags & 0x02 != 0) {
      if (bytes.length < (front != null ? 3 : 2)) return null;
      rear = bytes[bytes.length - 1];
    }
    if (front == null && rear == null) return null;
    return TacxGearStatus(front: front, rear: rear);
  }
}

/// A button frame: a flags byte, then the left button (flag 0x01, byte 1)
/// and the right button (flag 0x02, last byte); bit 7 set is pressed.
class TacxButtonStatus {
  const TacxButtonStatus({this.left, this.right});

  final bool? left;
  final bool? right;

  static TacxButtonStatus? parse(Uint8List bytes) {
    if (bytes.isEmpty) return null;
    final flags = bytes[0];
    bool? left;
    bool? right;
    if (flags & 0x01 != 0) {
      if (bytes.length < 2) return null;
      left = bytes[1] & 0x80 != 0;
    }
    if (flags & 0x02 != 0) {
      if (bytes.length < (left != null ? 3 : 2)) return null;
      right = bytes[bytes.length - 1] & 0x80 != 0;
    }
    if (left == null && right == null) return null;
    return TacxButtonStatus(left: left, right: right);
  }
}

/// A control point response: `20 <opcode> <result> <payload…>`, result 1 is
/// success. A gear table payload is `<count> <value…>`.
class TacxControlPointResponse {
  const TacxControlPointResponse({required this.opcode, required this.result, required this.payload});

  final int opcode;
  final int result;
  final Uint8List payload;

  static const responseCode = 0x20;
  static const success = 0x01;

  bool get isSuccess => result == success;

  List<int> get gearTable {
    if (payload.isEmpty) return const [];
    final count = payload[0];
    return payload.sublist(1, math.min(payload.length, 1 + count)).toList();
  }

  static TacxControlPointResponse? parse(Uint8List bytes) {
    if (bytes.length < 3 || bytes[0] != responseCode) return null;
    return TacxControlPointResponse(opcode: bytes[1], result: bytes[2], payload: bytes.sublist(3));
  }
}

class TacxNeoBikeConstants {
  static const String SERVICE_UUID = 'fe031000-17d0-470a-8798-4ad3e1c1f35b';
  static const String FEATURES_UUID = 'fe031001-17d0-470a-8798-4ad3e1c1f35b';
  static const String ERRORS_UUID = 'fe031002-17d0-470a-8798-4ad3e1c1f35b';
  static const String GEAR_STATUS_UUID = 'fe031003-17d0-470a-8798-4ad3e1c1f35b';
  static const String BUTTONS_UUID = 'fe031004-17d0-470a-8798-4ad3e1c1f35b';
  static const String UNKNOWN_1008_UUID = 'fe031008-17d0-470a-8798-4ad3e1c1f35b';
  static const String CONTROL_POINT_UUID = 'fe03100f-17d0-470a-8798-4ad3e1c1f35b';

  static const Map<String, String> characteristicNames = {
    FEATURES_UUID: 'features',
    ERRORS_UUID: 'errors',
    GEAR_STATUS_UUID: 'gears',
    BUTTONS_UUID: 'buttons',
    UNKNOWN_1008_UUID: '1008',
    CONTROL_POINT_UUID: 'control',
  };

  static const int FEATURE_ERRORS = 0x01;
  static const int FEATURE_GEAR_STATUS = 0x02;
  static const int FEATURE_BUTTONS = 0x04;
  static const int FEATURE_WEIGHT = 0x20;
  static const int FEATURE_GEAR_CONFIGURATION = 0x80;

  static const int OPCODE_FRONT_GEARS = 0x04;
  static const int OPCODE_REAR_GEARS = 0x05;

  static String describe(String uuid) => characteristicNames[uuid.toLowerCase()] ?? uuid;

  static String describeFeatures(int features) {
    const names = {
      FEATURE_ERRORS: 'errors',
      FEATURE_GEAR_STATUS: 'gear status',
      FEATURE_BUTTONS: 'buttons',
      FEATURE_WEIGHT: 'weight',
      FEATURE_GEAR_CONFIGURATION: 'gear tables',
    };
    final known = [
      for (final entry in names.entries)
        if (features & entry.key != 0) entry.value,
    ];
    final unknown = features & ~names.keys.fold<int>(0, (a, b) => a | b);
    return [...known, if (unknown != 0) 'unknown 0x${unknown.toRadixString(16)}'].join(', ');
  }

  /// The bike advertises as `Tacx Neo Bike …` / `NEO Bike …` (Smart, Plus);
  /// the plain trainers (`Tacx Neo 2T …`) never carry "BIKE".
  static bool matchesName(String name) {
    final upper = name.toUpperCase();
    final tacxOrNeo = upper.startsWith('TACX') || upper.startsWith('NEO');
    return tacxOrNeo && upper.contains('BIKE');
  }
}

class TacxNeoBikeButtons {
  static const ControllerButton rearUp = ControllerButton(
    'tacxRearUp',
    action: InGameAction.shiftUp,
    icon: LucideIcons.plus,
    color: Colors.black,
  );
  static const ControllerButton rearDown = ControllerButton(
    'tacxRearDown',
    action: InGameAction.shiftDown,
    icon: LucideIcons.minus,
    color: Colors.black,
  );
  static const ControllerButton frontUp = ControllerButton(
    'tacxFrontUp',
    action: InGameAction.shiftUp,
    icon: LucideIcons.chevronsUp,
    color: Colors.black,
  );
  static const ControllerButton frontDown = ControllerButton(
    'tacxFrontDown',
    action: InGameAction.shiftDown,
    icon: LucideIcons.chevronsDown,
    color: Colors.black,
  );
  static const ControllerButton leftButton = ControllerButton(
    'tacxLeftButton',
    action: InGameAction.steerLeft,
    icon: LucideIcons.chevronLeft,
    color: Colors.black,
  );
  static const ControllerButton rightButton = ControllerButton(
    'tacxRightButton',
    action: InGameAction.steerRight,
    icon: LucideIcons.chevronRight,
    color: Colors.black,
  );

  static const List<ControllerButton> values = [
    rearUp,
    rearDown,
    frontUp,
    frontDown,
    leftButton,
    rightButton,
  ];
}
