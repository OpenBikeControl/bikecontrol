import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:swift_control/bluetooth/devices/openbikecontrol/obc_ble_emulator.dart';
import 'package:swift_control/bluetooth/devices/openbikecontrol/obc_mdns_emulator.dart';
import 'package:swift_control/bluetooth/devices/openbikecontrol/protocol_parser.dart';
import 'package:swift_control/bluetooth/devices/zwift/ftms_mdns_emulator.dart';
import 'package:swift_control/bluetooth/devices/zwift/protocol/zp.pb.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_emulator.dart';
import 'package:swift_control/bluetooth/messages/notification.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/actions/android.dart';
import 'package:swift_control/utils/actions/base_actions.dart';
import 'package:swift_control/utils/actions/remote.dart';
import 'package:swift_control/utils/keymap/apps/my_whoosh.dart';
import 'package:swift_control/utils/requirements/android.dart';
import 'package:swift_control/utils/settings/settings.dart';
import 'package:universal_ble/universal_ble.dart';

import '../bluetooth/connection.dart';
import '../bluetooth/devices/mywhoosh/link.dart';
import 'requirements/multi.dart';
import 'requirements/platform.dart';

final core = Core();

class Core {
  late BaseActions actionHandler;
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final settings = Settings();
  final connection = Connection();

  late final whooshLink = WhooshLink();
  late final zwiftEmulator = ZwiftEmulator();
  late final zwiftMdnsEmulator = FtmsMdnsEmulator();
  late final obpMdnsEmulator = OpenBikeControlMdnsEmulator();
  late final obpBluetoothEmulator = OpenBikeControlBluetoothEmulator();

  late final logic = CoreLogic();
  late final permissions = Permissions();
}

class Permissions {
  Future<List<PlatformRequirement>> getScanRequirements() async {
    final List<PlatformRequirement> list;
    if (kIsWeb) {
      final availablity = await UniversalBle.getBluetoothAvailabilityState();
      if (availablity == AvailabilityState.unsupported) {
        list = [UnsupportedPlatform()];
      } else {
        list = [BluetoothTurnedOn()];
      }
    } else if (Platform.isMacOS) {
      list = [BluetoothTurnedOn()];
    } else if (Platform.isIOS) {
      list = [
        BluetoothTurnedOn(),
      ];
    } else if (Platform.isWindows) {
      list = [
        BluetoothTurnedOn(),
      ];
    } else if (Platform.isAndroid) {
      final deviceInfoPlugin = DeviceInfoPlugin();
      final deviceInfo = await deviceInfoPlugin.androidInfo;
      list = [
        BluetoothTurnedOn(),
        NotificationRequirement(),
        if (deviceInfo.version.sdkInt <= 30)
          LocationRequirement()
        else ...[
          BluetoothScanRequirement(),
          BluetoothConnectRequirement(),
        ],
      ];
    } else {
      list = [UnsupportedPlatform()];
    }

    await Future.wait(list.map((e) => e.getStatus()));
    return list.where((e) => !e.status).toList();
  }

  List<PlatformRequirement> getLocalControlRequirements() {
    return [Platform.isAndroid ? AccessibilityRequirement() : KeyboardRequirement()];
  }

  List<PlatformRequirement> getRemoteControlRequirements() {
    return [BluetoothTurnedOn(), if (Platform.isAndroid) BluetoothAdvertiseRequirement()];
  }
}

extension Granted on List<PlatformRequirement> {
  Future<bool> get allGranted async {
    await Future.wait(map((e) => e.getStatus()));
    return where((element) => !element.status).isEmpty;
  }
}

class CoreLogic {
  bool get showLocalControl {
    return core.settings.getLastTarget()?.connectionType == ConnectionType.local &&
        (Platform.isMacOS || Platform.isWindows || Platform.isAndroid);
  }

  bool get canRunAndroidService {
    return Platform.isAndroid && core.actionHandler is AndroidActions;
  }

  Future<bool> isAndroidServiceRunning() async {
    if (canRunAndroidService) {
      return (core.actionHandler as AndroidActions).accessibilityHandler.isRunning();
    }
    return false;
  }

  bool get isZwiftBleEnabled {
    return core.settings.getZwiftBleEmulatorEnabled() && showZwiftBleEmulator;
  }

  bool get isZwiftMdnsEnabled {
    return core.settings.getZwiftMdnsEmulatorEnabled() && showZwiftMsdnEmulator;
  }

  bool get isObpBleEnabled {
    return core.settings.getObpBleEnabled() && showObpBluetoothEmulator;
  }

  bool get isObpMdnsEnabled {
    return core.settings.getObpMdnsEnabled() && showObpMdnsEmulator;
  }

  bool get isMyWhooshLinkEnabled {
    return core.settings.getMyWhooshLinkEnabled() && showMyWhooshLink;
  }

  bool get showZwiftBleEmulator {
    return core.settings.getTrainerApp()?.supportsZwiftEmulation == true &&
        core.settings.getLastTarget() != Target.thisDevice;
  }

  bool get showZwiftMsdnEmulator {
    return core.settings.getTrainerApp()?.supportsZwiftEmulation == true;
  }

  bool get showObpMdnsEmulator {
    return core.settings.getTrainerApp()?.supportsOpenBikeProtocol == true;
  }

