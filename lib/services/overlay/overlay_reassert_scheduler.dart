import 'dart:async';

import 'package:bike_control/services/overlay/trainer_overlay_controller.dart';
import 'package:flutter/foundation.dart';

/// Re-tops the trainer overlay when a trainer app grabs the proxy while the
/// overlay is already on screen.
///
/// The bug this fixes (Android): the overlay is a system window added while
/// BikeControl is in the foreground. When a trainer app such as Rouvy then
/// comes to the foreground, the overlay ends up buried beneath it and stays
/// hidden — the rider sees it over every other app "but only not with Rouvy"
/// (support 73367365) — until the window is re-added. Disabling and re-enabling
/// the overlay fixes it because that re-adds the window; this scheduler
/// automates that re-add at the right moment.
///
/// It watches each proxy's "a trainer app is connected" signal
/// ([ProxyDevice.isConnectedListenable]) and, on the false→true edge, asks the
/// controller to [TrainerOverlayController.reassert]. The call is:
/// - **debounced**, so a flapping DirCon reconnect collapses into one re-top
///   rather than thrashing the window; and
/// - **gated** on the overlay being both enabled and currently showing, so a
///   trainer app connecting while the overlay is off never forces it on.
///
/// The scheduler is deliberately platform-agnostic and takes only a controller
/// and an `isEnabled` closure so it can be unit-tested without a real window;
/// `reassert()` is a no-op on the controllers whose overlay isn't a
/// re-stackable system window.
class OverlayReassertScheduler {
  OverlayReassertScheduler(
    this._controller, {
    required bool Function() isEnabled,
    Duration debounce = const Duration(milliseconds: 750),
  }) : _isEnabled = isEnabled,
       _debounce = debounce;

  final TrainerOverlayController _controller;
  final bool Function() _isEnabled;
  final Duration _debounce;

  final Map<ValueListenable<bool>, VoidCallback> _watched = {};
  final Map<ValueListenable<bool>, bool> _last = {};
  Timer? _debounceTimer;
  bool _disposed = false;

  /// Start watching [connected] (a proxy's `isConnectedListenable`) for a
  /// false→true edge. Idempotent per listenable, so watching a device that was
  /// already added on mount and again from the connection stream is safe.
  void watch(ValueListenable<bool> connected) {
    if (_disposed || _watched.containsKey(connected)) return;
    _last[connected] = connected.value;
    void listener() {
      final now = connected.value;
      final rising = now && !(_last[connected] ?? false);
      _last[connected] = now;
      if (rising) _schedule();
    }

    connected.addListener(listener);
    _watched[connected] = listener;
  }

  void _schedule() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () {
      if (_disposed) return;
      if (_isEnabled() && _controller.isShowing.value) {
        unawaited(_controller.reassert());
      }
    });
  }

  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _watched.forEach((listenable, listener) => listenable.removeListener(listener));
    _watched.clear();
    _last.clear();
  }
}
