// The News segment's unread dot: a post published in the last few days that
// the rider has not seen on News yet. Viewing News marks what is there read,
// and the answer survives a restart.
import 'package:bike_control/main.dart' show screenshotMode;
import 'package:bike_control/services/blog_news.dart';
import 'package:bike_control/services/blog_service.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget_snapshot.dart';

BlogPost _post(String slug, DateTime date) => BlogPost(date: date, title: slug, slug: slug);

Future<void> main() async {
  await ensureSnapshotHarness();
  final now = DateTime(2026, 9, 30, 12);

  setUp(() async {
    // The harness stages store renders, which never carry the dot.
    screenshotMode = false;
    addTearDown(() => screenshotMode = true);
    await core.settings.setSeenBlogPosts(const []);
  });

  BlogNewsController controller(List<BlogPost> posts) => BlogNewsController(fetch: () async => posts, clock: () => now);

  test('a recent post the rider has not seen is unread', () async {
    final news = controller([_post('fresh', DateTime(2026, 9, 29)), _post('old', DateTime(2026, 9, 1))]);
    await news.load();
    expect(news.hasUnread.value, isTrue);
  });

  test('only old posts: nothing unread', () async {
    final news = controller([_post('old', DateTime(2026, 9, 1))]);
    await news.load();
    expect(news.hasUnread.value, isFalse);
  });

  test('marking read clears the dot, and a restart remembers it', () async {
    final posts = [_post('fresh', DateTime(2026, 9, 29))];
    final news = controller(posts);
    await news.load();
    news.markRead();
    expect(news.hasUnread.value, isFalse);

    final again = controller(posts);
    await again.load();
    expect(again.hasUnread.value, isFalse);
  });

  test('a new post after the last visit brings the dot back', () async {
    final news = controller([_post('fresh', DateTime(2026, 9, 28))]);
    await news.load();
    news.markRead();

    final later = controller([_post('newer', DateTime(2026, 9, 30)), _post('fresh', DateTime(2026, 9, 28))]);
    await later.load();
    expect(later.hasUnread.value, isTrue);
  });

  test('a failed fetch is an error state, and retrying loads the posts', () async {
    var fail = true;
    final news = BlogNewsController(
      fetch: () async {
        if (fail) throw Exception('offline');
        return [_post('fresh', DateTime(2026, 9, 29))];
      },
      clock: () => now,
    );
    await news.load();
    expect(news.state.value, isA<NewsFailed>());
    expect(news.hasUnread.value, isFalse);

    fail = false;
    await news.load(force: true);
    expect((news.state.value as NewsLoaded).posts.single.slug, 'fresh');
    expect(news.hasUnread.value, isTrue);
  });
}
