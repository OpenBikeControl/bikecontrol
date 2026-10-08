import 'dart:async';

import 'package:flutter/foundation.dart';

/// The few seconds right after launch, while the setup is still finding
/// itself, during which Ride's banner holds one calm "Connecting…" line
/// instead of its steps.
///
/// Freshly launched, the chain flips a lot: the scan turns up a controller,
/// a remembered trainer reconnects, the connection method starts, the trainer
/// app picks the bridge up. Read step by step, that is "3 steps left", then
/// 2, then 4, and pending lines coming and going — complaints about things
/// that were about to sort themselves out.
///
/// The window ends, for good, at the first of:
/// - the setup being ready — "Ready to ride" is never held back;
/// - the remembered devices' reconnect being over (see
///   `Connection.startupReconnecting`) once the scan has run for
///   [scanQuiet];
/// - [maximum] after the banner was first shown, whatever is still going on,
///   so a step only the rider can do is never hidden for long.
class StartupSettling extends ChangeNotifier {
  StartupSettling();

  /// Already settled: the banner shows what the chain says from the start.
  StartupSettling.settled() : _settled = true;

  /// How long the scan runs before what it has (not) found counts.
  static const Duration scanQuiet = Duration(seconds: 3);

  /// The longest the window lasts.
  static const Duration maximum = Duration(seconds: 7);

  bool _settled = false;
  bool _reconnecting = true;
  bool _scanQuietOver = false;
  Timer? _maximumTimer;
  Timer? _scanTimer;

  bool get isSettled => _settled;

  /// Feeds what the screen sees now and answers whether the banner may show
  /// the chain as it is. The first call opens the window.
  ///
  /// Called from build: settling here does not notify — the answer already
  /// says so. Only the timers notify, so the screen rebuilds when the window
  /// runs out on its own.
  bool observe({required bool ready, required bool reconnecting, required bool scanning}) {
    if (_settled) return true;
    if (ready) {
      _settle(notify: false);
      return true;
    }
    _maximumTimer ??= Timer(maximum, () => _settle(notify: true));
    if (scanning) {
      _scanTimer ??= Timer(scanQuiet, () {
        _scanQuietOver = true;
        if (!_reconnecting) _settle(notify: true);
      });
    }
    _reconnecting = reconnecting;
    if (!_reconnecting && _scanQuietOver) _settle(notify: false);
    return _settled;
  }

  void _settle({required bool notify}) {
    if (_settled) return;
    _settled = true;
    _cancelTimers();
    if (notify) notifyListeners();
  }

  void _cancelTimers() {
    _maximumTimer?.cancel();
    _scanTimer?.cancel();
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }
}

/// The session's window — one per launch, not one per visit to Ride.
///
/// Tests start from [StartupSettling.settled] (see
/// `test/flutter_test_config.dart`) and swap in a fresh one where the window
/// itself is under test.
StartupSettling startupSettling = StartupSettling();
