// The changelog as releases: the newest in full and prominent, its entries
// grouped by kind; earlier releases compact until opened; and after an
// update, only what changed since the version last seen.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate, screenshotMode;
import 'package:bike_control/models/changelog.dart';
import 'package:bike_control/pages/changelog_page.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/changelog/whats_new.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../widget_snapshot.dart';

const _changelog = '''
### 7.0.0 (18-09-2026)
**Features**:
- Sensors: pair a heart-rate strap.

Read more in [our blog](https://bikecontrol.app/blog/bikecontrol-7-0/)

**Fixes**:
- Smart trainers: more trainers.

### 5.5.0 (14-05-2026)
**Features**:
- Virtual shifting overlay on macOS.

### 4.7.0 (04-02-2026)
**Fixes:**
- iOS: Remote pairing now works again
''';

Future<void> main() async {
  await ensureSnapshotHarness();
  late AppLocalizations l;

  setUp(() {
    l = AppLocalizations.current;
    ChangelogSource.debugBundled = () async => _changelog;
    ChangelogSource.debugCurrentVersion = '7.0.0';
  });

  tearDown(() {
    ChangelogSource.debugBundled = null;
    ChangelogSource.debugTranslated = null;
    ChangelogSource.debugCurrentVersion = null;
  });

  Widget app(Widget home) => ShadcnApp(
    localizationsDelegates: [
      ...ShadcnLocalizations.localizationsDelegates,
      const OtherLocalizationsDelegate(),
      AppLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en')],
    theme: BkTheme.build(Brightness.dark),
    home: home,
  );

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(const ChangelogPage()));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('the newest release leads, large, with its date and "Your version"', (tester) async {
    await pumpPage(tester);

    final latest = find.byKey(const ValueKey('changelog-latest'));
    expect(latest, findsOneWidget);
    final version = find.descendant(of: latest, matching: find.text('7.0.0'));
    expect(version, findsOneWidget);
    expect(find.descendant(of: latest, matching: find.text('September 18, 2026')), findsOneWidget);
    expect(find.descendant(of: latest, matching: find.text(l.changelogYourVersion)), findsOneWidget);

    // Larger than an earlier release's version.
    final earlier = find.descendant(of: find.byKey(const ValueKey('changelog-5.5.0')), matching: find.text('5.5.0'));
    expect(tester.getSize(version).height, greaterThan(tester.getSize(earlier).height));
  });

  testWidgets('its entries sit under their kind, with the note above them', (tester) async {
    await pumpPage(tester);

    final latest = find.byKey(const ValueKey('changelog-latest'));
    final added = find.descendant(of: latest, matching: find.byKey(const ValueKey('changelog-section-added')));
    final fixed = find.descendant(of: latest, matching: find.byKey(const ValueKey('changelog-section-fixed')));
    expect(find.descendant(of: added, matching: find.text(l.changelogKindAdded)), findsOneWidget);
    expect(
      find.descendant(of: added, matching: find.textContaining('pair a heart-rate strap', findRichText: true)),
      findsOneWidget,
    );
    expect(find.descendant(of: fixed, matching: find.text(l.changelogKindFixed)), findsOneWidget);
    expect(
      find.descendant(of: fixed, matching: find.textContaining('more trainers', findRichText: true)),
      findsOneWidget,
    );
    // The markdown link reads as its label.
    expect(find.descendant(of: latest, matching: find.textContaining('our blog', findRichText: true)), findsOneWidget);
    expect(find.textContaining('](', findRichText: true), findsNothing);
  });

  testWidgets('earlier releases are one row each until opened', (tester) async {
    await pumpPage(tester);

    expect(find.text(l.changelogEarlierVersions.toUpperCase()), findsOneWidget);
    expect(find.textContaining('overlay on macOS', findRichText: true), findsNothing);

    await tester.tap(find.byKey(const ValueKey('changelog-5.5.0')).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('overlay on macOS', findRichText: true), findsOneWidget);
    expect(find.textContaining('Remote pairing', findRichText: true), findsNothing);
  });

  testWidgets('in the rider\'s language where translated, English where not', (tester) async {
    ChangelogSource.debugTranslated = (language) async =>
        language == 'de' ? '### 7.0.0 (18-09-2026)\n**Features**:\n- Sensoren: koppel einen Brustgurt.\n' : null;
    final releases = await ChangelogSource.bundled(language: 'de');
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(WhatsNewPage(currentVersion: '7.0.0', sinceVersion: '4.7.0', releases: releasesSince(releases, '4.7.0'))),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('koppel einen Brustgurt', findRichText: true), findsOneWidget);
    expect(find.textContaining('heart-rate strap', findRichText: true), findsNothing);
    expect(find.textContaining('overlay on macOS', findRichText: true), findsOneWidget);
  });

  group('What\'s new after an update', () {
    setUp(() async {
      screenshotMode = false;
      WhatsNew.pending.value = null;
      await core.settings.setWhatsNewPending(null);
    });
    tearDown(() {
      screenshotMode = true;
      WhatsNew.pending.value = null;
      WhatsNewPage.canRate = () => true;
    });

    Future<void> pumpBanner(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        app(
          const Scaffold(
            child: Column(
              children: [
                WhatsNewBanner(),
                Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('a banner, not a dialog; it opens the releases since the last one seen full screen', (tester) async {
      WhatsNewPage.canRate = () => true;
      await WhatsNew.checkAtLaunch('7.0.0', '4.7.0');
      await pumpBanner(tester);

      expect(find.byType(WhatsNewPage), findsNothing);
      expect(find.text(l.whatsNewBannerTitle('7.0.0')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('whats-new-banner-open')));
      await tester.pumpAndSettle();

      expect(find.byType(WhatsNewPage), findsOneWidget);
      expect(find.byKey(const ValueKey('whats-new-7.0.0')), findsOneWidget);
      expect(find.byKey(const ValueKey('whats-new-5.5.0')), findsOneWidget);
      expect(find.byKey(const ValueKey('whats-new-4.7.0')), findsNothing);
      await tester.scrollUntilVisible(find.byKey(const ValueKey('whats-new-rate')), 200);
      expect(find.byKey(const ValueKey('whats-new-blog')), findsOneWidget);
      expect(find.text(l.whatsNewHelpTitle), findsOneWidget);

      // Opened is seen: the banner is gone, also after a restart.
      expect(WhatsNew.pending.value, isNull);
      expect(core.settings.getWhatsNewPending(), isNull);
    });

    testWidgets('it stays across launches until dismissed', (tester) async {
      await WhatsNew.checkAtLaunch('7.0.0', '5.5.0');
      WhatsNew.pending.value = null; // a restart
      await WhatsNew.checkAtLaunch('7.0.0', '7.0.0');
      await pumpBanner(tester);
      expect(find.byKey(const ValueKey('whats-new-banner')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('whats-new-banner-dismiss')));
      await tester.pump();
      expect(find.byKey(const ValueKey('whats-new-banner')), findsNothing);
      await WhatsNew.checkAtLaunch('7.0.0', '7.0.0');
      expect(WhatsNew.pending.value, isNull);
    });

    testWidgets('two updates unread: the page still starts at the first one missed', (tester) async {
      await WhatsNew.checkAtLaunch('5.5.0', '4.7.0');
      await WhatsNew.checkAtLaunch('7.0.0', '5.5.0');
      expect(WhatsNew.pending.value, ('7.0.0', '4.7.0'));
    });

    testWidgets('nothing after a fresh install, without a change since, or in store renders', (tester) async {
      await WhatsNew.checkAtLaunch('7.0.0', null);
      await WhatsNew.checkAtLaunch('7.0.0', '7.0.0');
      expect(WhatsNew.pending.value, isNull);
      screenshotMode = true;
      await WhatsNew.checkAtLaunch('7.0.0', '4.7.0');
      expect(WhatsNew.pending.value, isNull);
    });

    testWidgets('no rating plea where there is no store', (tester) async {
      WhatsNewPage.canRate = () => false;
      tester.view.physicalSize = const Size(390, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(const WhatsNewPage(currentVersion: '7.0.0', sinceVersion: '5.5.0')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('whats-new-blog')), findsOneWidget);
      expect(find.byKey(const ValueKey('whats-new-help')), findsNothing);
    });
  });
}
