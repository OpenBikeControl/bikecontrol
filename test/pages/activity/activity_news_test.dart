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
