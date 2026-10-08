import 'dart:async';

import 'package:bike_control/main.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/host_platform.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/requirements/local_network.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:bike_control/utils/requirements/platform.dart';
import 'package:bike_control/widgets/ui/connection_method.dart' show openPermissionSheet, satisfyRequirements;
import 'package:prop/prop.dart' show LogLevel;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:bike_control/bluetooth/devices/trainer_connection.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';

/// The wizard's three abstract connection methods, per the design. Each maps
/// onto the same prefs + emulator start/stop calls the settings-page tiles
/// (lib/widgets/apps/*_tile.dart) perform, so the wizard and Trainer
/// Connections stay one system.
enum OnboardingMethod { network, bluetooth, local }

/// obpDirCon rides on the same OBP mDNS server (see CoreLogic.showObpMdnsEmulator).
bool _supportsObpNetwork(SupportedApp app) =>
    app.supports(AppConnectionMethod.obpMdns) || app.supports(AppConnectionMethod.obpDirCon);

/// Rouvy declares rouvyMdns but shares the Zwift-mDNS pref and its own
/// emulator (see zwift_mdns_tile.dart / CoreLogic.isZwiftMdnsEnabled).
bool _supportsZwiftStyleMdns(SupportedApp app) =>
    app.supports(AppConnectionMethod.zwiftMdns) || app.supports(AppConnectionMethod.rouvyMdns);

bool _supportsNetwork(SupportedApp app) => _supportsObpNetwork(app) || _supportsZwiftStyleMdns(app);

bool _supportsBluetooth(SupportedApp app) =>
    app.supports(AppConnectionMethod.obpBle) || app.supports(AppConnectionMethod.zwiftBle);

bool get _localPlatform => HostPlatform.isMacOS || HostPlatform.isWindows || HostPlatform.isAndroid;

/// Whether the trainer app runs on this device and can't reach a BikeControl
/// bridge here (see [vsSameDeviceBlock]: MyWhoosh on Android, FulGaz, a
/// Microsoft Store app on Windows) — the rider has to move one of the two apps
/// to another device (see the trainer step's notice).
bool onboardingVirtualShiftingBlocked(SupportedApp app) =>
    core.settings.getLastTarget() == Target.thisDevice && vsSameDeviceBlock(app) != null;

/// Whether the trainer step should say up front that [app] has to run on
/// another device. For apps whose "this or another device" was answered for
/// the rider ([Target.supportedFor] leaves one choice: FulGaz) and that can't
/// reach a bridge on the same device either — riders put them on the same
/// iPad all the same, and nothing else would tell them why it never connects.
bool onboardingVsNeedsSecondDevice(SupportedApp app) =>
    core.settings.getLastTarget() != Target.thisDevice &&
    Target.supportedFor(app).length == 1 &&
    vsSameDeviceBlock(app) != null;

/// Whether the Where step's target turns on the Local method. Only for an app
/// on this device, and only where Local exists — on iOS a same-device app is
/// reached over the network.
bool onboardingWhereUsesLocal(Target target) =>
    target == Target.thisDevice && target.connectionType == ConnectionType.local;

/// Whether the tile is shown at all for [app]. Mirrors the settings page:
/// Local drives the app running on THIS device (CoreLogic.showLocalControl),
/// Bluetooth advertises to an app on ANOTHER device. On iOS the Local tile is
/// still shown for the same-device target but rendered disabled with a note,
/// so riders learn why it isn't an option there.
bool onboardingMethodVisible(OnboardingMethod method, SupportedApp app) {
  // The target itself, not its connectionType: on iOS "This Device" reports
  // remote (there is no Local method), yet Bluetooth still can't reach an app
  // on the same device.
  final sameDevice = core.settings.getLastTarget() == Target.thisDevice;
  return switch (method) {
    OnboardingMethod.network => _supportsNetwork(app),
    OnboardingMethod.bluetooth => _supportsBluetooth(app) && !sameDevice,
    OnboardingMethod.local => sameDevice,
  };
}

