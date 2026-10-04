import 'package:bike_control/main.dart' show recordError, screenshotMode;
import 'package:bike_control/models/changelog.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/changelog/changelog_view.dart';
import 'package:bike_control/widgets/ui/bk_page_column.dart';
import 'package:bike_control/widgets/ui/bk_page_header.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Where the changelog comes from: the bundled CHANGELOG.md, and — so a rider
/// on an older build still reads what the next one brings — the copy on the
/// main branch, when it can be fetched.
abstract final class ChangelogSource {
  static const String asset = 'CHANGELOG.md';
  static const String onlineUrl =
      'https://raw.githubusercontent.com/OpenBikeControl/bikecontrol/refs/heads/main/CHANGELOG.md';

  /// Stands in for the bundled file (and turns the online copy off) in tests.
  @visibleForTesting
  static Future<String> Function()? debugBundled;

  static Future<List<ChangelogRelease>> bundled() async =>
      parseChangelog(await (debugBundled?.call() ?? rootBundle.loadString(asset)));

  /// Null when there is no online copy to be had (offline, tests, store
  /// renders).
  static Future<List<ChangelogRelease>?> online() async {
    if (debugBundled != null || screenshotMode) return null;
    try {
      final response = await http.get(Uri.parse(onlineUrl));
      if (response.statusCode != 200) return null;
      final releases = parseChangelog(response.body);
      return releases.isEmpty ? null : releases;
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
      headers: [BkPageHeader(title: context.i18n.changelog)],
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
