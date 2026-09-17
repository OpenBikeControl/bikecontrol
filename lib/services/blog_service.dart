import 'dart:convert';

import 'package:bike_control/main.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const _blogSiteUrl = 'https://bikecontrol.app';

/// Tolerant read of a manifest field: anything that isn't a string is treated
/// as absent rather than crashing the whole list.
String? _string(Object? value) => value is String && value.isNotEmpty ? value : null;

/// One localized build of a post as published by the website.
///
/// The German (French, …) build of a post has its OWN slug — it is not a
/// transformation of the English one — so both the slug and the title have to
/// come from the manifest.
@immutable
class BlogTranslation {
  final String slug;
  final String title;

  /// Site-relative path, e.g. `/de/blog/controller-einrichten-tastenbelegung/`.
  final String url;

  const BlogTranslation({required this.slug, required this.title, required this.url});

  static BlogTranslation? fromJson(String languageCode, Map<String, dynamic> json) {
    final slug = _string(json['slug']);
    final title = _string(json['title']);
    if (slug == null || slug.isEmpty || title == null || title.isEmpty) return null;
    final url = _string(json['url']);
    return BlogTranslation(
      slug: slug,
      title: title,
      url: url != null && url.isNotEmpty ? url : '/$languageCode/blog/$slug/',
    );
  }
}

class BlogPost {
  final DateTime date;
  final String title;
  final String slug;

  /// Site-relative path of the English post as published, e.g.
  /// `/blog/bikecontrol-6-6-more-trainers-more-apps/`. Null when the post was
  /// derived from a filename (legacy manifest), in which case the path is
  /// built from [slug].
  final String? path;

  /// Localized builds keyed by lower-case language code (`de`, `fr`, …).
  final Map<String, BlogTranslation> translations;

  BlogPost({
    required this.date,
    required this.title,
    required this.slug,
    this.path,
    this.translations = const {},
  });

  /// The English (default) URL.
  String get url => urlForLanguage(null);

  /// The URL to open for [languageCode], falling back to the English post when
  /// that language has no translation — `/<lang>/blog/<english-slug>/` does not
  /// exist on the website and would bounce the reader back to `/blog/`.
  String urlForLanguage(String? languageCode) {
    final translation = translationFor(languageCode);
    return _absolute(translation?.url ?? path ?? '/blog/$slug');
  }

  /// The title to show for [languageCode], falling back to the English title.
  String titleForLanguage(String? languageCode) => translationFor(languageCode)?.title ?? title;

  /// The localized build for [languageCode], or null when untranslated.
  /// Accepts full locale codes (`de_DE`, `de-DE`) as well as bare languages.
  BlogTranslation? translationFor(String? languageCode) {
    if (languageCode == null || languageCode.isEmpty) return null;
    final normalized = languageCode.toLowerCase().split(RegExp('[_-]')).first;
    return translations[normalized];
  }

  static String _absolute(String path) => path.startsWith('http')
      ? path
      : '$_blogSiteUrl${path.startsWith('/') ? '' : '/'}$path';

  /// A post is "new" if it was published within the last 14 days.
  bool get isNew => DateTime.now().difference(date).inDays < 3;

  /// Parse one `entries` object from the manifest. The website publishes the
  /// real frontmatter slug/title/url here, so nothing is re-derived from the
  /// filename; an entry that is too incomplete to use falls back to
  /// [fromFilename] so a partially broken manifest still lists the post.
  static BlogPost? fromEntry(Map<String, dynamic> json) {
    final filename = _string(json['filename']);
    final fallback = filename == null ? null : fromFilename(filename);

    final slug = _string(json['slug']);
    final title = _string(json['title']);
    final date = DateTime.tryParse(_string(json['date']) ?? '') ?? fallback?.date;
    if (date == null || slug == null || slug.isEmpty || title == null || title.isEmpty) return fallback;

    final translations = <String, BlogTranslation>{};
    final rawTranslations = json['translations'];
    if (rawTranslations is Map) {
      rawTranslations.forEach((key, value) {
        if (key is! String || value is! Map) return;
        final languageCode = key.toLowerCase();
        final translation = BlogTranslation.fromJson(languageCode, value.cast<String, dynamic>());
        if (translation != null) translations[languageCode] = translation;
      });
    }

    final url = _string(json['url']);
    return BlogPost(
      date: date,
      title: title,
      slug: slug,
      path: url != null && url.isNotEmpty ? url : '/blog/$slug/',
      translations: translations,
    );
  }

  /// Parse a filename like "2026-02-27 BikeControl 5.md"
  /// Returns null if the filename doesn't start with a valid date.
  ///
  /// Legacy path: the slug guessed here only matches the website when the
  /// post's frontmatter slug happens to equal its slugified title. Kept as a
  /// fallback for manifests without an `entries` array so the blog list is
  /// never empty.
  static BlogPost? fromFilename(String filename) {
    final match = RegExp(r'^(\d{4}-\d{2}-\d{2})\s+(.+)\.md$').firstMatch(filename);
    if (match == null) return null;

    final date = DateTime.tryParse(match.group(1)!);
    if (date == null) return null;

    final title = match.group(2)!;
    final slug = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s-]'), '').trim().replaceAll(RegExp(r'\s+'), '-');

    return BlogPost(date: date, title: title, slug: slug);
  }
}

class BlogService {
  static final BlogService _instance = BlogService._();
  factory BlogService() => _instance;
  BlogService._();

  static const _manifestUrl = 'https://bikecontrol.app/blog/manifest.json';

  List<BlogPost>? _cachedPosts;
  Future<List<BlogPost>>? _fetchFuture;

  /// Fetch blog posts from the manifest. Results are cached.
  Future<List<BlogPost>> fetchPosts() {
    _fetchFuture ??= _doFetch();
    return _fetchFuture!;
  }

  Future<List<BlogPost>> _doFetch() async {
    try {
      final response = await http.get(Uri.parse(_manifestUrl));
      if (response.statusCode != 200) return _cachedPosts ?? [];

      final posts = parseManifest(jsonDecode(response.body) as Map<String, dynamic>);

      _cachedPosts = posts;
      return posts;
    } catch (e, s) {
      recordError(e, s, context: 'BlogService.fetchPosts');
      return _cachedPosts ?? [];
    }
  }

  /// Build the post list from a decoded manifest, newest first.
  ///
  /// Prefers the `entries` array (real slugs, titles and localized URLs) and
  /// falls back to the legacy `posts` filename list so an older or cached
  /// manifest still produces a list instead of an empty blog section.
  @visibleForTesting
  static List<BlogPost> parseManifest(Map<String, dynamic> json) {
    final entries = json['entries'];
    if (entries is List) {
      final posts = entries
          .whereType<Map>()
          .map((entry) => BlogPost.fromEntry(entry.cast<String, dynamic>()))
          .whereType<BlogPost>()
          .toList();
      if (posts.isNotEmpty) return posts..sort((a, b) => b.date.compareTo(a.date));
    }

    final filenames = (json['posts'] as List?)?.whereType<String>() ?? const <String>[];
    return filenames.map(BlogPost.fromFilename).whereType<BlogPost>().toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }
}
