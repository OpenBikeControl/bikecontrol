import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders [child] to a PNG file at [outputPath], headless, under `flutter test`.
///
/// Unlike the widget previewer (interactive only) this writes a real file, and
/// unlike `matchesGoldenFile` it doesn't compare — it just outputs the image, so
/// it's handy for docs/marketing/visual snapshots where you want the bytes, not
/// a pass/fail.
///
/// Renders at a fixed logical [size] and [pixelRatio] so the result is identical
/// regardless of the host machine's real screen. Call from inside a
/// [testWidgets] body:
///
/// ```dart
/// testWidgets('export front shift card', (tester) async {
///   await loadFonts(); // see note below — otherwise text renders as boxes
///   await renderWidgetToPng(
///     tester,
///     const MyCard(),
///     outputPath: 'build/snapshots/front_shift_card.png',
///     size: const Size(360, 200),
///   );
/// });
/// ```
///
/// Run with `flutter test test/widget_to_png_example_test.dart`.
///
/// Fonts: a bare `flutter test` ships the Ahem font (every glyph is a box). To
/// get real text, load fonts in `setUpAll`, e.g. golden_toolkit's
/// `loadAppFonts()`, or a manual [FontLoader] for your bundled .ttf assets.
Future<File> renderWidgetToPng(
  WidgetTester tester,
  Widget child, {
  required String outputPath,
  Size size = const Size(390, 844), // ~iPhone logical points
  double pixelRatio = 3.0,
  Color background = const Color(0xFFFFFFFF),
  bool settle = true,
}) async {
  // Pin the surface so layout constraints == [size] in logical pixels,
  // independent of the host. Physical pixels = size * pixelRatio.
  tester.view.physicalSize = size * pixelRatio;
  tester.view.devicePixelRatio = pixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final boundaryKey = GlobalKey();

  await tester.pumpWidget(
    RepaintBoundary(
      key: boundaryKey,
      child: MediaQuery(
        // Give descendants a correct MediaQuery (size, dpr, no padding).
        data: MediaQueryData(size: size, devicePixelRatio: pixelRatio),
        child: Directionality(
          textDirection: TextDirection.ltr,
          // Opaque backing so toImage() isn't transparent where the child
          // doesn't paint.
          child: ColoredBox(color: background, child: child),
        ),
      ),
    ),
  );

  if (settle) {
    // Drains animations/microtasks; switch to a fixed pump if your widget
    // has an infinite/repeating animation (pumpAndSettle would hang).
    await tester.pumpAndSettle();
  }

  return captureBoundaryToPng(
    tester,
    boundaryKey,
    outputPath: outputPath,
    pixelRatio: pixelRatio,
  );
}

/// Encodes the [RenderRepaintBoundary] behind [boundaryKey] to a PNG and writes
/// it to [outputPath]. Use this when the boundary already lives inside a richer
/// tree you pumped yourself (e.g. an app shell that provides theme + localization
/// + fonts) — see `front_shift_card_snapshot_test.dart`.
///
/// [pixelRatio] is the output scale: the boundary's logical size × this. Pass the
/// same value you used for the surface to get crisp, 1:1 device-pixel output.
Future<File> captureBoundaryToPng(
  WidgetTester tester,
  GlobalKey boundaryKey, {
  required String outputPath,
  double pixelRatio = 3.0,
}) async {
  final pngBytes = await encodeBoundaryToPng(tester, boundaryKey, pixelRatio: pixelRatio);

  // Written synchronously: awaiting real file I/O outside `runAsync` never
  // completes under the fake-clock test binding, and the capture helpers are
  // used under both bindings.
  final file = File(outputPath);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(pngBytes);
  return file;
}

/// Encodes the [RenderRepaintBoundary] behind [boundaryKey] to PNG bytes
/// without touching the disk — for callers that hash, compare or name the
/// frames themselves (see `onboarding_video_capture_test.dart`).
Future<Uint8List> encodeBoundaryToPng(
  WidgetTester tester,
  GlobalKey boundaryKey, {
  double pixelRatio = 3.0,
}) async {
  final boundary =
      boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

  // toImage()/toByteData() are real async and must run outside the
  // fake-async test zone, hence runAsync.
  Uint8List? pngBytes;
  await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final ByteData? data =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw StateError('toByteData returned null for the boundary');
      }
      pngBytes = data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  });
  return pngBytes!;
}