/// Whether the tile can be toggled (Local on iOS cannot).
bool onboardingMethodAvailable(OnboardingMethod method) =>
    method != OnboardingMethod.local || _localPlatform;

/// The concrete connection backing a tile, so the UI can show live
/// started/connected state (enabled is a pref; connected means the trainer
/// app is actually talking to us).
TrainerConnection? onboardingMethodConnection(OnboardingMethod method, SupportedApp app) => switch (method) {
      OnboardingMethod.network => _supportsObpNetwork(app)
          ? core.obpMdnsEmulator
          : _supportsZwiftStyleMdns(app)
              ? (app is Rouvy ? core.rouvyMdnsEmulator : core.zwiftMdnsEmulator)
              : null,
      OnboardingMethod.bluetooth => app.supports(AppConnectionMethod.obpBle)
          ? core.obpBluetoothEmulator
          : app.supports(AppConnectionMethod.zwiftBle)
              ? core.zwiftEmulator
              : null,
      OnboardingMethod.local => core.local,
    };

bool onboardingMethodEnabled(OnboardingMethod method, SupportedApp app) => switch (method) {
      OnboardingMethod.network => _supportsObpNetwork(app)
          ? core.settings.getObpMdnsEnabled()
          : core.settings.getZwiftMdnsEmulatorEnabled(),
      OnboardingMethod.bluetooth => app.supports(AppConnectionMethod.obpBle)
          ? core.settings.getObpBleEnabled()
          : core.settings.getZwiftBleEmulatorEnabled(),
      OnboardingMethod.local => core.settings.getLocalEnabled(),
    };

/// Toggles [method] with exactly the side effects of the corresponding
/// settings tile's onChange handler. [onUpdate] is invoked when async state
/// settles so the host can rebuild.
/// Re-verifies a network method that is *already* switched on.
///
/// [setOnboardingMethodEnabled] only checks on the enable transition, so a
/// rider arriving at the connection step with the method on from a previous
/// session — or who granted Local Network once and revoked it since — would
/// otherwise be told nothing until the connection silently failed. Switches the
/// method back off if the permission is still missing, so the tile stops
/// claiming it is on.
Future<void> verifyEnabledNetworkMethod(
  BuildContext context,
  SupportedApp app, {
  required VoidCallback onUpdate,
}) async {
  if (!onboardingMethodVisible(OnboardingMethod.network, app)) return;
  if (!onboardingMethodEnabled(OnboardingMethod.network, app)) return;
  final requirements = localNetworkRequirements();
  if (requirements.isEmpty) return;
  if (await satisfyRequirements(context, requirements)) {
    // Granted — actually bring the method up. The launch-time start was skipped
    // while the wizard held the screen, so without this the method reads as
    // enabled but advertises nothing.
    core.logic.startEnabledConnectionMethod(userInitiated: true);
    onUpdate();
    return;
  }
  if (!context.mounted) return;
  await setOnboardingMethodEnabled(context, OnboardingMethod.network, app, false, onUpdate: onUpdate);
}

