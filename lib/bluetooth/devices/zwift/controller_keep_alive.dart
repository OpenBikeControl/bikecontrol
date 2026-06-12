import 'dart:async';

/// The Zwift Click/Ride "released" controller frame: every button bit set to 1
/// means nothing is pressed. This is exactly what a key-up emits, so re-sending
/// it is a no-op for the game — it can never register a phantom press.
const List<int> kZwiftControllerReleasedState = [0x08, 0xFF, 0xFF, 0xFF, 0xFF, 0x0F];

/// Periodically invokes [onTick] while running.
///
/// Zwift (and Rouvy) drop a wired LAN controller after ~30s without any
/// traffic — see issue #367. Our Zwift controller emulators only emit on a
/// button press, so an idle rider (pedalling, not shifting) goes silent and
/// gets disconnected. Re-emitting the neutral "released" state on a fixed timer
/// keeps the connection's inactivity watchdog from firing.
class ControllerKeepAlive {
  ControllerKeepAlive({required this.onTick, this.interval = const Duration(seconds: 5)});

  final void Function() onTick;
  final Duration interval;

  Timer? _timer;

  bool get isRunning => _timer != null;

  /// Starts (or restarts) the periodic keepalive. Safe to call repeatedly —
  /// only ever one timer is active.
  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => onTick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
