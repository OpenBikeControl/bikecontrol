import 'dart:async';
import 'dart:io';

import 'package:dartx/dartx.dart';

import '../network_check.dart';
import '../network_probe_context.dart';

/// The four Windows-only OS-level checks (spec checks 10-13, §12-adjusted):
/// shell out to `sc`, `netsh`, `reg` and `powershell` through
/// [NetworkProbeContext.runProcess] and interpret their output. Every check
/// here skips outright off-Windows; a process that cannot be started
/// ([ProcessException]) or hangs past the context's cap ([TimeoutException])
/// is `unknown` with the error captured. Those are the only two expected
/// failure shapes — anything else is a bug in the probe and deliberately
/// propagates to the engine wrapper, which recordErrors it under the
/// check's id instead of filing it away as `unknown` with no trace. stdout
/// is capped to 4 KB before it is parsed or stored in a check's detail map
/// — except where a rule below specifically interprets a non-zero exit code,
/// or searches the uncapped output because the marker it looks for legitimately
/// sits past the cap (both documented per check).
const _stdoutCap = 4096;

String _capStdout(Object? stdout) {
  final text = stdout?.toString() ?? '';
  return text.length > _stdoutCap ? text.substring(0, _stdoutCap) : text;
}

/// Check 10: is Apple's "Bonjour Service" installed and running? MyWhoosh
/// only checks this once, at its own startup — a service started after
/// MyWhoosh launched still shows as broken there until MyWhoosh restarts.
Future<NetworkCheck> bonjourServiceCheck(NetworkProbeContext ctx) async {
  if (ctx.platform != 'windows') {
    return const NetworkCheck(id: NetworkCheckId.bonjourService, verdict: NetworkVerdict.skipped);
  }

  final ProcessResult result;
  try {
    result = await ctx.runProcess('sc', ['query', 'Bonjour Service']);
  } on ProcessException catch (e) {
    return NetworkCheck(id: NetworkCheckId.bonjourService, verdict: NetworkVerdict.unknown, detail: {'error': '$e'});
  } on TimeoutException catch (e) {
    return NetworkCheck(id: NetworkCheckId.bonjourService, verdict: NetworkVerdict.unknown, detail: {'error': '$e'});
  }
  final exitCode = result.exitCode;
  final stdout = _capStdout(result.stdout);

  if (stdout.contains('RUNNING')) {
    if (await _myWhooshStartedBeforeBonjour(ctx)) {
      return const NetworkCheck(
        id: NetworkCheckId.bonjourService,
        verdict: NetworkVerdict.fail,
        detail: {'state': 'started after MyWhoosh'},
      );
    }
    return const NetworkCheck(id: NetworkCheckId.bonjourService, verdict: NetworkVerdict.pass);
  }
  if (stdout.contains('1060') || exitCode != 0) {
    return const NetworkCheck(
      id: NetworkCheckId.bonjourService,
      verdict: NetworkVerdict.fail,
      detail: {'state': 'missing'},
      fixes: [NetworkFixId.reinstallBonjour, NetworkFixId.switchToLocal],
    );
  }
  return const NetworkCheck(
    id: NetworkCheckId.bonjourService,
    verdict: NetworkVerdict.fail,
    detail: {'state': 'stopped', 'note': 'start it, then restart the trainer app — MyWhoosh checks once at startup'},
    fixes: [NetworkFixId.reinstallBonjour],
  );
}

