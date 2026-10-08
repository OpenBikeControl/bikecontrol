// Geometry and copy tests for the store marketing board.
//
// The boards themselves are golden PNGs regenerated on demand (`flutter test
// --run-skipped --update-goldens test/screenshot_test.dart`) and the suite that
// writes them is tagged out of a normal run — so nothing in the default suite
// looks at them. That leaves the board's *layout* and its *copy* untested, and
// both failure modes are silent: a headline that overlaps the device, a size
// written in pixels instead of a fraction of the canvas, or an accent phrase
// off by one character, all look fine on the slot you happened to open and
// wrong on the four you did not.
//
// So these assert the composition arithmetically, on every slot the pipeline
// emits, against the same fractions `CustomFrame` lays out with.
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart';

import 'custom_frame.dart';
import 'store_copy.dart';

typedef Slot = ({DeviceType type, TargetPlatform platform, Size size});

/// The longest headline the listing actually carries, so the shrink-to-fit path
/// is the one under test rather than a comfortable one-liner.
const String _longTitle = 'Modalità app companion con scorciatoie personalizzate';

/// The board slots — every slot except the frameless twin, which draws no
/// board at all and is covered by its own test below.
Iterable<Slot> get _boardSlots =>
    kStoreSlots.where((s) => s.type != DeviceType.noFrame);

/// Renders a slot's board at exactly its canvas size, so every rect this test
/// reads back is already in canvas coordinates.
Future<Size> _pumpBoard(
  WidgetTester tester,
  Slot slot, {
  String title = _longTitle,
  String? accent,
  double scale = 1.0,
}) async {
  final resolution = slot.size * scale;
  final canvas = resolution / kStorePixelRatio;
  tester.view.physicalSize = resolution;
  tester.view.devicePixelRatio = kStorePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox.fromSize(
          size: canvas,
          child: CustomFrame(
            platform: slot.type,
            title: title,
            accent: accent,
            device: ScreenshotDevice(
              // Never the entry's Windows platform: only Android/iOS chrome is
              // ever drawn, and the desktop slot uses the frameless chrome.
              platform: slot.platform == TargetPlatform.iOS
                  ? TargetPlatform.iOS
                  : TargetPlatform.android,
              resolution: resolution,
              pixelRatio: kStorePixelRatio,
              goldenSubFolder: 'boardTest/',
              frameBuilder: ScreenshotFrame.noFrame,
            ),
            // A plain colour stands in for the app: this is a test of the board
            // around it, not of any screen inside it.
            child: const ColoredBox(color: Color(0xFFFFFFFF)),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return canvas;
}

/// The headline's painted paragraph, scoped to the band so the device chrome's
/// own text can never be what gets measured.
RenderParagraph _headline(WidgetTester tester) => tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.byKey(CustomFrame.headlineKey),
        matching: find.byType(RichText),
      ),
    );

