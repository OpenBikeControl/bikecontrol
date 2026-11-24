import '../../utils/core.dart';
import 'network_check.dart';
import 'network_self_test_result.dart';

/// Persistence for the last network self-test run — one slot, shared across
/// every trainer/target, mirroring how [Settings.getSelfTestResultJson] keeps
/// the per-trainer resistance self-test.
class NetworkSelfTestStore {
  const NetworkSelfTestStore._();

  /// Persist only completed or ≥1-active-probe-cancelled runs: a cancel hit
  /// before a single probe ran (or after only `skipped` rows) carries
  /// nothing worth showing later, so it is dropped rather than overwriting
  /// whatever the previous run left behind.
  static Future<void> save(NetworkSelfTestResult result) async {
    final hasActiveProbe = result.checks.any((check) => check.verdict != NetworkVerdict.skipped);
    if (!result.completed && !hasActiveProbe) {
      return;
    }
    await core.settings.setNetworkSelfTestResultJson(result.toJsonString());
  }

  static NetworkSelfTestResult? load() {
    return NetworkSelfTestResult.tryParse(core.settings.getNetworkSelfTestResultJson());
  }

  /// A stored result older than this no longer describes the device: the
  /// network, the app version or the method may all have changed since.
  static const staleAfter = Duration(hours: 24);

  /// `'Network self-test:\n<age line>\n<toBundleString()>'` or `''` when none
  /// stored — the caller (`debugText()`) interpolates this as a whole optional
  /// block, so an empty string must add nothing, not even a blank line.
  ///
  /// The bundle carries the LAST STORED run, not one made for the bundle, so
  /// the age line says how old it is and whether to trust it.
  static String bundleSection({DateTime Function() now = DateTime.now}) {
    final result = load();
    if (result == null) {
      return '';
    }
    return 'Network self-test:\n${ageLine(result.at, now())}\n${result.toBundleString()}';
  }

  /// `age=3d 4h STALE (stored result, run the check again)` / `age=12min`.
  static String ageLine(DateTime at, DateTime now) {
    final age = now.difference(at);
    final String text;
    if (age.isNegative) {
      text = '0min';
    } else if (age.inHours < 1) {
      text = '${age.inMinutes}min';
    } else if (age.inDays < 1) {
      text = '${age.inHours}h ${age.inMinutes % 60}min';
    } else {
      text = '${age.inDays}d ${age.inHours % 24}h';
    }
    return age > staleAfter ? 'age=$text STALE (stored result, run the check again)' : 'age=$text';
  }
}
