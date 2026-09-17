// Support-chat screenshots must show the screen the rider was on, never the
// sheet, drawer, popover, toast or dialog they opened support from.
//
// Jonas (2026-09-16): most support screenshots only showed the "Need help?"
// sheet. captureOverviewScreenshot() rendered a RepaintBoundary wrapped around
// the whole shadcn Scaffold, and shadcn paints sheets, drawers and toasts
// INSIDE that Scaffold (its DrawerOverlay and ToastLayer), so a help sheet
// that was still open at capture time ended up in the picture.
//
// These tests pump the real Navigation shell and require the capture to be
// pixel-identical whether or not something is open on top of it, while still
// showing the screen as it is laid out: the app header, the (unrolled) page
// and the footer.
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate, installLoggerErrorListener;
import 'package:bike_control/pages/home/home_sheets.dart' show openControllerHelpSheet;
import 'package:bike_control/pages/navigation.dart';
import 'package:bike_control/pages/overview.dart';
import 'package:bike_control/services/blog_service.dart';
import 'package:bike_control/services/overview_screenshot.dart';
import 'package:bike_control/widgets/title.dart';
import 'package:bike_control/widgets/ui/help_button.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/utils/shared.dart' show Logger;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../widget_snapshot.dart';

/// Production caps the capture at 2x; rendering the test surface at 2x too
/// means every logical offset the compositor handles is scaled, so a mix-up
/// between logical and physical pixels would misplace the page against its
/// header and footer.
const double _pixelRatio = 2.0;

/// Channel step up to which a page pixel still counts as unchanged when a
/// capture is compared with the screen: the screenshot rasterizes the page
/// on its own, which moves blended edges by a step or two.
const int _roundOff = 8;
const Size _phone = Size(400, 800);
const Size _desktop = Size(1000, 700);

