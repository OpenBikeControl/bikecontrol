import 'dart:convert' show utf8;

import 'package:bike_control/main.dart' show recordError, screenshotMode;
import 'package:bike_control/models/changelog.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/changelog/changelog_view.dart';
import 'package:bike_control/widgets/ui/bk_page_column.dart';
import 'package:bike_control/widgets/ui/bk_page_header.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart' as intl;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Where the changelog comes from: the bundled CHANGELOG.md, translated
/// release by release from `changelog/<language>.md` where a translation exists,
/// and — so a rider on an older build still reads what the next one brings —
/// the copies on the main branch, when they can be fetched.
abstract final class ChangelogSource {
  static const String asset = 'CHANGELOG.md';
  static const String onlineUrl =
      'https://raw.githubusercontent.com/OpenBikeControl/bikecontrol/refs/heads/main/CHANGELOG.md';

  /// The languages with a translated changelog (`changelog/<language>.md`).
  static const Set<String> translatedLanguages = {'de', 'es', 'fr', 'it', 'pl', 'zh'};

  static String translatedAsset(String language) => 'changelog/$language.md';
  static String translatedOnlineUrl(String language) =>
      'https://raw.githubusercontent.com/OpenBikeControl/bikecontrol/refs/heads/main/changelog/$language.md';

  /// Stands in for the bundled file (and turns the online copy off) in tests.
  @visibleForTesting
  static Future<String> Function()? debugBundled;

  /// Stands in for a bundled translation in tests; null means none.
  @visibleForTesting
  static Future<String?> Function(String language)? debugTranslated;

  /// The app's current language ("de" for de_DE).
  static String currentLanguage() => intl.Intl.getCurrentLocale().split(RegExp('[_-]')).first.toLowerCase();

  /// Apple builds leave out entries about other platforms (Apple rejects
  /// them). Overridable in tests.
  @visibleForTesting
  static bool Function() debugIsApple = () =>
      defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS;

  static List<ChangelogRelease> _forPlatform(List<ChangelogRelease> releases) =>
      debugIsApple() ? withoutOtherPlatforms(releases) : releases;

  static Future<List<ChangelogRelease>> bundled({String? language}) async =>
      _forPlatform(await _bundled(language: language));

  static Future<List<ChangelogRelease>> _bundled({String? language}) async {
    final english = parseChangelog(await (debugBundled?.call() ?? rootBundle.loadString(asset)));
    final lang = language ?? currentLanguage();
    if (!translatedLanguages.contains(lang)) return english;
    try {
      final text = debugBundled != null
          ? await debugTranslated?.call(lang)
          : await rootBundle.loadString(translatedAsset(lang));
      return text == null ? english : localizeReleases(english, parseChangelog(text));
    } catch (e, s) {
      recordError(e, s, context: 'Changelog.bundled($lang)');
      return english;
    }
  }

  /// Null when there is no online copy to be had (offline, tests, store
  /// renders).
  static Future<List<ChangelogRelease>?> online({String? language}) async {
    final releases = await _online(language: language);
    return releases == null ? null : _forPlatform(releases);
  }

  static Future<List<ChangelogRelease>?> _online({String? language}) async {
    if (debugBundled != null || screenshotMode) return null;
    try {
      final response = await http.get(Uri.parse(onlineUrl));
      if (response.statusCode != 200) return null;
      final releases = parseChangelog(utf8.decode(response.bodyBytes));
      if (releases.isEmpty) return null;
      final lang = language ?? currentLanguage();
      if (!translatedLanguages.contains(lang)) return releases;
      final translated = await http.get(Uri.parse(translatedOnlineUrl(lang)));
      if (translated.statusCode != 200) return releases;
      return localizeReleases(releases, parseChangelog(utf8.decode(translated.bodyBytes)));
    } catch (e, s) {
      recordError(e, s, context: 'Changelog.online');
      return null;
    }
  }

  /// The running app's version, to mark its release.
  static Future<String?> currentVersion() async {
    if (debugBundled != null) return debugCurrentVersion;
    try {
      return (await PackageInfo.fromPlatform()).version;
    } catch (e, s) {
      recordError(e, s, context: 'Changelog.currentVersion');
      return null;
    }
  }

  @visibleForTesting
  static String? debugCurrentVersion;
}

/// Settings → Changelog: every release, the newest in full.
class ChangelogPage extends StatefulWidget {
  const ChangelogPage({super.key});

  @override
  State<ChangelogPage> createState() => _ChangelogPageState();
}

class _ChangelogPageState extends State<ChangelogPage> {
  List<ChangelogRelease>? _releases;
  String? _currentVersion;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final releases = await ChangelogSource.bundled();
      final version = await ChangelogSource.currentVersion();
      if (!mounted) return;
      setState(() {
        _releases = releases;
        _currentVersion = version;
      });
    } catch (e, s) {
      recordError(e, s, context: 'ChangelogPage.load');
      if (mounted) setState(() => _failed = true);
      return;
    }
    final online = await ChangelogSource.online();
    if (online != null && mounted) setState(() => _releases = online);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final releases = _releases;
    return Scaffold(
      headers: [BkPageHeader(title: context.i18n.changelog, columnWidth: changelogMaxWidth)],
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: BkPageColumn(
          maxWidth: changelogMaxWidth,
          child: _failed
              ? Text(
                  context.i18n.changelogLoadFailed,
                  style: context.typography.base.copyWith(color: cs.mutedForeground),
                )
              : releases == null
              ? const SizedBox(height: 200)
              : ChangelogView(releases: releases, currentVersion: _currentVersion),
        ),
      ),
    );
  }
}
