import 'dart:io';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:keypress_simulator/keypress_simulator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/bluetooth/devices/zwift/protocol/zp.pb.dart';
import 'package:swift_control/gen/app_localizations.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/core.dart';
import 'package:swift_control/utils/keymap/apps/custom_app.dart';
import 'package:swift_control/utils/keymap/apps/my_whoosh.dart';
import 'package:swift_control/utils/keymap/apps/supported_app.dart';
import 'package:swift_control/utils/keymap/apps/zwift.dart';
import 'package:swift_control/utils/requirements/platform.dart';
import 'package:swift_control/widgets/ui/beta_pill.dart';
import 'package:swift_control/widgets/ui/toast.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../widgets/ui/warning.dart';

class KeyboardRequirement extends PlatformRequirement {
  KeyboardRequirement() : super(AppLocalizations.current.keyboardAccess);

  @override
  Future<void> call(BuildContext context, VoidCallback onUpdate) async {
    buildToast(
      context,
      title: AppLocalizations.current.enableKeyboardAccessMessage,
    );
    await keyPressSimulator.requestAccess(onlyOpenPrefPane: Platform.isMacOS);
  }

  @override
  Future<void> getStatus() async {
    status = await keyPressSimulator.isAccessAllowed();
  }
}

class BluetoothAdvertiseRequirement extends PlatformRequirement {
  BluetoothAdvertiseRequirement() : super(AppLocalizations.current.bluetoothAdvertiseAccess);

  @override
  Future<void> call(BuildContext context, VoidCallback onUpdate) async {
    await Permission.bluetoothAdvertise.request();
  }

  @override
  Future<void> getStatus() async {
    status = await Permission.bluetoothAdvertise.status == PermissionStatus.granted;
  }
}

class BluetoothTurnedOn extends PlatformRequirement {
  BluetoothTurnedOn() : super(AppLocalizations.current.bluetoothTurnedOn);

  @override
  Future<void> call(BuildContext context, VoidCallback onUpdate) async {
    final currentState = await UniversalBle.getBluetoothAvailabilityState();
    if (!kIsWeb && Platform.isIOS) {
      // on iOS we cannot programmatically enable Bluetooth, just open settings
      await PeripheralManager().showAppSettings();
    } else if (currentState == AvailabilityState.poweredOff) {
      await UniversalBle.enableBluetooth();
    } else {
      // I guess bluetooth is on now
      // TODO move UniversalBle.onAvailabilityChange
      getStatus();
      onUpdate();
    }
  }

  @override
  Widget? build(BuildContext context, VoidCallback onUpdate) {
    return OutlineButton(
      onPressed: () {
        call(context, onUpdate);
      },
      child: Text(context.i18n.enableBluetooth),
    );
  }

  @override
  Future<void> getStatus() async {
    final currentState = screenshotMode
        ? AvailabilityState.poweredOn
        : await UniversalBle.getBluetoothAvailabilityState();
    status = currentState == AvailabilityState.poweredOn || screenshotMode;
  }
}

class UnsupportedPlatform extends PlatformRequirement {
  UnsupportedPlatform()
    : super(kIsWeb ? AppLocalizations.current.browserNotSupported : AppLocalizations.current.platformNotSupported('platform')) {
    status = false;
  }

  @override
  Future<void> call(BuildContext context, VoidCallback onUpdate) async {}

  @override
  Future<void> getStatus() async {}
}

class ErrorRequirement extends PlatformRequirement {
  ErrorRequirement(super.name) {
    status = false;
  }

  @override
  Future<void> call(BuildContext context, VoidCallback onUpdate) async {
    onUpdate();
  }

  @override
  Future<void> getStatus() async {}
}

typedef BoolFunction = bool Function();

enum Target {
  thisDevice(
    icon: Icons.devices,
  ),
  otherDevice(
    icon: Icons.settings_remote_outlined,
  ),
  iOS(
    icon: Icons.settings_remote_outlined,
  ),
  android(
    icon: Icons.settings_remote_outlined,
  ),
  macOS(
    icon: Icons.settings_remote_outlined,
  ),
  windows(
    icon: Icons.settings_remote_outlined,
  );

  final IconData icon;

  const Target({required this.icon});

  String getTitle(BuildContext context) {
    return switch (this) {
      Target.thisDevice => context.i18n.targetThisDevice,
      Target.otherDevice => context.i18n.targetOtherDevice,
      Target.iOS => context.i18n.targetIOS,
      Target.android => context.i18n.targetAndroid,
      Target.macOS => context.i18n.targetMacOS,
      Target.windows => context.i18n.targetWindows,
    };
  }

  bool get isCompatible {
    return core.settings.getTrainerApp()?.compatibleTargets.contains(this) == true;
  }

