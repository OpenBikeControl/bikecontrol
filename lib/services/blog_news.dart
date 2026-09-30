import 'dart:async';

import 'package:bike_control/main.dart' show recordError, screenshotMode;
import 'package:bike_control/services/blog_service.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter/foundation.dart';

/// Where the News list is: loading, loaded, or failed.
sealed class NewsState {
  const NewsState();
}

class NewsLoading extends NewsState {
  const NewsLoading();
}

class NewsLoaded extends NewsState {
  const NewsLoaded(this.posts);
  final List<BlogPost> posts;
}

class NewsFailed extends NewsState {
  const NewsFailed();
}

/// The blog as Activity's News segment sees it: the posts, and whether any
/// recent one is still unread — the dot on the Activity tab and on the News
/// segment. Viewing News marks the posts on it read ([markRead]); which ones
/// were seen is kept across restarts.
class BlogNewsController {
  BlogNewsController({Future<List<BlogPost>> Function()? fetch, DateTime Function()? clock})
    : _fetch = fetch ?? debugFetchOverride ?? BlogService().fetchPostsOrThrow,
      _clock = clock ?? DateTime.now;

  /// Test seam for controllers the shell creates itself.
  @visibleForTesting
  static Future<List<BlogPost>> Function()? debugFetchOverride;

  /// Whether the shell fetches the posts at start, for the unread dot. Store
  /// renders stay off the network (unless a test stands in for it).
  static bool get fetchesAtStart => !screenshotMode || debugFetchOverride != null;

  final Future<List<BlogPost>> Function() _fetch;
  final DateTime Function() _clock;

  final ValueNotifier<NewsState> state = ValueNotifier(const NewsLoading());
  final ValueNotifier<bool> hasUnread = ValueNotifier(false);

  Future<void>? _loading;

  /// Fetches the posts once; [force] fetches again (the error state's retry).
  Future<void> load({bool force = false}) {
    if (!force && _loading != null) return _loading!;
    return _loading = _load();
  }

  Future<void> _load() async {
    if (state.value is! NewsLoaded) state.value = const NewsLoading();
    try {
      final posts = await _fetch();
      state.value = NewsLoaded(posts);
    } catch (e, s) {
      recordError(e, s, context: 'BlogNewsController.load');
      if (state.value is! NewsLoaded) state.value = const NewsFailed();
    }
    _refreshUnread();
  }

  /// Whether [post] counts as new: published within the last few days.
  bool isNew(BlogPost post) => post.isNewAt(_clock());

  List<BlogPost> get _posts => switch (state.value) {
    NewsLoaded(:final posts) => posts,
    _ => const [],
  };

  void _refreshUnread() {
    if (!core.settings.isInitialized) {
      hasUnread.value = false;
      return;
    }
    final seen = core.settings.getSeenBlogPosts().toSet();
    hasUnread.value = _posts.any((p) => isNew(p) && !seen.contains(p.slug));
  }

  /// The rider is looking at News: every new post there is read.
  void markRead() {
    if (!hasUnread.value || !core.settings.isInitialized) return;
    final fresh = _posts.where(isNew).map((p) => p.slug);
    final seen = {...core.settings.getSeenBlogPosts(), ...fresh};
    unawaited(core.settings.setSeenBlogPosts(seen.toList()));
    hasUnread.value = false;
  }

  void dispose() {
    state.dispose();
    hasUnread.dispose();
  }
}
