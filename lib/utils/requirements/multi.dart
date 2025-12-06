import 'dart:io';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/foundation.dart';
import 'package:keypress_simulator/keypress_simulator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/gen/l10n.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/core.dart';
import 'package:swift_control/utils/i18n_extension.dart';
import 'package:swift_control/utils/keymap/apps/my_whoosh.dart';
import 'package:swift_control/utils/keymap/apps/supported_app.dart';
import 'package:swift_control/utils/keymap/apps/zwift.dart';
import 'package:swift_control/utils/requirements/platform.dart';
import 'package:swift_control/widgets/ui/toast.dart';
import 'package:universal_ble/universal_ble.dart';

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
  Future<bool> getStatus() async {
    status = await keyPressSimulator.isAccessAllowed();
    return status;
  }
}

class BluetoothAdvertiseRequirement extends PlatformRequirement {
  BluetoothAdvertiseRequirement() : super(AppLocalizations.current.bluetoothAdvertiseAccess);

  @override
  Future<void> call(BuildContext context, VoidCallback onUpdate) async {
    await Permission.bluetoothAdvertise.request();
  }

  @override
  Future<bool> getStatus() async {
    status = await Permission.bluetoothAdvertise.status == PermissionStatus.granted;
    return status;
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
      if (Platform.isMacOS) {
        buildToast(context, title: name);
      } else {
        await UniversalBle.enableBluetooth();
      }
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
  Future<bool> getStatus() async {
    final currentState = screenshotMode
        ? AvailabilityState.poweredOn
        : await UniversalBle.getBluetoothAvailabilityState();
    status = currentState == AvailabilityState.poweredOn || screenshotMode;
    return status;
  }
}

class UnsupportedPlatform extends PlatformRequirement {
  UnsupportedPlatform()
    : super(
        kIsWeb
            ? AppLocalizations.current.browserNotSupported
            : AppLocalizations.current.platformNotSupported('platform'),
      ) {
    status = false;
  }

  @override
  Future<void> call(BuildContext context, VoidCallback onUpdate) async {}

  @override
  Future<bool> getStatus() async {
    return status;
  }
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
  Future<bool> getStatus() async {
    return false;
  }
}

typedef BoolFunction = bool Function();

enum Target {
  thisDevice(
    icon: Icons.devices,
  ),
  otherDevice(
    icon: Icons.settings_remote_outlined,
  );

  final IconData icon;

  const Target({required this.icon});

  String getTitle(BuildContext context) {
    return switch (this) {
      Target.thisDevice => context.i18n.targetThisDevice,
      Target.otherDevice => context.i18n.targetOtherDevice,
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
      Target.thisDevice when !isCompatible => AppLocalizations.current.platformRestrictionOtherDevicesOnly(appName),
      Target.otherDevice when !isCompatible => AppLocalizations.current.platformRestrictionNotSupported,
      Target.thisDevice => AppLocalizations.current.runAppOnThisDevice(appName),
      Target.otherDevice => AppLocalizations.current.runAppOnPlatformRemotely(
        appName,
        AppLocalizations.current.targetOtherDevice,
        preferredConnectionMethod,
      ),
    };
  }

  ConnectionType get connectionType {
    return switch (this) {
      Target.thisDevice when !Platform.isIOS => ConnectionType.local,
      _ => ConnectionType.remote,
    };
  }
}

class PlaceholderRequirement extends PlatformRequirement {
  PlaceholderRequirement() : super(AppLocalizations.current.requirement);

  @override
  Future<void> call(BuildContext context, VoidCallback onUpdate) async {}

  @override
  Future<bool> getStatus() async {
    status = false;
    return false;
  }
}
