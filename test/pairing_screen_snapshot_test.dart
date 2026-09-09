@Tags(['screenshots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/pages/onboarding/steps/step_trainer.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import 'widget_snapshot.dart';

/// The website's "Pair Your Smart Trainer to BikeControl" section
/// (bikecontrol_6_6/02_connection_card.png) needs the FTMS trainer
/// scanning/pairing screen. That screen is `onboardingTrainerBody()` in
/// `lib/pages/onboarding/steps/step_trainer.dart` — reached from the home
/// screen's trainer card via `openTrainerConnectSheet()`
/// (`lib/pages/home/home_sheets.dart`) and from the onboarding wizard
/// (`lib/pages/onboarding/onboarding_page.dart`). Both really import and call
/// it, so unlike `lib/pages/proxy.dart`'s `ProxyPage` (grep for "ProxyPage"
/// outside its own file: nothing — dead code, no callers, not reachable by a
/// 6.6 user), this is a screen a rider can actually land on. Do not swap this
/// back to `ProxyPage` — it would depict a screen that no longer exists in
/// the app.
///
/// `onboardingTrainerBody()`'s un-bridged branch always also renders
/// `VirtualShiftingStage()` (an app/ratio/front-shift demo carousel) between
/// the heading and the scan card — real, but it duplicates the sibling
/// website image `03_virtual_shifting.jpg`, and it doesn't illustrate this
/// section's copy ("...scans for compatible FTMS trainers nearby. Tap one
/// and you're paired."). It sits as its own sequential section (heading →
/// carousel → scan card → footer link), not interleaved with the scan card's
/// internals, so rather than switch screens we crop it out: this test
/// measures the real render tree for the exact pixel rect of the private
/// `_ScanCard` (the scanning header + discovered-trainer row) and of the
/// bridged branch's "Connected" card, and crops each capture down to just
/// that widget. Two genuine, reachable UI states, no fabricated screen, no
/// carousel.
///
/// Outputs (stack scan-then-connected vertically for the website image):
///   build/snapshots/pairing_scan_card.png       — scanning + discovered row
///   build/snapshots/pairing_connected_card.png  — paired confirmation
///
/// Run: flutter test --run-skipped test/pairing_screen_snapshot_test.dart
Future<void> main() async {
  await ensureSnapshotHarness();

  const padding = EdgeInsets.all(16);
  const pixelRatio = 3.0;
  final app = SupportedApp.supportedApps.first;

  /// Global top-left of [finder], in the same coordinate space `tester`
  /// reports everywhere else — NOT necessarily the PNG's (0,0). The PNG is a
  /// `RenderRepaintBoundary.toImage()` of `captureWidget`'s private boundary,
  /// so it is anchored at that widget's own origin, wherever that lands in
  /// the app's global coordinates.
  Offset topLeft(WidgetTester tester, Finder finder) => tester.getTopLeft(finder);
  Offset bottomLeft(WidgetTester tester, Finder finder) => tester.getBottomLeft(finder);

  /// Crops [source] to [crop] (in the source PNG's own physical-pixel space)
  /// and writes the result to [outputPath].
  Future<File> cropPng(WidgetTester tester, File source, {required String outputPath, required Rect crop}) async {
    late final File result;
    await tester.runAsync(() async {
      final bytes = await source.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final w = crop.width.round();
      final h = crop.height.round();
      canvas.drawImageRect(image, crop, Rect.fromLTWH(0, 0, crop.width, crop.height), Paint());
      final picture = recorder.endRecording();
      final cropped = await picture.toImage(w, h);
      final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
      final file = File(outputPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
      cropped.dispose();
      result = file;
    });
    return result;
  }

  testWidgets('pairing screen: scan card (scanning + discovered Wahoo KICKR)', (tester) async {
    final rootKey = GlobalKey();
    // Three real, already-recognised trainer models (see the whitelist in
    // trainer_card_snapshots_test.dart) so the scan card shows a plausible
    // multi-trainer result — "compatible FTMS trainers" (plural) — with the
    // featured Wahoo KICKR first, matching the connected card below it.
    final wahoo = ProxyDevice(BleDevice(deviceId: '00:11:22:33:44:55', name: 'Wahoo KICKR'));
    final zwiftHub = ProxyDevice(BleDevice(deviceId: '00:11:22:33:44:56', name: 'Zwift Hub'));
    final eliteDireto = ProxyDevice(BleDevice(deviceId: '00:11:22:33:44:57', name: 'Elite Direto XR'));

    final files = await captureWidget(
      tester,
      name: 'pairing_scan_full',
      width: 380,
      settle: false,
      padding: padding,
      pixelRatio: pixelRatio,
      builder: (context) => KeyedSubtree(
        key: rootKey,
        child: onboardingTrainerBody(
          context,
          app: app,
          trainers: [wahoo, zwiftHub, eliteDireto],
          onPick: (_) {},
          onRescan: () {},
        ),
      ),
    );

    // The scan card is a private class (`_ScanCard`) — findable by its
    // runtime type name even though it isn't importable.
    final scanCardFinder = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_ScanCard');
    expect(scanCardFinder, findsOneWidget);

    final contentTop = topLeft(tester, find.byKey(rootKey));
    final cardTop = topLeft(tester, scanCardFinder);
    final cardBottom = bottomLeft(tester, scanCardFinder);

    // Boundary origin, derived algebraically (see `topLeft` doc above):
    // captureWidget's RepaintBoundary wraps ColoredBox(Padding(padding,
    // SizedBox(child: our content))), so the boundary's top-left is exactly
    // `padding.topLeft` above our content's top-left in the same coordinate
    // space — regardless of where that content sits in the wider app.
    final boundaryTop = contentTop - Offset(padding.left, padding.top);

    // Determine actual pixel width from the captured PNG itself.
    late final int pngWidth;
    await tester.runAsync(() async {
      final bytes = await files.first.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      pngWidth = frame.image.width;
      frame.image.dispose();
    });

    final finalCrop = Rect.fromLTRB(
      0,
      (cardTop.dy - boundaryTop.dy) * pixelRatio,
      pngWidth.toDouble(),
      (cardBottom.dy - boundaryTop.dy) * pixelRatio,
    );
    // ignore: avoid_print
    print('SCAN crop=$finalCrop pngWidth=$pngWidth');

    await cropPng(
      tester,
      files.first,
      outputPath: 'build/snapshots/pairing_scan_card.png',
      crop: finalCrop,
    );
  });

  testWidgets('pairing screen: connected Wahoo KICKR card', (tester) async {
    final rootKey = GlobalKey();
    final wahoo = ProxyDevice(
      BleDevice(deviceId: '00:11:22:33:44:55', name: 'Wahoo KICKR'),
    )..debugSetTrainerAppConnected(true);

    final files = await captureWidget(
      tester,
      name: 'pairing_connected_full',
      width: 380,
      settle: false,
      padding: padding,
      pixelRatio: pixelRatio,
      builder: (context) => KeyedSubtree(
        key: rootKey,
        child: onboardingTrainerBody(
          context,
          app: app,
          trainers: [wahoo],
          onPick: (_) {},
        ),
      ),
    );

    // The connected card is the (unkeyed) bordered Container that is the
    // nearest Container ancestor of the "Connected" badge.
    final badgeFinder = find.byType(SecondaryBadge);
    expect(badgeFinder, findsOneWidget);
    final cardFinder = find.ancestor(of: badgeFinder, matching: find.byType(Container)).first;

    final contentTop = topLeft(tester, find.byKey(rootKey));
    final cardTop = topLeft(tester, cardFinder);
    final cardBottom = bottomLeft(tester, cardFinder);
    final boundaryTop = contentTop - Offset(padding.left, padding.top);

    late final int pngWidth;
    await tester.runAsync(() async {
      final bytes = await files.first.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      pngWidth = frame.image.width;
      frame.image.dispose();
    });

    final finalCrop = Rect.fromLTRB(
      0,
      (cardTop.dy - boundaryTop.dy) * pixelRatio,
      pngWidth.toDouble(),
      (cardBottom.dy - boundaryTop.dy) * pixelRatio,
    );
    // ignore: avoid_print
    print('CONNECTED crop=$finalCrop pngWidth=$pngWidth');

    await cropPng(
      tester,
      files.first,
      outputPath: 'build/snapshots/pairing_connected_card.png',
      crop: finalCrop,
    );
  });
}
