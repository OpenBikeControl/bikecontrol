import 'package:flutter/foundation.dart';

/// Which trainer app connected in this session, and the advertised-address
/// verdict it connected through.
///
/// The trainer app's counterpart to `Connection.wasConnectedThisSession`, and
/// session-scoped for the same reason. The home page that reads it is built
/// afresh on every tab swipe: a latch kept on the page forgot the connection
/// the moment the rider looked elsewhere, and turned an app that had
/// disconnected back into one that never connected — with the network
/// self-test offered for it again.
///
/// Two rules decide what counts as connecting:
/// - Per app. The latch names the app that was picked when it connected, so
///   an app picked after a drop starts from scratch.
/// - Only over a real method. Local reports connected the moment it is
///   switched on and says nothing about whether the app is there, so a
///   session on Local alone latches nothing.
class AppConnectionLatch {
  AppConnectionLatch({required String? Function() pickedApp, required bool Function() connectedOverRealMethod})
    : _pickedApp = pickedApp,
      _connectedOverRealMethod = connectedOverRealMethod;

  final String? Function() _pickedApp;
  final bool Function() _connectedOverRealMethod;

  String? _connectedApp;
  String? _addressWarningAtConnect;
  bool _addressReadSinceConnect = false;
  String? _lastAddressWarning;
  bool _connected = false;

  /// Whether [app] is the app that connected in this session.
  bool wasConnected(String? app) => app != null && app == _connectedApp;

  /// The advertised-address verdict the app of [wasConnected] connected
  /// through — see `AppInput.advertisedAddressWarningAtConnect`.
  ///
  /// The first reading to land after it connected, while it was still
  /// connected. Until one does, the last reading from before stands in: it
  /// may be stale, since the network can change without anything reading the
  /// address again.
  String? get addressWarningAtConnect => _addressWarningAtConnect;

  /// Looks again at whether the picked app is connected, and latches the
  /// moment it connects.
  ///
  /// Also the moment another app is picked while the connection stays up:
  /// that app's card shows it connected, so when the connection goes, that is
  /// the app that disconnected.
  void sync() {
    final app = _pickedApp();
    final connected = app != null && _connectedOverRealMethod();
    if (connected && (!_connected || app != _connectedApp)) {
      _connectedApp = app;
      _addressWarningAtConnect = _lastAddressWarning;
      _addressReadSinceConnect = false;
    }
    _connected = connected;
  }

  /// Takes an advertised-address reading: the warning, or null when the
  /// address looks fine.
  void noteAddressWarning(String? warning) {
    // A reading can land before anything has told the latch that the app
    // connected, so it looks for itself first.
    sync();
    _lastAddressWarning = warning;
    if (_connected && !_addressReadSinceConnect) {
      _addressWarningAtConnect = warning;
      _addressReadSinceConnect = true;
    }
  }

  /// Keeps the latch current with nobody looking: [sync] runs whenever one of
  /// [sources] changes. Meant for sources that live as long as the app does,
  /// so the listeners are never removed.
  void watch(Iterable<Listenable> sources) {
    for (final source in sources) {
      source.addListener(sync);
    }
  }

  /// Forgets everything. `core`, which owns the latch, outlives every test.
  @visibleForTesting
  void reset() {
    _connectedApp = null;
    _addressWarningAtConnect = null;
    _addressReadSinceConnect = false;
    _lastAddressWarning = null;
    _connected = false;
  }
}