Future<void> main() async {
  await ensureSnapshotHarness();
  // The comparisons below need a page that holds still. The desktop rail's
  // blog list fetches bikecontrol.app and shows animated skeletons until that
  // returns, so take the network away (the fetch fails at once and the list
  // settles empty) instead of racing a real request.
  HttpOverrides.global = _NoNetwork();
  // Every recordError() otherwise starts the full diagnostics gather (mDNS
  // scans and all) in the background; a plain log is all these tests need.
  installLoggerErrorListener();
  Logger.onRecordError = (message, error, _) => debugPrint('recordError($message): $error');

  Future<void> pumpShell(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = _pixelRatio;
    tester.view.physicalSize = size * _pixelRatio;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ShadcnApp(
        debugShowCheckedModeBanner: false,
        // As in main.dart: shadcn's own default turns popovers and menus into
        // sheets on phones.
        menuHandler: OverlayHandler.popover,
        popoverHandler: OverlayHandler.popover,
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        theme: ThemeData(colorScheme: ColorSchemes.lightSlate, radius: 0.7),
        home: const Navigation(),
      ),
    );
    await tester.pump();
    // Let the (network-less) blog fetch resolve so its skeletons are gone
    // before anything is captured.
    await tester.runAsync(() => BlogService().fetchPosts());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  // Any context on the page itself: below the Scaffold, so shadcn finds the
  // Scaffold's DrawerOverlay and ToastLayer from it, exactly like the home
  // page's own "Something not working?" button does.
  BuildContext pageContext(WidgetTester tester) => tester.element(find.byType(OverviewPage));

  Future<void> settleOverlay(WidgetTester tester) async {
    await tester.pump();
    // Longest entry animation involved is the toast's 500 ms.
    await tester.pump(const Duration(milliseconds: 700));
  }

  /// The support screenshot exactly as the chat receives it (PNG), decoded.
  Future<_Rgba> captureSupportScreenshot(WidgetTester tester) async {
    final context = pageContext(tester);
    late _Rgba result;
    await tester.runAsync(() async {
      var done = false;
      final pending = captureOverviewScreenshot(context: context).whenComplete(() => done = true);
      // The stitched capture scrolls the page and awaits a frame per step;
      // the test binding only produces frames when pumped.
      while (!done) {
        await Future<void>.delayed(const Duration(milliseconds: 16));
        if (!done) await tester.pump();
      }
      final attachment = await pending;
      expect(attachment, isNotNull, reason: 'the capture failed (see the recordError output above)');
      result = await _Rgba.decodePng(attachment!.file.bytes!);
    });
    return result;
  }

  /// What the whole shell looks like on screen right now.
  Future<_Rgba> captureWholeShell(WidgetTester tester) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(overviewScreenshotKey));
    late _Rgba result;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: _pixelRatio);
      try {
        // Same PNG round trip as the support screenshot, so both sides of a
        // comparison went through identical encoding.
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        result = await _Rgba.decodePng(png!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    });
    return result;
  }

  void expectSameImage(_Rgba actual, _Rgba expected, String reason) {
    expect(actual.sizeLabel, expected.sizeLabel, reason: reason);
    expect(actual.differingPixels(expected), 0, reason: reason);
  }

  /// Checks that [shot] opens with the app header exactly as [screen] shows
  /// it, and returns how many pixel rows that header takes.
  int expectHeaderOnTop(WidgetTester tester, _Rgba shot, _Rgba screen) {
    expect(shot.width, screen.width);
    final appBar = find.ancestor(of: find.byType(AppTitle), matching: find.byType(AppBar));
    final headerRows = (tester.getBottomLeft(appBar).dy * _pixelRatio).floor();
    expect(
      screen.distinctColors(toRow: headerRows),
      greaterThan(1),
      reason: 'the header rows carry the app title, not just background',
    );
    expect(
      shot.differingPixels(screen, toRow: headerRows),
      0,
      reason: 'the app header must open the screenshot, exactly as on screen',
    );
    return headerRows;
  }

  // `marker` is text only the open overlay shows, proving it really is open.
  final overlays = <({String name, String Function() marker, void Function(BuildContext) open})>[
    (
      name: 'the "Need help?" sheet',
      marker: () => AppLocalizations.current.onboardingHelpSheetTitle,
      open: (context) => unawaited(openControllerHelpSheet(context)),
    ),
    (
      name: 'a drawer',
      marker: () => 'Drawer on top',
      open: (context) => unawaited(
        openDrawer<void>(
          context: context,
          position: OverlayPosition.left,
          builder: (_) => const SizedBox(width: 240, child: Text('Drawer on top')),
        ),
      ),
    ),
    (
      name: 'a popover',
      marker: () => 'Popover on top',
      open: (context) => showPopover<void>(
        context: context,
        alignment: Alignment.topCenter,
        builder: (_) => const SurfaceCard(child: Text('Popover on top')),
      ),
    ),
    (
      name: 'a toast',
      marker: () => 'Toast on top',
      open: (context) => showToast(
        context: context,
        location: ToastLocation.topCenter,
        showDuration: const Duration(minutes: 5),
        builder: (_, _) => const SurfaceCard(child: Text('Toast on top')),
      ),
    ),
    (
      name: 'a dialog',
      marker: () => 'Dialog on top',
      open: (context) => unawaited(
        showDialog<void>(
          context: context,
          builder: (_) => const AlertDialog(title: Text('Dialog on top')),
        ),
      ),
    ),
  ];

  for (final size in [_phone, _desktop]) {
    final layout = size == _phone ? 'phone' : 'desktop';
    for (final overlay in overlays) {
      testWidgets('$layout: ${overlay.name} left open while support is opened is not in the screenshot', (
        tester,
      ) async {
        await pumpShell(tester, size);
        final nothingOpen = await captureSupportScreenshot(tester);

        overlay.open(pageContext(tester));
        await settleOverlay(tester);
        expect(find.text(overlay.marker()), findsOneWidget, reason: '${overlay.name} is really open');

        final withOverlay = await captureSupportScreenshot(tester);
        expectSameImage(withOverlay, nothingOpen, '${overlay.name} leaked into the support screenshot');
      });
    }

    testWidgets('$layout: the screenshot opens with the screen as shown: the app header, then the page', (
      tester,
    ) async {
      await pumpShell(tester, size);
      final screen = await captureWholeShell(tester);
      final shot = await captureSupportScreenshot(tester);

      // Taller than the screen only because the page is unrolled.
      expect(shot.height, greaterThanOrEqualTo(screen.height));
      final headerRows = expectHeaderOnTop(tester, shot, screen);

      // The phone's footer floats over the bottom of the screen, but the
      // screenshot puts it after the unrolled page (next test).
      final pageRows = size == _phone
          ? (tester.getTopLeft(find.byType(HelpButton)).dy * _pixelRatio).floor()
          : screen.height;
      expect(
        shot.differingPixels(screen, fromRow: headerRows, toRow: pageRows, tolerance: _roundOff),
        0,
        reason: 'the page must sit right below the header, as on screen',
      );
    });
  }

  testWidgets('phone: the floating footer closes the unrolled screenshot, as on screen at the end of the page', (
    tester,
  ) async {
    await pumpShell(tester, _phone);
    final shot = await captureSupportScreenshot(tester);

    final page = tester.state<ScrollableState>(
      find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first,
    );
    expect(page.position.maxScrollExtent, greaterThan(0), reason: 'the page must scroll for this to mean anything');
    page.position.jumpTo(page.position.maxScrollExtent);
    await tester.pump();
    final screenAtEnd = await captureWholeShell(tester);

    final footerRows = screenAtEnd.height - (tester.getTopLeft(find.byType(HelpButton)).dy * _pixelRatio).floor();
    expect(
      shot.differingPixels(
        screenAtEnd,
        fromRow: shot.height - footerRows,
        toRow: shot.height,
        otherFromRow: screenAtEnd.height - footerRows,
        tolerance: _roundOff,
      ),
      0,
      reason: 'the footer belongs over the end of the page, at the bottom of the screenshot',
    );
  });

  testWidgets('phone: with the keyboard up the footer is hidden, and the screenshot does without it', (tester) async {
    // shadcn keeps the footer offstage while the keyboard is up, so it has
    // never been painted and cannot be captured.
    tester.view.viewInsets = const FakeViewPadding(bottom: 300 * _pixelRatio);
    await pumpShell(tester, _phone);
    expect(find.byType(HelpButton), findsNothing);
    expect(find.byType(HelpButton, skipOffstage: false), findsOneWidget);

    final screen = await captureWholeShell(tester);
    // Fails if the capture fails.
    final shot = await captureSupportScreenshot(tester);
    expectHeaderOnTop(tester, shot, screen);
  });
}

