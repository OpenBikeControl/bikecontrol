import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:keypress_simulator/keypress_simulator.dart';
import 'package:swift_control/main.dart';
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
    title: 'This device',
    description: 'Trainer app runs on this device',
    icon: Icons.devices,
  ),
  iPad(
    title: 'iPad',
    description: 'Remotely control any trainer app on an iPad by acting as a Mouse, or directly via MyWhoosh Link',
    icon: Icons.settings_remote_outlined,
  ),
  android(
    title: 'Android Device',
    description: 'Remotely control any trainer app on another Android device, or directly via MyWhoosh Link',
    icon: Icons.settings_remote_outlined,
    isBeta: true,
  ),
  macOS(
    title: 'Mac',
    description: 'Remotely control any trainer app on another Mac, or directly via MyWhoosh Link',
    icon: Icons.settings_remote_outlined,
    isBeta: true,
  ),
  windows(
    title: 'Windows PC',
    description: 'Remotely control any trainer app on another Windows PC, or directly via MyWhoosh Link',
    icon: Icons.settings_remote_outlined,
    isBeta: true,
  );

  final String title;
  final String description;
  final IconData icon;
  final bool isBeta;

  const Target({required this.title, required this.description, required this.icon, this.isBeta = false});

  bool get isCompatible {
    return switch (this) {
      Target.thisDevice => !Platform.isIOS,
      _ => true,
    };
  }

  String? get warning {
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
        'Select Target Device',
        description: 'Select your Target Device where you want to run your trainer app on',
      ) {
    status = false;
  }

  @override
  Future<void> call(BuildContext context, VoidCallback onUpdate) async {}

  @override
  Future<void> getStatus() async {
    status = settings.getLastTarget() != null;
  }

  @override
  Widget? build(BuildContext context, VoidCallback onUpdate) {
    return DropdownMenu<Target>(
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
                    if (target.isBeta || (!Platform.isIOS && target == Target.iPad)) BetaPill(),
                  ],
                ),
                Text(
                  target.isCompatible
                      ? target.description
                      : 'Due to iOS restrictions only controlling trainer apps on other devices is supported.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      }).toList(),
      hintText: name,
      initialSelection: settings.getLastTarget(),
      onSelected: (target) async {
        if (target != null) {
          await settings.setLastTarget(target);
          initializeActions(target.connectionType);
          if (target.warning != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(target.warning!),
                duration: Duration(seconds: 10),
              ),
            );
          }
          onUpdate();
        }
      },
    );
  }

  @override
  Widget? buildDescription() {
    final target = settings.getLastTarget();

    if (target != null) {
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
        return Text(target.title);
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
