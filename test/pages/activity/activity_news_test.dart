// Activity holds the blog again, as its News segment: the log and the posts
// share the section, and a recent post the rider has not read marks the
// Activity item and the News segment with a dot until News is viewed.
import 'dart:async';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/activity/activity_log.dart';
import 'package:bike_control/pages/activity/activity_section.dart';
import 'package:bike_control/pages/activity/news_view.dart';
import 'package:bike_control/pages/shell/app_shell.dart';
import 'package:bike_control/services/blog_news.dart';
import 'package:bike_control/services/blog_service.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter/services.dart' show StandardMessageCodec;
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

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
  Finder segment(String label) => find.descendant(of: find.byType(ActivitySegments), matching: find.text(label));

  Future<void> openActivity(WidgetTester tester) async {
    await tester.tap(tabItem());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('Activity has Activity and News segments that switch the content', (tester) async {
    await pumpShell(tester, const Size(390, 844));
    await openActivity(tester);

    expect(segment(l().activity), findsOneWidget);
    expect(segment(l().activityTabNews), findsOneWidget);
    expect(find.byType(ActivityLogView), findsOneWidget);
    expect(find.byType(NewsView), findsNothing);
    expect(find.byType(ActivityClearButton), findsOneWidget);

    await tester.tap(segment(l().activityTabNews));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(NewsView), findsOneWidget);
    expect(find.byType(ActivityLogView), findsNothing);
    expect(find.text('Seven point one'), findsOneWidget);
    expect(find.text('A calmer home screen.'), findsOneWidget);
    expect(find.text('Winter update'), findsOneWidget);
    // Clear is the log's; News has nothing to clear.
    expect(find.byType(ActivityClearButton), findsNothing);

    await tester.tap(segment(l().activity));
    await tester.pump();
    expect(find.byType(ActivityLogView), findsOneWidget);
    await disposeShell(tester);
  });

  testWidgets('an unread post puts a dot on the Activity item and the News segment until News is viewed', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpShell(tester, const Size(390, 844));
    await tester.pump();

    expect(find.byKey(const ValueKey('activity-news-dot')), findsOneWidget, reason: 'on the tab item');
    expect(find.bySemanticsLabel(l().a11yTabHasNewPosts(l().activity)), findsOneWidget);

    await openActivity(tester);
    expect(find.byKey(const ValueKey('news-segment-dot')), findsOneWidget);

    await tester.tap(segment(l().activityTabNews));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('activity-news-dot')), findsNothing);
    expect(find.byKey(const ValueKey('news-segment-dot')), findsNothing);
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

  group('from 840: the log and News side by side', () {
    Finder sidebarItem(String label) => find.descendant(of: find.byType(ShellSidebar), matching: find.text(label));

    Future<void> openWideActivity(WidgetTester tester, Size size) async {
      await pumpShell(tester, size);
      await tester.pump();
      await tester.tap(sidebarItem(l().activity));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    for (final size in const [Size(1180, 820), Size(1280, 800)]) {
      testWidgets('${size.width.toInt()}: two panes, no segments, each with its own header', (tester) async {
        await openWideActivity(tester, size);

        expect(find.byType(ActivitySegments), findsNothing);
        final logPane = find.byKey(const ValueKey('activity-log-pane'));
        final newsPane = find.byKey(const ValueKey('activity-news-pane'));
        expect(find.descendant(of: logPane, matching: find.byType(ActivityLogView)), findsOneWidget);
        expect(find.descendant(of: newsPane, matching: find.byType(NewsView)), findsOneWidget);
        expect(
          tester.getRect(find.byType(NewsView)).left,
          greaterThan(tester.getRect(find.byType(ActivityLogView)).right),
          reason: 'log left, News right',
        );

        // Each pane has its header: the log's carries Clear.
        expect(find.descendant(of: logPane, matching: find.text(l().activity)), findsOneWidget);
        expect(find.descendant(of: logPane, matching: find.byType(ActivityClearButton)), findsOneWidget);
        expect(find.descendant(of: newsPane, matching: find.text(l().activityTabNews)), findsOneWidget);
        expect(find.byType(ActivityClearButton), findsOneWidget, reason: 'not also in the page header');

        // Each scrolls on its own.
        expect(find.descendant(of: logPane, matching: find.byType(SingleChildScrollView)), findsOneWidget);
        expect(find.descendant(of: newsPane, matching: find.byType(SingleChildScrollView)), findsOneWidget);

        // The posts in one column in their pane.
        final first = tester.getRect(find.widgetWithText(NewsCard, 'Seven point one'));
        final second = tester.getRect(find.widgetWithText(NewsCard, 'Winter update'));
        expect(second.left, moreOrLessEquals(first.left));
        expect(second.top, greaterThan(first.bottom));
        await disposeShell(tester);
      });
    }

    testWidgets('opening Activity reads the news: News is on screen', (tester) async {
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
      expect(find.byKey(const ValueKey('news-segment-dot')), findsNothing);
      await disposeShell(tester);
    });

    testWidgets('below 840 the segments stay', (tester) async {
      await pumpShell(tester, const Size(700, 900));
      await tester.tap(find.descendant(of: find.byType(ShellTopTabs), matching: find.text(l().activity)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(ActivitySegments), findsOneWidget);
      expect(find.byKey(const ValueKey('activity-news-pane')), findsNothing);
      // Opening Activity on the log segment does not read the news.
      expect(core.settings.getSeenBlogPosts(), isNot(contains('seven-one')));
      await disposeShell(tester);
    });
  });

  group('News states', () {
    Future<void> openNews(WidgetTester tester) async {
      await pumpShell(tester, const Size(390, 844));
      await openActivity(tester);
      await tester.tap(segment(l().activityTabNews));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('no posts: says so', (tester) async {
      BlogNewsController.debugFetchOverride = () async => [];
      await openNews(tester);
      expect(find.text(l().newsEmpty), findsOneWidget);
      await disposeShell(tester);
    });

    testWidgets('a failed load: says so, and Retry loads again', (tester) async {
      var fail = true;
      BlogNewsController.debugFetchOverride = () async {
        if (fail) throw Exception('offline');
        return [old];
      };
      await openNews(tester);
      expect(find.text(l().newsLoadFailed), findsOneWidget);

      fail = false;
      await tester.tap(find.text(l().retry));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Winter update'), findsOneWidget);
      await disposeShell(tester);
    });

    testWidgets('loading: placeholder cards', (tester) async {
      final never = Completer<List<BlogPost>>();
      BlogNewsController.debugFetchOverride = () => never.future;
      await openNews(tester);
      expect(find.byKey(const ValueKey('news-loading')), findsOneWidget);
      never.complete([]);
      await disposeShell(tester);
    });
  });
}
