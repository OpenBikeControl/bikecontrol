import 'package:prop/mdns/mdns_responder.dart' show MdnsQueryLogEntry;

import '../../../bluetooth/devices/openbikecontrol/obp_mdns_backend.dart';
import '../network_check.dart';
import '../network_probe_context.dart';

/// Check 9: "press the button" — prompts the user to open the trainer app's
/// pairing screen and tap BikeControl, then watches what actually crosses the
/// wire for up to [window], polling every [tick]. Unlike the other probes
/// this one is driven by a loop rather than a single I/O call, so it needs
/// its own seams: [NetworkProbeContext.queryLog] (what the responder saw),
/// [NetworkProbeContext.trainerAppConnectedNow] (sampled fresh every tick,
/// not the fixed snapshot on [NetworkProbeContext.trainerAppConnected]) and
/// [NetworkProbeContext.sleep]/[NetworkProbeContext.now] so tests can drive
/// it without a real clock.
Future<NetworkCheck> guidedWatchCheck(
  NetworkProbeContext ctx, {
  Duration window = const Duration(seconds: 60),
  Duration tick = const Duration(milliseconds: 500),
  bool Function()? isCancelled,
}) async {
  final osResponder = ctx.backend == ObpMdnsBackend.osResponder;
  final start = ctx.now();

  // Under the OS responder, OBC's own advertisement never touches our
  // responder's query log (the OS answers it), so there is nothing to browse
  // for there — skip reading it and classify on `connected` alone below.
  //
  // Correlate entries by OBJECT IDENTITY, not list position: the responder
  // (MdnsResponder._recordQuery) folds an exact repeat by REMOVING the
  // existing MdnsQueryLogEntry and RE-APPENDING the SAME instance at the end
  // of the log (count++, at updated) — so an unrelated entry folding shifts
  // every later index, and position-based correlation both false-positives
  // (an untouched entry slides into a just-vacated slot and compares against
  // a stale count) and false-negatives (a baseline entry that keeps folding
  // never looks "new" by list growth alone). `Map.identity()` sidesteps both:
  // it tracks the exact entry instance regardless of where it moves.
  final seenCounts = Map<MdnsQueryLogEntry, int>.identity();
  if (!osResponder) {
    for (final entry in ctx.queryLog()) {
      seenCounts[entry] = entry.count;
    }
  }

  var browsed = false;
  var resolved = false;
  var addressAsks = 0;

  void classify(MdnsQueryLogEntry entry) {
    for (final question in entry.questions) {
      if (question.startsWith('PTR _openbikecontrol') || question.startsWith('PTR _wahoo-fitness-tnp')) {
        browsed = true;
      } else if ((question.startsWith('SRV ') || question.startsWith('TXT ')) && question.contains('BikeControl')) {
        resolved = true;
      } else if (_isAddressQuestion(question, ctx.advertisedHostname)) {
        addressAsks++;
      }
    }
  }

  while (true) {
    if (isCancelled != null && isCancelled()) {
      return const NetworkCheck(
        id: NetworkCheckId.guidedWatch,
        verdict: NetworkVerdict.skipped,
        detail: {'reason': 'skipped'},
      );
    }

    if (!osResponder) {
      for (final entry in ctx.queryLog()) {
        final previousCount = seenCounts[entry];
        if (previousCount == null) {
          // Brand-new entry instance since the watch started.
          classify(entry);
          seenCounts[entry] = entry.count;
        } else if (entry.count > previousCount) {
          // A fold happened during the watch — same instance, higher count
          // (whether it was new-since-baseline or already present at
          // baseline and kept folding; either way this is fresh activity).
          classify(entry);
          seenCounts[entry] = entry.count;
        }
      }
    }

    final connected = ctx.trainerAppConnectedNow();
    final elapsed = ctx.now().difference(start);
    final remaining = window - elapsed;
    ctx.onWatchProgress(
      WatchProgress(
        browsed: browsed,
        resolved: resolved,
        addressAsks: addressAsks,
        connected: connected,
        remaining: remaining.isNegative ? Duration.zero : remaining,
        window: window,
      ),
    );

    if (connected) {
      return const NetworkCheck(id: NetworkCheckId.guidedWatch, verdict: NetworkVerdict.pass);
    }

    if (elapsed >= window) {
      break;
    }

    await ctx.sleep(tick);
  }

  // The system mDNS service (Android NSD — the recommended setting there —
  // or Bonjour) answers every query itself, so nothing the trainer app asked
  // ever reaches this probe: there is no failure to see, only a connection
  // that did not happen yet. A warning here told every rider on the
  // recommended setting that "something on this network could interfere";
  // it is an informational pass, and the page's next-step line tells them to
  // pick BikeControl in the app.
  if (osResponder) {
    return const NetworkCheck(
      id: NetworkCheckId.guidedWatch,
      verdict: NetworkVerdict.pass,
      detail: {'note': 'OS responder answers queries; only the TCP accept is visible', 'connected': 'false'},
    );
  }

  if (addressAsks >= 3) {
    return NetworkCheck(
      id: NetworkCheckId.guidedWatch,
      verdict: NetworkVerdict.fail,
      detail: {'addressAsks': '$addressAsks'},
      fixes: [if (ctx.backend == ObpMdnsBackend.platformDefault) NetworkFixId.useOsResponderForObc],
    );
  }

  if (!browsed) {
    // The trainer app never searched. Most often it is not allowed to use the
    // local network (Apple asks per app) or sits on another Wi-Fi — causes in
    // the trainer app, not here. A Mac running both apps can open the very
    // list where the trainer app is switched on; elsewhere the hint says
    // where to look, and Local stays as the way around it.
    return NetworkCheck(
      id: NetworkCheckId.guidedWatch,
      verdict: NetworkVerdict.fail,
      detail: const {'hint': 'no query arrived'},
      fixes: [
        if (ctx.platform == 'macos') NetworkFixId.openAppLocalNetworkSettings,
        NetworkFixId.switchToLocal,
      ],
    );
  }

  if (!resolved) {
    return const NetworkCheck(id: NetworkCheckId.guidedWatch, verdict: NetworkVerdict.warn);
  }

  return const NetworkCheck(
    id: NetworkCheckId.guidedWatch,
    verdict: NetworkVerdict.warn,
    detail: {'note': 'found and resolved, never connected'},
  );
}

/// True when [question] (e.g. `'A BikeControl.local'`) asks for an A/AAAA
/// record matching [hostname] (e.g. `'BikeControl.local'`), comparing with
/// the `.local` suffix stripped, case-insensitively.
bool _isAddressQuestion(String question, String? hostname) {
  if (hostname == null) return false;
  final String name;
  if (question.startsWith('A ')) {
    name = question.substring(2);
  } else if (question.startsWith('AAAA ')) {
    name = question.substring(5);
  } else {
    return false;
  }
  return _stripLocal(name) == _stripLocal(hostname);
}

String _stripLocal(String value) {
  final lower = value.trim().toLowerCase();
  const suffix = '.local';
  return lower.endsWith(suffix) ? lower.substring(0, lower.length - suffix.length) : lower;
}
