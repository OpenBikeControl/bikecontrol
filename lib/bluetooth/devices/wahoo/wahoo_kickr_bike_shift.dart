import 'dart:collection';

import 'package:bike_control/bluetooth/devices/wahoo/wahoo_kickr_bike_trainer.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../bluetooth_device.dart';

class WahooKickrBikeShift extends BluetoothDevice {
  WahooKickrBikeShift(super.scanResult)
    : super(
        availableButtons: WahooKickrBikeShiftConstants.prefixToButton.values.toList(),
      );

  /// The bike's trainer role, when its service discovery found a trainer
  /// service (see [WahooKickrBikeTrainer]); null for a bike that exposes only
  /// its shifters, which then stays a controller exactly as before.
  WahooKickrBikeTrainer? get trainer => _trainer;
  WahooKickrBikeTrainer? _trainer;

  /// A smart bike's link is not a battery to save, and cutting it would take a
  /// running bridge down with it — mid-ride, without a single button press.
  @override
  bool get exemptFromBatterySaver => _trainer?.isConnectedOrConnecting ?? false;

  @override
  Future<void> handleServices(List<BleService> services) async {
    final service = services.firstOrNullWhere((e) => e.uuid == WahooKickrBikeShiftConstants.SERVICE_UUID);
    final characteristic = service?.characteristics.firstOrNullWhere(
      (e) => e.uuid == WahooKickrBikeShiftConstants.CHARACTERISTIC_UUID,
    );

    if (characteristic != null) {
      await UniversalBle.subscribeNotifications(device.deviceId, service!.uuid, characteristic.uuid);
    }

    await _attachTrainer(services);

    if (characteristic == null) {
      final missing = service == null
          ? 'Service not found: ${WahooKickrBikeShiftConstants.SERVICE_UUID}'
          : 'Characteristic not found: ${WahooKickrBikeShiftConstants.CHARACTERISTIC_UUID}';
      // Nothing to offer without the shifters unless the bike is a trainer.
      if (_trainer == null) throw Exception(missing);
      core.connection.signalNotification(LogNotification('$this: $missing — trainer only'));
    }
  }

  /// Lists the bike a second time, as a trainer, when it exposes a trainer
  /// service — over this same connection. Not on web, where BikeControl has no
  /// trainer bridge at all.
  Future<void> _attachTrainer(List<BleService> services) async {
    if (kIsWeb) return;
    // A previous connection's role cannot outlive it (see [disconnect]); this
    // only guards a repeated discovery on the same link.
    await _releaseTrainer();
    final trainer = WahooKickrBikeTrainer.forHost(this, services);
    if (trainer == null) return;
    _trainer = trainer;
    core.connection.signalNotification(LogNotification('$this: trainer services found, also listed as a trainer'));
    core.connection.addDevices([trainer]);
  }

  /// Removes the trainer role together with this connection, so the bike is
  /// never left listed as a trainer whose link is gone.
  Future<void> _releaseTrainer() async {
    final trainer = _trainer;
    _trainer = null;
    if (trainer == null) return;
    try {
      await core.connection.disconnect(
        trainer,
        forget: false,
        persistForget: false,
        dropped: trainer.isConnectedOrConnecting,
      );
    } catch (e, s) {
      await recordError(e, s, context: 'KICKR BIKE: release trainer role');
    }
  }

  @override
  Future<void> disconnect() async {
    await _releaseTrainer();
    return super.disconnect();
  }

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) {
    // Notifications are routed by device id, which the trainer role shares —
    // everything that is not a shifter frame is the trainer's.
    if (characteristic != WahooKickrBikeShiftConstants.CHARACTERISTIC_UUID) {
      return _trainer?.processCharacteristic(characteristic, bytes) ?? Future.value();
    }
    final hex = toHex(bytes);

    // Short-frame detection (hard-coded families)
    final s = parseShortFrame(hex);
    if (s != null) {
      if (s.pressed) {
        handleButtonsClicked([s.button]);
      } else {
        handleButtonsClicked([]);
      }
    }
    return Future.value();
  }

  // Deduplicate per (prefix, type) using the 7-bit rolling sequence
  final Map<String, int> lastSeqByPrefix = HashMap<String, int>();

  String toHex(Uint8List bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();

  // Parse short frames like "PPQQRR" (e.g., "0001E6", "80005E", "40008F", "010004")
  ShortFrame? parseShortFrame(String hex) {
    final re = RegExp(r'^[0-9A-F]{6}$', caseSensitive: false);
    if (!re.hasMatch(hex)) return null;

    final prefix = hex.substring(0, 4); // PPQQ
    final rrHex = hex.substring(4, 6); // RR
    if (!WahooKickrBikeShiftConstants.prefixToButton.containsKey(prefix)) return null;

    final idx = int.parse(rrHex, radix: 16);
    final type = (idx & 0x80) != 0 ? true : false; // MSB of RR
    final seq = idx & 0x7F; // rolling counter for dedupe

    return ShortFrame(
      prefix: prefix,
      rrHex: rrHex,
      idx: idx,
      pressed: type,
      seq: seq,
      button: WahooKickrBikeShiftConstants.prefixToButton[prefix]!,
    );
  }

  bool isLongFrame(String hex) {
    final re = RegExp(r'^FF0F01', caseSensitive: false);
    return re.hasMatch(hex);
  }

  // Returns true if this (prefix,type,seq) has not been handled yet
  bool shouldHandleOnce(String prefix, String type, int seq) {
    final key = '$prefix:$type';
    final last = lastSeqByPrefix[key];
    if (last == seq) return false;
    lastSeqByPrefix[key] = seq;
    return true;
  }
}

