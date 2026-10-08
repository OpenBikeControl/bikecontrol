// The changelog as releases: the newest in full and prominent, its entries
// grouped by kind; earlier releases compact until opened; and after an
// update, only what changed since the version last seen.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate, screenshotMode;
import 'package:bike_control/pages/changelog_page.dart';
import 'package:bike_control/widgets/changelog_dialog.dart';
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

  testWidgets('after an update, only the releases since the last one seen, and Got it closes', (tester) async {
    screenshotMode = false;
    addTearDown(() => screenshotMode = true);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => Scaffold(
            child: Button.primary(
              onPressed: () => ChangelogDialog.showIfNeeded(context, '7.0.0', '4.7.0'),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text(l.whatsNew), findsOneWidget);
    expect(find.byKey(const ValueKey('whats-new-7.0.0')), findsOneWidget);
    expect(find.byKey(const ValueKey('whats-new-5.5.0')), findsOneWidget);
    expect(find.byKey(const ValueKey('whats-new-4.7.0')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('whats-new-close')));
    await tester.pumpAndSettle();
    expect(find.text(l.whatsNew), findsNothing);
  });

  testWidgets('nothing after a fresh install or without a change since', (tester) async {
    screenshotMode = false;
    addTearDown(() => screenshotMode = true);
    late BuildContext ctx;
    await tester.pumpWidget(app(Builder(builder: (c) => const SizedBox())));
    ctx = tester.element(find.byType(SizedBox).first);
    await ChangelogDialog.showIfNeeded(ctx, '7.0.0', null);
    await ChangelogDialog.showIfNeeded(ctx, '7.0.0', '7.0.0');
    await tester.pumpAndSettle();
    expect(find.text(l.whatsNew), findsNothing);
  });
}
