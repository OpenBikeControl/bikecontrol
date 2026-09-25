import 'dart:io';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart'
    show OtherLocalizationsDelegate, screenshotLocale, screenshotMode;
import 'package:bike_control/utils/actions/base_actions.dart' show StubActions;
import 'package:bike_control/utils/core.dart' show core;
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:flutter/material.dart' as m;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart'; // tester.loadAssets()
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widget_to_png.dart';

/// Generic harness for rendering any BikeControl widget to a PNG file under
/// `flutter test`, with the real app theme, localized strings, and real fonts.
///
/// Two calls plug in any widget — see `front_shift_card_snapshot_test.dart`:
///
/// ```dart
/// Future<void> main() async {
///   await ensureSnapshotHarness();          // binding + mocks + core bootstrap
///   // ...set up any app state the widget reads (devices, configs)...
///   testWidgets('MyWidget', (tester) async {
///     await captureWidget(
///       tester,
///       name: 'my_widget',
///       width: 380,
///       locales: const ['en', 'de'],
///       builder: (context) => const MyWidget(),
///     );
///   });
/// }
/// ```
///
/// Output: `build/snapshots/my_widget-<locale>.png` (or `my_widget.png` for a
/// single locale).

Future<void>? _bootstrap;

/// Idempotent one-time setup. Call (and await) this FIRST in `main()`, before
/// declaring tests and before touching `core` — it initializes the test binding,
/// installs plugin mocks, and bootstraps `core.settings` so the configs/settings
/// stores are usable. Safe to call repeatedly; only the first call does work.
Future<void> ensureSnapshotHarness() {
  // Must be the very first binding call so toImage()/loadAssets() run in the
  // same environment the golden suite is proven against. (Selecting the binding
  // has to happen before any testWidgets runs, hence: call this from main().)
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  return ensureSnapshotAppState();
}

/// Everything [ensureSnapshotHarness] does except choosing the binding.
///
/// For captures that need the fake-clock binding instead of the live one the
/// integration binding runs: under the live binding `pump(duration)` waits
/// real time and frames are stamped by the wall clock, so an animation's
/// phase in a captured frame depends on how fast the machine was. Call
/// `TestWidgetsFlutterBinding.ensureInitialized()` first, then this.
Future<void> ensureSnapshotAppState() => _bootstrap ??= _runBootstrap();

Future<void> _runBootstrap() async {
  PackageInfo.setMockInitialValues(
    appName: 'BikeControl',
    packageName: 'de.jonasbark.swiftcontrol',
    version: '6.2.0',
    buildNumber: '1',
    buildSignature: '',
  );
  FlutterSecureStorage.setMockInitialValues({});
  SharedPreferences.setMockInitialValues({});
  IAPManager.instance.isPurchased.value = true;

  // Force locale via [screenshotLocale] (set per-locale in captureWidget) and
  // flip app code into screenshot behaviour.
  screenshotMode = true;

  // core.settings.init() can call core.actionHandler.init(); stub the `late`
  // field so that path never NPEs.
  core.actionHandler = StubActions();

  // core.settings.init() runs Supabase.initialize(), and supabase_flutter
  // subscribes to app_links' deep-link stream for detectSessionInUri. With no
  // platform behind it that `listen` fails with an asynchronous
  // MissingPluginException which the binding pins on whichever test happens
  // to be running — the "stray app_links platform-stream error" that used to
  // fail the first test of a harness file whenever files ran in parallel.
  // Answer the stream's `listen`/`cancel` method calls with success and never
  // emit anything. (setMockStreamHandler would do the same but registers an
  // addTearDown, which is not allowed here, outside a test.)
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('com.llfbandit.app_links/events'),
    (_) async => null,
  );

  // Some bootstrap reads AppLocalizations.current before a delegate has loaded.
  await AppLocalizations.load(const Locale('en'));
  await core.settings.init();
  await core.settings.reset(); // clears prefs; reset() can toggle IAP, so re-set:
  IAPManager.instance.isPurchased.value = true;
}

/// main.dart's light or dark app theme, so snapshots match the app exactly.
ThemeData snapshotTheme(Brightness brightness) => brightness == Brightness.dark
    ? ThemeData(
        colorScheme: ColorSchemes.darkSlate.copyWith(
          card: () => const Color(0xFF001A29),
          background: () => const Color(0xFF232323),
          muted: () => const Color(0xFF3A3A3A),
          border: () => const Color(0xFF3A3A3A),
          secondary: () => const Color(0xFF3A3A3A),
        ),
        typography: Typography.geist().scale(0.9),
        radius: 0.7,
      )
    : ThemeData(
        colorScheme: ColorSchemes.lightSlate.copyWith(
          mutedForeground: () => const Color(0xFFA1A1AA),
          primary: () => BKColor.main,
        ),
        typography: Typography.geist().scale(0.9),
        radius: 0.7,
      );

