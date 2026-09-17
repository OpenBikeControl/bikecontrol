// BlogPostsWidget must render each post in the app's ACTIVE language: the
// German build of a post has its own slug (/de/blog/<german-slug>/), so the
// row's title and the launched URL both follow `Localizations.localeOf`.
// Posts without a translation stay on the English /blog/ URL — the /de/ URL
// for an untranslated post 404s.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/services/blog_service.dart';
import 'package:bike_control/widgets/blog_posts_widget.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// Records every URL passed to `launchUrl` instead of hitting a real platform
/// channel, so taps are assertable.
class _FakeUrlLauncher extends UrlLauncherPlatform {
  final List<String> launchedUrls = [];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrls.add(url);
    return true;
  }
}

final _translated = BlogPost(
  date: DateTime(2026, 8, 21),
  title: 'Configure Your Controller Tutorial',
  slug: 'configure-your-controller-tutorial',
  path: '/blog/configure-your-controller-tutorial/',
  translations: {
    'de': const BlogTranslation(
      slug: 'controller-einrichten-tastenbelegung',
      title: 'Controller einrichten: Tastenbelegung',
      url: '/de/blog/controller-einrichten-tastenbelegung/',
    ),
  },
);

final _untranslated = BlogPost(
  date: DateTime(2026, 9, 3),
  title: '6.6 - More Trainers, More Apps',
  slug: 'bikecontrol-6-6-more-trainers-more-apps',
  path: '/blog/bikecontrol-6-6-more-trainers-more-apps/',
);

Future<void> _pump(WidgetTester tester, Locale locale, List<BlogPost> posts) async {
  await tester.pumpWidget(
    ShadcnApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      localizationsDelegates: [
        ...ShadcnLocalizations.localizationsDelegates,
        const OtherLocalizationsDelegate(),
        AppLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      home: Scaffold(
        child: BlogPostsWidget(showHeader: false, postsFutureOverride: Future.value(posts)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async => initializeDateFormatting());

  late _FakeUrlLauncher fake;

  setUp(() {
    fake = _FakeUrlLauncher();
    final previous = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = fake;
    addTearDown(() => UrlLauncherPlatform.instance = previous);
  });

  testWidgets('English locale shows the English title and opens the English URL', (tester) async {
    await _pump(tester, const Locale('en'), [_translated]);

    expect(find.text('Configure Your Controller Tutorial'), findsOneWidget);

    await tester.tap(find.text('Configure Your Controller Tutorial'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(fake.launchedUrls, ['https://bikecontrol.app/blog/configure-your-controller-tutorial/']);
  });

  testWidgets('German locale shows the German title and opens the German URL', (tester) async {
    await _pump(tester, const Locale('de'), [_translated]);

    expect(find.text('Controller einrichten: Tastenbelegung'), findsOneWidget);
    expect(find.text('Configure Your Controller Tutorial'), findsNothing);

    await tester.tap(find.text('Controller einrichten: Tastenbelegung'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(fake.launchedUrls, ['https://bikecontrol.app/de/blog/controller-einrichten-tastenbelegung/']);
  });

  testWidgets('German locale falls back to English for an untranslated post', (tester) async {
    await _pump(tester, const Locale('de'), [_untranslated]);

    expect(find.text('6.6 - More Trainers, More Apps'), findsOneWidget);

    await tester.tap(find.text('6.6 - More Trainers, More Apps'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    // NOT /de/blog/... — that URL does not exist for this post.
    expect(fake.launchedUrls, ['https://bikecontrol.app/blog/bikecontrol-6-6-more-trainers-more-apps/']);
  });
}
