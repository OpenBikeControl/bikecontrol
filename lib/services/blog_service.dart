import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class BlogPost {
  final DateTime date;
  final String title;
  final String slug;

  BlogPost({required this.date, required this.title, required this.slug});

  String get url => 'https://bikecontrol.app/blog/$slug';

  /// A post is "new" if it was published within the last 14 days.
  bool get isNew => DateTime.now().difference(date).inDays < 3;

  /// Parse a filename like "2026-02-27 BikeControl 5.md"
  /// Returns null if the filename doesn't start with a valid date.
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

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final filenames = (json['posts'] as List).cast<String>();

      final posts = filenames.map(BlogPost.fromFilename).whereType<BlogPost>().toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      _cachedPosts = posts;
      return posts;
    } catch (e) {
      debugPrint('BlogService: Failed to fetch posts: $e');
      return _cachedPosts ?? [];
    }
  }
}