  bool get isBeta {
    final supportedApp = core.settings.getTrainerApp();

    if (supportedApp is Zwift) {
      // everything is supported, this device is not compatible anyway
      return false;
    }

    return switch (this) {
      Target.thisDevice => false,
      _ => supportedApp == null || supportedApp.supportsOpenBikeProtocol == false,
    };
  }

  String getDescription(SupportedApp? app) {
    final appName = app?.name ?? 'the Trainer app';
    final preferredConnectionMethod = app?.supportsOpenBikeProtocol == true
        ? AppLocalizations.current.openBikeControlConnection
        : app is MyWhoosh
        ? AppLocalizations.current.myWhooshDirectConnection
        : '';

    return switch (this) {
      Target.thisDevice when !isCompatible =>
        AppLocalizations.current.platformRestrictionOtherDevicesOnly(appName),
      Target.otherDevice when !isCompatible => AppLocalizations.current.platformRestrictionNotSupported,
      Target.thisDevice => AppLocalizations.current.runAppOnThisDevice(appName),
      Target.iOS =>
        AppLocalizations.current.runAppOnPlatformRemotely(appName, 'an Apple device', preferredConnectionMethod),
      Target.android =>
        AppLocalizations.current.runAppOnPlatformRemotely(appName, 'an Android device', preferredConnectionMethod),
      Target.macOS =>
        AppLocalizations.current.runAppOnPlatformRemotely(appName, 'a Mac', preferredConnectionMethod),
      Target.windows =>
        AppLocalizations.current.runAppOnPlatformRemotely(appName, 'a Windows PC', preferredConnectionMethod),
      Target.otherDevice =>
        AppLocalizations.current.runAppOnPlatformRemotely(appName, 'another device', ''),
    };
  }

  String? get warning {
    if (core.logic.ignoreWarnings) {
      // no warnings for zwift emulation
      return null;
    }
    return switch (this) {
      Target.android when Platform.isAndroid =>
        AppLocalizations.current.selectThisDeviceWarning('Android'),
      Target.macOS when Platform.isMacOS =>
        AppLocalizations.current.selectThisDeviceWarning('macOS'),
      Target.windows when Platform.isWindows =>
        AppLocalizations.current.selectThisDeviceWarning('Windows'),
      Target.android => AppLocalizations.current.recommendDownloadBikeControl('Android'),
      Target.macOS => AppLocalizations.current.recommendDownloadBikeControl('macOS'),
      Target.windows => AppLocalizations.current.recommendDownloadBikeControl('Windows'),
      _ => null,
    };
  }

  ConnectionType get connectionType {
    return switch (this) {
      Target.thisDevice => ConnectionType.local,
      _ => ConnectionType.remote,
    };
  }
}

class TargetRequirement extends PlatformRequirement {
  TargetRequirement()
    : super(
        AppLocalizations.current.selectTrainerAppAndTarget,
        description: AppLocalizations.current.selectTargetDeviceDescription,
      ) {
    status = false;
  }

  @override
  Future<void> call(BuildContext context, VoidCallback onUpdate) async {}

  @override
  Future<void> getStatus() async {
    status = core.settings.getLastTarget() != null && core.settings.getTrainerApp() != null;
  }

