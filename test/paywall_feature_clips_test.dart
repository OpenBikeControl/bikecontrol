// The paywall names the rider's own trainer app on the "shift in your app"
// line (which app does the gears was unclear), and each feature line that has
// a short demo clip on the website gets a small ▶ that opens it in a sheet.
import 'dart:async';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate, installLoggerErrorListener, screenshotMode;
import 'package:bike_control/pages/paywall.dart';
import 'package:bike_control/pages/paywall_feature_clip.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/openbikecontrol.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/prop.dart' show Logger;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'helpers/touch_targets.dart';
import 'widget_snapshot.dart';

/// Records launched URLs instead of opening them; [result] decides whether the
/// platform reports success.
class _FakeUrlLauncher extends UrlLauncherPlatform {
  final List<String> launched = [];
  bool result = true;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return result;
  }
}

/// A poster that never arrives: the sheet stays on its placeholder.
class _PendingImage extends ImageProvider<_PendingImage> {
  @override
  Future<_PendingImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_PendingImage key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(Completer<ImageInfo>().future);
}

/// A poster that fails to load, like a request with no connection.
class _FailingImage extends ImageProvider<_FailingImage> {
  @override
  Future<_FailingImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_FailingImage key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(Future<ImageInfo>.error(StateError('poster: no connection')));
}