/// Whether a running MyWhoosh was started before Bonjour's daemon was.
///
/// MyWhoosh asks once, when it creates its discovery managers, whether the
/// Bonjour Service runs, and never again. Measured on 6.2.3: with Bonjour
/// started after MyWhoosh, MyWhoosh put not one browse on the wire and the
/// BikeControl button stayed dead until MyWhoosh was restarted — although the
/// service then reads as running. Riders get here by installing or repairing
/// Bonjour with MyWhoosh still open.
///
/// Process creation times come from CIM, which (unlike `Get-Process`) reads a
/// SYSTEM process's start time without elevation. Anything unreadable — no
/// MyWhoosh running, a failed or slow query — is "no", so this can only add a
/// finding, never hide the pass.
Future<bool> _myWhooshStartedBeforeBonjour(NetworkProbeContext ctx) async {
  const script =
      "Get-CimInstance Win32_Process -Filter \"Name='mDNSResponder.exe' or Name='MyWhoosh.exe'\" | "
      "ForEach-Object { Write-Output (\$_.Name + '=' + \$_.CreationDate.ToUniversalTime().ToString('o')) }";
  final ProcessResult result;
  try {
    result = await ctx.runProcess('powershell', ['-NoProfile', '-NonInteractive', '-Command', script]);
  } on ProcessException {
    return false;
  } on TimeoutException {
    return false;
  }
  final starts = <String, DateTime>{};
  for (final line in _capStdout(result.stdout).split('\n')) {
    final split = line.indexOf('=');
    if (split <= 0) continue;
    final time = DateTime.tryParse(line.substring(split + 1).trim());
    if (time == null) continue;
    final name = line.substring(0, split).trim().toLowerCase();
    // Several MyWhoosh processes: the earliest is the one that made the check.
    final known = starts[name];
    if (known == null || time.isBefore(known)) starts[name] = time;
  }
  final myWhoosh = starts['mywhoosh.exe'];
  final bonjour = starts['mdnsresponder.exe'];
  return myWhoosh != null && bonjour != null && myWhoosh.isBefore(bonjour);
}

/// Check 11 (NEW, §12): does the Winsock catalog list Bonjour's `mdnsNSP`
/// name-service provider? Without it `getaddrinfo("<host>.local")` — the
/// exact call MyWhoosh makes — has no way to reach Bonjour's cache, so the
/// "Register through Bonjour" button cannot work regardless of what
/// [bonjourServiceCheck] says.
Future<NetworkCheck> bonjourNspCheck(NetworkProbeContext ctx) async {
  if (ctx.platform != 'windows') {
    return const NetworkCheck(id: NetworkCheckId.bonjourNsp, verdict: NetworkVerdict.skipped);
  }

  final ProcessResult result;
  try {
    result = await ctx.runProcess('netsh', ['winsock', 'show', 'catalog']);
  } on ProcessException catch (e) {
    return NetworkCheck(id: NetworkCheckId.bonjourNsp, verdict: NetworkVerdict.unknown, detail: {'error': '$e'});
  } on TimeoutException catch (e) {
    return NetworkCheck(id: NetworkCheckId.bonjourNsp, verdict: NetworkVerdict.unknown, detail: {'error': '$e'});
  }
  if (result.exitCode != 0) {
    return NetworkCheck(
      id: NetworkCheckId.bonjourNsp,
      verdict: NetworkVerdict.unknown,
      detail: {'error': 'exit ${result.exitCode}'},
    );
  }

  // Searched over the FULL output, not [_capStdout]: the Winsock catalog runs
  // ~25 KB and lists namespace providers after every protocol entry, so
  // mdnsNSP sits past 22 KB on a stock machine. Capping first made this check
  // answer "missing" on every machine, including ones with a healthy Bonjour
  // — inverting the one verdict that decides whether MyWhoosh can work at all.
  final catalog = result.stdout?.toString() ?? '';
  if (catalog.toLowerCase().contains('mdnsnsp')) {
    return const NetworkCheck(id: NetworkCheckId.bonjourNsp, verdict: NetworkVerdict.pass);
  }
  return const NetworkCheck(
    id: NetworkCheckId.bonjourNsp,
    verdict: NetworkVerdict.fail,
    detail: {'note': 'Bonjour resolver hook missing — the MyWhoosh button cannot work without it'},
    fixes: [NetworkFixId.reinstallBonjour, NetworkFixId.switchToLocal],
  );
}