class ShortFrame {
  final String prefix; // PPQQ
  final String rrHex; // RR
  final int idx;
  final bool pressed;
  final int seq;
  final ControllerButton button;

  ShortFrame({
    required this.prefix,
    required this.rrHex,
    required this.idx,
    required this.pressed,
    required this.seq,
    required this.button,
  });
}

class WahooKickrBikeShiftConstants {
  static const String SERVICE_UUID = "a026ee0d-0a7d-4ab3-97fa-f1500f9feb8b";
  static const String CHARACTERISTIC_UUID = "a026e03c-0a7d-4ab3-97fa-f1500f9feb8b";

  // https://support.wahoofitness.com/hc/en-us/articles/22259367275410-Shifter-and-button-configuration-for-KICKR-BIKE-1-2
  static const Map<String, ControllerButton> prefixToButton = {
    '0001': WahooKickrShiftButtons.rightUp, //'Right Up',
    '8000': WahooKickrShiftButtons.rightDown, //'Right Down',
    '0008': WahooKickrShiftButtons.rightSteer, //'Right Steer',
    '0200': WahooKickrShiftButtons.leftUp, // 'Left Up',
    '0400': WahooKickrShiftButtons.leftDown, //'Left Down',
    '2000': WahooKickrShiftButtons.leftSteer, //'Left Steer',
    '0004': WahooKickrShiftButtons.shiftUpRight, // 'Right Shift Up',
    '0002': WahooKickrShiftButtons.shiftDownRight, // 'Right Shift Down',
    '1000': WahooKickrShiftButtons.shiftUpLeft, //'Left Shift Up',
    '0800': WahooKickrShiftButtons.shiftDownLeft, //'Left Shift Down',
    '4000': WahooKickrShiftButtons.rightBrake, //'Right Brake',
    '0100': WahooKickrShiftButtons.leftBrake, //'Left Brake',
  };
}

class WahooKickrShiftButtons {
  static const ControllerButton leftSteer = ControllerButton(
    'leftSteer',
    action: InGameAction.navigateLeft,
    icon: LucideIcons.chevronLeft,
    color: Colors.black,
  );
  static const ControllerButton rightSteer = ControllerButton(
    'rightSteer',
    action: InGameAction.navigateRight,
    icon: LucideIcons.chevronRight,
    color: Colors.black,
  );
  static const ControllerButton leftDown = ControllerButton('leftDown', action: InGameAction.shiftDown);
  static const ControllerButton leftBrake = ControllerButton('leftBrake', action: InGameAction.shiftDown);

  static const ControllerButton shiftUpLeft = ControllerButton(
    'shiftUpLeft',
    action: InGameAction.shiftDown,
    icon: LucideIcons.minus,
    color: Colors.black,
  );
  static const ControllerButton shiftDownLeft = ControllerButton(
    'shiftDownLeft',
    action: InGameAction.shiftDown,
    icon: LucideIcons.minus,
    color: Colors.black,
  );
  static const ControllerButton leftUp = ControllerButton('leftUp', action: InGameAction.shiftDown);

  static const ControllerButton rightDown = ControllerButton('rightDown', action: InGameAction.shiftUp);
  static const ControllerButton rightBrake = ControllerButton('rightBrake', action: InGameAction.shiftUp);

  static const ControllerButton shiftUpRight = ControllerButton(
    'shiftUpRight',
    action: InGameAction.shiftUp,
    icon: LucideIcons.plus,
    color: Colors.black,
  );
  static const ControllerButton shiftDownRight = ControllerButton('shiftDownRight', action: InGameAction.shiftUp);
  static const ControllerButton rightUp = ControllerButton('rightUp', action: InGameAction.shiftUp);

  static const List<ControllerButton> values = [
    leftSteer,
    rightSteer,
    leftDown,
    leftBrake,
    shiftUpLeft,
    shiftDownLeft,
    leftUp,
    rightDown,
    rightBrake,
    shiftUpRight,
    shiftDownRight,
    rightUp,
  ];
}
