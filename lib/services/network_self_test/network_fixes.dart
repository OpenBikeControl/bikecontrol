/// One-tap fix dispatcher for the network self-test rows (Task 11) and the
/// troubleshooting page (Task 12).
///
/// Unlike the rest of `network_self_test/` this file is deliberately not a
/// pure data/model layer: it is the action layer, so it imports `core`,
/// Flutter widgets, and plugin APIs directly.
library;

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
import 'package:shadcn_flutter/shadcn_flutter.dart' show BuildContext;
import 'package:url_launcher/url_launcher_string.dart';

import 'network_check.dart';
import 'network_method_target.dart';

/// Executes one fix. Returns true when the action completed (not necessarily
/// that it helped). Failures toast + recordError and return false; a refusal
/// (restart / backend switch while the trainer app is connected) toasts the
/// reason and returns false without recordError — nothing went wrong.
Future<bool> runNetworkFix(BuildContext context, NetworkFixId fix) async {
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

    case NetworkFixId.openBonjourDownload:
      return _launch(
        'https://octoclip.app/learn/how-to-install-bonjour-on-windows/',
        context: 'runNetworkFix.openBonjourDownload',
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

    case NetworkFixId.sendToSupport:
      // Owned by the page (it needs to push SupportChatPage) — a caller
      // that dispatches this here instead of routing it itself is a wiring
      // bug, so this only returns false and never runs in release builds.
      assert(false, 'sendToSupport must be handled by the page, not runNetworkFix');
      return false;
  }
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
