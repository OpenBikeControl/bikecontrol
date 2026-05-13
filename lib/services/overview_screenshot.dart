import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bike_control/main.dart';
import 'package:bike_control/pages/support_chat/widgets/support_composer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// GlobalKey on the [RepaintBoundary] wrapping the Navigation Scaffold
/// (chrome + body). Used by both support-chat entry points so they can
/// pre-stage a dashboard screenshot before pushing the chat page.
final GlobalKey overviewScreenshotKey = GlobalKey(debugLabel: 'overviewScreenshot');

/// Hard cap on how much logical scroll height we'll capture. Keeps the
/// stitched PNG and its in-flight raster buffers from blowing up on
/// pages with very long activity logs. ~6000 logical px is enough to
/// cover a packed dashboard several viewports tall.
const double _maxStitchHeightLogical = 6000.0;

/// Captures the app's current screen (chrome + the first vertical
/// scroll view, fully unrolled when possible) as a PNG and wraps it
/// as a staged attachment. Returns null on any failure so the caller
/// can open the support chat without a pre-attachment.
Future<StagedAttachment?> captureOverviewScreenshot({
  BuildContext? context,
  double maxPixelRatio = 2.0,
}) async {
  try {
    final boundaryContext = overviewScreenshotKey.currentContext;
    if (boundaryContext == null) return null;
    final boundaryRO = boundaryContext.findRenderObject();
    if (boundaryRO is! RenderRepaintBoundary) return null;

    final pixelRatio = context != null
        ? min(MediaQuery.devicePixelRatioOf(context), maxPixelRatio)
        : maxPixelRatio;

    final scroll = _findFirstVerticalScrollable(boundaryContext as Element);
    final ui.Image image;
    if (scroll != null && scroll.position.maxScrollExtent > 0) {
      image = await _captureStitched(boundaryRO, scroll, pixelRatio);
    } else {
      image = await boundaryRO.toImage(pixelRatio: pixelRatio);
    }

    final ByteData? png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (png == null) return null;
    final bytes = png.buffer.asUint8List();

    final name = 'bikecontrol-screenshot-${DateTime.now().millisecondsSinceEpoch}.png';
    return StagedAttachment(
      PlatformFile(
        name: name,
        size: bytes.length,
        bytes: bytes,
      ),
    );
  } catch (e, s) {
    await recordError(e, s, context: 'overview_screenshot');
    return null;
  }
}

class _ScrollableHit {
  final Element element;
  final ScrollableState state;
  _ScrollableHit(this.element, this.state);
  ScrollPosition get position => state.position;
}

/// Pre-order walk of [root]'s descendants returning the first
/// [Scrollable] whose axis is vertical. We want the dashboard's main
/// vertical scroll view; a [PageView] above it (horizontal) is skipped.
_ScrollableHit? _findFirstVerticalScrollable(Element root) {
  _ScrollableHit? result;
  void visit(Element el) {
    if (result != null) return;
    if (el is StatefulElement && el.state is ScrollableState) {
      final s = el.state as ScrollableState;
      if (s.position.axis == Axis.vertical) {
        result = _ScrollableHit(el, s);
        return;
      }
    }
    el.visitChildren(visit);
  }
  root.visitChildren(visit);
  return result;
}

/// Walks the [scroll] position from top to bottom in viewport-sized
/// steps, captures the boundary at each step, then composites a single
/// tall image. Chrome above and below the viewport is taken from the
/// first shot; only the body region is stitched. The user briefly sees
/// the page scroll during capture — acceptable for a debug screenshot.
Future<ui.Image> _captureStitched(
  RenderRepaintBoundary boundary,
  _ScrollableHit scroll,
  double pixelRatio,
) async {
  final scrollableRO = scroll.element.findRenderObject();
  if (scrollableRO is! RenderBox || !scrollableRO.hasSize) {
    return boundary.toImage(pixelRatio: pixelRatio);
  }

  final position = scroll.position;
  final viewportTopLogical = scrollableRO.localToGlobal(Offset.zero, ancestor: boundary).dy;
  final viewportHeightLogical = scrollableRO.size.height;
  if (viewportHeightLogical <= 0) {
    return boundary.toImage(pixelRatio: pixelRatio);
  }

  final cappedMaxScroll = min(
    position.maxScrollExtent,
    max(0.0, _maxStitchHeightLogical - viewportHeightLogical),
  );
  final originalOffset = position.pixels;

  final offsets = <double>[];
  double current = 0;
  while (true) {
    offsets.add(current);
    if (current >= cappedMaxScroll) break;
    current = min(current + viewportHeightLogical, cappedMaxScroll);
  }

  final shots = <ui.Image>[];
  try {
    for (final off in offsets) {
      position.jumpTo(off);
      await WidgetsBinding.instance.endOfFrame;
      shots.add(await boundary.toImage(pixelRatio: pixelRatio));
    }
  } finally {
    position.jumpTo(originalOffset);
  }

  if (shots.length == 1) {
    return shots.first;
  }

  try {
    final shotWidthPx = shots.first.width;
    final shotHeightPx = shots.first.height;
    final viewportTopPx = (viewportTopLogical * pixelRatio).round();
    final viewportHeightPx = (viewportHeightLogical * pixelRatio).round();
    final viewportBottomPx = viewportTopPx + viewportHeightPx;
    final chromeBottomPx = max(0, shotHeightPx - viewportBottomPx);
    final contentTotalPx = (cappedMaxScroll * pixelRatio).round() + viewportHeightPx;
    final stitchedHeight = viewportTopPx + contentTotalPx + chromeBottomPx;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();
    final fullWidth = shotWidthPx.toDouble();

    // Top chrome from the first shot.
    if (viewportTopPx > 0) {
      final rect = Rect.fromLTWH(0, 0, fullWidth, viewportTopPx.toDouble());
      canvas.drawImageRect(shots.first, rect, rect, paint);
    }

    // Body portions: append only the unseen pixels of each shot so the
    // top of shot[i] doesn't overwrite already-stitched content.
    int contentCoveredPx = 0;
    for (int i = 0; i < shots.length; i++) {
      final scrollOffsetPx = (offsets[i] * pixelRatio).round();
      final newStartPx = max(scrollOffsetPx, contentCoveredPx);
      final newEndPx = scrollOffsetPx + viewportHeightPx;
      final overlap = newStartPx - scrollOffsetPx;
      final visibleHeight = newEndPx - newStartPx;
      if (visibleHeight <= 0) continue;
      final src = Rect.fromLTWH(
        0,
        (viewportTopPx + overlap).toDouble(),
        fullWidth,
        visibleHeight.toDouble(),
      );
      final dst = Rect.fromLTWH(
        0,
        (viewportTopPx + newStartPx).toDouble(),
        fullWidth,
        visibleHeight.toDouble(),
      );
      canvas.drawImageRect(shots[i], src, dst, paint);
      contentCoveredPx = newEndPx;
    }

    // Bottom chrome from the first shot.
    if (chromeBottomPx > 0) {
      final src = Rect.fromLTWH(0, viewportBottomPx.toDouble(), fullWidth, chromeBottomPx.toDouble());
      final dst = Rect.fromLTWH(
        0,
        (viewportTopPx + contentTotalPx).toDouble(),
        fullWidth,
        chromeBottomPx.toDouble(),
      );
      canvas.drawImageRect(shots.first, src, dst, paint);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(shotWidthPx, stitchedHeight);
    picture.dispose();
    return image;
  } finally {
    for (final s in shots) {
      s.dispose();
    }
  }
}
