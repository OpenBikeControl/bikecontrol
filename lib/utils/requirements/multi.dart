import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:keypress_simulator/keypress_simulator.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/keymap/apps/custom_app.dart';
import 'package:swift_control/utils/keymap/apps/my_whoosh.dart';
import 'package:swift_control/utils/keymap/apps/supported_app.dart';
import 'package:swift_control/utils/keymap/apps/zwift.dart';
import 'package:swift_control/utils/requirements/platform.dart';
import 'package:swift_control/utils/requirements/remote.dart';
import 'package:swift_control/widgets/beta_pill.dart';
import 'package:universal_ble/universal_ble.dart';

class KeyboardRequirement extends PlatformRequirement {
  KeyboardRequirement() : super('Keyboard access');

  @override
  Future<void> call(BuildContext context, VoidCallback onUpdate) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Enable keyboard access in the following screen for SwiftControl. If you don\'t see SwiftControl, please add it manually.',
        ),
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
      await peripheralManager.showAppSettings();
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
    return ElevatedButton(
      onPressed: () {
        call(context, onUpdate);
      },
      child: Text('Enable Bluetooth'),
    );
  }

  @override
  Future<void> getStatus() async {
    final currentState = await UniversalBle.getBluetoothAvailabilityState();
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

typedef BoolFunction = bool Function();

enum Target {
  thisDevice(
    title: 'This Device',
    icon: Icons.devices,
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
    return actionHandler.supportedApp?.compatibleTargets.contains(this) == true;
  }

  bool get isBeta {
    final supportedApp = actionHandler.supportedApp;

    if (supportedApp is Zwift) {
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
        'Run ${app?.name ?? 'the Trainer app'} on your Apple device and control it remotely from this device${app is MyWhoosh ? ', e.g. by using MyWhoosh Link method' : ''}.',
      Target.android =>
        'Run ${app?.name ?? 'the Trainer app'} on your Android device and control it remotely from this device${app is MyWhoosh ? ', e.g. by using MyWhoosh Link method' : ''}.',
      Target.macOS =>
        'Run ${app?.name ?? 'the Trainer app'} on your Mac and control it remotely from this device${app is MyWhoosh ? ', e.g. by using MyWhoosh Link method' : ''}.',
      Target.windows =>
        'Run ${app?.name ?? 'the Trainer app'} on your Windows PC and control it remotely from this device${app is MyWhoosh ? ', e.g. by using MyWhoosh Link method' : ''}.',
    };
  }

  String? get warning {
    if (actionHandler.supportedApp is Zwift) {
      // no warnings for zwift
      return null;
    }
    return switch (this) {
      Target.android when Platform.isAndroid =>
        "Select 'This device' unless you want to control another Android device. Are you sure?",
      Target.macOS when Platform.isMacOS =>
        "Select 'This device' unless you want to control another macOS device. Are you sure?",
      Target.windows when Platform.isWindows =>
        "Select 'This device' unless you want to control another Windows device. Are you sure?",
      Target.android => "Download and use SwiftControl on that Android device.",
      Target.macOS => "Download and use SwiftControl on that macOS device.",
      Target.windows => "Download and use SwiftControl on that Windows device.",
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
    status = settings.getLastTarget() != null && settings.getTrainerApp() != null;
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
          DropdownMenu<SupportedApp>(
            dropdownMenuEntries: SupportedApp.supportedApps.map((app) {
              return DropdownMenuEntry(
                value: app,
                label: app.name,
              );
            }).toList(),
            hintText: 'Select Trainer app',
            initialSelection: settings.getTrainerApp(),
            onSelected: (selectedApp) async {
              if (settings.getTrainerApp() is MyWhoosh && selectedApp is! MyWhoosh && whooshLink.isStarted.value) {
                whooshLink.stopServer();
              }
              settings.setTrainerApp(selectedApp!);
              if (actionHandler.supportedApp == null ||
                  (actionHandler.supportedApp is! CustomApp && selectedApp is! CustomApp)) {
                actionHandler.init(selectedApp);
                settings.setSupportedApp(selectedApp);
              }
              setState(() {});
            },
          ),
          SizedBox(height: 8),
          Text(
            'Select Target where ${settings.getTrainerApp()?.name ?? 'the Trainer app'} runs on',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          DropdownMenu<Target>(
            dropdownMenuEntries: Target.values.map((target) {
              return DropdownMenuEntry(
                value: target,
                label: target.title,
                enabled: target.isCompatible,
                trailingIcon: Icon(target.icon),
                labelWidget: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(target.title, style: TextStyle(fontWeight: FontWeight.bold)),
                          if (target.isBeta) BetaPill(),
                        ],
                      ),
                      Text(
                        target.getDescription(actionHandler.supportedApp),
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      if (target == Target.thisDevice)
                        Container(
                          margin: EdgeInsets.only(top: 12),
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(context).dividerColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
            hintText: 'Select Target device',
            initialSelection: settings.getLastTarget(),
            onSelected: (target) async {
              if (target != null) {
                await settings.setLastTarget(target);
                initializeActions(settings.getTrainerApp()?.connectionType ?? target.connectionType);
                if (target.warning != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(target.warning!),
                      duration: Duration(seconds: 10),
                    ),
                  );
                }
                setState(() {});
              }
            },
          ),
          ElevatedButton(
            onPressed: settings.getTrainerApp() != null && settings.getLastTarget() != null
                ? () {
                    onUpdate();
                  }
                : null,
            child: Text('Continue'),
          ),
        ],
      ),
    );
  }

  @override
  Widget? buildDescription() {
    final trainer = settings.getTrainerApp();
    final target = settings.getLastTarget();

    if (target != null && trainer != null) {
      if (target.warning != null) {
        return Row(
          spacing: 8,
          children: [
            Icon(Icons.warning, color: Colors.red, size: 16),
            Expanded(
              child: Text(
                settings.getLastTarget()!.warning!,
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
