import 'package:bike_control/utils/window_size.dart';
import 'package:bike_control/widgets/ui/bk_tappable.dart';
import 'dart:io' show Platform;

import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../gen/l10n.dart';
import '../services/network_self_test/network_check.dart';
import '../services/network_self_test/network_probe_context.dart';
import 'network_test/network_tokens.dart';
import 'ui/small_progress_indicator.dart';

/// id → row title (exhaustive switch, l10n keys from Task 9).
String networkCheckTitle(BuildContext context, NetworkCheckId id) {
  final l10n = AppLocalizations.of(context);
  return switch (id) {
    NetworkCheckId.methodListening => l10n.networkCheckMethodListening,
    NetworkCheckId.advertisedAddress => l10n.networkCheckAdvertisedAddress,
    NetworkCheckId.vpn => l10n.networkCheckVpn,
    NetworkCheckId.advertisementVisible => l10n.networkCheckAdvertisementVisible,
    NetworkCheckId.localNetworkPermission => l10n.networkCheckLocalNetworkPermission,
    NetworkCheckId.backend => l10n.networkCheckBackend,
    NetworkCheckId.resolveOwnHostname => l10n.networkCheckResolveOwnHostname,
    NetworkCheckId.tcpSelfConnect => l10n.networkCheckTcpSelfConnect,
    NetworkCheckId.guidedWatch => l10n.networkCheckGuidedWatch,
    NetworkCheckId.bonjourService => l10n.networkCheckBonjourService,
    NetworkCheckId.bonjourNsp => l10n.networkCheckBonjourNsp,
    NetworkCheckId.windowsMdnsResolver => l10n.networkCheckWindowsMdnsResolver,
    NetworkCheckId.networkProfile => l10n.networkCheckNetworkProfile,
    NetworkCheckId.firewallRule => l10n.networkCheckFirewallRule,
    NetworkCheckId.multicastLock => l10n.networkCheckMulticastLock,
  };
}

/// fix → button label (exhaustive switch). On Windows,
/// [NetworkFixId.useOsResponderForObc] reads as "Register through Bonjour"
/// (`networkFixRegisterBonjour`) since the OS responder there IS Bonjour;
/// elsewhere it reads as the generic `networkFixUseOsResponder`.
String networkFixLabel(BuildContext context, NetworkFixId fix) {
  final l10n = AppLocalizations.of(context);
  return switch (fix) {
    NetworkFixId.restartMethod => l10n.networkFixRestartMethod,
    NetworkFixId.useOsResponderForObc =>
      !kIsWeb && Platform.isWindows ? l10n.networkFixRegisterBonjour : l10n.networkFixUseOsResponder,
    NetworkFixId.useResponderForObc => l10n.networkFixUseResponder,
    NetworkFixId.switchToLocal => l10n.networkFixSwitchToLocal,
    NetworkFixId.openFirewallSettings => l10n.networkFixOpenFirewallSettings,
    NetworkFixId.openBonjourDownload => l10n.networkFixOpenBonjourDownload,
    NetworkFixId.openLocalNetworkSettings => l10n.networkFixOpenLocalNetworkSettings,
    // Never actually shown as a per-row fix button — checks never carry this
    // fix (only the troubleshooting page's footer does) — kept only so this
    // switch stays exhaustive.
    NetworkFixId.sendToSupport => l10n.networkTroubleshootSendToSupport,
  };
}

/// Optional plain-language hint under a non-pass row. Only these three check
/// ids get one, and only when they actually failed — a warn/unknown on the
/// same id isn't specific enough to justify the extra sentence.
String? networkCheckHint(BuildContext context, NetworkCheck check) {
  if (check.verdict != NetworkVerdict.fail) return null;
  final l10n = AppLocalizations.of(context);
  return switch (check.id) {
    NetworkCheckId.bonjourService => l10n.networkHintBonjourService,
    NetworkCheckId.bonjourNsp => l10n.networkHintBonjourNsp,
    NetworkCheckId.resolveOwnHostname => l10n.networkHintResolveFail,
    _ => null,
  };
}

String _verdictWord(AppLocalizations l10n, NetworkVerdict verdict) {
  return switch (verdict) {
    NetworkVerdict.pass => l10n.networkVerdictPass,
    NetworkVerdict.warn => l10n.networkVerdictWarn,
    NetworkVerdict.fail => l10n.networkVerdictFail,
    NetworkVerdict.unknown => l10n.networkVerdictUnknown,
    NetworkVerdict.skipped => l10n.networkVerdictSkipped,
  };
}