void main() {
  for (final slot in _boardSlots) {
    group(slot.type.name, () {
      testWidgets('the headline strip sits inside the band', (tester) async {
        final canvas = await _pumpBoard(tester, slot);
        final strip = tester.getRect(find.byKey(CustomFrame.headlineKey));
        final band = canvas.height * CustomFrame.bandFraction(slot.type);

        expect(strip.top, greaterThanOrEqualTo(0.0));
        expect(strip.left, greaterThanOrEqualTo(0.0));
        expect(strip.right, lessThanOrEqualTo(canvas.width));
        expect(strip.bottom, lessThanOrEqualTo(band),
            reason: 'the claim belongs on the board, not over the device');
      });

      testWidgets('the headline never reaches the device', (tester) async {
        await _pumpBoard(tester, slot);
        expect(
          tester
              .getRect(find.byKey(CustomFrame.headlineKey))
              .overlaps(tester.getRect(find.byKey(CustomFrame.deviceKey))),
          isFalse,
        );
      });

      testWidgets('the strip is sized off the canvas, never in pixels',
          (tester) async {
        final canvas = await _pumpBoard(tester, slot);
        final strip = tester.getRect(find.byKey(CustomFrame.headlineKey));
        expect(strip.left, closeTo(canvas.width * 0.07, 0.5));
        expect(strip.width, closeTo(canvas.width * 0.86, 0.5));
        expect(strip.height, closeTo(CustomFrame.band(slot.type, canvas), 0.5));
      });

      testWidgets('the tilt is paid for by starting the device lower',
          (tester) async {
        // A `Transform` resizes nothing, so a rotated device paints ABOVE the
        // box it is positioned in — and that rising corner would arrive inside
        // the headline. The frame compensates by pushing the box down; this is
        // the assertion that the payment is exactly right, so the painted top
        // edge still lands where a flat device's did.
        final canvas = await _pumpBoard(tester, slot);
        final device = tester.getRect(find.byKey(CustomFrame.deviceKey));
        final band = canvas.height * CustomFrame.bandFraction(slot.type);
        final paintedTop = device.top - CustomFrame.tiltOverhang(canvas);

        expect(paintedTop, closeTo(band, 0.5),
            reason: 'the rotated corner no longer starts at the band foot');
        expect(tester.getRect(find.byKey(CustomFrame.headlineKey)).bottom,
            lessThanOrEqualTo(paintedTop));
      });

      testWidgets('the rounded corner never swallows the status bar',
          (tester) async {
        // golden_screenshot paints the status bar as a full-width image, and
        // its clock and battery sit close to the edges — so a corner radius
        // sized for a phone, applied to a landscape tablet viewport, eats the
        // battery. The insets below are measured off the package's own topbar
        // assets (the opaque bounding box, as a fraction of the image), and
        // the assertion is simply that the corner arc still contains the
        // status bar's outermost corner.
        final ({double inset, double top}) statusBar = switch (slot.type) {
          // iphone_topbar.png 1320x186 drawn 62 logical tall: content spans
          // x 0.135–0.908, y from 0.403 of the bar.
          DeviceType.iPhone => (inset: 1 - 0.9076, top: 0.403 * 62),
          // android_phone_topbar.png 1280x156 drawn 52 tall: x to 0.934,
          // y from 0.372.
          DeviceType.android => (inset: 1 - 0.9344, top: 0.372 * 52),
          // android_tablet_topbar.png 2560x36 drawn 24 tall: x to 0.986,
          // y from 0.194 — the tightest of the four.
          DeviceType.androidTablet => (inset: 1 - 0.9859, top: 0.194 * 24),
          // ipad_topbar.png 2064x64 drawn 32 tall: x to 0.975, y from 0.297.
          DeviceType.iPad => (inset: 1 - 0.9748, top: 0.297 * 32),
          // The desktop slot uses the frameless chrome — no status bar to eat.
          _ => (inset: 0.0, top: 0.0),
        };
        if (statusBar.top == 0) return;

        final canvas = await _pumpBoard(tester, slot);
        // The app is laid out at the canvas' own logical size in this pipeline.
        final app = canvas;
        final r = math.min(app.width, app.height) *
            CustomFrame.radiusFraction(slot.type);
        // Distance from the corner circle's centre to the status bar's outer
        // corner. Deliberately not gated on the point actually falling in the
        // corner quadrant: outside it this is stricter than it needs to be,
        // and erring towards a slightly squarer screen is the safe direction.
        final dx = app.width * statusBar.inset - r;
        final dy = statusBar.top - r;
        expect(math.sqrt(dx * dx + dy * dy), lessThan(r),
            reason: 'a radius of $r clips the status bar on ${slot.type.name}');
      });

      testWidgets('the device bleeds off the bottom of the canvas',
          (tester) async {
        // A product shot, not a boxed thumbnail.
        final canvas = await _pumpBoard(tester, slot);
        final device = tester.getRect(find.byKey(CustomFrame.deviceKey));
        expect(device.bottom, greaterThan(canvas.height));
      });

      testWidgets('the accent recolours the phrase without rewriting the claim',
          (tester) async {
        await _pumpBoard(tester, slot,
            title: 'Control any trainer with ANY controller',
            accent: 'ANY controller');
        final span = _headline(tester).text;
        expect(span.toPlainText(), 'Control any trainer with ANY controller',
            reason: 'splitting the headline must not change what it says');
        // Exactly one run is coloured, and it is the accent.
        final coloured = <String>[];
        span.visitChildren((s) {
          if (s is TextSpan && s.style?.color == kStoreAccentColor) {
            coloured.add(s.toPlainText());
          }
          return true;
        });
        expect(coloured, <String>['ANY controller']);
      });

      testWidgets('an accent that is not in the headline leaves it plain',
          (tester) async {
        // A miss is a design regression, not a reason to fail a release build.
        await _pumpBoard(tester, slot, title: 'Full Control', accent: 'nope');
        expect(_headline(tester).text.toPlainText(), 'Full Control');
      });

      testWidgets('a word too long for the strip is never broken in half',
          (tester) async {
        // A word wider than the strip does not wrap, it BREAKS — mid-word, no
        // hyphen. It is a WIDTH failure, and shrink-to-fit only ever solved
        // height, so the block is laid out at the width of its widest word and
        // `FittedBox` pays for it by taking the whole claim down a size.
        final canvas =
            await _pumpBoard(tester, slot, title: 'Geschwindigkeitsbegrenzungsanzeige');
        // One word, so one line — measured as height, since a break would put
        // the tail on a second line and double it. 1.15 is the style's line
        // height; the paragraph is measured before `FittedBox` scales it.
        final lineHeight =
            canvas.width * CustomFrame.titleFraction(slot.type) * 1.15;
        expect(_headline(tester).size.height, lessThan(lineHeight * 1.5),
            reason: 'the single word was broken across lines');

        // And it still fits its reserved box, because `FittedBox` pays for the
        // extra width by scaling — the whole point of widening the layout
        // rather than letting the text overflow.
        final strip = tester.getRect(find.byKey(CustomFrame.headlineKey));
        final painted = tester.getRect(find.descendant(
          of: find.byKey(CustomFrame.headlineKey),
          matching: find.byType(RichText),
        ));
        expect(painted.width, lessThanOrEqualTo(strip.width + 0.5));
        expect(painted.height, lessThanOrEqualTo(strip.height + 0.5));
      });

      testWidgets('an ordinary headline still lays out at the strip width',
          (tester) async {
        // The widening is a floor, not a new width: a headline whose words all
        // fit must lay out exactly as it did, or every board on the listing
        // quietly loses type size to a rule meant for one word.
        //
        // Short words on purpose. The test font is close to monospace at one em
        // a glyph — far wider than the real one — so the narrow phone strips
        // hold only about twelve characters here, and a title picked for its
        // *rendered* length would trip the widening path and test nothing.
        final canvas =
            await _pumpBoard(tester, slot, title: 'Full Control of Shifting');
        expect(_headline(tester).size.width, closeTo(canvas.width * 0.86, 0.5));
      });
    });
  }

  // The anti-hardcoding test, and the reason the whole board is written in
  // fractions: double the canvas and every part of the lockup doubles with it.
  // A margin or a type size written as a pixel count sits still instead, and
  // that is the failure that only ever shows up as "it looks fine on the phone
  // and wrong on the tablet".
  testWidgets('the whole lockup scales with the canvas, never in pixels',
      (tester) async {
    final slot = kStoreSlots.firstWhere((s) => s.type == DeviceType.iPhone);

    await _pumpBoard(tester, slot);
    final small = tester.getRect(find.byKey(CustomFrame.headlineKey));
    final smallDevice = tester.getRect(find.byKey(CustomFrame.deviceKey));
    final smallType = _headline(tester).text.style!.fontSize!;

    await _pumpBoard(tester, slot, scale: 2);
    final large = tester.getRect(find.byKey(CustomFrame.headlineKey));
    final largeDevice = tester.getRect(find.byKey(CustomFrame.deviceKey));
    final largeType = _headline(tester).text.style!.fontSize!;

    expect(large.left, closeTo(small.left * 2, 0.5));
    expect(large.top, closeTo(small.top * 2, 0.5));
    expect(large.width, closeTo(small.width * 2, 0.5));
    expect(large.height, closeTo(small.height * 2, 0.5));
    expect(largeDevice.top, closeTo(smallDevice.top * 2, 0.5));
    expect(largeType, closeTo(smallType * 2, 0.5));
  });

  // The frameless twin is bare app pixels for the website and the blog, so
  // there is no board for a headline to sit on.
  testWidgets('the frameless twin carries no board and no headline',
      (tester) async {
    final slot = kStoreSlots.firstWhere((s) => s.type == DeviceType.noFrame);
    await _pumpBoard(tester, slot, title: _longTitle);

    expect(find.byKey(CustomFrame.headlineKey), findsNothing);
    expect(find.byKey(CustomFrame.deviceKey), findsNothing);
    expect(find.text(_longTitle), findsNothing);
  });

  group('the hue ramp', () {
    double hue(Color c) => HSLColor.fromColor(c).hue;

    test('walks the hue in listing order, ends symmetric about the brand', () {
      // The two ends sit an equal distance either side of the unshifted brand
      // colour, so the middle of the listing IS the brand and neither end is
      // the odd one out.
      final first = kStoreBrandStyle.forScene(kSceneOrder.first);
      final last = kStoreBrandStyle.forScene(kSceneOrder.last);
      expect(
        hue(first.gradientTop) - hue(kStoreBrandStyle.gradientTop),
        closeTo(-(hue(last.gradientTop) - hue(kStoreBrandStyle.gradientTop)), 0.6),
      );
    });

    test('every board is a different colour, and none by much', () {
      final hues = <double>[
        for (final id in kSceneOrder) hue(kStoreBrandStyle.forScene(id).gradientTop),
      ];
      expect(hues.toSet().length, kSceneOrder.length,
          reason: 'two boards share a hue');
      // Monotonic: the ramp has to follow the order the listing is scrolled in,
      // or it is six colours rather than a progression.
      for (var i = 1; i < hues.length; i++) {
        expect(hues[i], greaterThan(hues[i - 1]));
      }
      // And the whole set stays inside the brand family: 24° keeps every board
      // recognisably this blue while the set still moves.
      expect(hues.last - hues.first, closeTo(24, 0.6));
    });

    test('shifts the two stops together, and leaves the type alone', () {
      final shifted = kStoreBrandStyle.forScene(kSceneOrder.last);
      // Both stops move by the same amount, or the gradient changes character
      // rather than colour.
      expect(
        hue(shifted.gradientTop) - hue(kStoreBrandStyle.gradientTop),
        closeTo(
            hue(shifted.gradientBottom) - hue(kStoreBrandStyle.gradientBottom), 0.6),
      );
      expect(shifted.titleColor, kStoreBrandStyle.titleColor);
      expect(shifted.accentColor, kStoreBrandStyle.accentColor);
    });

    test('a scene that is not in the listing is left unshifted', () {
      // The frameless twin is not a board; the ramp is decoration and must not
      // throw on the release pipeline over an id it does not know.
      final bare = kStoreBrandStyle.forScene('frontderailleur-gear');
      expect(bare.gradientTop, kStoreBrandStyle.gradientTop);
      expect(bare.gradientBottom, kStoreBrandStyle.gradientBottom);
    });
  });

  group('headline contrast', () {
    // The headline is large bold type, so WCAG's large-text floor (3:1) is the
    // legal minimum — but it is the one line a shopper reads, on a thumbnail,
    // so the white claim is held to the body-text 4.5:1 and only the accent
    // phrase gets the 3:1 allowance. Measured against the worst background the
    // strip can sit on: either gradient stop, hue-shifted for the scene, with
    // the glow's light added at that point of the strip.
    double luminance(Color c) {
      double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
      return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
    }

    double contrast(Color a, Color b) {
      final la = luminance(a), lb = luminance(b);
      return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
    }

    for (final slot in _boardSlots) {
      test('${slot.type.name}: every scene headline reads on its board', () {
        final canvas = slot.size / kStorePixelRatio;
        final side = canvas.width * 0.07;
        final top = canvas.height * 0.035;
        final strip = Rect.fromLTWH(side, top, canvas.width - 2 * side, CustomFrame.band(slot.type, canvas));
        final points = <Offset>[
          strip.topLeft, strip.topCenter, strip.topRight,
          strip.centerLeft, strip.center, strip.centerRight,
          strip.bottomLeft, strip.bottomCenter, strip.bottomRight,
        ];
        for (final scene in kSceneOrder) {
          final style = kStoreBrandStyle.forScene(scene);
          for (final stop in <Color>[style.gradientTop, style.gradientBottom]) {
            for (final p in points) {
              final glow = CustomFrame.glowAlphaAt(p, canvas);
              final bg = Color.lerp(stop, const Color(0xFFFFFFFF), glow)!;
              expect(contrast(style.titleColor, bg), greaterThanOrEqualTo(4.5),
                  reason: '$scene: white headline on $bg at $p');
              expect(contrast(style.accentColor, bg), greaterThanOrEqualTo(3.0),
                  reason: '$scene: accent on $bg at $p');
            }
          }
        }
      });
    }
  });

  group('the copy', () {
    test('every scene in the listing has a headline in every locale', () {
      for (final scene in kSceneOrder) {
        expect(kSceneHeadlines[scene], isNotNull, reason: '$scene has no headlines');
        for (final loc in kScreenshotLocales) {
          expect(kSceneHeadlines[scene]![loc], isNotNull,
              reason: '$scene is missing its $loc headline');
        }
      }
    });

    test('no headline is longer than the board can carry', () {
      for (final scene in kSceneOrder) {
        for (final loc in kScreenshotLocales) {
          final headline = sceneHeadline(scene, loc);
          expect(headline.length, lessThanOrEqualTo(kSceneHeadlineMaxChars),
              reason: '$scene/$loc is ${headline.length} characters: "$headline"');
        }
      }
    });

    test('every accent is really a run of its own headline', () {
      // A phrase that is off by one character does not throw and does not
      // warn — it silently renders that one headline plain.
      for (final scene in kSceneOrder) {
        for (final loc in kScreenshotLocales) {
          final accent = sceneAccent(scene, loc);
          expect(accent, isNotNull, reason: '$scene/$loc has no accent phrase');
          expect(sceneHeadline(scene, loc), contains(accent!),
              reason: '"$accent" is not in the $loc headline for $scene');
        }
      }
    });

    test('the accent picks out a phrase rather than the whole claim', () {
      // Colouring everything is colouring nothing.
      for (final scene in kSceneOrder) {
        for (final loc in kScreenshotLocales) {
          final headline = sceneHeadline(scene, loc);
          final accent = sceneAccent(scene, loc)!;
          expect(accent.length / headline.length, lessThan(2 / 3),
              reason: '$scene/$loc accents "$accent" out of "$headline"');
        }
      }
    });
  });

  test('the listing order matches the one the upload script uploads in', () {
    // The hue ramp reads a scene's position out of kSceneOrder, and the shell
    // script numbers the uploaded files 01_…, 02_… out of its own SCENES line.
    // Two copies of the listing order is how one of them drifts.
    final script = File('scripts/prepare_store_screenshots.sh').readAsStringSync();
    final line = RegExp(r'^SCENES="([^"]*)"', multiLine: true).firstMatch(script);
    expect(line, isNotNull, reason: 'prepare_store_screenshots.sh has no SCENES= line');
    expect(line!.group(1)!.split(RegExp(r'\s+')), kSceneOrder);
  });
}