/// Check 12 (§12: demoted to advisory-only): Windows' own Dnscache mDNS
/// resolver. Field-verified to fail on a machine where everything else
/// works — MyWhoosh's resolution path goes through Bonjour, not Dnscache —
/// so this never carries a fix, it's purely informational.
Future<NetworkCheck> windowsMdnsResolverCheck(NetworkProbeContext ctx) async {
  if (ctx.platform != 'windows') {
    return const NetworkCheck(id: NetworkCheckId.windowsMdnsResolver, verdict: NetworkVerdict.skipped);
  }

  final ProcessResult result;
  try {
    result = await ctx.runProcess('reg', [
      'query',
      r'HKLM\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters',
      '/v',
      'EnableMDNS',
    ]);
  } on ProcessException catch (e) {
    return NetworkCheck(id: NetworkCheckId.windowsMdnsResolver, verdict: NetworkVerdict.unknown, detail: {'error': '$e'});
  } on TimeoutException catch (e) {
    return NetworkCheck(id: NetworkCheckId.windowsMdnsResolver, verdict: NetworkVerdict.unknown, detail: {'error': '$e'});
  }
  if (result.exitCode != 0) {
    // reg query fails when the value doesn't exist at all — that's the
    // default state, not a problem.
    return const NetworkCheck(
      id: NetworkCheckId.windowsMdnsResolver,
      verdict: NetworkVerdict.pass,
      detail: {'EnableMDNS': 'absent (default)'},
    );
  }

  final stdout = _capStdout(result.stdout);
  if (stdout.contains('0x1')) {
    return const NetworkCheck(id: NetworkCheckId.windowsMdnsResolver, verdict: NetworkVerdict.pass);
  }
  if (stdout.contains('0x0')) {
    return const NetworkCheck(
      id: NetworkCheckId.windowsMdnsResolver,
      verdict: NetworkVerdict.warn,
      detail: {
        'note': 'Windows mDNS resolution is off; not needed for MyWhoosh (Bonjour handles it), may affect other apps',
      },
    );
  }
  return NetworkCheck(
    id: NetworkCheckId.windowsMdnsResolver,
    verdict: NetworkVerdict.unknown,
    detail: {'error': stdout},
  );
}