/// The one-line summary under a check's name: what this check actually looked
/// at, in the rider's terms rather than the protocol's.
///
/// Falls back to the bare verdict word when a check has nothing more useful to
/// say than whether it passed.
String? networkCheckSummary(BuildContext context, NetworkCheck check) {
  final l10n = AppLocalizations.of(context);
  return switch (check.id) {
    NetworkCheckId.methodListening => l10n.networkSummaryMethodListening,
    NetworkCheckId.advertisedAddress => l10n.networkSummaryAdvertisedAddress,
    NetworkCheckId.vpn => l10n.networkSummaryVpn,
    NetworkCheckId.advertisementVisible => l10n.networkSummaryAdvertisementVisible,
    NetworkCheckId.localNetworkPermission => l10n.networkSummaryLocalNetworkPermission,
    NetworkCheckId.backend => l10n.networkSummaryBackend,
    NetworkCheckId.resolveOwnHostname => l10n.networkSummaryResolveOwnHostname,
    NetworkCheckId.tcpSelfConnect => l10n.networkSummaryTcpSelfConnect,
    NetworkCheckId.guidedWatch => l10n.networkSummaryGuidedWatch,
    NetworkCheckId.bonjourService => l10n.networkSummaryBonjourService,
    NetworkCheckId.bonjourNsp => l10n.networkSummaryBonjourNsp,
    NetworkCheckId.windowsMdnsResolver => l10n.networkSummaryWindowsMdnsResolver,
    NetworkCheckId.networkProfile => l10n.networkSummaryNetworkProfile,
    NetworkCheckId.firewallRule => l10n.networkSummaryFirewallRule,
    NetworkCheckId.multicastLock => l10n.networkSummaryMulticastLock,
  };
}

/// The single fact worth showing in the row's mono column.
///
/// Probes emit a bag of detail keys; this picks the one a rider (or the
/// support person reading a screenshot) would actually scan for, in order of
/// usefulness. Everything else stays in the expandable block.
String? networkCheckHeadlineValue(NetworkCheck check) {
  const preferred = [
    'address',
    'resolvedTo',
    'hostname',
    'backend',
    'state',
    'latencyMs',
    'port',
    'held',
    'category',
    'reason',
    'error',
  ];
  for (final key in preferred) {
    final value = check.detail[key];
    if (value == null || value.isEmpty) continue;
    return key == 'latencyMs' ? '$value ms' : value;
  }
  return null;
}

/// One row of the network self-test, in the design's three-column grid:
/// a tinted status mark, the check's name over a one-line summary, and its
/// measured value set in mono on the right.
///
/// Rows live inside a card and are separated by a hairline rather than each
/// being its own bordered box — colour marks the status, it does not ring the
/// row.
class NetworkCheckRow extends StatefulWidget {
  final NetworkCheck check;

  /// Shows a spinner instead of the verdict glyph while true.
  final bool running;

  /// Non-null renders the live guided-watch bullet list under the row.
  final WatchProgress? watch;

  final void Function(NetworkFixId fix)? onFix;
  final VoidCallback? onSkipWatch;

  /// Greys out individual fix buttons (e.g. the server-stopping fixes while a
  /// trainer app is connected) — the page passes the same predicate it uses
  /// for its header buttons, so row and header never disagree.
  final bool Function(NetworkFixId fix)? isFixDisabled;

  /// Draws the hairline under the row. False on the last row of a card.
  final bool showDivider;

  const NetworkCheckRow({
    super.key,
    required this.check,
    this.running = false,
    this.watch,
    this.onFix,
    this.onSkipWatch,
    this.isFixDisabled,
    this.showDivider = true,
  });

  @override
  State<NetworkCheckRow> createState() => _NetworkCheckRowState();
}

