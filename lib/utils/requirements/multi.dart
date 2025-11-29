import 'dart:io';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:keypress_simulator/keypress_simulator.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/bluetooth/devices/zwift/protocol/zp.pb.dart';
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
  KeyboardRequirement() : super('Keyboard access');

  @override
  Future<void> call(BuildContext context, VoidCallback onUpdate) async {
    showToast(
      context: context,
      builder: (c, overlay) => buildToast(
        context,
        overlay,
        title:
            'Enable keyboard access in the following screen for BikeControl. If you don\'t see BikeControl, please add it manually.',
      ),
    );
    await keyPressSimulator.requestAccess(onlyOpenPrefPane: Platform.isMacOS);
  }

  @override
  Future<void> getStatus() async {
    status = await keyPressSimulator.isAccessAllowed();
  }
}

class BluetoothTurnedOn extends PlatformRequirement {
  BluetoothTurnedOn() : super('Bluetooth turned on');

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
      child: Text('Enable Bluetooth'),
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
    : super('This ${kIsWeb ? 'Browser does not support Web Bluetooth and ' : 'platform'} is not supported :(') {
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
    title: 'This Device',
    icon: Icons.devices,
  ),
  otherDevice(
    title: 'Other Device',
    icon: Icons.settings_remote_outlined,
  ),
  iOS(
    title: 'iPhone / iPad / Apple TV',
    icon: Icons.settings_remote_outlined,
  ),
  android(
    title: 'Android Device',
    icon: Icons.settings_remote_outlined,
  ),
  macOS(
    title: 'Mac',
    icon: Icons.settings_remote_outlined,
  ),
  windows(
    title: 'Windows PC',
    icon: Icons.settings_remote_outlined,
  );

  final String title;
  final IconData icon;

  const Target({required this.title, required this.icon});

  bool get isCompatible {
    return core.settings.getTrainerApp()?.compatibleTargets.contains(this) == true;
  }

  bool get isBeta {
    final supportedApp = core.settings.getTrainerApp();

    if (supportedApp is Zwift && !(Platform.isIOS || Platform.isMacOS)) {
      // everything is supported, this device is not compatible anyway
      return false;
    }

    return switch (this) {
      Target.thisDevice => false,
      _ => true,
    };
  }

  String getDescription(SupportedApp? app) {
    return switch (this) {
      Target.thisDevice when !isCompatible =>
        'Due to platform restrictions only controlling ${app?.name ?? 'the Trainer app'} on other devices is supported.',
      Target.thisDevice => 'Run ${app?.name ?? 'the Trainer app'} on this device.',
      Target.iOS =>
        'Run ${app?.name ?? 'the Trainer app'} on an Apple device and control it remotely from this device${app is MyWhoosh ? ', e.g. by using MyWhoosh Direct Connect' : ''}.',
      Target.android =>
        'Run ${app?.name ?? 'the Trainer app'} on an Android device and control it remotely from this device${app is MyWhoosh ? ', e.g. by using MyWhoosh Direct Connect' : ''}.',
      Target.macOS =>
        'Run ${app?.name ?? 'the Trainer app'} on a Mac and control it remotely from this device${app is MyWhoosh ? ', e.g. by using MyWhoosh Direct Connect' : ''}.',
      Target.windows =>
        'Run ${app?.name ?? 'the Trainer app'} on a Windows PC and control it remotely from this device${app is MyWhoosh ? ', e.g. by using MyWhoosh Direct Connect' : ''}.',
      Target.otherDevice =>
        'Run ${app?.name ?? 'the Trainer app'} on another device and control it remotely from this device.',
    };
  }

  String? get warning {
    if (core.settings.getTrainerApp()?.supportsZwiftEmulation == true) {
      // no warnings for zwift emulation
      return null;
    }
    return switch (this) {
      Target.android when Platform.isAndroid =>
        "Select 'This device' unless you want to control another Android device. Are you sure?",
      Target.macOS when Platform.isMacOS =>
        "Select 'This device' unless you want to control another macOS device. Are you sure?",
      Target.windows when Platform.isWindows =>
        "Select 'This device' unless you want to control another Windows device. Are you sure?",
      Target.android => "We highly recommended to download and use BikeControl on that Android device.",
      Target.macOS => "We highly recommended to download and use BikeControl on that macOS device.",
      Target.windows => "We highly recommended to download and use BikeControl on that Windows device.",
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
        'Select Trainer App & Target Device',
        description: 'Select your Target Device where you want to run your trainer app on',
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
          Text('Select Trainer App', style: TextStyle(fontWeight: FontWeight.bold)),
          Select<SupportedApp>(
            constraints: BoxConstraints(maxWidth: 400, minWidth: 400),
            itemBuilder: (c, app) => Text(app.name),
            popup: SelectPopup(
              items: SelectItemList(
                children: SupportedApp.supportedApps.map((app) {
                  return SelectItemButton(
                    value: app,
                    child: app is Zwift && !(Platform.isWindows || Platform.isAndroid)
                        ? Basic(
                            title: Text(app.name),
                            trailing: Icon(Icons.warning_amber),
                            trailingAlignment: Alignment.centerRight,
                            subtitle: Text(
                              'When running BikeControl on Apple devices you are limited to on-screen controls (so no virtual shifting) only due to platform restrictions :(',
                            ).xSmall.muted,
                          )
                        : Text(app.name),
                  );
                }).toList(),
              ),
            ).call,
            placeholder: Text('Select Trainer app'),
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
              'Select Target where ${core.settings.getTrainerApp()?.name ?? 'the Trainer app'} runs on',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Select<Target>(
              constraints: BoxConstraints(maxWidth: 400, minWidth: 400),
              itemBuilder: (c, app) => Text(app.title),
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
                        title: Text(target.title),
                      ),
                    );
                  }).toList(),
                ),
              ).call,
              placeholder: Text('Select Target device'),
              value: core.settings.getLastTarget() != Target.thisDevice ? Target.otherDevice : Target.thisDevice,
              enabled: core.settings.getTrainerApp() != null,
              onChanged: (target) async {
                if (target != null) {
                  await core.settings.setLastTarget(target);
                  if (target.warning != null) {
                    showToast(
                      context: context,
                      builder: (c, overlay) => buildToast(
                        context,
                        overlay,
                        title: target.warning,
                        level: LogLevel.LOGLEVEL_WARNING,
                      ),
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
              'Select the other device where ${core.settings.getTrainerApp()?.name ?? 'the Trainer app'} runs on',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Select<Target>(
              constraints: BoxConstraints(maxWidth: 400, minWidth: 400),
              itemBuilder: (c, app) => Text(app.title),
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
                                  target.title,
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
              placeholder: Text('Select Target device'),
              value: core.settings.getLastTarget(),
              enabled: core.settings.getTrainerApp() != null,
              onChanged: (target) async {
                if (target != null) {
                  await core.settings.setLastTarget(target);
                  initializeActions(target.connectionType);
                  if (target.warning != null && context.mounted) {
                    showToast(
                      context: context,
                      builder: (c, overlay) => buildToast(
                        context,
                        overlay,
                        title: target.warning,
                        level: LogLevel.LOGLEVEL_WARNING,
                      ),
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
        return Text('${trainer.name} on ${target.title}');
      }
    } else {
      return null;
    }
  }
}

class PlaceholderRequirement extends PlatformRequirement {
  PlaceholderRequirement() : super('Requirement');

  @override
  Future<void> call(BuildContext context, VoidCallback onUpdate) async {}

  @override
  Future<void> getStatus() async {
    status = false;
  }
}