  bool get showObpBluetoothEmulator {
    return (core.settings.getTrainerApp()?.supportsOpenBikeProtocol == true) &&
        core.settings.getLastTarget() != Target.thisDevice;
  }

  bool get isRemoteControlEnabled {
    return core.settings.getRemoteControlEnabled() && showRemote;
  }

  bool get showMyWhooshLink =>
      core.settings.getTrainerApp() is MyWhoosh &&
      core.settings.getLastTarget() != null &&
      core.whooshLink.isCompatible(core.settings.getLastTarget()!);

  bool get showRemote => core.settings.getLastTarget() != Target.thisDevice && core.actionHandler is RemoteActions;

  bool get showForegroundMessage =>
      core.actionHandler is RemoteActions &&
      !kIsWeb &&
      Platform.isIOS &&
      (core.actionHandler as RemoteActions).isConnected;

  AppInfo? get obpConnectedApp => core.obpMdnsEmulator.isConnected.value ?? core.obpBluetoothEmulator.isConnected.value;

  bool get emulatorEnabled =>
      (core.settings.getMyWhooshLinkEnabled() && showMyWhooshLink) ||
      (core.settings.getZwiftBleEmulatorEnabled() && showZwiftBleEmulator) ||
      (core.settings.getZwiftMdnsEmulatorEnabled() && showZwiftMsdnEmulator) ||
      (core.settings.getObpBleEnabled() && showObpBluetoothEmulator) ||
      (core.settings.getObpMdnsEnabled() && showObpMdnsEmulator);

  bool get showObpActions =>
      (core.settings.getObpBleEnabled() && showObpBluetoothEmulator) ||
      (core.settings.getObpMdnsEnabled() && showObpMdnsEmulator);

  bool get ignoreWarnings =>
      core.settings.getTrainerApp()?.supportsZwiftEmulation == true ||
      core.settings.getTrainerApp()?.supportsOpenBikeProtocol == true;

  bool get showLocalRemoteOptions =>
      core.actionHandler.supportedModes.isNotEmpty &&
      ((showLocalControl && core.settings.getLocalEnabled()) ||
          (core.logic.showRemote && core.settings.getRemoteControlEnabled()));

  bool get hasNoConnectionMethod =>
      !core.logic.isZwiftBleEnabled &&
      !core.logic.isZwiftMdnsEnabled &&
      !core.logic.showObpActions &&
      !(core.settings.getMyWhooshLinkEnabled() && core.logic.showMyWhooshLink) &&
      !core.logic.showLocalRemoteOptions;

  Future<bool> isTrainerConnected() async {
    if (screenshotMode) {
      return true;
    } else if (showLocalControl) {
      if (canRunAndroidService) {
        return isAndroidServiceRunning();
      } else {
        return core.settings.getLocalEnabled();
      }
    } else if (showMyWhooshLink) {
      return core.whooshLink.isConnected.value;
    } else if (showObpMdnsEmulator) {
      return core.obpMdnsEmulator.isConnected.value != null;
    } else if (showObpBluetoothEmulator) {
      return core.obpBluetoothEmulator.isConnected.value != null;
    } else if (showZwiftBleEmulator) {
      return core.zwiftEmulator.isConnected.value;
    } else if (showZwiftMsdnEmulator) {
      return core.zwiftMdnsEmulator.isConnected.value == true;
    } else if (showRemote) {
      return (core.actionHandler as RemoteActions).isConnected;
    } else {
      return false;
    }
  }

  void initialize() async {
    if (screenshotMode) {
      return;
    }
    if (isZwiftBleEnabled && await core.permissions.getRemoteControlRequirements().allGranted) {
      core.zwiftEmulator.startAdvertising(() {}).catchError((e) {
        core.settings.setZwiftBleEmulatorEnabled(false);
        core.connection.signalNotification(
          AlertNotification(LogLevel.LOGLEVEL_WARNING, 'Failed to start Zwift mDNS Emulator: $e'),
        );
      });
    }
    if (isZwiftMdnsEnabled) {
      core.zwiftMdnsEmulator.startServer().catchError((e) {
        core.settings.setZwiftMdnsEmulatorEnabled(false);
        core.connection.signalNotification(
          AlertNotification(LogLevel.LOGLEVEL_WARNING, 'Failed to start Zwift mDNS Emulator: $e'),
        );
      });
    }
    if (isObpMdnsEnabled) {
      core.obpMdnsEmulator.startServer().catchError((e) {
        core.settings.setObpMdnsEnabled(false);
        core.connection.signalNotification(
          AlertNotification(LogLevel.LOGLEVEL_WARNING, 'Failed to start OpenBikeControl mDNS Emulator: $e'),
        );
      });
    }
    if (isObpBleEnabled && await core.permissions.getRemoteControlRequirements().allGranted) {
      core.obpBluetoothEmulator.startServer().catchError((e) {
        core.settings.setObpBleEnabled(false);
        core.connection.signalNotification(
          AlertNotification(LogLevel.LOGLEVEL_WARNING, 'Failed to start OpenBikeControl BLE Emulator: $e'),
        );
      });
    }

    if (isMyWhooshLinkEnabled) {
      core.connection.startMyWhooshServer();
    }

    if (isRemoteControlEnabled) {
      // TODO start remote control server
    }
  }
}
