import 'dart:async';

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/protocol_parser.dart';
import 'package:bike_control/bluetooth/devices/steering_device.dart';
import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:flutter/foundation.dart';

/// An OpenBikeControl transport (BLE or network) that can carry the `0x1B`
/// Steering Angle to the app connected to it.
abstract interface class SteeringAngleSink {
  /// The app on the other end, once it sent its App Information.
  ValueListenable<AppInfo?> get connectedApp;

  /// An app is attached and a message can go out right now.
  bool get canSendSteeringAngle;

  /// Sends a button-state message carrying only `0x1B` = [value].
  Future<void> sendSteeringAngle(int value);
}

/// Whether [app] should receive the angle at all: only when it listed `0x1B`
/// in its App Information. The protocol allows sending it alongside Steer
/// Left / Right to every app, but an app that predates `0x1B` may reject a
/// message with an ID it doesn't know, so the angle is opt-in.
bool appWantsSteeringAngle(AppInfo app) => app.supportsSteeringAngle;

/// Steer Left / Right presses from an angle input are left out for an app
/// that listed `0x1B`: it steers from the angle, which is already streaming
/// for every button of [keyPair]. Presses from plain buttons (a controller
/// key mapped to Steer Left) are never dropped.
bool steersByAngleOnly(AppInfo app, KeyPair keyPair) =>
    app.supportsSteeringAngle &&
    (keyPair.inGameAction == InGameAction.steerLeft || keyPair.inGameAction == InGameAction.steerRight) &&
    keyPair.buttons.isNotEmpty &&
    keyPair.buttons.every(core.obcSteeringAngle.coversSteeringButton);

/// The same conditions under which this device's Steer Left / Right presses
/// would reach the trainer app: one of its steering buttons is mapped to a
/// steering action in the active keymap, the mapping is not a Pro action the
/// rider lacks, and the daily command budget is not used up. Angle updates
/// themselves don't spend commands.
bool obcSteeringAngleAllowed(SteeringDevice device) {
  final keymap = core.actionHandler.supportedApp?.keymap;
  if (keymap == null) return false;
  final pairs = [
    ...keymap.getKeyPairs(device.steerLeftButton),
    ...keymap.getKeyPairs(device.steerRightButton),
  ].where((kp) => kp.inGameAction == InGameAction.steerLeft || kp.inGameAction == InGameAction.steerRight);
  if (pairs.isEmpty) return false;
  final iap = IAPManager.instance;
  if (pairs.every((kp) => kp.isProAction) && !iap.isProEnabledForCurrentDevice) return false;
  return iap.canExecuteCommand;
}

/// Streams each connected [SteeringDevice]'s calibrated angle to the connected
/// OpenBikeControl apps as `0x1B` Steering Angle, alongside the existing
/// Steer Left / Right presses (the thresholded output of the same angle).
///
/// Per device: sent whenever the encoded value changes, at most once per
/// [minInterval] (≤ 30 Hz); a value that changes inside the window is sent
/// when the window closes, so the app always ends on the settled angle.
/// `0x00` goes out when the angle becomes unavailable — recalibration, the
/// gate closing, or the device going away ([detach]).
class ObcSteeringAngleBroadcaster {
  ObcSteeringAngleBroadcaster({
    required Iterable<SteeringAngleSink> Function() sinks,
    required bool Function(SteeringDevice device) isAllowed,
    this.minInterval = const Duration(milliseconds: 34),
  }) : _sinks = sinks,
       _isAllowed = isAllowed;

  final Iterable<SteeringAngleSink> Function() _sinks;
  final bool Function(SteeringDevice device) _isAllowed;

  /// 34 ms rather than 33.3 so no one-second window can hold a 31st message.
  final Duration minInterval;

  final Map<SteeringDevice, _Track> _tracks = {};
  final List<VoidCallback> _disposers = [];

  /// Starts (or resumes) streaming [device]'s angle.
  void attach(SteeringDevice device) {
    final existing = _tracks[device];
    if (existing != null && !existing.detached) return;
    final track = existing ?? _Track(device);
    track.detached = false;
    _tracks[device] = track;
    track.listener = () => _offer(track, _target(device));
    device.steeringAngle.addListener(track.listener!);
    device.steeringCalibrated.addListener(track.listener!);
    _offer(track, _target(device));
  }

