import 'dart:io';

import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/bike_control.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:flutter/foundation.dart';

/// What happens to the rider's own button mapping when they pick another
/// trainer app.
enum KeymapSwitchChoice {
  /// Keep using the custom mapping that is active now.
  keepCustom,

  /// Switch to the picked app's built-in mapping. The custom one stays saved.
  useAppButtons,
}

/// The name of the active custom mapping when picking [selectedApp] should
/// ask what to do with it — it was copied from a different app, or from none
/// we know of. Null when there's nothing to ask: the active mapping is a
/// built-in one, the rider picked a custom "app", or the custom mapping was
/// made from [selectedApp] itself.
String? customKeymapToConfirmFor(SupportedApp selectedApp) {
  final active = core.actionHandler.supportedApp;
  if (active is! CustomApp || selectedApp is CustomApp) return null;
  if (core.settings.getCustomKeymapOrigin(active.profileName) == selectedApp.name) return null;
  return active.profileName;
}

/// Applies the trainer app selection, stopping unsupported emulators,
/// initializing the action handler, and starting the enabled connection method.
///
/// [keymapChoice] decides what happens to an active custom mapping (see
/// [customKeymapToConfirmFor]); the UI asks the rider before calling this.
///
/// Shared by [ConfigurationPage] and the onboarding wizard.
Future<void> applyTrainerAppSelection(
  SupportedApp selectedApp, {
  KeymapSwitchChoice keymapChoice = KeymapSwitchChoice.keepCustom,
}) async {
  if (selectedApp is! MyWhoosh) {
    if (core.whooshLink.isStarted.value) {
      core.whooshLink.stopServer();
    }
  }
  if (!selectedApp.supports(AppConnectionMethod.zwiftMdns)) {
    if (core.zwiftMdnsEmulator.isStarted.value) {
      core.zwiftMdnsEmulator.stop();
    }
    // TODO restart mDNS when advertisementName changes
  }
  if (!selectedApp.supports(AppConnectionMethod.zwiftBle)) {
    if (core.zwiftEmulator.isStarted.value) {
      core.zwiftEmulator.stopAdvertising();
    }
  }
  if (!selectedApp.supports(AppConnectionMethod.rouvyMdns)) {
    if (core.rouvyMdnsEmulator.isStarted.value) {
      core.rouvyMdnsEmulator.stop();
    }
  }
  if (core.obpMdnsEmulator.isStarted.value) {
    core.obpMdnsEmulator.stopServer();
  }
  if (core.obpBluetoothEmulator.isStarted.value) {
    core.obpBluetoothEmulator.stopServer();
  }

  core.settings.setTrainerApp(selectedApp);
  final active = core.actionHandler.supportedApp;
  if (active == null ||
      (selectedApp is! CustomApp &&
          (active is! CustomApp || keymapChoice == KeymapSwitchChoice.useAppButtons))) {
    core.actionHandler.init(selectedApp);
    await core.settings.setKeyMap(selectedApp);
  }
  core.logic.startEnabledConnectionMethod();

  if (selectedApp is BikeControl) {
    core.settings.setLastTarget(Target.thisDevice);
  } else if (!selectedApp.receivesButtonEvents) {
    // Nothing we can send reaches this app locally, so a stale "this device"
    // would leave the rider on a target that cannot work.
    core.settings.setLastTarget(Target.otherDevice);
  }
}

/// Applies the target selection, enabling OBP methods or local connection
/// as appropriate, and starting the enabled connection method.
///
/// Shared by [ConfigurationPage] and the onboarding wizard.
Future<void> applyTargetSelection(Target target) async {
  await core.settings.setLastTarget(target);

  if ((core.settings.getTrainerApp()?.supports(AppConnectionMethod.obpBle) == true ||
          core.settings.getTrainerApp()?.supports(AppConnectionMethod.obpMdns) == true) &&
      !core.logic.emulatorEnabled) {
    core.settings.setObpMdnsEnabled(true);
  }

  // enable local connection on Windows if the app doesn't support OBP
  if (target == Target.thisDevice &&
      !core.settings.getTrainerApp()!.supports(AppConnectionMethod.obpBle) &&
      !core.settings.getTrainerApp()!.supports(AppConnectionMethod.obpMdns) &&
      !kIsWeb &&
      Platform.isWindows) {
    core.settings.setLocalEnabled(true);
  }
  core.logic.startEnabledConnectionMethod();
}
