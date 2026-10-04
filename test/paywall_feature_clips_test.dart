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
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/prop.dart' show Logger;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

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

/// Plays clips without a real player. [mode] decides what a new player does:
/// report itself ready, fail to load, or stay loading.
class _FakeVideoPlatform extends VideoPlayerPlatform {
  _ClipLoad mode = _ClipLoad.ready;
  final List<String> created = [];
  final List<int> disposed = [];
  final List<int> played = [];
  final List<int> paused = [];
  final Map<int, bool> looping = {};
  final Map<int, double> volume = {};
  final Map<int, StreamController<VideoEvent>> _events = {};

  // Player ids are unique across tests, so a player released late by an
  // earlier test never shows up here.
  static int _instances = 0;
  final int _base = ++_instances * 100;
  late int _nextId = first;

  /// The id the first player created gets.
  int get first => _base + 1;

  /// The players still alive.
  Iterable<int> get live => _events.keys.where((id) => !disposed.contains(id));

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = _nextId++;
    created.add(options.dataSource.uri!);
    final events = _events[id] = StreamController<VideoEvent>();
    switch (mode) {
      case _ClipLoad.ready:
        events.add(
          VideoEvent(
            eventType: VideoEventType.initialized,
            duration: const Duration(seconds: 6),
            size: const Size(720, 720),
          ),
        );
      case _ClipLoad.fails:
        events.addError(PlatformException(code: 'VideoError', message: 'clip: no connection'));
      case _ClipLoad.pending:
        break;
    }
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events[playerId]!.stream;

  @override
  Future<void> dispose(int playerId) async {
    if (_events.containsKey(playerId)) disposed.add(playerId);
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async => this.looping[playerId] = looping;

  @override
  Future<void> setVolume(int playerId, double volume) async => this.volume[playerId] = volume;

  @override
  Future<void> play(int playerId) async => played.add(playerId);

  @override
  Future<void> pause(int playerId) async => paused.add(playerId);

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<void> setPreventsDisplaySleepDuringVideoPlayback(int playerId, bool prevents) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      ColoredBox(key: ValueKey('fake-video-${options.playerId}'), color: const Color(0xFF336699));
}

enum _ClipLoad { ready, fails, pending }

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
  late _FakeVideoPlatform video;
  setUp(() {
    launcher = _FakeUrlLauncher();
    final previous = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = launcher;
    addTearDown(() => UrlLauncherPlatform.instance = previous);
    video = _FakeVideoPlatform();
    final previousVideo = VideoPlayerPlatform.instance;
    VideoPlayerPlatform.instance = video;
    addTearDown(() => VideoPlayerPlatform.instance = previousVideo);
  });

  /// Routes recordError into a list of contexts for the test's duration.
  List<String> captureRecordedErrors() {
    installLoggerErrorListener();
    final recorded = <String>[];
    final pipeline = Logger.onRecordError;
    Logger.onRecordError = (context, error, stack) => recorded.add(context);
    addTearDown(() => Logger.onRecordError = pipeline);
    return recorded;
  }

  final toggle = find.byKey(const ValueKey('paywall-clip-toggle'));
  final openInBrowser = find.byKey(const ValueKey('paywall-clip-open-browser'));

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

    testWidgets('tapping ▶ opens the clip sheet for that feature; the clip loads only then', (tester) async {
      useTrainerApp(null);
      final l = await pump(tester);
      expect(video.created, isEmpty, reason: 'no clip loads with the paywall');
      await tester.ensureVisible(find.byKey(const ValueKey('paywall-clip-buttonGestures')));
      await tester.tap(find.byKey(const ValueKey('paywall-clip-buttonGestures')));
      await tester.pump(const Duration(milliseconds: 600));

      final sheet = find.byType(PaywallFeatureClipView);
      expect(sheet, findsOneWidget);
      expect(tester.widget<PaywallFeatureClipView>(sheet).clip, PaywallFeatureClip.buttonGestures);
      expect(find.descendant(of: sheet, matching: find.text(l.paywall_configure3ActionsPerButton)), findsOneWidget);
      expect(video.created, ['https://bikecontrol.app/videos/features/buttonGestures.mp4']);
      expect(launcher.launched, isEmpty, reason: 'the clip plays in the app');
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

    void reduceMotion(WidgetTester tester) {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
        reduceMotion: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    }

    /// Lets the fake player's load, the sheet's reaction and playback settle.
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 10; i++) {
        await tester.pump();
      }
    }

    Finder posterOf(ImageProvider poster) => find.byWidgetPredicate((w) => w is Image && w.image == poster);
    Finder fakeFrame() => find.byKey(ValueKey('fake-video-${video.first}'));

