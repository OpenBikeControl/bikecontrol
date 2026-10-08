enum NetworkVerdict { pass, warn, fail, unknown, skipped }

enum NetworkCheckId {
  methodListening,
  advertisedAddress,
  vpn,
  advertisementVisible,
  localNetworkPermission,
  backend,
  resolveOwnHostname,
  tcpSelfConnect,
  guidedWatch,
  bonjourService,
  bonjourNsp,
  windowsMdnsResolver,
  networkProfile,
  firewallRule,
  multicastLock,
}

enum NetworkFixId {
  restartMethod,
  useOsResponderForObc,
  useResponderForObc,
  switchToLocal,
  openFirewallSettings,
  openNetworkProfileSettings,
  openBonjourDownload,
  openLocalNetworkSettings,
  openAppLocalNetworkSettings,
  sendToSupport,
}

class NetworkCheck {
  final NetworkCheckId id;
  final NetworkVerdict verdict;

  /// Structured facts for the expandable detail (keys are stable English
  /// identifiers like 'address', 'latencyMs', 'error'; values raw strings).
  final Map<String, String> detail;
  final List<NetworkFixId> fixes;

  const NetworkCheck({required this.id, required this.verdict, this.detail = const {}, this.fixes = const []});
}

/// Numeric severity used to fold a set of checks into a single verdict.
/// Higher is worse. `skipped` is not used here since callers filter it out.
int _severity(NetworkVerdict verdict) {
  switch (verdict) {
    case NetworkVerdict.pass:
      return 0;
    case NetworkVerdict.warn:
      return 1;
    case NetworkVerdict.unknown:
      return 2;
    case NetworkVerdict.fail:
      return 3;
    case NetworkVerdict.skipped:
      return -1;
  }
}

/// Severity order for the overall verdict: fail > unknown > warn > pass.
/// skipped rows are ignored entirely. Empty or all-skipped input yields pass.
NetworkVerdict overallVerdict(Iterable<NetworkCheck> checks) {
  var worst = NetworkVerdict.pass;
  for (final check in checks) {
    if (check.verdict == NetworkVerdict.skipped) {
      continue;
    }
    if (_severity(check.verdict) > _severity(worst)) {
      worst = check.verdict;
    }
  }
  return worst;
}