/// Checks 12+13 combined: the advertised interface's network category
/// (Private/Public/Domain) and any inbound firewall rule for BikeControl.
/// Both come out of a single PowerShell invocation (starting `powershell.exe`
/// is the slow part of this whole probe set, so it's only paid once).
Future<({NetworkCheck profile, NetworkCheck firewall})> windowsNetworkProfileAndFirewallChecks(
  NetworkProbeContext ctx,
) async {
  if (ctx.platform != 'windows') {
    return (
      profile: const NetworkCheck(id: NetworkCheckId.networkProfile, verdict: NetworkVerdict.skipped),
      firewall: const NetworkCheck(id: NetworkCheckId.firewallRule, verdict: NetworkVerdict.skipped),
    );
  }

  // `#FWSTATE` asks whether the firewall is even switched on per profile: a
  // missing inbound rule blocks nothing on a machine whose firewall is off,
  // and warning about it there (with a button into Defender settings) is noise
  // about a non-problem. The rule query stays last because it is the one whose
  // pipeline legitimately yields nothing.
  //
  // Both firewall sections read the firewall's COM API (HNetCfg.FwPolicy2),
  // not the NetSecurity cmdlets. Without elevation
  // `Get-NetFirewallApplicationFilter` fails with "access denied", which
  // `-ErrorAction SilentlyContinue` turned into "no rule" on every normal run;
  // and `Get-NetFirewallProfile` alone takes seconds on a cold CIM provider,
  // enough to time the whole probe out on slower machines. The COM API needs
  // no elevation, answers in well under a second and, unlike `netsh`, is not
  // localized. Rules print as `Enabled=Action=ProfileMask`.
  const script = '''
Write-Output '#PROFILE'; Get-NetConnectionProfile | ForEach-Object { Write-Output (\$_.InterfaceAlias + '=' + \$_.NetworkCategory) };
\$fw = New-Object -ComObject HNetCfg.FwPolicy2;
Write-Output '#FWSTATE'; Write-Output ('Domain=' + \$fw.FirewallEnabled(1)); Write-Output ('Private=' + \$fw.FirewallEnabled(2)); Write-Output ('Public=' + \$fw.FirewallEnabled(4));
Write-Output '#FIREWALL'; \$fw.Rules | Where-Object { \$_.Direction -eq 1 -and (\$_.ApplicationName -like '*bike_control*' -or \$_.ApplicationName -like '*BikeControl*') } | ForEach-Object { Write-Output (\$_.Enabled.ToString() + '=' + \$(if (\$_.Action -eq 1) { 'Allow' } else { 'Block' }) + '=' + \$_.Profiles) }
''';

  final ProcessResult result;
  try {
    result = await ctx.runProcess('powershell', ['-NoProfile', '-NonInteractive', '-Command', script]);
  } on ProcessException catch (e) {
    return _bothUnknown('$e');
  } on TimeoutException catch (e) {
    return _bothUnknown('$e');
  }
  // Deliberately NOT gated on the exit code. `powershell.exe -Command` exits 1
  // when the last pipeline yields nothing, and "no BikeControl firewall rule"
  // is exactly that — `Get-NetFirewallApplicationFilter` matches nothing, the
  // `-ErrorAction SilentlyContinue` hides the output but not the failure
  // state, and stderr stays empty. Bailing there threw away a complete and
  // correct `#PROFILE` section and reported both checks as "could not check".
  // The markers below say whether the script actually ran; the exit code does
  // not.
  final stdout = _capStdout(result.stdout);
  final profileLines = <String>[];
  final fwStateLines = <String>[];
  final firewallLines = <String>[];
  var sawFirewallMarker = false;
  var section = 0; // 0 = before any marker, 1 = #PROFILE, 2 = #FWSTATE, 3 = #FIREWALL
  for (final rawLine in stdout.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    if (line == '#PROFILE') {
      section = 1;
      continue;
    }
    if (line == '#FWSTATE') {
      section = 2;
      continue;
    }
    if (line == '#FIREWALL') {
      section = 3;
      sawFirewallMarker = true;
      continue;
    }
    if (section == 1) profileLines.add(line);
    if (section == 2) fwStateLines.add(line);
    if (section == 3) firewallLines.add(line);
  }

  // No marker at all means the script never ran (bad execution policy, missing
  // powershell) rather than "nothing to report" — that is the real unknown.
  if (section == 0) {
    return _bothUnknown('exit ${result.exitCode}');
  }

  final profile = _parseProfile(ctx, profileLines);
  return (
    profile: profile,
    firewall: sawFirewallMarker
        ? _parseFirewall(
            firewallLines,
            enabled: _firewallEnabledFor(profile.detail['category'], fwStateLines),
            category: profile.detail['category'],
          )
        : NetworkCheck(
            id: NetworkCheckId.firewallRule,
            verdict: NetworkVerdict.unknown,
            detail: {'error': 'exit ${result.exitCode}'},
          ),
  );
}

/// Whether the firewall is switched on for the profile that governs the
/// advertised interface — `Domain` / `Private` / `Public` lines of
/// `Name=True|False`.
///
/// Falls back to "any profile on" when the category is unknown, and to true
/// when the section is missing entirely: assuming the firewall is on is the
/// safe direction, since it keeps the advisory rather than silencing it.
bool _firewallEnabledFor(String? category, List<String> lines) {
  final states = <String, bool>{};
  for (final line in lines) {
    final split = line.indexOf('=');
    if (split <= 0) continue;
    states[line.substring(0, split)] = line.substring(split + 1).toLowerCase() == 'true';
  }
  if (states.isEmpty) return true;
  if (category != null && states.containsKey(category)) return states[category]!;
  return states.values.any((on) => on);
}

({NetworkCheck profile, NetworkCheck firewall}) _bothUnknown(String error) {
  final detail = {'error': error};
  return (
    profile: NetworkCheck(id: NetworkCheckId.networkProfile, verdict: NetworkVerdict.unknown, detail: detail),
    firewall: NetworkCheck(id: NetworkCheckId.firewallRule, verdict: NetworkVerdict.unknown, detail: detail),
  );
}

