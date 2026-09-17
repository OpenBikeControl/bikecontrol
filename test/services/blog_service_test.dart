// The blog manifest carries the website's REAL slugs. Before this, the app
// invented a slug by slugifying the markdown filename's title — which 404'd
// for every post whose frontmatter slug differs from its title, and always
// sent German users to the English URL.
//
// Pins: a manifest `entries` array wins over filename derivation (slug, title
// and url verbatim), a locale with a translation gets the localized URL +
// title, a locale WITHOUT one falls back to the English post (a /de/ URL for
// an untranslated post 404s), and a manifest without `entries` still yields
// posts through the legacy filename path.
import 'package:bike_control/services/blog_service.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _manifest({bool withEntries = true}) => {
  'posts': [
    '2026-09-03 BikeControl 6.6 Smart Trainer Compatibility.md',
    '2026-08-21 Configure Your Controller Tutorial.md',
  ],
  'translations': {
    'de': ['2026-08-21 Configure Your Controller Tutorial.de.md'],
  },
  if (withEntries)
    'entries': [
      {
        'filename': '2026-09-03 BikeControl 6.6 Smart Trainer Compatibility.md',
        'date': '2026-09-03',
        'slug': 'bikecontrol-6-6-more-trainers-more-apps',
        'title': '6.6 - More Trainers, More Apps',
        'url': '/blog/bikecontrol-6-6-more-trainers-more-apps/',
        'translations': <String, dynamic>{},
      },
      {
        'filename': '2026-08-21 Configure Your Controller Tutorial.md',
        'date': '2026-08-21',
        'slug': 'configure-your-controller-tutorial',
        'title': 'Configure Your Controller Tutorial',
        'url': '/blog/configure-your-controller-tutorial/',
        'translations': {
          'de': {
            'slug': 'controller-einrichten-tastenbelegung',
            'title': 'Controller einrichten: Tastenbelegung',
            'url': '/de/blog/controller-einrichten-tastenbelegung/',
          },
        },
      },
    ],
};

void main() {
  group('manifest entries', () {
    test('the server-supplied slug/title/url win over filename derivation', () {
      final posts = BlogService.parseManifest(_manifest());

      final release = posts.first;
      expect(release.date, DateTime.parse('2026-09-03'));
      expect(release.slug, 'bikecontrol-6-6-more-trainers-more-apps');
      // NOT the stale filename title "BikeControl 6.6 Smart Trainer Compatibility".
      expect(release.title, '6.6 - More Trainers, More Apps');
      expect(release.url, 'https://bikecontrol.app/blog/bikecontrol-6-6-more-trainers-more-apps/');
    });

    test('posts are sorted newest first', () {
      final posts = BlogService.parseManifest(_manifest());
      expect(posts.map((p) => p.slug), [
        'bikecontrol-6-6-more-trainers-more-apps',
        'configure-your-controller-tutorial',
      ]);
    });

    test('a translated post yields the localized URL and title', () {
      final tutorial = BlogService.parseManifest(_manifest())[1];

      expect(tutorial.urlForLanguage('de'), 'https://bikecontrol.app/de/blog/controller-einrichten-tastenbelegung/');
      expect(tutorial.titleForLanguage('de'), 'Controller einrichten: Tastenbelegung');
    });

    test('an untranslated post falls back to the English URL and title', () {
      final release = BlogService.parseManifest(_manifest()).first;

      // /de/blog/<english-slug>/ 404s — a German reader must get the /blog/ URL.
      expect(release.urlForLanguage('de'), 'https://bikecontrol.app/blog/bikecontrol-6-6-more-trainers-more-apps/');
      expect(release.titleForLanguage('de'), '6.6 - More Trainers, More Apps');
    });

    test('an unknown locale falls back to English', () {
      final tutorial = BlogService.parseManifest(_manifest())[1];

      expect(tutorial.urlForLanguage('ja'), 'https://bikecontrol.app/blog/configure-your-controller-tutorial/');
      expect(tutorial.titleForLanguage('ja'), 'Configure Your Controller Tutorial');
      expect(tutorial.urlForLanguage(null), 'https://bikecontrol.app/blog/configure-your-controller-tutorial/');
    });

    test('a regional locale code still matches its language translation', () {
      final tutorial = BlogService.parseManifest(_manifest())[1];

      expect(tutorial.urlForLanguage('de_DE'), 'https://bikecontrol.app/de/blog/controller-einrichten-tastenbelegung/');
    });

    test('a translation without an explicit url derives /<lang>/blog/<slug>/', () {
      final posts = BlogService.parseManifest({
        'entries': [
          {
            'date': '2026-08-21',
            'slug': 'configure-your-controller-tutorial',
            'title': 'Configure Your Controller Tutorial',
            'translations': {
              'de': {'slug': 'controller-einrichten-tastenbelegung', 'title': 'Controller einrichten'},
            },
          },
        ],
      });

      expect(posts.single.url, 'https://bikecontrol.app/blog/configure-your-controller-tutorial/');
      expect(
        posts.single.urlForLanguage('de'),
        'https://bikecontrol.app/de/blog/controller-einrichten-tastenbelegung/',
      );
    });

    test('an entry missing slug/title falls back to its filename', () {
      final posts = BlogService.parseManifest({
        'entries': [
          {'filename': '2026-03-19 BikeControl 5.md'},
        ],
      });

      expect(posts.single.slug, 'bikecontrol-5');
      expect(posts.single.title, 'BikeControl 5');
    });

    test('an entry that is neither usable nor filename-backed is dropped', () {
      final posts = BlogService.parseManifest({
        'entries': [
          {'date': '2026-03-19'},
          {'date': '2026-03-20', 'slug': 'ok', 'title': 'Ok'},
        ],
      });

      expect(posts.map((p) => p.slug), ['ok']);
    });
  });

  group('legacy manifest (no entries)', () {
    test('still yields posts through the filename path', () {
      final posts = BlogService.parseManifest(_manifest(withEntries: false));

      expect(posts.map((p) => p.slug), [
        'bikecontrol-66-smart-trainer-compatibility',
        'configure-your-controller-tutorial',
      ]);
      expect(posts.first.url, 'https://bikecontrol.app/blog/bikecontrol-66-smart-trainer-compatibility');
      // No translation data is derivable from filenames: German stays English.
      expect(posts[1].urlForLanguage('de'), 'https://bikecontrol.app/blog/configure-your-controller-tutorial');
    });

    test('an empty entries array does not blank the list', () {
      final json = _manifest(withEntries: false)..['entries'] = <dynamic>[];
      expect(BlogService.parseManifest(json), hasLength(2));
    });

    test('a manifest with neither key yields an empty list', () {
      expect(BlogService.parseManifest(<String, dynamic>{}), isEmpty);
    });
  });

  group('BlogPost.fromFilename', () {
    test('parses date and title', () {
      final post = BlogPost.fromFilename('2026-02-27 BikeControl 5.md')!;

      expect(post.date, DateTime.parse('2026-02-27'));
      expect(post.title, 'BikeControl 5');
      expect(post.slug, 'bikecontrol-5');
      expect(post.url, 'https://bikecontrol.app/blog/bikecontrol-5');
    });

    test('returns null without a leading date', () {
      expect(BlogPost.fromFilename('BikeControl 5.md'), isNull);
      expect(BlogPost.fromFilename('2026-02-27 BikeControl 5.txt'), isNull);
    });
  });
}
