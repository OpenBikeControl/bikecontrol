// Activity is one page at every width: the blog's newest posts as a banner,
// then the log and the rides, each with its action on its own title. A
// recent post the rider has not read dots the Activity item until Activity
// (and with it the banner) is opened.
import 'dart:async';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/activity/activity_log.dart';
import 'package:bike_control/pages/activity/news_view.dart';
import 'package:bike_control/pages/activity/rides_view.dart';
import 'package:bike_control/pages/shell/app_shell.dart';
import 'package:bike_control/services/blog_news.dart';
import 'package:bike_control/services/blog_service.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter/services.dart' show StandardMessageCodec;
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../helpers/ride_rig.dart';
import '../../helpers/shell_harness.dart';
import '../../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();
  quietShellEnvironment();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
    'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
    (_) async => const StandardMessageCodec().encodeMessage(<Object?>[null]),
  );
  AppLocalizations l() => AppLocalizations.current;

  final fresh = BlogPost(
    date: DateTime.now().subtract(const Duration(days: 1)),
    title: 'Seven point one',
    slug: 'seven-one',
    excerpt: 'A calmer home screen.',
  );
  final old = BlogPost(date: DateTime(2026, 1, 5), title: 'Winter update', slug: 'winter');

  setUp(() async {
    await core.settings.setSeenBlogPosts(const []);
    BlogNewsController.debugFetchOverride = () async => [fresh, old];
  });

  tearDown(() {
    BlogNewsController.debugFetchOverride = null;
  });

  Finder tabItem() => find.descendant(of: find.byType(ShellTabBar), matching: find.text(l().activity));
  Future<void> openActivity(WidgetTester tester) async {
    await tester.tap(tabItem());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('phone: no tabs — the banner, then the log, then the rides, stacked', (tester) async {
    await pumpShell(tester, const Size(390, 844));
    await openActivity(tester);

    expect(find.text('Seven point one'), findsOneWidget, reason: 'the newest post in the banner');
    final banner = tester.getRect(find.byKey(const ValueKey('news-banner')));
    final log = tester.getRect(find.byKey(const ValueKey('activity-log-pane')));
    final rides = tester.getRect(find.byKey(const ValueKey('activity-rides-pane'), skipOffstage: false));
    expect(log.top, greaterThan(banner.bottom));
    expect(rides.top, greaterThan(log.bottom), reason: 'stacked, not side by side');
    expect(rides.left, moreOrLessEquals(log.left));
    expect(
      find.descendant(of: find.byKey(const ValueKey('activity-log-pane')), matching: find.byType(ActivityClearButton)),
      findsOneWidget,
    );
    expect(find.descendant(of: find.byType(ShellTopBar), matching: find.byType(ActivityClearButton)), findsNothing);
    await disposeShell(tester);
  });

  testWidgets('an unread post dots the Activity item until Activity is opened', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpShell(tester, const Size(390, 844));
    await tester.pump();

    expect(find.byKey(const ValueKey('activity-news-dot')), findsOneWidget, reason: 'on the tab item');
    expect(find.bySemanticsLabel(l().a11yTabHasNewPosts(l().activity)), findsOneWidget);

    await openActivity(tester);
    expect(find.byKey(const ValueKey('activity-news-dot')), findsNothing);
    expect(core.settings.getSeenBlogPosts(), contains('seven-one'));
    semantics.dispose();
    await disposeShell(tester);
  });

  testWidgets('only old posts: no dot', (tester) async {
    BlogNewsController.debugFetchOverride = () async => [old];
    await pumpShell(tester, const Size(390, 844));
    await tester.pump();
    expect(find.byKey(const ValueKey('activity-news-dot')), findsNothing);
    await disposeShell(tester);
  });

  testWidgets('the dot shows in the sidebar too', (tester) async {
    await pumpShell(tester, const Size(1280, 800));
    await tester.pump();
    expect(
      find.descendant(of: find.byType(ShellSidebar), matching: find.byKey(const ValueKey('activity-news-dot'))),
      findsOneWidget,
    );
    await disposeShell(tester);
  });

  group('from 840: News as a banner over the log and the rides', () {
    Finder sidebarItem(String label) => find.descendant(of: find.byType(ShellSidebar), matching: find.text(label));

    Future<void> openWideActivity(WidgetTester tester, Size size) async {
      await pumpShell(tester, size);
      await tester.pump();
      await tester.tap(sidebarItem(l().activity));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    for (final size in const [Size(1180, 820), Size(1280, 800)]) {
      testWidgets('${size.width.toInt()}: the banner on top, the log and the rides under it', (tester) async {
        await openWideActivity(tester, size);

        final banner = tester.getRect(find.byType(NewsBanner));
        final logPane = find.byKey(const ValueKey('activity-log-pane'));
        final ridesPane = find.byKey(const ValueKey('activity-rides-pane'));
        expect(find.text('Seven point one'), findsOneWidget, reason: 'the newest post in the banner');
        expect(tester.getRect(logPane).top, greaterThan(banner.bottom));
        expect(tester.getRect(ridesPane).left, greaterThan(tester.getRect(logPane).right), reason: 'log left');
        expect(find.descendant(of: logPane, matching: find.byType(ActivityLogView)), findsOneWidget);
        expect(find.descendant(of: ridesPane, matching: find.byType(RidesView)), findsOneWidget);

        // Each pane's action sits on its own title, none in the page's bar.
        expect(find.descendant(of: logPane, matching: find.byType(ActivityClearButton)), findsOneWidget);
        expect(find.descendant(of: ridesPane, matching: find.byType(RidesMenuButton)), findsOneWidget);
        expect(find.descendant(of: find.byType(ShellTopBar), matching: find.byType(ActivityClearButton)), findsNothing);
        await disposeShell(tester);
      });
    }

    testWidgets('the two panes\' titles and first cards line up', (tester) async {
      await RideRig.install();
      await openWideActivity(tester, const Size(1280, 800));
      final logTitle = tester.getRect(find.byKey(const ValueKey('activity-log-title')));
      final ridesTitle = tester.getRect(find.byKey(const ValueKey('activity-rides-title')));
      expect(logTitle.top, moreOrLessEquals(ridesTitle.top));
      expect(logTitle.height, moreOrLessEquals(ridesTitle.height));
      await disposeShell(tester);
    });

    testWidgets('the banner reads the news; the dots step through the newest posts', (tester) async {
      await pumpShell(tester, const Size(1280, 800));
      await tester.pump();
      final dot = find.descendant(
        of: find.byType(ShellSidebar),
        matching: find.byKey(const ValueKey('activity-news-dot')),
      );
      expect(dot, findsOneWidget);

      await tester.tap(sidebarItem(l().activity));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(dot, findsNothing);
      expect(core.settings.getSeenBlogPosts(), contains('seven-one'));

      await tester.tap(find.byKey(const ValueKey('news-banner-dot-1')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Winter update'), findsOneWidget);
      expect(find.text('Seven point one'), findsNothing);
      await disposeShell(tester);
    });

    testWidgets('swiping the banner pages through the posts', (tester) async {
      await openWideActivity(tester, const Size(1280, 800));
      final banner = find.byKey(const ValueKey('news-banner'));
      expect(find.text('Seven point one'), findsOneWidget);

      // Left: the next post.
      await tester.drag(banner, const Offset(-200, 0));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Winter update'), findsOneWidget);
      expect(find.text('Seven point one'), findsNothing);

      // Right: back to the one before.
      await tester.drag(banner, const Offset(200, 0));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Seven point one'), findsOneWidget);

      // Right again from the first: stays.
      await tester.drag(banner, const Offset(200, 0));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Seven point one'), findsOneWidget);
      await disposeShell(tester);
    });

    testWidgets('no posts: no banner, the panes start under the title', (tester) async {
      BlogNewsController.debugFetchOverride = () async => [];
      await openWideActivity(tester, const Size(1280, 800));
      expect(find.byKey(const ValueKey('news-banner')), findsNothing);
      expect(find.byKey(const ValueKey('activity-log-pane')), findsOneWidget);
      await disposeShell(tester);
    });

    test('the banner counts as viewing News', () {
      final shell = ShellController(news: BlogNewsController());
      addTearDown(shell.dispose);
      expect(shell.viewingNews, isFalse);
      shell.section.value = AppSection.activity;
      expect(shell.viewingNews, isTrue);
    });
  });

  group('one ⋮ per top bar', () {
    Finder menus() => find.byWidgetPredicate((w) => w is Icon && w.icon == LucideIcons.ellipsisVertical);

    testWidgets('every section\'s bar has at most one ⋮', (tester) async {
      await pumpShell(tester, const Size(390, 844));
      for (final section in AppSection.values) {
        await tester.tap(
          find.descendant(
            of: find.byType(ShellTabBar),
            matching: find.text(section.label(tester.element(find.byType(ShellTabBar)))),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          find.descendant(of: find.byType(ShellTopBar), matching: menus()).evaluate().length,
          lessThanOrEqualTo(1),
          reason: section.name,
        );
      }
      await disposeShell(tester);
    });

    testWidgets('Fahrten: its own ⋮ on its title, with "Alle löschen"', (tester) async {
      await pumpShell(tester, const Size(390, 844));
      await openActivity(tester);
      final ridesMenu = find.descendant(
        of: find.byKey(const ValueKey('activity-rides-pane')),
        matching: find.byKey(const ValueKey('rides-menu')),
      );
      await tester.ensureVisible(ridesMenu);
      await tester.pump();
      await tester.tap(ridesMenu);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('rides-delete-all')), findsOneWidget);
      await disposeShell(tester);
    });
  });

  group('News states', () {
    testWidgets('no posts or a failed load: no banner, the log first', (tester) async {
      BlogNewsController.debugFetchOverride = () async => throw Exception('offline');
      await pumpShell(tester, const Size(390, 844));
      await openActivity(tester);
      expect(find.byKey(const ValueKey('news-banner')), findsNothing);
      expect(find.byKey(const ValueKey('activity-log-pane')), findsOneWidget);
      await disposeShell(tester);
    });

    testWidgets('loading: a placeholder banner', (tester) async {
      final never = Completer<List<BlogPost>>();
      BlogNewsController.debugFetchOverride = () => never.future;
      await pumpShell(tester, const Size(390, 844));
      await openActivity(tester);
      expect(find.byKey(const ValueKey('news-banner')), findsOneWidget);
      never.complete([]);
      await disposeShell(tester);
    });
  });
}