/// Renders [builder]'s widget once per entry in [locales] and writes a tight
/// PNG per locale to [outputDir].
///
/// - [name]: output base filename. One locale → `name.png`; many → `name-<loc>.png`.
/// - [width]: logical width given to the widget. The capture is cropped tight to
///   `width + padding` — make it wide enough that the widget doesn't overflow.
/// - [height]: normally omitted, so the widget is given unbounded height and
///   sets its own. Pass one to shoot a full-screen PAGE instead: the surface
///   becomes exactly `width` × `height`, the scroll view is dropped (a page
///   with its own viewport can't live inside another one), and MediaQuery
///   reports that size — which is what a page measuring itself against the
///   screen, e.g. the touch-area editor, needs to lay out correctly.
/// - [padding]: breathing room painted around the widget (in [background]).
/// - [background]: backdrop colour; defaults to the theme's background.
/// - [brightness]: light or dark app theme (mirrors main.dart's themes).
/// - [pixelRatio]: output scale (3.0 ≈ a modern phone's device pixels).
///
/// The widget is given UNBOUNDED height (via a scroll view) so a root Column with
/// the default `mainAxisSize.max` shrink-wraps to its content instead of filling
/// the surface. Returns the written files, one per locale.
Future<List<File>> captureWidget(
  WidgetTester tester, {
  required String name,
  required Widget Function(BuildContext context) builder,
  List<String> locales = const ['en'],
  double width = 380,
  double? height,
  EdgeInsets padding = const EdgeInsets.all(16),
  Color? background,
  Brightness brightness = Brightness.light,
  double pixelRatio = 3.0,
  String outputDir = 'build/snapshots',
  /// If false, use pump(duration) instead of pumpAndSettle — needed when the
  /// widget contains an infinite animation (e.g. a CircularProgressIndicator)
  /// that would cause pumpAndSettle to time out.
  bool settle = true,
}) async {
  await ensureSnapshotHarness();

  // Surface width == widget + padding so the full-width scroll viewport (which
  // forces a tight cross-axis width) crops exactly to the widget. Height is
  // arbitrary when [height] is null: the SingleChildScrollView makes the
  // captured subtree's vertical axis unbounded, so the widget sets its own
  // height. With a [height], the surface IS the widget plus its padding.
  tester.view.physicalSize =
      Size(
        width + padding.horizontal,
        height == null ? 2000 : height + padding.vertical,
      ) *
      pixelRatio;
  tester.view.devicePixelRatio = pixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final lightTheme = snapshotTheme(Brightness.light);
  final darkTheme = snapshotTheme(Brightness.dark);

  final files = <File>[];
  for (final loc in locales) {
    await AppLocalizations.load(Locale(loc));
    screenshotLocale = Locale(loc);

    final boundaryKey = GlobalKey();

    await tester.pumpWidget(
      ShadcnApp(
        debugShowCheckedModeBanner: false,
        locale: Locale(loc),
        // Mirror main.dart's delegate stack so AppLocalizations.of(context) and
        // shadcn's own strings both resolve for [loc].
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: brightness == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light,
        materialTheme: m.ThemeData(),
        home: Builder(
          builder: (context) {
            final captured = RepaintBoundary(
              key: boundaryKey,
              child: ColoredBox(
                color: background ?? Theme.of(context).colorScheme.background,
                child: Padding(
                  padding: padding,
                  child: SizedBox(
                    width: width,
                    height: height,
                    child: builder(context),
                  ),
                ),
              ),
            );
            return height == null
                ? SingleChildScrollView(child: captured)
                : captured;
          },
        ),
      ),
    );

    // First pump builds the tree; loadAssets() loads the fonts it finds there
    // (Geist etc.); the second pump re-renders with real glyphs, not Ahem boxes.
    await tester.pump();
    await tester.loadAssets();
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // For widgets with infinite animations (spinners, etc.) pumpAndSettle
      // would time out. Pump a fixed frame so the widget is rendered.
      await tester.pump(const Duration(milliseconds: 100));
    }

    final fileName = locales.length == 1 ? '$name.png' : '$name-$loc.png';
    files.add(
      await captureBoundaryToPng(
        tester,
        boundaryKey,
        outputPath: '$outputDir/$fileName',
        pixelRatio: pixelRatio,
      ),
    );
  }
  return files;
}
