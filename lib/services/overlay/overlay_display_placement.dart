import 'dart:math';
import 'dart:ui';

import 'package:bike_control/main.dart' show recordError;
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart' as wm;

/// How much of the overlay, per axis, has to stay on a display for the rider to
/// still be able to grab it.
const double _minReachableExtent = 40;

/// Where [window] has to move to be reachable on one of [displays], or null when
/// it already is. It goes to the nearest display, as close to where it was as
/// fits, and an overlay pushed partly off a screen by the rider stays put.
///
/// All rects share the coordinate space of `window_manager`'s bounds and
/// `screen_retriever`'s visible areas.
Offset? overlayPositionOnDisplays(Rect window, List<Rect> displays) {
  if (displays.isEmpty) return null;

  final reachable = displays.any((display) {
    final overlap = display.intersect(window);
    return overlap.width >= min(_minReachableExtent, window.width) &&
        overlap.height >= min(_minReachableExtent, window.height);
  });
  if (reachable) return null;

  Offset closestPoint(Rect display) => Offset(
    window.center.dx.clamp(display.left, display.right),
    window.center.dy.clamp(display.top, display.bottom),
  );
  double distance(Rect display) => (closestPoint(display) - window.center).distanceSquared;
  final nearest = displays.reduce((a, b) => distance(b) < distance(a) ? b : a);

  return Offset(
    max(nearest.left, min(window.left, nearest.right - window.width)),
    max(nearest.top, min(window.top, nearest.bottom - window.height)),
  );
}

/// Keeps the desktop overlay window on a connected display: a window left on a
/// display that is gone is invisible and can't be dragged back.
class OverlayDisplayWatcher with ScreenListener {
  void start() => screenRetriever.addListener(this);

  void stop() => screenRetriever.removeListener(this);

  @override
  void onScreenEvent(String eventName) {
    ensureVisible();
  }

  /// Moves the overlay onto a connected display if it isn't on one.
  Future<void> ensureVisible() async {
    try {
      final bounds = await wm.windowManager.getBounds();
      final displays = await screenRetriever.getAllDisplays();
      final position = overlayPositionOnDisplays(bounds, [
        for (final display in displays)
          (display.visiblePosition ?? Offset.zero) & (display.visibleSize ?? display.size),
      ]);
      if (position != null) await wm.windowManager.setPosition(position);
    } catch (e, s) {
      recordError(e, s, context: 'overlay.window.ensureVisible');
    }
  }
}
