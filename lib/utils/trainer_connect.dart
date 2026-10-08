import 'dart:async';

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/go_pro_dialog.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:prop/prop.dart' show LogLevel, RetrofitMode;
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Stands in for [connectTrainerFromPicker] in tests.
@visibleForTesting
Future<bool> Function(BuildContext context, ProxyDevice device)? debugConnectTrainerOverride;

/// Connects a smart trainer the way the onboarding wizard does: pick it from a
/// list, and it bridges over WiFi.
///
/// Shared by the onboarding trainer step and the home screen's trainer card, so
/// "connect my trainer" behaves identically wherever a rider reaches it — same
/// transport, same trial gate, same routing through the connection manager.
///
/// Returns true when a connect was actually started.
Future<bool> connectTrainerFromPicker(BuildContext context, ProxyDevice device) async {
  if (debugConnectTrainerOverride case final override?) return override(context, device);
  try {
    if (device.isStartedListenable.value || device.isStarting.value || device.isConnectedListenable.value) {
      return false;
    }
    if (IAPManager.instance.isTrialExpired) {
      await showGoProDialog(context);
      return false;
    }
    // WiFi transport: the trainer app finds "<trainer> - BikeControl" over the
    // network, and no BLE-advertise permission prompt interrupts the flow.
    device.setRetrofitMode(RetrofitMode.wifi);
    await core.settings.setRetrofitMode(device.trainerKey, RetrofitMode.wifi);
    await core.settings.setAutoConnect(device.trainerKey, true);
    // Route through the connection manager (not device.startProxy directly) so
    // the action / connection-state listeners are attached — same rationale as
    // ConnectionCard._onSelect.
    await core.connection.connectDevice(device);
    return true;
  } catch (e, s) {
    recordError(e, s, context: 'connect trainer from picker');
    final l10n = AppLocalizations.current;
    buildToast(
      level: LogLevel.LOGLEVEL_ERROR,
      title: trainerConnectErrorMessage(l10n, e, context.mounted ? device.displayName(context) : device.toString()),
    );
    return false;
  }
}

/// What a rider reads when connecting [trainer] fails: what to check, never
/// the raw exception (that goes to the log).
String trainerConnectErrorMessage(AppLocalizations l10n, Object error, String trainer) =>
    error is TimeoutException ? l10n.trainerConnectTimeout(trainer) : l10n.trainerConnectFailed(trainer);
