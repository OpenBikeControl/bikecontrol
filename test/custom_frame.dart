// The marketing board the App Store / Play Store / Mac App Store assets are
// drawn on: a BikeControl-gradient canvas carrying the scene's headline, with
// the app rendered inside a `golden_screenshot` device frame below it.
//
// Every number in the grid below is a FRACTION of the canvas, never a pixel
// count, and that is load-bearing rather than tidy: the slots this pipeline
// emits are 440x956, 414x896, 1280x800, 917x688 and 853x533 logical, so
// anything expressed in pixels lands somewhere different on each of them.
// `store_board_test.dart` asserts it stays that way.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:golden_screenshot/golden_screenshot.dart';

import 'store_copy.dart';

/// Which device chrome (status bar / gesture handle) is drawn around the app —
/// and, for [DeviceType.noFrame], whether there is a marketing board at all.
enum DeviceType {
  android,
  androidTablet,
  iPhone,
  iPad,
  desktop,

  /// No chrome and no board: the bare app pixels, for the website, the blog and
  /// the docs. Never a store slot.
  noFrame,
}

/// Every slot the pipeline renders, and what each one satisfies.
///
/// These resolutions are not a style choice — App Store Connect and Play
/// Console reject an upload whose pixel size is outside their window, and
/// fastlane classifies a screenshot purely by pixel size:
///
///  * `android` 1320×2868 — Play Console phone screenshots (9:16, inside the
///    320–3840 px window).
///  * `androidTablet` 3840×2400 — Play Console 10" tablet screenshots.
///  * `iPhone` 1242×2688 — App Store Connect iPhone 6.5" display. In deliver's
///    `IOS_65` list, so it lands in the set it says it does. (1290×2796 must
///    NOT be used as a "6.9-inch" set: deliver has no 6.9" class and maps it to
///    `APP_IPHONE_67`, so the upload dies with "Too many screenshots found for
///    device".)
///  * `iPad` 2752×2064 — App Store Connect iPad 12.9" display, required while
///    the binary targets iPad.
///  * `desktop` 2560×1600 — Mac App Store, which deliver maps to `APP_DESKTOP`.
///  * `noFrame` 1100×2390 — not a store slot: the frameless twin used by the
///    website, the blog and the docs.
///
/// `scripts/prepare_store_screenshots.sh` copies these into the per-locale
/// fastlane layout; `store_board_test.dart` keeps its scene order and this
/// table honest.
const List<({DeviceType type, TargetPlatform platform, Size size})> kStoreSlots =
    <({DeviceType type, TargetPlatform platform, Size size})>[
  (type: DeviceType.android, platform: TargetPlatform.android, size: Size(1320, 2868)),
  (type: DeviceType.androidTablet, platform: TargetPlatform.android, size: Size(3840, 2400)),
  (type: DeviceType.iPhone, platform: TargetPlatform.iOS, size: Size(1242, 2688)),
  (type: DeviceType.iPad, platform: TargetPlatform.iOS, size: Size(2752, 2064)),
  (type: DeviceType.desktop, platform: TargetPlatform.windows, size: Size(2560, 1600)),
  // 1320x2868 / 1.2, kept spelled out so the list stays const.
  (type: DeviceType.noFrame, platform: TargetPlatform.windows, size: Size(1100, 2390)),
];

/// The pixel ratio every slot's canvas is laid out at.
const double kStorePixelRatio = 3;

/// A store screenshot: a headline band over a framed, slightly tilted device.
///
/// Laid out in the canvas' logical space (`device.resolution / pixelRatio`).
/// The app is laid out at that same logical size and scaled into the device
/// area by a [FittedBox], so every slot renders the same fixture at a realistic
/// viewport instead of at whatever shape the store demands of the PNG.
class CustomFrame extends StatelessWidget {
  const CustomFrame({
    super.key,
    required this.title,
    required this.device,
    required this.child,
    required this.platform,
    this.frameColors,
    this.style = kStoreBrandStyle,
    this.accent,
  });

  final DeviceType platform;

  /// The marketing headline. Ignored entirely on [DeviceType.noFrame].
  final String title;

  final ScreenshotDevice device;
  final ScreenshotFrameColors? frameColors;

  /// The gradient / headline / accent colours, already rotated for this scene's
  /// place in the listing — see [StoreFrameStyle.forScene].
  final StoreFrameStyle style;