Future<void> main() async {
  await ensureSnapshotHarness();

  final proCard = find.byKey(const ValueKey('paywall-pro-card'));
  final baseCard = find.byKey(const ValueKey('paywall-base-card'));
  Finder inCard(Finder card, String text) => find.descendant(of: card, matching: find.text(text));

  late _FakeUrlLauncher launcher;
  setUp(() {
    launcher = _FakeUrlLauncher();
    final previous = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = launcher;
    addTearDown(() => UrlLauncherPlatform.instance = previous);
  });

  Future<AppLocalizations> pump(WidgetTester tester, {Size size = const Size(390, 2000)}) async {
    tester.view.physicalSize = size * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    IAPManager.instance.isPurchased.value = false;
    addTearDown(() => IAPManager.instance.isPurchased.value = true);
    await tester.pumpWidget(
      ShadcnApp(
        debugShowCheckedModeBanner: false,
        scaling: BkTheme.scaling,
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        theme: BkTheme.build(Brightness.light),
        home: SingleChildScrollView(child: Paywall(debugClipPoster: (_) => _PendingImage())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    return AppLocalizations.of(tester.element(find.byType(Paywall)));
  }

  void useTrainerApp(dynamic app, {bool screenshots = false}) {
    final wasScreenshotMode = screenshotMode;
    screenshotMode = screenshots;
    if (app != null) core.settings.setTrainerApp(app);
    addTearDown(() {
      screenshotMode = wasScreenshotMode;
      core.settings.prefs.remove('trainer_app');
    });
  }

  group('the "shift in your app" line', () {
    test('names real trainer apps; generic apps and none fall back', () {
      final wasScreenshotMode = screenshotMode;
      addTearDown(() => screenshotMode = wasScreenshotMode);
      screenshotMode = false;
      expect(paywallShiftAppName(MyWhoosh()), 'MyWhoosh');
      expect(paywallShiftAppName(Zwift()), 'Zwift');
      expect(paywallShiftAppName(null), isNull);
      expect(paywallShiftAppName(CustomApp()), isNull, reason: 'a keymap profile is not an app that shifts');
      expect(paywallShiftAppName(OpenBikeControl()), isNull);
      // Store screenshots keep every app name generic.
      screenshotMode = true;
      expect(paywallShiftAppName(MyWhoosh()), isNull);
    });

    testWidgets('uses the selected trainer app on both cards', (tester) async {
      useTrainerApp(MyWhoosh());
      final l = await pump(tester);
      final line = l.paywall_shiftInNamedApp('MyWhoosh');
      expect(inCard(proCard, line), findsOneWidget);
      expect(inCard(baseCard, line), findsOneWidget);
      expect(find.text(l.paywall_shiftInYourApp), findsNothing);
    });

    testWidgets('falls back to the generic wording with no app selected', (tester) async {
      useTrainerApp(null);
      final l = await pump(tester);
      expect(inCard(proCard, l.paywall_shiftInYourApp), findsOneWidget);
      expect(inCard(baseCard, l.paywall_shiftInYourApp), findsOneWidget);
    });

    testWidgets('stays generic in store-screenshot mode', (tester) async {
      useTrainerApp(MyWhoosh(), screenshots: true);
      final l = await pump(tester);
      expect(inCard(proCard, l.paywall_shiftInYourApp), findsOneWidget);
      expect(find.textContaining('MyWhoosh'), findsNothing);
    });
  });

  group('feature clips', () {
    test('clips stream from the website', () {
      expect(
        PaywallFeatureClip.buttonGestures.videoUrl,
        'https://bikecontrol.app/videos/features/buttonGestures.mp4',
      );
      expect(
        PaywallFeatureClip.buttonGestures.posterUrl,
        'https://bikecontrol.app/videos/features/buttonGestures.jpg',
      );
    });

    testWidgets('lines with a clip show a labelled ▶ on the Pro card only', (tester) async {
      useTrainerApp(null);
      final l = await pump(tester);
      final withClip = {
        l.paywall_vsByBikeControl: PaywallFeatureClip.smartTrainerVirtualShifting,
        l.paywall_shiftInYourApp: PaywallFeatureClip.virtualGearShifting,
        l.paywall_configure3ActionsPerButton: PaywallFeatureClip.buttonGestures,
        l.paywall_shareSensors: PaywallFeatureClip.heartRate,
        l.paywall_startAnyCommandShortcutWithAnyButton: PaywallFeatureClip.launchCommand,
        l.paywall_controlYourDeviceMusic: PaywallFeatureClip.music,
        l.paywall_createScreenshots: PaywallFeatureClip.screenshots,
      };
      final handle = tester.ensureSemantics();
      for (final MapEntry(key: label, value: clip) in withClip.entries) {
        final button = find.descendant(of: proCard, matching: find.byKey(ValueKey('paywall-clip-${clip.name}')));
        expect(button, findsOneWidget, reason: label);
        expect(find.semantics.byLabel(l.paywall_watchClip(label)), findsOne, reason: label);
        // On the same line as its label.
        final row = tester.getRect(inCard(proCard, label));
        final play = tester.getRect(button);
        expect(play.center.dy, inInclusiveRange(row.top - 16, row.bottom + 16), reason: label);
      }
      // Seven clips, none on the lines without one, none on the Base card.
      expect(find.descendant(of: proCard, matching: find.byType(PaywallClipButton)), findsNWidgets(7));
      expect(find.descendant(of: baseCard, matching: find.byType(PaywallClipButton)), findsNothing);
      expect(
        targetsBelowAndroidMinimum(tester, [
          for (final clip in withClip.values) find.byKey(ValueKey('paywall-clip-${clip.name}')),
        ]),
        isEmpty,
      );
      handle.dispose();
    });

    testWidgets('tapping ▶ opens the clip sheet for that feature, nothing launched yet', (tester) async {
      useTrainerApp(null);
      final l = await pump(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('paywall-clip-buttonGestures')));
      await tester.tap(find.byKey(const ValueKey('paywall-clip-buttonGestures')));
      await tester.pump(const Duration(milliseconds: 600));

      final sheet = find.byType(PaywallFeatureClipView);
      expect(sheet, findsOneWidget);
      expect(tester.widget<PaywallFeatureClipView>(sheet).clip, PaywallFeatureClip.buttonGestures);
      expect(find.descendant(of: sheet, matching: find.text(l.paywall_configure3ActionsPerButton)), findsOneWidget);
      expect(launcher.launched, isEmpty, reason: 'the clip only loads when asked for');

      await tester.tap(find.byKey(const ValueKey('paywall-clip-play')));
      await tester.pump();
      expect(launcher.launched, ['https://bikecontrol.app/videos/features/buttonGestures.mp4']);
    });
  });

  group('clip sheet', () {
    Future<AppLocalizations> pumpSheet(WidgetTester tester, {required ImageProvider poster}) async {
      tester.view.physicalSize = const Size(390, 844) * 3.0;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ShadcnApp(
          debugShowCheckedModeBanner: false,
          scaling: BkTheme.scaling,
          localizationsDelegates: [
            ...ShadcnLocalizations.localizationsDelegates,
            const OtherLocalizationsDelegate(),
            AppLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          theme: BkTheme.build(Brightness.dark),
          home: Scaffold(
            child: PaywallFeatureClipView(
              title: 'Button gestures',
              clip: PaywallFeatureClip.buttonGestures,
              poster: poster,
            ),
          ),
        ),
      );
      await tester.pump();
      return AppLocalizations.of(tester.element(find.byType(PaywallFeatureClipView)));
    }

    for (final reduced in [false, true]) {
      testWidgets('shows the poster and a play control first, never autoplays (reduced motion: $reduced)', (
        tester,
      ) async {
        if (reduced) {
          tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
            disableAnimations: true,
            reduceMotion: true,
          );
          addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
        }
        final poster = _PendingImage();
        await pumpSheet(tester, poster: poster);
        await tester.pump(const Duration(seconds: 2));
        expect(find.byWidgetPredicate((w) => w is Image && w.image == poster), findsOneWidget);
        expect(find.byKey(const ValueKey('paywall-clip-play')), findsOneWidget);
        expect(launcher.launched, isEmpty);
      });
    }

    testWidgets('a poster that fails to load says so and is recorded', (tester) async {
      installLoggerErrorListener();
      final recorded = <String>[];
      final pipeline = Logger.onRecordError;
      Logger.onRecordError = (context, error, stack) => recorded.add(context);
      addTearDown(() => Logger.onRecordError = pipeline);

      final l = await pumpSheet(tester, poster: _FailingImage());
      await tester.pump();
      await tester.pump();
      expect(find.text(l.paywall_clipLoadError), findsOneWidget);
      expect(recorded, hasLength(1));
      // Playing is still offered: the clip itself may load fine.
      expect(find.byKey(const ValueKey('paywall-clip-play')), findsOneWidget);
    });

    testWidgets('a clip that cannot be opened says so and is recorded', (tester) async {
      installLoggerErrorListener();
      final recorded = <String>[];
      final pipeline = Logger.onRecordError;
      Logger.onRecordError = (context, error, stack) => recorded.add(context);
      addTearDown(() => Logger.onRecordError = pipeline);
      launcher.result = false;

      final l = await pumpSheet(tester, poster: _PendingImage());
      await tester.tap(find.byKey(const ValueKey('paywall-clip-play')));
      await tester.pump();
      await tester.pump();
      expect(find.text(l.paywall_clipLoadError), findsOneWidget);
      expect(recorded, hasLength(1));
    });
  });
}
