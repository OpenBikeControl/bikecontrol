import 'dart:io';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/host_platform.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:bike_control/utils/requirements/platform.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:flutter/foundation.dart';
import 'package:keypress_simulator/keypress_simulator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:url_launcher/url_launcher_string.dart';

class KeyboardRequirement extends PlatformRequirement {
  KeyboardRequirement() : super(AppLocalizations.current.keyboardAccess, icon: LucideIcons.keyboard);

  @override
  Future<void> call(BuildContext context, VoidCallback onUpdate) async {
    buildToast(
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
  BluetoothAdvertiseRequirement()
    : super(AppLocalizations.current.bluetoothAdvertiseAccess, icon: LucideIcons.headphones);

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
  BluetoothTurnedOn() : super(AppLocalizations.current.bluetoothTurnedOn, icon: LucideIcons.bluetooth);

  @override
  Future<void> call(BuildContext context, VoidCallback onUpdate) async {
    final currentState = await UniversalBle.getBluetoothAvailabilityState();
    if (!kIsWeb && Platform.isIOS) {
      // on iOS we cannot programmatically enable Bluetooth, just open settings
      await UniversalBle.requestPermissions();
    } else if (!kIsWeb && Platform.isMacOS && currentState == AvailabilityState.unauthorized) {
      // The radio is on, but this app is not authorized for Bluetooth (macOS
      // gates Bluetooth per-app). Toggling the radio won't help — send the user
      // to the Bluetooth privacy pane where they can grant BikeControl access.
      await launchUrlString('x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth');
      await UniversalBle.requestPermissions();
    } else if (currentState == AvailabilityState.poweredOff) {
      if (Platform.isMacOS) {
        buildToast(title: name);
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
    // Distinguish "radio off" from "app not authorized" on macOS: when the
    // radio is on but this app lacks Bluetooth permission, relabel so the
    // requirement (and its action) point at System Settings, not a radio toggle.
    if (!kIsWeb && Platform.isMacOS && currentState == AvailabilityState.unauthorized) {
      name = AppLocalizations.current.bluetoothPermissionRequired;
    } else {
      name = AppLocalizations.current.bluetoothTurnedOn;
    }
    return status;
  }
}

class UnsupportedPlatform extends PlatformRequirement {
  UnsupportedPlatform()
    : super(
        kIsWeb
            ? AppLocalizations.current.browserNotSupported
            : AppLocalizations.current.platformNotSupported('platform'),
        icon: LucideIcons.circleAlert,
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
  ErrorRequirement(super.name, {required super.icon}) {
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
    icon: LucideIcons.monitorSmartphone,
  ),
  // A screen somewhere else — not a gamepad, which read as "controller".
  otherDevice(
    icon: LucideIcons.monitor,
  );

  final IconData icon;

  const Target({required this.icon});

  /// The targets worth offering for [app]. Everything, unless no button press
  /// can reach it on the device BikeControl runs on — then a second device is
  /// the only answer, and the picker says so by having nothing else in it.
  static List<Target> supportedFor(SupportedApp? app) =>
      app != null && !app.receivesButtonEvents ? const [Target.otherDevice] : Target.values;

  String getTitle(BuildContext context) {
    return switch (this) {
      Target.thisDevice => context.i18n.targetThisDevice,
      Target.otherDevice => context.i18n.targetOtherDevice,
    };
  }

  bool get isBeta {
    final supportedApp = core.settings.getTrainerApp();

    if (supportedApp is Zwift) {
      // everything is supported, this device is not compatible anyway
      return false;
    }

    return switch (this) {
      Target.thisDevice => false,
      _ =>
        supportedApp == null ||
            (!supportedApp.supports(AppConnectionMethod.obpBle) &&
                !supportedApp.supports(AppConnectionMethod.obpMdns) &&
                !supportedApp.supports(AppConnectionMethod.obpDirCon)),
    };
  }

  String getDescription(SupportedApp? app) {
    final l = AppLocalizations.current;
    if (app == null) {
      return switch (this) {
        Target.thisDevice => l.targetThisDeviceDescriptionNoApp,
        Target.otherDevice => l.targetOtherDeviceDescriptionNoApp,
      };
    }
    final viaOpenBikeControl =
        app.supports(AppConnectionMethod.obpBle) ||
        app.supports(AppConnectionMethod.obpMdns) ||
        app.supports(AppConnectionMethod.obpDirCon);
    return switch (this) {
      Target.thisDevice => l.runAppOnThisDevice(app.name),
      Target.otherDevice when viaOpenBikeControl => l.targetOtherDeviceDescriptionObc(app.name),
      Target.otherDevice when app is MyWhoosh => l.targetOtherDeviceDescriptionMyWhoosh(app.name),
      Target.otherDevice => l.targetOtherDeviceDescription(app.name),
    };
  }

  ConnectionType get connectionType {
    return switch (this) {
      Target.thisDevice when !kIsWeb && !HostPlatform.isIOS => ConnectionType.local,
      _ => ConnectionType.remote,
    };
  }
}