  /// Stops streaming [device]'s angle and tells the apps it is unavailable.
  void detach(SteeringDevice device) {
    final track = _tracks[device];
    if (track == null || track.detached) return;
    _unlisten(track);
    track.detached = true;
    _offer(track, OpenBikeProtocolParser.STEERING_ANGLE_UNAVAILABLE);
  }

  /// Follows the connection's device events: a [SteeringDevice] that is
  /// connected is attached, one that is not is detached.
  void watchDevices(Stream<BaseDevice> deviceChanges) {
    final sub = deviceChanges.listen((device) {
      if (device is! SteeringDevice) return;
      if (device.isConnected) {
        attach(device as SteeringDevice);
      } else {
        detach(device as SteeringDevice);
      }
    });
    _disposers.add(sub.cancel);
  }

  /// An app connecting later gets the current angles at once instead of
  /// waiting for the handlebar to move.
  void watchApps(Iterable<SteeringAngleSink> sinks) {
    for (final sink in sinks) {
      void onApp() {
        final app = sink.connectedApp.value;
        if (app == null || !sink.canSendSteeringAngle || !appWantsSteeringAngle(app)) return;
        for (final track in _tracks.values) {
          final value = track.lastSent;
          if (track.detached || value == null || !_isAngle(value)) continue;
          _sendTo(sink, value);
        }
      }

      sink.connectedApp.addListener(onApp);
      _disposers.add(() => sink.connectedApp.removeListener(onApp));
    }
  }

  /// Whether [button] is a steering button of a device whose angle the apps
  /// are receiving right now — the presses it produces are then redundant for
  /// an app that steers from `0x1B`.
  bool coversSteeringButton(ControllerButton button) => _tracks.values.any(
    (t) =>
        !t.detached &&
        (t.device.steerLeftButton == button || t.device.steerRightButton == button) &&
        t.lastSent != null &&
        _isAngle(t.lastSent!),
  );

  void dispose() {
    for (final track in _tracks.values) {
      _unlisten(track);
      track.cooldown?.cancel();
    }
    _tracks.clear();
    for (final d in _disposers) {
      d();
    }
    _disposers.clear();
  }

  int _target(SteeringDevice device) {
    if (!device.steeringCalibrated.value || !_isAllowed(device)) {
      return OpenBikeProtocolParser.STEERING_ANGLE_UNAVAILABLE;
    }
    // SteeringDevice reports positive ⇒ LEFT; the protocol wants positive ⇒ RIGHT.
    return OpenBikeProtocolParser.encodeSteeringAngle(-device.steeringAngle.value);
  }

  void _offer(_Track track, int value) {
    track.pending = value;
    if (!(track.cooldown?.isActive ?? false)) _flush(track);
    _dropIfDone(track);
  }

  void _flush(_Track track) {
    final value = track.pending;
    track.pending = null;
    if (value == null || value == track.lastSent) return;
    // Nothing was ever announced, so there is nothing to retract.
    if (track.lastSent == null && value == OpenBikeProtocolParser.STEERING_ANGLE_UNAVAILABLE) return;
    track.lastSent = value;
    for (final sink in _sinks()) {
      final app = sink.connectedApp.value;
      if (app == null || !sink.canSendSteeringAngle || !appWantsSteeringAngle(app)) continue;
      _sendTo(sink, value);
    }
    track.cooldown = Timer(minInterval, () {
      _flush(track);
      _dropIfDone(track);
    });
  }

  void _dropIfDone(_Track track) {
    if (track.detached && track.pending == null && !(track.cooldown?.isActive ?? false)) {
      if (identical(_tracks[track.device], track)) _tracks.remove(track.device);
    }
  }

  void _sendTo(SteeringAngleSink sink, int value) {
    unawaited(
      sink.sendSteeringAngle(value).catchError((Object e, StackTrace s) {
        recordError(e, s, context: 'ObcSteeringAngle.send');
      }),
    );
  }

  void _unlisten(_Track track) {
    final l = track.listener;
    if (l == null) return;
    track.device.steeringAngle.removeListener(l);
    track.device.steeringCalibrated.removeListener(l);
    track.listener = null;
  }

  static bool _isAngle(int value) => value >= 0x02 && value <= 0xFE;
}

class _Track {
  _Track(this.device);

  final SteeringDevice device;
  VoidCallback? listener;
  bool detached = false;

  /// The last value that went out; null until the first one did.
  int? lastSent;

  /// The newest value waiting for the rate-limit window to close.
  int? pending;
  Timer? cooldown;
}
