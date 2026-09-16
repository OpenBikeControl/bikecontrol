import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bike_control/main.dart';
import 'package:bike_control/pages/support_chat/widgets/support_composer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/rendering.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// GlobalKey on the [RepaintBoundary] around the whole Navigation Scaffold
/// (see [ScreenshotScaffold]). Both support-chat entry points use it to
/// pre-stage a dashboard screenshot before pushing the chat page; the
/// store-screenshot suite captures the screen through it.
final GlobalKey overviewScreenshotKey = GlobalKey(debugLabel: 'overviewScreenshot');

// The regions of a [ScreenshotScaffold] the support screenshot is built from.
final GlobalKey _headerKey = GlobalKey(debugLabel: 'overviewScreenshot.header');
final GlobalKey _bodyKey = GlobalKey(debugLabel: 'overviewScreenshot.body');
final GlobalKey _footerKey = GlobalKey(debugLabel: 'overviewScreenshot.footer');

/// Hard cap on how much logical scroll height we'll capture. Keeps the
/// stitched PNG and its in-flight raster buffers from blowing up on
/// pages with very long activity logs. ~6000 logical px is enough to
/// cover a packed dashboard several viewports tall.
const double _maxStitchHeightLogical = 6000.0;

/// The shadcn [Scaffold] of the app's main screen, laid out so the support
/// screenshot can leave out whatever is open on top of the screen.
///
/// shadcn paints sheets and drawers (its DrawerOverlay) and toasts (its
/// ToastLayer) inside the Scaffold, so a capture of the whole Scaffold also
/// shows the "Need help?" sheet a rider typically opens support from — it is
/// still open while the screenshot is taken. The headers, the body and the
/// footers therefore each sit in a [RepaintBoundary] of their own, below
/// those layers, and [captureOverviewScreenshot] puts the screenshot together
/// from them.
///
/// [overviewScreenshotKey] still wraps the whole Scaffold. The keys are
/// global, so only one of these can be mounted at a time.
class ScreenshotScaffold extends StatelessWidget {
  const ScreenshotScaffold({
    super.key,
    required this.headers,
    this.footers = const [],
    this.floatingFooter = false,
    required this.child,
  });

  final List<Widget> headers;
  final List<Widget> footers;
  final bool floatingFooter;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: overviewScreenshotKey,
      child: Scaffold(
        headers: [
          if (headers.isNotEmpty) _bars(_headerKey, headers, isHeader: true),
        ],
        footers: [
          if (footers.isNotEmpty) _bars(_footerKey, footers, isHeader: false),
        ],
        floatingFooter: floatingFooter,
        // The Scaffold places its child inside its ToastLayer, so toasts stay
        // outside this boundary as well.
        child: RepaintBoundary(key: _bodyKey, child: child),
      ),
    );
  }

  /// One boundary around all of [bars], each still given the
  /// [ScaffoldBarData] the Scaffold would have given it directly — the first
  /// header's AppBar pads itself for the status bar based on it.
  static Widget _bars(GlobalKey key, List<Widget> bars, {required bool isHeader}) {
    return RepaintBoundary(
      key: key,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < bars.length; i++)
            Data<ScaffoldBarData>.inherit(
              data: ScaffoldBarData(isHeader: isHeader, childIndex: i, childrenCount: bars.length),
              child: bars[i],
            ),
        ],
      ),
    );
  }
}