class _NetworkCheckRowState extends State<NetworkCheckRow> {
  bool _detailExpanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tokens = NetworkTokens.of(context);
    final check = widget.check;
    final expandable = check.detail.isNotEmpty;

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _mark(context, tokens),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  networkCheckTitle(context, check.id),
                  style: context.typography.small.copyWith(fontWeight: FontWeight.w600),
                ),
                Builder(
                  builder: (context) {
                    final summary = networkCheckSummary(context, check) ?? _verdictWord(l10n, check.verdict);
                    return Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(summary, style: context.typography.xSmall.copyWith(color: cs.mutedForeground)),
                    );
                  },
                ),
                if (check.fixes.isNotEmpty) ...[
                  const Gap(8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final fix in check.fixes.take(2))
                        Button.outline(
                          style: ButtonStyle.outline(size: ButtonSize.small),
                          onPressed: widget.onFix == null || (widget.isFixDisabled?.call(fix) ?? false)
                              ? null
                              : () => widget.onFix!(fix),
                          child: Text(networkFixLabel(context, fix)),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const Gap(14),
          _value(context, cs, expandable),
        ],
      ),
    );

    final watch = widget.watch;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (expandable)
          // A disclosure: focusable, and it tells a screen reader whether
          // the detail block under it is open.
          BkTappable(
            onPressed: () => setState(() => _detailExpanded = !_detailExpanded),
            expanded: _detailExpanded,
            child: row,
          )
        else
          row,
        if (expandable && _detailExpanded) _detailBlock(context, cs, tokens, check),
        if (watch != null) _watchSection(context, l10n, watch),
        if (widget.showDivider) Container(height: 1, color: tokens.hairline),
      ],
    );
  }

  /// The design's 22px tinted disc. A spinner replaces it while the check runs.
  Widget _mark(BuildContext context, NetworkTokens tokens) {
    if (widget.running) {
      return const SizedBox(
        width: 22,
        height: 22,
        child: Center(child: RepaintBoundary(child: SmallProgressIndicator())),
      );
    }
    final cs = Theme.of(context).colorScheme;
    final (icon, fg, bg) = switch (widget.check.verdict) {
      NetworkVerdict.pass => (LucideIcons.check, tokens.ok, tokens.okBg),
      NetworkVerdict.warn => (LucideIcons.circleAlert, tokens.warn, tokens.warnBg),
      NetworkVerdict.fail => (LucideIcons.x, tokens.danger, tokens.dangerBg),
      NetworkVerdict.unknown => (LucideIcons.minus, cs.mutedForeground, cs.muted),
      NetworkVerdict.skipped => (LucideIcons.minus, cs.mutedForeground, cs.muted),
    };
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, size: 13, color: fg),
    );
  }

  /// The mono right-hand column: the one measured fact this check produced,
  /// plus the disclosure chevron when there is more underneath.
  Widget _value(BuildContext context, ColorScheme cs, bool expandable) {
    // The design's value column assumes a desktop window. On a phone it takes
    // width the check's own name needs, and both end up wrapping mid-word — so
    // below the breakpoint the fact stays in the expandable block, where it
    // already lives, and only the chevron remains.
    final headline = MediaQuery.sizeOf(context).width < Breakpoints.networkValueColumn
        ? null
        : networkCheckHeadlineValue(widget.check);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (headline != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              headline,
              textAlign: TextAlign.right,
              style: Theme.of(
                context,
              ).typography.mono.copyWith(fontSize: context.typography.caption.fontSize, color: cs.mutedForeground),
            ),
          ),
        if (expandable) ...[
          const Gap(10),
          Icon(
            _detailExpanded ? LucideIcons.chevronDown : LucideIcons.chevronRight,
            size: 13,
            color: cs.mutedForeground,
          ),
        ],
      ],
    );
  }

  /// The design's `<pre>` block: every fact the check gathered, aligned in
  /// mono on a recessed panel, indented to clear the status mark.
  Widget _detailBlock(BuildContext context, ColorScheme cs, NetworkTokens tokens, NetworkCheck check) {
    final entries = check.detail.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final width = entries.map((e) => e.key.length).fold(0, (a, b) => a > b ? a : b);
    final hint = networkCheckHint(context, check);
    return Padding(
      padding: const EdgeInsets.fromLTRB(54, 0, 18, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hint != null) ...[
            Text(hint, style: context.typography.xSmall.copyWith(color: cs.mutedForeground)),
            const Gap(8),
          ],
          Container(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 13),
            decoration: BoxDecoration(
              color: tokens.pageBg,
              border: Border.all(color: tokens.hairline),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              [for (final e in entries) '${e.key.padRight(width)}  ${e.value}'].join('\n'),
              style: Theme.of(context).typography.mono.copyWith(
                fontSize: context.typography.caption.fontSize,
                height: 1.75,
                color: cs.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _watchSection(BuildContext context, AppLocalizations l10n, WatchProgress watch) {
    final app = widget.check.detail['app'] ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        Text(l10n.networkWatchPrompt(app)).xSmall.textMuted,
        _watchBullet(context, l10n.networkWatchFoundUs(app), watch.browsed),
        _watchBullet(context, l10n.networkWatchResolved, watch.resolved),
        _watchBullet(context, l10n.networkWatchAddressAsks(watch.addressAsks), watch.addressAsks > 0),
        _watchBullet(context, l10n.networkWatchConnected, watch.connected),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.networkWatchRemaining(watch.remaining.inSeconds)).xSmall.textMuted,
            Button.ghost(
              style: ButtonStyle.ghost(size: ButtonSize.small),
              onPressed: widget.onSkipWatch,
              child: Text(l10n.networkWatchSkip),
            ),
          ],
        ),
      ],
    );
  }

  Widget _watchBullet(BuildContext context, String text, bool active) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      '• $text',
      style: context.typography.xSmall.copyWith(color: active ? cs.foreground : cs.mutedForeground),
    );
  }
}