  /// The run of [title] to pick out in [StoreFrameStyle.accentColor]. Null, or
  /// a run that is not in the title, leaves the headline plain: a headline
  /// missing its accent is a design regression, but a *crash* on the release
  /// pipeline over one is out of proportion. `store_board_test.dart` is what
  /// makes the miss loud instead.
  final String? accent;

  final Widget child;

  /// The headline's *reserved* box — the whole strip the text may occupy, not
  /// the shrink-to-fit glyphs inside it.
  static const Key headlineKey = Key('storeBoardHeadline');

  /// The framed device's box, including the part that bleeds off the canvas.
  static const Key deviceKey = Key('storeBoardDevice');

  // --------------------------------------------------------------- the grid

  /// Side margin, both edges.
  static const double _sideFraction = 0.07;

  /// Where the band's content starts, below the canvas' top edge.
  static const double _bandTopFraction = 0.035;

  /// Clearance kept between the bottom of the band's content and the device.
  static const double _bandFootFraction = 0.015;

  /// Landscape canvases — the tablet and desktop slots — hold two to three
  /// times as many characters on a line as a phone does, so they need fewer
  /// lines but a proportionally *deeper* band, because their canvas is short.
  static bool isWide(DeviceType platform) => const <DeviceType>{
        DeviceType.androidTablet,
        DeviceType.iPad,
        DeviceType.desktop,
      }.contains(platform);

  /// Fraction of the canvas height given to the headline band.
  ///
  /// 0.17 on the phone slots. The landscape slots get 0.22 — not because they
  /// need more room for text, but because their canvas is short: at 0.17 the
  /// desktop board's band is 91 logical units against type that wants 44, which
  /// left `FittedBox` scaling the claim to ~40% and shipping the tablet and
  /// desktop boards in a visibly smaller voice than the phone ones. It costs
  /// the device 5% of a canvas whose landscape app render has room to spare.
  static double bandFraction(DeviceType platform) => isWide(platform) ? 0.22 : 0.17;

  /// The bezel around the screen, as a fraction of the viewport's SHORT side.
  ///
  /// Short side, not width, because a bezel is a physical property of the
  /// device: a tablet held in landscape has the same bezel it had in portrait.
  /// Taken off the width it would be 28 logical units on the 1280-wide tablet
  /// against 9 on the phone — the same slab of plastic, three times thicker.
  static const double bezelFraction = 0.022;

  /// The screen's corner radius, as a fraction of the viewport's SHORT side.
  ///
  /// Phones really are dramatically rounder than tablets — an iPhone 15 Pro's
  /// corner is about 0.14 of its width, an iPad Pro's about 0.02 — so one
  /// fraction cannot serve both. 0.085 is what the phone slots already look
  /// right at; the tablets get 0.030.
  ///
  /// This is not only taste. `golden_screenshot` paints the status bar as a
  /// full-width image whose clock and battery sit close to the edges — on the
  /// iPad slot they end 23 logical units in from the right and start 9.5 down
  /// from the top — and a radius past ~53 there swallows the battery. The
  /// phone fraction applied to a 917-wide landscape viewport gives 78.
  /// `store_board_test.dart` holds every slot's corner clear of that point.
  static double radiusFraction(DeviceType platform) => isWide(platform) ? 0.030 : 0.085;

  /// Headline size, as a fraction of the canvas WIDTH.
  ///
  /// 0.072 on the phone slots. A landscape canvas is two to three times wider,
  /// so the same fraction would put a single line past the height of any band
  /// the board can spare — 0.045 is the width-relative size at which the
  /// longest headline in the set still lands on one line there.
  static double titleFraction(DeviceType platform) => isWide(platform) ? 0.045 : 0.072;

  /// The height actually available to the band's content, once the top inset
  /// and the clearance above the device are taken off.
  static double band(DeviceType platform, Size canvas) =>
      canvas.height * (bandFraction(platform) - _bandTopFraction - _bandFootFraction);

  // ------------------------------------------------------------------ the look
  //
  // Three things separate this board from a flat gradient with a screenshot
  // pasted on it. Each is one number, so the next argument about any of them is
  // also cheap to settle.

  /// Device rotation, in degrees, negative leaning the top to the left.
  ///
  /// −3 rather than the −6 a first pass would reach for: enough that the phone
  /// reads as an object standing on the board instead of a rectangle pasted
  /// onto it, not so much that the app-bar text visibly climbs. At −2 it reads
  /// as a mistake; past −4 the UI starts looking like it is sliding off.
  static const double deviceTilt = -3;