NetworkCheck _parseProfile(NetworkProbeContext ctx, List<String> lines) {
  final categories = <String, String>{};
  for (final line in lines) {
    final split = line.indexOf('=');
    if (split <= 0) continue;
    categories[line.substring(0, split)] = line.substring(split + 1);
  }

  String? alias;
  final chosen = ctx.snapshot?.addressReport.chosen;
  if (chosen != null) {
    alias = ctx.snapshot?.addressReport.candidates
        .firstOrNullWhere((candidate) => candidate.address == chosen.address)
        ?.interfaceName;
  }

  final String category;
  // The connection the verdict is about, so the fix can open its own
  // settings page (where the Public/Private switch lives).
  final String connection;
  if (alias != null && categories.containsKey(alias)) {
    category = categories[alias]!;
    connection = alias;
  } else if (categories.values.contains('Public')) {
    // Alias not found (or not advertising yet) — fail safe to the worst
    // category actually present rather than guessing.
    category = 'Public';
    connection = categories.entries.firstWhere((e) => e.value == 'Public').key;
  } else if (categories.isNotEmpty) {
    category = categories.values.first;
    connection = categories.keys.first;
  } else {
    return const NetworkCheck(
      id: NetworkCheckId.networkProfile,
      verdict: NetworkVerdict.unknown,
      detail: {'error': 'no network profile reported'},
    );
  }

  final detail = {'category': category, 'interface': connection};
  if (category == 'Public') {
    // Public is a property of the connection, switched in Windows' network
    // settings — the firewall page this used to open cannot change it.
    return NetworkCheck(
      id: NetworkCheckId.networkProfile,
      verdict: NetworkVerdict.warn,
      detail: detail,
      fixes: const [NetworkFixId.openNetworkProfileSettings],
    );
  }
  return NetworkCheck(id: NetworkCheckId.networkProfile, verdict: NetworkVerdict.pass, detail: detail);
}

/// The firewall API's profile bit for a network category.
const _profileBits = {'Domain': 1, 'Private': 2, 'Public': 4};

/// Whether a rule line (`Enabled=Action[=ProfileMask]`) allows inbound traffic
/// on [category]. A missing mask (older script output) or an unknown category
/// counts as covering it.
bool _allowsOn(String line, String? category) {
  final parts = line.split('=');
  if (parts.length < 2 || parts[0] != 'True' || parts[1] != 'Allow') return false;
  final bit = _profileBits[category];
  final mask = parts.length > 2 ? int.tryParse(parts[2]) : null;
  if (bit == null || mask == null) return true;
  return mask & bit != 0;
}

NetworkCheck _parseFirewall(List<String> lines, {required bool enabled, String? category}) {
  // Nothing to allow past a firewall that is switched off. Reporting "no rule
  // found" there is a warning about a non-problem, and it comes with a button
  // into Defender settings that has nothing to do.
  if (!enabled) {
    return const NetworkCheck(
      id: NetworkCheckId.firewallRule,
      verdict: NetworkVerdict.pass,
      detail: {'note': 'firewall is off for this network'},
    );
  }
  if (lines.isEmpty) {
    return const NetworkCheck(
      id: NetworkCheckId.firewallRule,
      verdict: NetworkVerdict.warn,
      detail: {'rules': 'none found'},
      fixes: [NetworkFixId.openFirewallSettings],
    );
  }
  if (lines.any((line) => _allowsOn(line, category))) {
    return const NetworkCheck(id: NetworkCheckId.firewallRule, verdict: NetworkVerdict.pass);
  }
  // Rules exist, but none allows inbound on this network — typically allowed
  // for Private only while the connection is Public.
  return NetworkCheck(
    id: NetworkCheckId.firewallRule,
    verdict: NetworkVerdict.warn,
    detail: {'rules': 'none allow ${category ?? 'this network'}'},
    fixes: const [NetworkFixId.openFirewallSettings],
  );
}