Future<void> setOnboardingMethodEnabled(
  BuildContext context,
  OnboardingMethod method,
  SupportedApp app,
  bool value, {
  required VoidCallback onUpdate,
}) async {
  void toastError(Object e) {
    core.connection.signalNotification(
      AlertNotification(LogLevel.LOGLEVEL_ERROR, 'Error: ${e.toString()}'),
    );
  }

  switch (method) {
    case OnboardingMethod.network:
      // Local Network lives here rather than in getScanRequirements(): every
      // consumer of that list treats a non-empty result as "don't scan", so a
      // denial there would silently kill Bluetooth scanning, and probing it at
      // app start pops the system dialog before onboarding has even been shown.
      if (value && !await satisfyRequirements(context, localNetworkRequirements())) {
        onUpdate();
        return;
      }
      if (_supportsObpNetwork(app)) {
        // Mirrors openbikecontrol_mdns_tile.dart onChange.
        core.settings.setObpMdnsEnabled(value);
        if (!value) {
          core.obpMdnsEmulator.stopServer();
        } else {
          core.obpMdnsEmulator.startServer().catchError((e, s) {
            recordError(e, s, context: 'onboarding OBP mDNS Emulator');
            core.settings.setObpMdnsEnabled(false);
            toastError(e);
            onUpdate();
          });
        }
      } else if (_supportsZwiftStyleMdns(app)) {
        // Mirrors zwift_mdns_tile.dart onChange (Rouvy shares the toggle).
        core.settings.setZwiftMdnsEmulatorEnabled(value);
        void onStartError(Object e, StackTrace s) {
          recordError(e, s, context: 'onboarding Zwift mDNS Emulator');
          core.settings.setZwiftMdnsEmulatorEnabled(false);
          toastError(e);
          onUpdate();
        }
        if (app is Rouvy) {
          value ? core.rouvyMdnsEmulator.startServer().catchError(onStartError) : core.rouvyMdnsEmulator.stop();
        } else {
          value ? core.zwiftMdnsEmulator.startServer().catchError(onStartError) : core.zwiftMdnsEmulator.stop();
        }
      }
    case OnboardingMethod.bluetooth:
      if (value) {
        await core.stopAllBleConnections();
      }
      if (app.supports(AppConnectionMethod.obpBle)) {
        // Mirrors openbikecontrol_ble_tile.dart onChange.
        core.settings.setObpBleEnabled(value);
        if (!value) {
          core.obpBluetoothEmulator.stopServer();
        } else {
          core.obpBluetoothEmulator.startServer().catchError((e, s) {
            recordError(e, s, context: 'onboarding OBP BLE Emulator');
            core.settings.setObpBleEnabled(false);
            toastError(e);
            onUpdate();
          });
        }
      } else if (app.supports(AppConnectionMethod.zwiftBle)) {
        // Mirrors zwift_tile.dart onChange.
        core.settings.setZwiftBleEmulatorEnabled(value);
        if (!value) {
          core.zwiftEmulator.stopAdvertising();
        } else {
          core.zwiftEmulator.startAdvertising(onUpdate).catchError((e, s) {
            recordError(e, s, context: 'onboarding Zwift BLE Emulator');
            core.zwiftEmulator.cleanup();
            core.zwiftEmulator.isStarted.value = false;
            core.settings.setZwiftBleEmulatorEnabled(false);
            toastError(e);
            onUpdate();
          });
        }
      }
    case OnboardingMethod.local:
      if (!_localPlatform) return;
      if (value) {
        // Gate on LIVE permission state: if the rider dismisses or denies the
        // permission sheet, Local must not report itself enabled.
        final requirements = core.permissions.getLocalControlRequirements();
        // A status check that throws counts as not granted — never enable
        // Local on a permission state we couldn't verify.
        Future<bool> liveStatus(PlatformRequirement r) async {
          try {
            return await r.getStatus();
          } catch (e, s) {
            recordError(e, s, context: 'onboarding local requirement status');
            return false;
          }
        }

        var states = await Future.wait(requirements.map(liveStatus));
        final missing = [
          for (var i = 0; i < requirements.length; i++)
            if (!states[i]) requirements[i],
        ];
        if (missing.isNotEmpty) {
          if (context.mounted) {
            await openPermissionSheet(context, missing);
          }
          states = await Future.wait(missing.map(liveStatus));
          if (states.any((granted) => !granted)) {
            onUpdate();
            return;
          }
        }
      }
      // Mirrors local_tile.dart onChange.
      core.settings.setLocalEnabled(value);
      if (core.logic.canRunAndroidService) {
        unawaited(core.logic.isAndroidServiceRunning().then((isRunning) {
          core.connection.signalNotification(LogNotification('Local Control: $isRunning'));
          core.local.isStarted.value = isRunning;
          core.local.isConnected.value = isRunning;
          onUpdate();
        }));
      } else {
        core.local.isStarted.value = value;
        core.local.isConnected.value = value;
        core.connection.signalNotification(LogNotification('Local Control: $value'));
      }
  }
  onUpdate();
}
