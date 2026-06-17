import 'dart:async';

/// Decides when connected BLE controllers should be auto-disconnected to save
/// their battery. Pure timing/state logic — it knows nothing about BLE; the
/// owner ([Connection]) supplies live state via the [isTrainerAppConnected],
/// [isOnlyLocalActive] and [hasEligibleControllers] callbacks and performs the
/// actual disconnect/notification in [onTimeout].
///
/// Modes (re-evaluated on every event):
///  * A non-Local trainer app is connected  -> no timer (rider is active).
///  * A trainer app was connected and left  -> 5-minute sliding grace.
///  * Only Local is active                  -> 30-minute sliding timer.
/// The 5-minute grace arms ONLY on a real disconnect transition, never during
/// the initial "waiting for the trainer app" window.
class InactivityDisconnector {
  InactivityDisconnector({
    required this.isTrainerAppConnected,
    required this.isOnlyLocalActive,
    required this.hasEligibleControllers,
    required this.onTimeout,
    this.graceTimeout = const Duration(minutes: 5),
    this.localTimeout = const Duration(minutes: 30),
  });

  final bool Function() isTrainerAppConnected;
  final bool Function() isOnlyLocalActive;
  final bool Function() hasEligibleControllers;
  final void Function(Duration timeout) onTimeout;
  final Duration graceTimeout;
  final Duration localTimeout;

  Timer? _timer;
  Duration? _currentDuration;
  bool _appWasConnected = false;
  bool _graceArmed = false;
  bool _disposed = false;

  /// A trainer app's connection state changed. Detects the connected->left
  /// transition that arms the grace, and cancels it when an app (re)connects.
  void onTrainerConnectionChanged() {
    final connected = isTrainerAppConnected();
    if (connected) {
      _appWasConnected = true;
      _graceArmed = false;
    } else if (_appWasConnected) {
      _appWasConnected = false;
      _graceArmed = true;
    }
    _reevaluate();
  }

  /// A controller connected or disconnected.
  void onDeviceConnectionChanged() => _reevaluate();

  /// A button was pressed on a controller — slide (restart) the running timer.
  void onButtonActivity() => _reevaluate(resetSliding: true);

  void dispose() {
    _disposed = true;
    _cancel();
  }

  void _reevaluate({bool resetSliding = false}) {
    if (_disposed) return;
    if (!hasEligibleControllers()) {
      _cancel();
      _graceArmed = false;
      return;
    }
    if (isTrainerAppConnected()) {
      _cancel();
      return;
    }
    if (_graceArmed) {
      _arm(graceTimeout, resetSliding);
    } else if (isOnlyLocalActive()) {
      _arm(localTimeout, resetSliding);
    } else {
      _cancel();
    }
  }

  void _arm(Duration duration, bool resetSliding) {
    if (_timer != null && _currentDuration == duration && !resetSliding) return;
    _timer?.cancel();
    _currentDuration = duration;
    _timer = Timer(duration, _fire);
  }

  void _cancel() {
    _timer?.cancel();
    _timer = null;
    _currentDuration = null;
  }

  void _fire() {
    final duration = _currentDuration ?? graceTimeout;
    _timer = null;
    _currentDuration = null;
    _graceArmed = false;
    if (_disposed) return;
    if (!hasEligibleControllers()) return;
    if (isTrainerAppConnected()) return;
    onTimeout(duration);
  }
}