  /// Peak opacity of the radial light behind the band, and how far it reaches.
  ///
  /// What makes a glow read is the falloff, not the peak: 0.20 ramping LINEARLY
  /// to zero across nine tenths of the canvas, behind a phone covering most of
  /// it, is invisible. [_glowStops] holds better than half the strength through
  /// the inner half before dropping, which is what gives the light a centre.
  ///
  /// It sits behind the device, below the headline, not behind the type: lit
  /// from under the claim, the board's light end took white type down to 3:1
  /// and the accent phrase to 2:1. `store_board_test.dart` holds the strip's
  /// contrast against exactly this falloff.
  static const double _glowPeak = 0.20;
  static const double _glowRadius = 0.50;
  static const Alignment _glowCenter = Alignment(0, 0.3);
  static const List<double> _glowStops = <double>[0.0, 0.45, 1.0];

  /// The glow's white opacity at [point] on a [canvas] — the same falloff the
  /// `RadialGradient` below paints, so `store_board_test.dart` can hold the
  /// headline's contrast against the light it actually sits in.
  static double glowAlphaAt(Offset point, Size canvas) {
    final centre = _glowCenter.withinRect(Offset.zero & canvas);
    final reach = _glowRadius * canvas.shortestSide;
    final t = (point - centre).distance / reach;
    final peaks = <double>[_glowPeak, _glowPeak * 0.55, 0];
    if (t >= _glowStops.last) return 0;
    for (var i = 1; i < _glowStops.length; i++) {
      if (t <= _glowStops[i]) {
        final f = (t - _glowStops[i - 1]) / (_glowStops[i] - _glowStops[i - 1]);
        return peaks[i - 1] + (peaks[i] - peaks[i - 1]) * f;
      }
    }
    return 0;
  }

