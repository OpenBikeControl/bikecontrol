/// One-tap fix dispatcher for the network self-test rows (Task 11) and the
/// troubleshooting page (Task 12).
///
/// Unlike the rest of `network_self_test/` this file is deliberately not a
/// pure data/model layer: it is the action layer, so it imports `core`,
/// Flutter widgets, and plugin APIs directly.
library;

import 'dart:io';

import 'package:bike_control/bluetooth/devices/openbikecontrol/obp_mdns_backend.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/services/local_network_access.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/ui/connection_method.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:flutter/foundation.dart';
import 'package:local_network_permission/local_network_permission.dart';
import 'package:prop/prop.dart' show LogLevel;
import 'package:prop/utils/shared.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' show BuildContext;
import 'package:url_launcher/url_launcher_string.dart';

import 'network_check.dart';
import 'network_method_target.dart';

/// Executes one fix. Returns true when the action completed (not necessarily
/// that it helped). Failures toast + recordError and return false; a refusal
/// (restart / backend switch while the trainer app is connected) toasts the
/// reason and returns false without recordError — nothing went wrong.
///
/// [from] is the check the fix was offered on, when the caller knows it — the
/// network-profile fix reads which connection to open from its detail.
Future<bool> runNetworkFix(BuildContext context, NetworkFixId fix, {NetworkCheck? from}) async {
  switch (fix) {
    case NetworkFixId.restartMethod:
      // The method the selected trainer app rides on — OpenBikeControl for
      // MyWhoosh, the Click server for Rouvy, DirCon for Zwift — not always
      // OpenBikeControl.
      final target = currentNetworkMethodTarget();
      // The page greys this button out while connected, so reaching here
      // with a live connection is defensive — but say why rather than
      // appearing to do nothing.
      if (target.isConnected.value) {
        _toastRefusedWhileConnected();
        return false;
      }
      try {
        await target.restart();
        return true;
      } catch (e, s) {
        recordError(e, s, context: 'runNetworkFix.restartMethod.${target.kind.name}');
        buildToast(level: LogLevel.LOGLEVEL_ERROR, title: target.restartFailedMessage);
        return false;
      }

    case NetworkFixId.useOsResponderForObc:
      return switchObpBackend(ObpMdnsBackend.osResponder);

    case NetworkFixId.useResponderForObc:
      return switchObpBackend(ObpMdnsBackend.platformDefault);

    case NetworkFixId.switchToLocal:
      try {
        // A false here is the rider declining a permission sheet, not a
        // failure — no toast for that.
        return await enableLocalControl(context);
      } catch (e, s) {
        recordError(e, s, context: 'runNetworkFix.switchToLocal');
        _toastFailed();
        return false;
      }

    case NetworkFixId.openFirewallSettings:
      return _launch('ms-settings:windowsdefender', context: 'runNetworkFix.openFirewallSettings');

    case NetworkFixId.openNetworkProfileSettings:
      return _launch(
        networkProfileSettingsUri(from?.detail['interface']),
        context: 'runNetworkFix.openNetworkProfileSettings',
      );

    case NetworkFixId.reinstallBonjour:
      return reinstallBonjourWithWinget(
        run: (executable, arguments) => Process.run(executable, arguments),
        openGuide: (url) => _launch(url, context: 'runNetworkFix.reinstallBonjour'),
      );

    case NetworkFixId.openLocalNetworkSettings:
      try {
        await LocalNetworkPermission.openSettings();
        LocalNetworkAccess.invalidate();
        return true;
      } catch (e, s) {
        recordError(e, s, context: 'runNetworkFix.openLocalNetworkSettings');
        _toastFailed();
        return false;
      }

    case NetworkFixId.openAppLocalNetworkSettings:
      // System Settings › Privacy & Security › Local Network: the per-app list
      // the trainer app has to be switched on in. Same URL scheme as the
      // Bluetooth privacy pane the requirements screen opens.
      return _launch(
        'x-apple.systempreferences:com.apple.preference.security?Privacy_LocalNetwork',
        context: 'runNetworkFix.openAppLocalNetworkSettings',
      );

    case NetworkFixId.sendToSupport:
      // Owned by the page (it needs to push SupportChatPage) — a caller
      // that dispatches this here instead of routing it itself is a wiring
      // bug, so this only returns false and never runs in release builds.
      assert(false, 'sendToSupport must be handled by the page, not runNetworkFix');
      return false;
  }
}

/// Manual Bonjour install guide, the fallback when winget cannot do it.
const bonjourInstallGuideUrl = 'https://octoclip.app/learn/how-to-install-bonjour-on-windows/';

bool _bonjourReinstallRunning = false;