class _NoNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      throw const SocketException('overview_screenshot_test runs without network');
}

class _Rgba {
  _Rgba(this.width, this.height, this.bytes);

  final int width;
  final int height;
  final Uint8List bytes;

  String get sizeLabel => '${width}x$height';

  static Future<_Rgba> decodePng(Uint8List png) async {
    final codec = await ui.instantiateImageCodec(png);
    try {
      final frame = await codec.getNextFrame();
      final image = frame.image;
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        return _Rgba(image.width, image.height, data!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  /// Pixels in rows `[fromRow, toRow)` (default: every row both images have)
  /// with a channel more than [tolerance] off the matching pixel of [other],
  /// whose rows are read from [otherFromRow] (default: [fromRow]) on.
  int differingPixels(_Rgba other, {int fromRow = 0, int? toRow, int? otherFromRow, int tolerance = 0}) {
    expect(other.width, width, reason: 'only same-width images can be compared');
    final endRow = toRow ?? min(height, other.height);
    final rowShift = (otherFromRow ?? fromRow) - fromRow;
    var count = 0;
    for (var y = fromRow; y < endRow; y++) {
      for (var x = 0; x < width; x++) {
        final i = (y * width + x) * 4;
        final j = ((y + rowShift) * width + x) * 4;
        for (var c = 0; c < 4; c++) {
          if ((bytes[i + c] - other.bytes[j + c]).abs() > tolerance) {
            count++;
            break;
          }
        }
      }
    }
    return count;
  }

  int distinctColors({required int toRow}) {
    final view = ByteData.sublistView(bytes);
    final colors = <int>{};
    for (var p = 0; p < toRow * width; p++) {
      colors.add(view.getUint32(p * 4));
    }
    return colors.length;
  }
}
