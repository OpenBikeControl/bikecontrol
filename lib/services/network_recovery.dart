import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:prop/mdns/service_advertiser.dart';
import 'package:prop/utils/resilient_tcp_server.dart';
import 'package:prop/utils/shared.dart';
import 'package:prop/utils/suspension_watch.dart';

import '../main.dart' show recordError;

/// Brings the network methods back after the app was suspended (iOS) or the
/// machine slept (macOS), and keeps the record of it for the support bundle.
///
/// iOS closes a suspended app's listening sockets and its Bonjour
/// registration. The servers still look started and the advertisement still
/// looks published, so a trainer app finds nothing until the method is
/// restarted by hand. A Mac that slept can wake with a responder socket that
/// no longer hears the network. Both show up as a standstill on
/// [SuspensionWatch]; this class answers one by binding the listeners again
/// (iOS) and publishing the advertisement again.
class NetworkRecovery {
  NetworkRecovery({
    SuspensionWatch? watch,
    TargetPlatform? platform,
    Future<void> Function()? rebindListeners,
    Future<void> Function({bool force})? recoverAdvertiser,
    void Function()? refreshKeepAlive,
    DateTime Function() now = DateTime.now,
  }) : _watch = watch ?? SuspensionWatch.instance,
       _platform = platform,
       _rebindListeners = rebindListeners ?? ResilientTcpServer.rebindAllListeners,
       _recoverAdvertiser = recoverAdvertiser ?? RecoverableAdvertiser.recoverInstance,
       _refreshKeepAlive = refreshKeepAlive ?? SharedLogic.refreshKeepAlive,
       _now = now;

  static final NetworkRecovery instance = NetworkRecovery();

  final SuspensionWatch _watch;
  final TargetPlatform? _platform;
  final Future<void> Function() _rebindListeners;
  final Future<void> Function({bool force}) _recoverAdvertiser;
  final void Function() _refreshKeepAlive;
  final DateTime Function() _now;

  DateTime? lastBackgroundAt;
  DateTime? lastResumeAt;
  DateTime? lastRecoveryAt;
  bool _started = false;

  TargetPlatform get _target => _platform ?? defaultTargetPlatform;

  /// Only the Apple platforms for now; the others keep their behaviour.
  bool get _applies => !kIsWeb && (_target == TargetPlatform.iOS || _target == TargetPlatform.macOS);

  void start() {
    if (_started || !_applies) return;
    _started = true;
    _watch
      ..addListener(_afterStandstill)
      ..start();
  }

  void onLifecycleState(AppLifecycleState state) {
    if (!_applies) return;
    switch (state) {
      case AppLifecycleState.resumed:
        lastResumeAt = _now();
        // A standstill is acted on now rather than at the next tick.
        _watch.check();
        _refreshKeepAlive();
        // Also without a standstill: the address may have moved, or Bonjour
        // may have reported the registration lost while we were away.
        _guard(_recoverAdvertiser(), 'NetworkRecovery.resume');
      case AppLifecycleState.inactive || AppLifecycleState.hidden || AppLifecycleState.paused:
        if (state == AppLifecycleState.paused) lastBackgroundAt = _now();
        // The waiting limit counts from the moment the rider leaves.
        _refreshKeepAlive();
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _afterStandstill(Duration gap) async {
    lastRecoveryAt = _now();
    if (_target == TargetPlatform.iOS) {
      await _rebindListeners();
    }
    await _recoverAdvertiser(force: true);
  }

  /// Whether a trainer app can find what we advertise, repairing it once
  /// when it cannot.
  ///
  /// Browses for our own advertisement the way a trainer app would. When it
  /// is missing, the listeners are bound again (iOS) and everything is
  /// published again, and the browse is repeated. False only when it is
  /// still missing after that; true when nothing is advertised or on a
  /// platform this does not apply to.
  Future<bool> ensureAdvertisementVisible({
    required bool Function() advertising,
    required Future<bool> Function() ownAdvertisementSeen,
    Duration settle = const Duration(seconds: 2),
  }) async {
    if (!_applies || !advertising()) return true;
    if (await ownAdvertisementSeen()) {
      lastInvisibleAt = null;
      return true;
    }
    // A forced repair unregisters and publishes everything again. Looks come
    // every 20 s while the advertisement is flagged missing, and a browse can
    // miss our own records (macOS) — repairing on each of them would churn
    // the very records a trainer app is resolving. Once per pause; in
    // between, only look. A standstill still repairs at once.
    final lastRepair = _lastForcedRepairAt;
    if (lastRepair != null && _now().difference(lastRepair) < forcedRepairPause) {
      lastInvisibleAt = _now();
      return false;
    }
    _lastForcedRepairAt = lastRecoveryAt = _now();
    if (_target == TargetPlatform.iOS) {
      await _rebindListeners();
    }
    await _recoverAdvertiser(force: true);
    // Bonjour probes and announces before a browse can see the records.
    await Future<void>.delayed(settle);
    if (!advertising()) return true;
    final seen = await ownAdvertisementSeen();
    lastInvisibleAt = seen ? null : _now();
    return seen;
  }

  /// When the advertisement was last found missing even after a repair.
  DateTime? lastInvisibleAt;

  /// The shortest time between two forced repairs from
  /// [ensureAdvertisementVisible].
  static const forcedRepairPause = Duration(minutes: 10);
  DateTime? _lastForcedRepairAt;

  void _guard(Future<void> future, String context) {
    unawaited(future.catchError((Object e, StackTrace s) => recordError(e, s, context: context)));
  }

  /// Lines for the support bundle: when the app last left and came back,
  /// whether the process stood still, and what was repaired.
  List<String> diagnosticLines() {
    if (!_applies) return const [];
    String time(DateTime? at) => at == null ? 'never' : at.toIso8601String().split('.').first;
    final advertiser = ServiceAdvertiser.instance;
    final recovery = advertiser is RecoverableAdvertiser ? (advertiser as RecoverableAdvertiser).recoveryStatus : null;
    return [
      'last background ${time(lastBackgroundAt)} · last resume ${time(lastResumeAt)}',
      'standstill: ${_watch.status}',
      if (lastRecoveryAt != null) 'recovered after a standstill at ${time(lastRecoveryAt)}',
      if (recovery != null) 'advertisement: $recovery',
      if (lastInvisibleAt != null) 'own advertisement not found after a repair at ${time(lastInvisibleAt)}',
      if (_target == TargetPlatform.iOS) 'keep-alive: ${SharedLogic.keepAliveStatus}',
    ];
  }
}
