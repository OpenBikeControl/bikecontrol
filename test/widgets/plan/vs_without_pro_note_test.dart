// The old line under the plans read "Without Pro, you can try BikeControl's
// virtual shifting for 20 min a day" — as if, without Pro, there were no
// virtual shifting at all. The trainer app shifts without Pro; Pro is what
// BikeControl adds on top. The note now says that, names the rider's trainer
// app, and links to the blog post comparing the two in the rider's language.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate, installLoggerErrorListener, screenshotMode;
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/widgets/plan/vs_without_pro_note.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/prop.dart' show Logger;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../helpers/touch_targets.dart';
import '../../widget_snapshot.dart';

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

Future<void> main() async {
  await ensureSnapshotHarness();

  late _FakeUrlLauncher launcher;
  setUp(() {
    launcher = _FakeUrlLauncher();
    final previous = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = launcher;
    addTearDown(() => UrlLauncherPlatform.instance = previous);
  });

  Future<AppLocalizations> pump(WidgetTester tester, {SupportedApp? app, Locale locale = const Locale('en')}) async {
    tester.view.physicalSize = const Size(390, 844) * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ShadcnApp(
        debugShowCheckedModeBanner: false,
        scaling: BkTheme.scaling,
        locale: locale,
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        theme: BkTheme.build(Brightness.light),
        home: Scaffold(child: VsWithoutProNote(app: app)),
      ),
    );
    await tester.pump();
    return AppLocalizations.of(tester.element(find.byType(VsWithoutProNote)));
  }

  final learnMore = find.byKey(const ValueKey('vs-without-pro-learn-more'));

  test('the blog post opens in the rider\'s language, English where it has no translation', () {
    expect(vsBlogPostUrl('en'), 'https://bikecontrol.app/blog/virtual-shifting-with-and-without-bikecontrol/');
    expect(vsBlogPostUrl('de'), 'https://bikecontrol.app/de/blog/virtuelles-schalten-mit-und-ohne-bikecontrol/');
    expect(vsBlogPostUrl('fr'), 'https://bikecontrol.app/fr/blog/passage-de-vitesses-virtuel-bikecontrol/');
    expect(vsBlogPostUrl('es'), 'https://bikecontrol.app/es/blog/cambio-virtual-con-y-sin-bikecontrol/');
    expect(vsBlogPostUrl('it'), 'https://bikecontrol.app/it/blog/cambio-virtuale-con-e-senza-bikecontrol/');
    expect(vsBlogPostUrl('pl'), vsBlogPostUrl('en'));
  });

  testWidgets('names the selected trainer app', (tester) async {
    final wasScreenshotMode = screenshotMode;
    screenshotMode = false;
    addTearDown(() => screenshotMode = wasScreenshotMode);
    final l = await pump(tester, app: MyWhoosh());
    expect(find.text(l.vsWithoutProNote('MyWhoosh')), findsOneWidget);
    expect(find.text(l.vsWithoutProNoteYourApp), findsNothing);
  });

  testWidgets('falls back to "your trainer app" with no app, a keymap, or in store screenshots', (tester) async {
    final wasScreenshotMode = screenshotMode;
    addTearDown(() => screenshotMode = wasScreenshotMode);
    screenshotMode = false;
    var l = await pump(tester);
    expect(find.text(l.vsWithoutProNoteYourApp), findsOneWidget);
    l = await pump(tester, app: CustomApp());
    expect(find.text(l.vsWithoutProNoteYourApp), findsOneWidget);
    screenshotMode = true;
    l = await pump(tester, app: MyWhoosh());
    expect(find.text(l.vsWithoutProNoteYourApp), findsOneWidget);
  });

  testWidgets('"Learn more" opens the post in the rider\'s language, with a 48dp target', (tester) async {
    final l = await pump(tester, locale: const Locale('de'));
    expect(find.text(l.vsWithoutProLearnMore), findsOneWidget);
    expect(targetsBelowAndroidMinimum(tester, [learnMore]), isEmpty);
    await tester.tap(learnMore);
    await tester.pump();
    expect(launcher.launched, ['https://bikecontrol.app/de/blog/virtuelles-schalten-mit-und-ohne-bikecontrol/']);
  });

  testWidgets('a link that can\'t open is recorded, not swallowed', (tester) async {
    installLoggerErrorListener();
    final recorded = <String>[];
    final pipeline = Logger.onRecordError;
    Logger.onRecordError = (context, error, stack) => recorded.add(context);
    addTearDown(() => Logger.onRecordError = pipeline);
    launcher.result = false;

    await pump(tester, locale: const Locale('pl'));
    await tester.tap(learnMore);
    await tester.pump();
    expect(launcher.launched, ['https://bikecontrol.app/blog/virtual-shifting-with-and-without-bikecontrol/']);
    expect(recorded, contains(startsWith('Virtual shifting blog post')));
  });
}