/// Captures the app's current screen (header, the page with its first
/// vertical scroll view fully unrolled when possible, and footer) as a PNG
/// and wraps it as a staged attachment. Sheets, drawers, popovers, toasts and
/// dialogs open at the time are left out: riders usually open support from
/// one, and the screenshot is meant to show the screen behind it. Returns null
/// on any failure so the caller can open the support chat without a
/// pre-attachment.
Future<StagedAttachment?> captureOverviewScreenshot({
  BuildContext? context,
  double maxPixelRatio = 2.0,
}) async {
  try {
    final screenContext = overviewScreenshotKey.currentContext;
    if (screenContext == null) return null;
    final screen = screenContext.findRenderObject();
    if (screen is! RenderRepaintBoundary) return null;

    final pixelRatio = context != null ? min(MediaQuery.devicePixelRatioOf(context), maxPixelRatio) : maxPixelRatio;

    final image = await _captureScreen(screenContext as Element, screen, pixelRatio);
    final ByteData? png;
    try {
      png = await image.toByteData(format: ui.ImageByteFormat.png);
    } finally {
      image.dispose();
    }
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

/// A captured region and where its top-left corner goes, in physical pixels
/// relative to the top-left corner of the page.
typedef _Shot = ({ui.Image image, Offset offset});

/// Captures a [ScreenshotScaffold]'s regions and puts them together as the
/// screen shows them. Any other boundary keyed [overviewScreenshotKey] is
/// captured as a whole.
Future<ui.Image> _captureScreen(Element screenElement, RenderRepaintBoundary screen, double pixelRatio) async {
  final bodyContext = _bodyKey.currentContext;
  final body = bodyContext?.findRenderObject();
  if (bodyContext == null || body is! RenderRepaintBoundary) {
    return (await _captureUnrolled(screenElement, screen, pixelRatio)).image;
  }

  final images = <ui.Image>[];
  try {
    // Chrome first: unrolling the page scrolls it.
    final header = await _captureChrome(_headerKey, body, screen, pixelRatio);
    if (header != null) images.add(header.image);
    final footer = await _captureChrome(_footerKey, body, screen, pixelRatio);
    if (footer != null) images.add(footer.image);
    final page = await _captureUnrolled(bodyContext as Element, body, pixelRatio);
    images.add(page.image);

    return await _compose(
      page: page.image,
      chrome: [
        if (header != null) header,
        // The footer belongs at the bottom of the page, however much taller
        // unrolling made it.
        if (footer != null) (image: footer.image, offset: footer.offset.translate(0, page.addedHeight.toDouble())),
      ],
      background: _scaffoldBackground(screenElement),
    );
  } finally {
    for (final image in images) {
      image.dispose();
    }
  }
}

/// Captures the chrome region behind [key], unless the Scaffold has left it
/// out (shadcn keeps the footer offstage while the keyboard is up).
Future<_Shot?> _captureChrome(
  GlobalKey key,
  RenderBox page,
  RenderObject screen,
  double pixelRatio,
) async {
  final region = key.currentContext?.findRenderObject();
  if (region is! RenderRepaintBoundary || !region.hasSize || region.size.isEmpty || !_isPainted(region, screen)) {
    return null;
  }
  // Measured against the page rather than the screen: an open drawer scales
  // the whole Scaffold down, and the page and its chrome share that scale.
  final offset = MatrixUtils.transformPoint(region.getTransformTo(page), Offset.zero) * pixelRatio;
  final image = await region.toImage(pixelRatio: pixelRatio);
  return (image: image, offset: Offset(offset.dx.roundToDouble(), offset.dy.roundToDouble()));
}

/// False when a render object between [region] and [screen] does not paint
/// what lies below it (an [Offstage], for one).
bool _isPainted(RenderObject region, RenderObject screen) {
  RenderObject child = region;
  while (!identical(child, screen)) {
    final parent = child.parent;
    if (parent == null) return true;
    if (!parent.paintsChild(child)) return false;
    child = parent;
  }
  return true;
}

/// What the Scaffold paints behind its regions (it gives [ScreenshotScaffold]
/// no colour of its own).
Color _scaffoldBackground(BuildContext context) =>
    ComponentTheme.maybeOf<ScaffoldTheme>(context)?.backgroundColor ?? Theme.of(context).colorScheme.background;

/// Paints [page] and then the [chrome] over it, as the Scaffold paints them,
/// onto its [background], growing the image to fit chrome outside the page.
Future<ui.Image> _compose({
  required ui.Image page,
  required List<_Shot> chrome,
  required Color background,
}) async {
  var bounds = Offset.zero & Size(page.width.toDouble(), page.height.toDouble());
  for (final shot in chrome) {
    bounds = bounds.expandToInclude(shot.offset & Size(shot.image.width.toDouble(), shot.image.height.toDouble()));
  }

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..translate(-bounds.left, -bounds.top)
    ..drawRect(bounds, Paint()..color = background);
  final paint = Paint();
  canvas.drawImage(page, Offset.zero, paint);
  for (final shot in chrome) {
    canvas.drawImage(shot.image, shot.offset, paint);
  }
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(bounds.width.round(), bounds.height.round());
  } finally {
    picture.dispose();
  }
}

/// Captures [boundary], with the first vertical scroll view under [element]
/// unrolled when it has more to show. `addedHeight` is how many physical
/// pixels taller than [boundary] that made the image.
Future<({ui.Image image, int addedHeight})> _captureUnrolled(
  Element element,
  RenderRepaintBoundary boundary,
  double pixelRatio,
) async {
  final scroll = _findFirstVerticalScrollable(element);
  if (scroll != null && scroll.position.maxScrollExtent > 0) {
    return _captureStitched(boundary, scroll, pixelRatio);
  }
  return (image: await boundary.toImage(pixelRatio: pixelRatio), addedHeight: 0);
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
/// tall image. Whatever sits above and below the viewport inside the
/// boundary is taken from the first shot; only the viewport region is
/// stitched. The user briefly sees the page scroll during capture —
/// acceptable for a debug screenshot.
Future<({ui.Image image, int addedHeight})> _captureStitched(
  RenderRepaintBoundary boundary,
  _ScrollableHit scroll,
  double pixelRatio,
) async {
  final scrollableRO = scroll.element.findRenderObject();
  if (scrollableRO is! RenderBox || !scrollableRO.hasSize) {
    return (image: await boundary.toImage(pixelRatio: pixelRatio), addedHeight: 0);
  }

  final position = scroll.position;
  final viewportTopLogical = scrollableRO.localToGlobal(Offset.zero, ancestor: boundary).dy;
  final viewportHeightLogical = scrollableRO.size.height;
  if (viewportHeightLogical <= 0) {
    return (image: await boundary.toImage(pixelRatio: pixelRatio), addedHeight: 0);
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
    return (image: shots.first, addedHeight: 0);
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
    return (image: image, addedHeight: stitchedHeight - shotHeightPx);
  } finally {
    for (final s in shots) {
      s.dispose();
    }
  }
}