    testWidgets('shows the poster and a loading indicator while the clip loads', (tester) async {
      video.mode = _ClipLoad.pending;
      final poster = _PendingImage();
      await pumpSheet(tester, poster: poster);
      await tester.pump(const Duration(seconds: 1));
      expect(posterOf(poster), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(fakeFrame(), findsNothing);
      expect(video.played, isEmpty);
    });

    testWidgets('plays the clip inline, muted and looping, once it is ready', (tester) async {
      final l = await pumpSheet(tester, poster: _PendingImage());
      await settle(tester);
      expect(video.created, hasLength(1));
      expect(video.played, [video.first]);
      expect(video.volume[video.first], 0, reason: 'muted');
      expect(video.looping[video.first], isTrue);
      expect(fakeFrame(), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      // Square clip: the frame keeps the video's aspect ratio.
      final frame = tester.getSize(fakeFrame());
      expect(frame.width, moreOrLessEquals(frame.height, epsilon: 0.5));
      expect(launcher.launched, isEmpty);

      // The clips burn their caption into the bottom of the frame, so the
      // pause control sits in the top-right corner, clear of it, at 48dp.
      final clipRect = tester.getRect(fakeFrame());
      final pause = tester.getRect(toggle);
      expect(pause.top, lessThan(clipRect.top + clipRect.height * 0.25), reason: 'top of the clip, not over the caption');
      expect(pause.right, greaterThan(clipRect.right - clipRect.width * 0.25), reason: 'right-hand corner');
      expect(pause.width, greaterThanOrEqualTo(47.5));
      expect(pause.height, greaterThanOrEqualTo(47.5));

      // A labelled pause control; tapping it pauses, tapping again plays.
      final handle = tester.ensureSemantics();
      expect(find.semantics.byLabel(l.paywall_pauseClip), findsOne);
      handle.dispose();
      final pauses = video.paused.length;
      await tester.tap(toggle);
      await settle(tester);
      expect(video.paused, hasLength(pauses + 1));
      expect(find.bySemanticsLabel(l.paywall_playClip), findsOneWidget);
      await tester.tap(toggle);
      await settle(tester);
      expect(video.played, [video.first, video.first]);
    });

    testWidgets('under reduced motion shows the poster and a play control, and plays only when asked', (
      tester,
    ) async {
      reduceMotion(tester);
      final poster = _PendingImage();
      final l = await pumpSheet(tester, poster: poster);
      await settle(tester);
      await tester.pump(const Duration(seconds: 2));
      expect(video.played, isEmpty, reason: 'no autoplay under reduced motion');
      expect(posterOf(poster), findsOneWidget);
      expect(fakeFrame(), findsNothing);
      expect(find.bySemanticsLabel(l.paywall_playClip), findsOneWidget);
      expect(targetsBelowAndroidMinimum(tester, [toggle]), isEmpty);

      await tester.tap(toggle);
      await settle(tester);
      expect(video.played, [video.first]);
      expect(video.volume[video.first], 0);
      expect(fakeFrame(), findsOneWidget);
    });

    testWidgets('a clip that fails to load says so, is recorded, and offers the browser', (tester) async {
      final recorded = captureRecordedErrors();
      video.mode = _ClipLoad.fails;
      final l = await pumpSheet(tester, poster: _PendingImage());
      await settle(tester);
      expect(find.text(l.paywall_clipLoadError), findsOneWidget);
      expect(recorded, hasLength(1));
      expect(recorded.single, contains('buttonGestures'));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(toggle, findsNothing);

      expect(openInBrowser, findsOneWidget);
      expect(find.text(l.paywall_openClipInBrowser), findsOneWidget);
      await tester.tap(openInBrowser);
      await tester.pump();
      expect(launcher.launched, ['https://bikecontrol.app/videos/features/buttonGestures.mp4']);
    });

    testWidgets('a browser that cannot open the clip is recorded too', (tester) async {
      final recorded = captureRecordedErrors();
      video.mode = _ClipLoad.fails;
      launcher.result = false;
      final l = await pumpSheet(tester, poster: _PendingImage());
      await settle(tester);
      await tester.tap(openInBrowser);
      await settle(tester);
      expect(find.text(l.paywall_clipLoadError), findsOneWidget);
      expect(recorded, hasLength(2));
    });

    testWidgets('a poster that fails to load is recorded; the clip still plays', (tester) async {
      final recorded = captureRecordedErrors();
      await pumpSheet(tester, poster: _FailingImage());
      await settle(tester);
      expect(recorded, hasLength(1));
      expect(fakeFrame(), findsOneWidget);
      expect(openInBrowser, findsNothing);
    });

    testWidgets('closing the sheet releases the player', (tester) async {
      await pumpSheet(tester, poster: _PendingImage());
      await settle(tester);
      expect(video.live, [video.first]);
      await tester.pumpWidget(const SizedBox());
      await settle(tester);
      expect(video.disposed, [video.first]);
      expect(video.live, isEmpty);
    });

    testWidgets('closing while the clip still loads releases the player too', (tester) async {
      video.mode = _ClipLoad.pending;
      await pumpSheet(tester, poster: _PendingImage());
      await tester.pumpWidget(const SizedBox());
      await settle(tester);
      expect(video.disposed, [video.first]);
    });
  });
}
