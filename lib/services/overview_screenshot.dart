import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bike_control/main.dart';
import 'package:bike_control/pages/support_chat/widgets/support_composer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Single GlobalKey wrapping OverviewPage's [RepaintBoundary]. Reached
/// from the help menu and the proxy device details "Submit Feedback"
/// flows so they can pre-stage a dashboard screenshot before pushing
/// the support chat.
final GlobalKey overviewScreenshotKey = GlobalKey(debugLabel: 'overviewScreenshot');

/// Captures the current OverviewPage as a PNG and wraps it as a staged
/// attachment ready to drop into the support composer. Returns null if
/// the boundary isn't mounted yet or if the raster/encode fails — the
/// caller should treat null as "open chat without a pre-attachment".
Future<StagedAttachment?> captureOverviewScreenshot({
  BuildContext? context,
  double maxPixelRatio = 2.0,
}) async {
  try {
    final boundaryContext = overviewScreenshotKey.currentContext;
    if (boundaryContext == null) return null;
    final renderObject = boundaryContext.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) return null;

    final pixelRatio = context != null
        ? min(MediaQuery.devicePixelRatioOf(context), maxPixelRatio)
        : maxPixelRatio;

    final ui.Image image = await renderObject.toImage(pixelRatio: pixelRatio);
    final ByteData? png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (png == null) return null;
    final bytes = png.buffer.asUint8List();

    final name = 'overview-${DateTime.now().millisecondsSinceEpoch}.png';
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
