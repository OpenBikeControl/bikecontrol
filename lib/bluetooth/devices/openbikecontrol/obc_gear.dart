import 'dart:async';

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/protocol_parser.dart';
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/main.dart' show recordError;
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';

export 'package:bike_control/bluetooth/devices/openbikecontrol/protocol_parser.dart' show ObcGearPosition;

/// An OpenBikeControl transport (BLE or network) that can tell the app
/// connected to it which virtual gear BikeControl is in.
abstract interface class GearStateSink {
  /// The app on the other end, once it sent its App Information.
  ValueListenable<AppInfo?> get connectedApp;

  /// An app is attached and a message can go out right now.
  bool get canSendGearState;

  /// Sends a ready-made button-state message (see
  /// [OpenBikeProtocolParser.encodeGearState]).
  Future<void> sendGearState(Uint8List message);
}

/// The OBC position of [currentGear]. With front shifting the flat index
/// concatenates the rings: the small ring is gears 1..[maxGear], the large
/// ring [maxGear]+1..2×[maxGear].
ObcGearPosition obcGearPosition({
  required int currentGear,
  required int maxGear,
  required bool frontShiftEnabled,
  required bool largeRing,
}) {
  if (!frontShiftEnabled) return ObcGearPosition(flat: currentGear);
  return ObcGearPosition(
    flat: largeRing ? maxGear + currentGear : currentGear,
    chainring: largeRing ? 2 : 1,
    cassette: currentGear,
  );
}

/// Reports BikeControl's virtual gear to connected OpenBikeControl apps as
/// `0x03` Gear Set (plus `0x04` / `0x05` with front shifting), so they can
/// show it — only to apps that listed those ids in their App Information.
///
/// Sent whenever [position] changes to a new gear and to an app as soon as it
/// connects. Nothing goes out while there is no gear ([position] is null):
/// the protocol has no "unknown gear" value.
class ObcGearBroadcaster {
  ObcGearBroadcaster({
    required Iterable<GearStateSink> Function() sinks,
    required ValueListenable<ObcGearPosition?> position,
  }) : _sinks = sinks,
       _position = position {
    _position.addListener(_onPosition);
    _disposers.add(() => _position.removeListener(_onPosition));
    _onPosition();
  }

  final Iterable<GearStateSink> Function() _sinks;
  final ValueListenable<ObcGearPosition?> _position;
  final List<VoidCallback> _disposers = [];

  /// The last position that went out; null while there is no gear.
  ObcGearPosition? _lastSent;

  /// An app connecting later gets the current gear at once instead of
  /// waiting for the next shift.
  void watchApps(Iterable<GearStateSink> sinks) {
    for (final sink in sinks) {
      void onApp() {
        final position = _position.value;
        if (position != null) _sendTo(sink, position);
      }

      sink.connectedApp.addListener(onApp);
      _disposers.add(() => sink.connectedApp.removeListener(onApp));
    }
  }

  void dispose() {
    for (final d in _disposers) {
      d();
    }
    _disposers.clear();
  }

  void _onPosition() {
    final position = _position.value;
    if (position == _lastSent) return;
    _lastSent = position;
    if (position == null) return;
    for (final sink in _sinks()) {
      _sendTo(sink, position);
    }
  }

  void _sendTo(GearStateSink sink, ObcGearPosition position) {
    final app = sink.connectedApp.value;
    if (app == null || !sink.canSendGearState) return;
    final message = OpenBikeProtocolParser.encodeGearState(position, app);
    if (message == null) return;
    unawaited(
      sink.sendGearState(message).catchError((Object e, StackTrace s) {
        recordError(e, s, context: 'ObcGear.send');
      }),
    );
  }
}

/// The gear of the trainer BikeControl bridges with virtual shifting: the
/// first connected [ProxyDevice] that has a [FitnessBikeDefinition] — the one
/// shifter presses go to. Null when no bridged trainer shifts virtually.
class BridgeGearPosition extends ValueNotifier<ObcGearPosition?> {
  BridgeGearPosition({required Iterable<ProxyDevice> Function() proxies}) : _proxies = proxies, super(null);

  final Iterable<ProxyDevice> Function() _proxies;
  final Set<ProxyDevice> _watched = {};
  StreamSubscription<BaseDevice>? _sub;

  FitnessBikeDefinition? _def;
  Listenable? _defListenable;

  /// Follows proxies connecting, disconnecting and switching VS on and off.
  void watchDevices(Stream<BaseDevice> deviceChanges) {
    _sub ??= deviceChanges.listen((device) {
      if (device is ProxyDevice) _resolve();
    });
    _resolve();
  }

  void _resolve() {
    for (final proxy in _proxies()) {
      if (_watched.add(proxy)) proxy.fitnessBikeListenable.addListener(_resolve);
    }
    final def = _proxies().where((p) => p.isConnected).map((p) => p.fitnessBike).whereNotNull().firstOrNull;
    if (!identical(def, _def)) {
      _defListenable?.removeListener(_read);
      _def = def;
      _defListenable = def == null ? null : Listenable.merge([def.currentGear, def.frontRing]);
      _defListenable?.addListener(_read);
    }
    _read();
  }

  void _read() {
    final def = _def;
    value = def == null
        ? null
        : obcGearPosition(
            currentGear: def.currentGear.value,
            maxGear: def.maxGear,
            frontShiftEnabled: def.frontShiftEnabled,
            largeRing: def.frontRing.value == FrontRing.large,
          );
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    _defListenable?.removeListener(_read);
    for (final proxy in _watched) {
      proxy.fitnessBikeListenable.removeListener(_resolve);
    }
    super.dispose();
  }
}
