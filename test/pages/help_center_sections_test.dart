// Task 10: the "Known issues" section body. Pins: known-issues renders one
// ghost row per fetched issue, routing each tap to the plain
// bikecontrol.app/issues/<id> URL; an empty or failing fetch hides the
// section entirely (no dead card).
//
// Usage-fix round (Bug 2): issues that carry a `helpBlogSlug` are
// "Blog-derived seeds" (website migration
// 20260517070000_seed_intake_help_issues.sql) — tutorial/help entries for
// the support intake form's "Read tutorial" affordance, not incidents. This
// section now excludes them outright rather than routing to the blog post,
// which superseded an earlier design (see git history) that did route them
// there.
//
// Design round 1 added two more groups: "Guides & videos" dropped its blog
// list for a direct Tutorials link (the Instruction Videos row that followed
// it was later removed — mostly outdated), and
// "Contact & community" collapsed its support row + a separate report row
// into one "Tell us what's wrong" / "Chat with support · no account needed"
// row, keeping the same tap/unread-dot wiring.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/help_center/widgets/contact_community_section.dart';
import 'package:bike_control/pages/help_center/widgets/guides_videos_section.dart';
import 'package:bike_control/pages/help_center/widgets/help_center_section_card.dart';
import 'package:bike_control/pages/help_center/widgets/known_issues_section.dart';
import 'package:bike_control/services/support_chat_models.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// Records every URL passed to `launchUrlString`/`launchUrl` instead of
/// hitting a real platform channel, so taps are assertable.
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

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    ShadcnApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [AppLocalizations.delegate],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      home: Scaffold(child: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeDateFormatting();
  });

  setUp(() async {
    // GuidesVideosSection/ContactCommunitySection read `core.settings`
    // directly (no test-seam override, unlike YourSetupSection) — prefs
    // must be assigned before `Settings.getTrainerApp()` /
    // `getSupportChatActive()` are called or they throw.
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
  });

  group('KnownIssuesSection', () {
    testWidgets('renders a row per fetched issue, plus its own header card', (tester) async {
      final l10n = await AppLocalizations.load(const Locale('en'));
      final issues = [
        const SupportIssue(id: 'i1', title: 'MyWhoosh drops connection'),
        const SupportIssue(id: 'i2', title: 'Zwift Click V2 pairing fails'),
      ];

      await _pump(tester, KnownIssuesSection(index: 2, fetchIssues: () async => issues));
      await tester.pump();

      // Usage-fix round 3: this section now owns its whole
      // HelpCenterSectionCard (header included), not just the row list — see
      // the "hides ... entirely, header included" test below for the empty
      // side of this.
      expect(find.text(l10n.helpCenterKnownIssues), findsOneWidget);
      expect(find.text('MyWhoosh drops connection'), findsOneWidget);
      expect(find.text('Zwift Click V2 pairing fails'), findsOneWidget);
    });

    testWidgets('tapping a row without a blog slug opens the generic issue URL', (tester) async {
      final fake = _FakeUrlLauncher();
      final previous = UrlLauncherPlatform.instance;
      UrlLauncherPlatform.instance = fake;
      addTearDown(() => UrlLauncherPlatform.instance = previous);
      final issues = [const SupportIssue(id: 'abc123', title: 'Some issue')];

      await _pump(tester, KnownIssuesSection(index: 2, fetchIssues: () async => issues));
      await tester.pump();

      await tester.tap(find.text('Some issue'));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(fake.launchedUrls, ['https://bikecontrol.app/issues/abc123']);
    });

    testWidgets('excludes issues that carry a helpBlogSlug — those are tutorial seeds, not incidents', (
      tester,
    ) async {
      final issues = [
        const SupportIssue(id: 'i1', title: 'MyWhoosh drops connection'),
        const SupportIssue(id: 'i2', title: 'How to pair your Zwift Click V2', helpBlogSlug: 'pair-click-v2'),
      ];

      await _pump(tester, KnownIssuesSection(index: 2, fetchIssues: () async => issues));
      await tester.pump();

      expect(find.text('MyWhoosh drops connection'), findsOneWidget);
      expect(find.text('How to pair your Zwift Click V2'), findsNothing);
    });

    testWidgets('hides the section when every fetched issue carries a helpBlogSlug', (tester) async {
      final issues = [
        const SupportIssue(id: 'i2', title: 'How to pair your Zwift Click V2', helpBlogSlug: 'pair-click-v2'),
      ];

      await _pump(tester, KnownIssuesSection(index: 2, fetchIssues: () async => issues));
      await tester.pump();

      expect(find.byType(Button), findsNothing);
    });

    testWidgets('hides the section entirely, header included, when the fetch returns no issues', (tester) async {
      final l10n = await AppLocalizations.load(const Locale('en'));

      await _pump(tester, KnownIssuesSection(index: 2, fetchIssues: () async => const []));
      await tester.pump();

      // Usage-fix round 3 (Jonas): an empty "Bekannte Probleme" card — header
      // with nothing under it — must not render at all. KnownIssuesSection
      // now owns its whole HelpCenterSectionCard, so an empty fetch collapses
      // the header and divider along with the row list, not just the rows.
      expect(find.byType(Button), findsNothing);
      expect(find.text(l10n.helpCenterKnownIssues), findsNothing, reason: 'header must hide too, not just the body');
      expect(find.byType(HelpCenterSectionCard), findsNothing);
      // The widget itself is still mounted (so a later non-empty fetch could
      // still show it) — it just paints nothing.
      expect(find.byType(KnownIssuesSection), findsOneWidget);
    });

    testWidgets('hides the section (and records, not throws) when the fetch fails', (tester) async {
      await _pump(tester, KnownIssuesSection(index: 2, fetchIssues: () async => throw Exception('network down')));
      await tester.pump();

      expect(find.byType(Button), findsNothing);
      expect(find.byType(HelpCenterSectionCard), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('GuidesVideosSection', () {
    testWidgets(
      'shows a Tutorials row linking bikecontrol.app/blog (Bug 4: /tutorials 404s) and no YouTube videos row',
      (
        tester,
      ) async {
        final fake = _FakeUrlLauncher();
        final previous = UrlLauncherPlatform.instance;
        UrlLauncherPlatform.instance = fake;
        addTearDown(() => UrlLauncherPlatform.instance = previous);

        await _pump(tester, const GuidesVideosSection());
        await tester.pump();

        final l10n = AppLocalizations.of(tester.element(find.byType(GuidesVideosSection)));
        expect(find.text(l10n.tutorials), findsOneWidget);
        // The instruction-videos drawer (YouTube channel feed, mostly
        // outdated) is gone: with no controller there is no article row
        // either, so Tutorials is the only row left.
        expect(find.byIcon(LucideIcons.monitorPlay), findsNothing);
        expect(find.byType(Button), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('help-center-tutorials')));
        await tester.pump();

        // https://bikecontrol.app/tutorials does not exist on the website (only
        // /blog and /blog/:slug) — the tutorials are the blog's "Blog-derived
        // seeds" posts, so this points at /blog until a dedicated index exists.
        expect(fake.launchedUrls, ['https://bikecontrol.app/blog']);
      },
    );
  });

  group('ContactCommunitySection', () {
    testWidgets('shows a single report row (title + subtitle) instead of two support entries', (tester) async {
      final l10n = await AppLocalizations.load(const Locale('en'));

      await _pump(tester, const ContactCommunitySection());
      await tester.pump();

      expect(find.text(l10n.helpCenterReportTitle), findsOneWidget);
      expect(find.text(l10n.helpCenterReportSubtitle), findsOneWidget);
      final supportRowFinder = find.byKey(const ValueKey('help-center-chat-with-support'));
      expect(
        supportRowFinder,
        findsOneWidget,
        reason: 'same row/wiring as before, only relabeled',
      );
      expect(
        tester.getTopLeft(supportRowFinder).dy,
        lessThan(tester.getTopLeft(find.text('Reddit')).dy),
        reason: 'support row leads, matching the spec/mockup order',
      );

      // Reddit/Facebook/GitHub rows are untouched.
      expect(find.text('Reddit'), findsOneWidget);
      expect(find.text('Facebook'), findsOneWidget);
      expect(find.text('GitHub'), findsOneWidget);
    });
  });
}