  @override
  Widget? build(BuildContext context, VoidCallback onUpdate) {
    return StatefulBuilder(
      builder: (c, setState) => Column(
        spacing: 8,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.i18n.selectTrainerApp),
          Select<SupportedApp>(
            constraints: BoxConstraints(maxWidth: 400, minWidth: 400),
            itemBuilder: (c, app) => Text(app.name),
            popup: SelectPopup(
              items: SelectItemList(
                children: SupportedApp.supportedApps.map((app) {
                  return SelectItemButton(
                    value: app,
                    child: Text(app.name),
                  );
                }).toList(),
              ),
            ).call,
            placeholder: Text(context.i18n.selectTrainerAppPlaceholder),
            value: core.settings.getTrainerApp(),
            onChanged: (selectedApp) async {
              if (core.settings.getTrainerApp() is MyWhoosh &&
                  selectedApp is! MyWhoosh &&
                  core.whooshLink.isStarted.value) {
                core.whooshLink.stopServer();
              }
              core.settings.setTrainerApp(selectedApp!);
              if (core.settings.getLastTarget() == null && Target.thisDevice.isCompatible) {
                await core.settings.setLastTarget(Target.thisDevice);
              }
              if (core.actionHandler.supportedApp == null ||
                  (core.actionHandler.supportedApp is! CustomApp && selectedApp is! CustomApp)) {
                core.actionHandler.init(selectedApp);
                core.settings.setKeyMap(selectedApp);
              }
              setState(() {});
              onUpdate();
            },
          ),
          if (core.settings.getTrainerApp() != null) ...[
            SizedBox(height: 8),
            Text(
              context.i18n.selectTargetWhereAppRuns(core.settings.getTrainerApp()?.name ?? 'the Trainer app'),
            ),
            Select<Target>(
              constraints: BoxConstraints(maxWidth: 400, minWidth: 400),
              itemBuilder: (c, app) => Text(app.getTitle(context)),
              popup: SelectPopup(
                items: SelectItemList(
                  children: [Target.thisDevice, Target.otherDevice].map((target) {
                    return SelectItemButton(
                      value: target,
                      enabled: target.isCompatible,
                      child: Basic(
                        leading: Icon(target.icon),
                        leadingAlignment: Alignment.centerLeft,
                        subtitle: Text(
                          target.getDescription(core.settings.getTrainerApp()),
                        ).xSmall.muted,
                        title: Text(target.getTitle(context)),
                      ),
                    );
                  }).toList(),
                ),
              ).call,
              placeholder: Text(context.i18n.selectTargetDevice),
              value: core.settings.getLastTarget() != Target.thisDevice ? Target.otherDevice : Target.thisDevice,
              enabled: core.settings.getTrainerApp() != null,
              onChanged: (target) async {
                if (target != null) {
                  await core.settings.setLastTarget(target);

                  if (core.settings.getTrainerApp()?.supportsOpenBikeProtocol == true && !core.logic.emulatorEnabled) {
                    core.settings.setObpMdnsEnabled(true);
                    core.obpMdnsEmulator.startServer().catchError((e) {
                      buildToast(
                        context,
                        title: context.i18n.errorStartingOpenBikeControlServer,
                      );
                    });
                  }

                  if (target.warning != null) {
                    buildToast(
                      context,
                      title: target.warning,
                      level: LogLevel.LOGLEVEL_WARNING,
                    );
                  }
                  setState(() {});
                  onUpdate();
                }
              },
            ),
          ],

          if (core.settings.getLastTarget() != null && core.settings.getLastTarget() != Target.thisDevice) ...[
            SizedBox(height: 8),
            Text(
              context.i18n.selectOtherDeviceWhereAppRuns(core.settings.getTrainerApp()?.name ?? 'the Trainer app'),
            ),
            Select<Target>(
              constraints: BoxConstraints(maxWidth: 400, minWidth: 400),
              itemBuilder: (c, app) => Text(app.getTitle(context)),
              popup: SelectPopup(
                items: SelectItemList(
                  children: Target.values.whereNot((e) => [Target.thisDevice, Target.otherDevice].contains(e)).map((
                    target,
                  ) {
                    return SelectItemButton(
                      value: target,
                      enabled: target.isCompatible,
                      child: Basic(
                        leading: Icon(target.icon),
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  target.getTitle(context),
                                  style: TextStyle(
                                    fontWeight: target == Target.thisDevice && target.isCompatible
                                        ? FontWeight.bold
                                        : null,
                                  ),
                                ),
                                if (target.isBeta) BetaPill(),
                              ],
                            ),
                          ],
                        ),
                        subtitle: Text(
                          target.getDescription(core.settings.getTrainerApp()),
                        ).small,
                      ),
                    );
                  }).toList(),
                ),
              ).call,
              placeholder: Text(context.i18n.selectTargetDevice),
              value: core.settings.getLastTarget(),
              enabled: core.settings.getTrainerApp() != null,
              onChanged: (target) async {
                if (target != null) {
                  await core.settings.setLastTarget(target);
                  initializeActions(target.connectionType);
                  if (target.warning != null && context.mounted) {
                    buildToast(
                      context,
                      title: target.warning,
                      level: LogLevel.LOGLEVEL_WARNING,
                    );
                  }
                  setState(() {});
                  onUpdate();
                }
              },
            ),

            if (core.settings.getLastTarget()?.warning != null) ...[
              Warning(
                children: [
                  Icon(Icons.warning_amber, color: Theme.of(context).colorScheme.primaryForeground),
                  Text(
                    core.settings.getLastTarget()!.warning!,
                    style: TextStyle(color: Theme.of(context).colorScheme.primaryForeground),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  @override
  Widget? buildDescription() {
    final trainer = core.settings.getTrainerApp();
    final target = core.settings.getLastTarget();

    if (target != null && trainer != null) {
      if (target.warning != null) {
        return Row(
          spacing: 8,
          children: [
            Icon(Icons.warning, color: Colors.red, size: 16),
            Expanded(
              child: Text(
                core.settings.getLastTarget()!.warning!,
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      } else {
        return Builder(builder: (context) => Text(AppLocalizations.current.appNameOnTargetName(trainer.name, target.getTitle(context))));
      }
    } else {
      return null;
    }
  }
}

class PlaceholderRequirement extends PlatformRequirement {
  PlaceholderRequirement() : super(AppLocalizations.current.requirement);

  @override
  Future<void> call(BuildContext context, VoidCallback onUpdate) async {}

  @override
  Future<void> getStatus() async {
    status = false;
  }
}