/// Reinstalls Apple Bonjour through winget. `--force` because a plain
/// `winget install` reports "already installed" and leaves a broken install
/// (service running, mdnsNSP missing) untouched — the case this is offered
/// for. Field-confirmed 2026-11-01: a rider whose reinstall with Apple's
/// download did not bring back the MyWhoosh button was fixed by
/// `winget install --id=Apple.Bonjour -e`.
///
/// The Bonjour installer raises its own admin prompt. No winget (older
/// Windows 10 without App Installer), a declined prompt or a failed install
/// fall back to [bonjourInstallGuideUrl] and return false: nothing changed
/// yet, so the page must not re-run. A second tap while one runs is ignored.
@visibleForTesting
Future<bool> reinstallBonjourWithWinget({
  required Future<ProcessResult> Function(String executable, List<String> arguments) run,
  required Future<bool> Function(String url) openGuide,
}) async {
  if (_bonjourReinstallRunning) return false;
  _bonjourReinstallRunning = true;
  try {
    buildToast(
      title: AppLocalizations.current.networkFixReinstallBonjourRunning,
      duration: const Duration(seconds: 10),
    );
    final ProcessResult result;
    try {
      result = await run('winget', [
        'install',
        '--id=Apple.Bonjour',
        '-e',
        '--force',
        '--accept-package-agreements',
        '--accept-source-agreements',
      ]);
    } on ProcessException catch (e) {
      // Expected on machines without winget — not an error worth reporting.
      Logger.info('reinstallBonjour: winget not available: $e');
      return await _openBonjourGuide(openGuide);
    }
    if (result.exitCode != 0) {
      final out = '${result.stdout}'.trim();
      Logger.warn(
        'reinstallBonjour: winget exited ${result.exitCode}: '
        '${out.length > 500 ? out.substring(out.length - 500) : out}',
      );
      return await _openBonjourGuide(openGuide);
    }
    buildToast(title: AppLocalizations.current.networkFixReinstallBonjourDone, duration: const Duration(seconds: 10));
    return true;
  } finally {
    _bonjourReinstallRunning = false;
  }
}

Future<bool> _openBonjourGuide(Future<bool> Function(String url) openGuide) async {
  buildToast(level: LogLevel.LOGLEVEL_WARNING, title: AppLocalizations.current.networkFixReinstallBonjourFallback);
  await openGuide(bonjourInstallGuideUrl);
  return false;
}

/// The Windows settings page holding the Public/Private switch for the
/// connection called [interfaceAlias] (`Get-NetConnectionProfile`'s
/// InterfaceAlias). Windows names its adapters "Wi-Fi"/"WLAN" and "Ethernet"
/// (numbered when there are several) in every language; anything else, or no
/// name at all, gets the network status page, which links to the active
/// connection's properties.
String networkProfileSettingsUri(String? interfaceAlias) {
  final alias = interfaceAlias?.trim().toLowerCase() ?? '';
  if (RegExp(r'^(wi-?fi|wlan|wireless)').hasMatch(alias)) return 'ms-settings:network-wifi';
  if (RegExp(r'^ethernet').hasMatch(alias)) return 'ms-settings:network-ethernet';
  return 'ms-settings:network-status';
}

/// Opens [url] externally; a launcher that throws OR reports it could not
/// open the URL is a failed arm either way (toast + false).
Future<bool> _launch(String url, {required String context}) async {
  try {
    final ok = await launchUrlString(url, mode: LaunchMode.externalApplication);
    if (!ok) _toastFailed();
    return ok;
  } catch (e, s) {
    recordError(e, s, context: context);
    _toastFailed();
    return false;
  }
}

void _toastFailed() {
  buildToast(level: LogLevel.LOGLEVEL_ERROR, title: AppLocalizations.current.networkFixFailed);
}

void _toastRefusedWhileConnected() {
  final app = core.settings.getTrainerApp()?.name;
  buildToast(
    level: LogLevel.LOGLEVEL_WARNING,
    title: app == null
        ? AppLocalizations.current.networkFixRefusedConnectedNoApp
        : AppLocalizations.current.networkFixRefusedConnected(app),
  );
}

/// Testable core of the backend switch (no BuildContext): set pref →
/// stopServer → startServer → verify the registration actually landed on
/// [target]. Any other outcome restores the previous pref, restarts on it
/// (best effort), toasts, and returns false:
///
/// * `startServer()` threw — recordError + the generic failure toast.
/// * it came up, but `activeBackend != target` — the Windows-without-Bonjour
///   degrade in `resolveAdvertiser` (the only path that resolves to a
///   different backend than requested). Before this was checked, "Register
///   through Bonjour" on such a machine silently succeeded: the pref stayed
///   at osResponder, the page re-ran with the identical result, and row 6
///   (keyed on activeBackend) offered no way back. It is the recommended
///   fix there, so it says exactly what is missing.
///
/// Refuses outright while the trainer app is connected: stopServer() would
/// drop a connection that works.
@visibleForTesting
Future<bool> switchObpBackend(ObpMdnsBackend target) async {
  final emulator = core.obpMdnsEmulator;
  if (emulator.isConnected.value) {
    _toastRefusedWhileConnected();
    return false;
  }
  final previous = core.settings.getObpMdnsBackend();
  await core.settings.setObpMdnsBackend(target);
  await emulator.stopServer();
  try {
    await emulator.startServer();
  } catch (e, s) {
    recordError(e, s, context: 'switchObpBackend');
    _toastFailed();
    await _restoreObpBackend(previous);
    return false;
  }
  if (emulator.activeBackend != target) {
    buildToast(level: LogLevel.LOGLEVEL_ERROR, title: AppLocalizations.current.networkFixBonjourMissing);
    await _restoreObpBackend(previous);
    return false;
  }
  return true;
}

Future<void> _restoreObpBackend(ObpMdnsBackend previous) async {
  await core.settings.setObpMdnsBackend(previous);
  try {
    // stopServer() is idempotent; it also clears a TCP server left bound by
    // a start that failed after binding, so the restart does not walk ports.
    await core.obpMdnsEmulator.stopServer();
    await core.obpMdnsEmulator.startServer();
  } catch (e, s) {
    recordError(e, s, context: 'switchObpBackend.restore');
  }
}