  /// The width the headline is laid out at: [strip] — the reserved band — or
  /// the widest single word in [title], whichever is larger.
  ///
  /// Without the second term a word too long for the strip does not wrap, it
  /// **breaks**, mid-word, with no hyphen — so a German compound or
  /// "ciclocomputador" ships snapped in half. `FittedBox(scaleDown)` scales in
  /// both dimensions, so laying the block out wider simply makes the type
  /// smaller: a headline in a slightly quieter voice, which is a far better
  /// outcome for a store listing than a broken word.
  ///
  /// Only the words the copy actually contains are measured, so this costs
  /// nothing on the boards where nothing is too long — the strip wins and the
  /// layout is exactly what it was.
  static double headlineLayoutWidth(
    String title, {
    required TextStyle style,
    required double strip,
  }) {
    var widest = strip;
    for (final word in title.split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      final painter = TextPainter(
        text: TextSpan(text: word, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      widest = math.max(widest, painter.width);
      painter.dispose();
    }
    return widest;
  }

  /// How far [deviceTilt] lifts the device's rising corner, in canvas units.
  ///
  /// A `Transform` resizes nothing: a rotated device paints ABOVE the box it is
  /// positioned in, and that rising corner arrives inside the headline. The
  /// frame pays for it by starting the device lower by exactly this much, so
  /// the painted top edge lands where an untilted device's was and every
  /// clearance argued for the flat board still holds.
  ///
  /// Half the device's width times the sine of the angle — the rotation is
  /// about the centre, so half the width is the lever. The device's own height
  /// does not enter into it: the bottom already bleeds off the canvas.
  static double tiltOverhang(Size canvas) =>
      (canvas.width * 0.88 / 2) * math.sin(deviceTilt.abs() * math.pi / 180);

  /// The headline, with [accent] in the accent colour if it is there to find.
  TextSpan _headlineSpan(TextStyle textStyle) {
    final phrase = accent;
    final at = phrase == null ? -1 : title.indexOf(phrase);
    if (at < 0) return TextSpan(text: title, style: textStyle);
    return TextSpan(
      style: textStyle,
      children: <TextSpan>[
        TextSpan(text: title.substring(0, at)),
        TextSpan(text: phrase, style: TextStyle(color: style.accentColor)),
        TextSpan(text: title.substring(at + phrase!.length)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // The frameless set is the bare app pixels — no board, no bezel, no
    // headline. The Scaffold stays because the golden capture finds it by type.
    if (platform == DeviceType.noFrame) return Scaffold(body: child);

    final canvas = device.resolution / device.pixelRatio;
    // The app is laid out at the canvas' own logical size, which for every slot
    // this pipeline emits is already a realistic device viewport (440x956,
    // 414x896, 1280x800, …) rather than the store's PNG aspect. So `app` and
    // `canvas` coincide here — but the bezel and the corner radius below are
    // still written against `app`, because they are painted INSIDE the
    // FittedBox that scales the app: sized off the canvas they would swell or
    // shrink with the scale factor instead of staying a constant fraction of
    // the phone.
    final app = canvas;
    final bandHeight = canvas.height * bandFraction(platform);
    final bandTop = canvas.height * _bandTopFraction;
    final bandInner = band(platform, canvas);
    final side = canvas.width * _sideFraction;
    final short = math.min(app.width, app.height);
    final bezel = short * bezelFraction;
    final radius = short * radiusFraction(platform);
    final titleStyle = TextStyle(
      color: style.titleColor,
      fontSize: canvas.width * titleFraction(platform),
      height: 1.15,
      letterSpacing: -0.4,
      fontWeight: FontWeight.w800,
    );

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          // Corner to corner rather than straight down. The same two brand
          // stops travel further across the canvas that way, so the board has a
          // light side and a dark side instead of a horizon.
          gradient: LinearGradient(
            colors: <Color>[style.gradientTop, style.gradientBottom],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // The light. Under everything, so it lifts the board's own colour
            // and never washes out the type sitting on it.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: _glowCenter,
                    radius: _glowRadius,
                    colors: <Color>[
                      const Color(0xFFFFFFFF).withValues(alpha: _glowPeak),
                      const Color(0xFFFFFFFF).withValues(alpha: _glowPeak * 0.55),
                      const Color(0x00FFFFFF),
                    ],
                    stops: _glowStops,
                  ),
                ),
              ),
            ),
            // Headline. Left-aligned in the band and centred on the band's own
            // middle rather than hung off its top, so a one-line claim sits on
            // the same axis a three-line one grows symmetrically around instead
            // of sliding down into the device. It shrinks to fit rather than
            // wrapping off the board, so a long translation can never collide
            // with the device below it.
            Positioned(
              key: headlineKey,
              top: bandTop,
              left: side,
              right: side,
              height: bandInner,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: headlineLayoutWidth(
                      title,
                      style: titleStyle,
                      strip: canvas.width - 2 * side,
                    ),
                    child: Text.rich(
                      _headlineSpan(titleStyle),
                      textAlign: TextAlign.left,
                      style: titleStyle,
                    ),
                  ),
                ),
              ),
            ),
            // The device. Bleeds off the bottom edge (negative `bottom`) so the
            // screen is as large as possible and the board reads as a product
            // shot rather than a boxed thumbnail.
            Positioned(
              top: bandHeight + tiltOverhang(canvas),
              left: canvas.width * 0.06,
              right: canvas.width * 0.06,
              bottom: -canvas.height * 0.02,
              child: FittedBox(
                key: deviceKey,
                child: Transform.rotate(
                  angle: deviceTilt * math.pi / 180,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF15171A),
                      borderRadius: BorderRadius.circular(radius + bezel),
                      // Sized off the viewport's short side like the bezel, so
                      // the drop stays the same fraction of the device on every
                      // slot rather than growing with the canvas.
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: const Color(0xFF000000).withValues(alpha: 0.42),
                          blurRadius: short * 0.10,
                          spreadRadius: short * 0.005,
                          offset: Offset(0, short * 0.04),
                        ),
                      ],
                    ),
                    // The bezel is *padding around* the screen, not a border
                    // painted over it. Drawn as a `foregroundDecoration` border
                    // — which is what this frame used to do — it eats `bezel`
                    // logical pixels of app on every edge: invisible at phone
                    // scale, but at tablet width it clips the back arrow off
                    // the app bar.
                    padding: EdgeInsets.all(bezel),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(radius),
                      child: SizedBox(
                        width: app.width,
                        height: app.height,
                        child: switch (platform) {
                          DeviceType.android =>
                            ScreenshotFrame.androidPhone(device: device, frameColors: frameColors, child: child),
                          DeviceType.androidTablet =>
                            ScreenshotFrame.androidTablet(device: device, frameColors: frameColors, child: child),
                          DeviceType.iPhone =>
                            ScreenshotFrame.iphone(device: device, frameColors: frameColors, child: child),
                          DeviceType.iPad =>
                            ScreenshotFrame.ipad(device: device, frameColors: frameColors, child: child),
                          DeviceType.desktop =>
                            ScreenshotFrame.noFrame(device: device, frameColors: frameColors, child: child),
                          DeviceType.noFrame => throw UnimplementedError(),
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
