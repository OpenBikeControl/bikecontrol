import 'dart:io';

import 'package:bike_control/bluetooth/devices/openbikecontrol/obc_ble_emulator.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/obc_mdns_emulator.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/protocol_parser.dart';
import 'package:bike_control/bluetooth/devices/trainer_connection.dart';
import 'package:bike_control/bluetooth/devices/zwift/ftms_mdns_emulator.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_emulator.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/bluetooth/remote_keyboard_pairing.dart';
import 'package:bike_control/bluetooth/remote_pairing.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/utils/actions/android.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/actions/remote.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/requirements/android.dart';
import 'package:bike_control/utils/settings/settings.dart';
import 'package:dartx/dartx.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:prop/prop.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../bluetooth/connection.dart';
import '../bluetooth/devices/mywhoosh/link.dart';
import 'keymap/apps/rouvy.dart';
import 'media_key_handler.dart';
import 'requirements/multi.dart';
import 'requirements/platform.dart';

final core = Core();

class Core {
  late BaseActions actionHandler;
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final settings = Settings();
  final connection = Connection();

  late final supabase = Supabase.instance.client;
  late final whooshLink = WhooshLink();
  late final zwiftEmulator = ZwiftEmulator();
  late final zwiftMdnsEmulator = FtmsMdnsEmulator();
  late final obpMdnsEmulator = OpenBikeControlMdnsEmulator();
  late final obpBluetoothEmulator = OpenBikeControlBluetoothEmulator();
  late final remotePairing = RemotePairing();
  late final remoteKeyboardPairing = RemoteKeyboardPairing();

  late final mediaKeyHandler = MediaKeyHandler();
  late final logic = CoreLogic();
  late final permissions = Permissions();
}

class Permissions {
  Future<List<PlatformRequirement>> getScanRequirements() async {
    final List<PlatformRequirement> list;
    if (screenshotMode) {
      list = [];
    } else if (kIsWeb) {
      final availablity = await UniversalBle.getBluetoothAvailabilityState();
      if (availablity == AvailabilityState.unsupported) {
        list = [UnsupportedPlatform()];
      } else {
        list = [BluetoothTurnedOn()];
      }
    } else if (Platform.isMacOS) {
      list = [
        BluetoothTurnedOn(),
        if (core.settings.getShowOnboarding()) NotificationRequirement(),
      ];
    } else if (Platform.isIOS) {
      list = [
        BluetoothTurnedOn(),
        NotificationRequirement(),
      ];
    } else if (Platform.isWindows) {
      list = [
        BluetoothTurnedOn(),
        NotificationRequirement(),
      ];
    } else if (Platform.isAndroid) {
      final deviceInfoPlugin = DeviceInfoPlugin();
      final deviceInfo = await deviceInfoPlugin.androidInfo;
      list = [
        if (deviceInfo.version.sdkInt <= 30)
          LocationRequirement()
        else ...[
          BluetoothScanRequirement(),
          BluetoothConnectRequirement(),
        ],
        BluetoothTurnedOn(),
        NotificationRequirement(),
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
    return [
      BluetoothTurnedOn(),
      if (Platform.isAndroid) ...[
        BluetoothScanRequirement(),
        BluetoothConnectRequirement(),
        BluetoothAdvertiseRequirement(),
      ],
    ];
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
    return core.settings.getTrainerApp()?.supportsZwiftEmulation == true && core.settings.getTrainerApp() is! Rouvy;
  }

  bool get showObpMdnsEmulator {
    return core.settings.getTrainerApp()?.supportsOpenBikeProtocol.containsAny([
          OpenBikeProtocolSupport.network,
          OpenBikeProtocolSupport.dircon,
        ]) ==
        true;
  }

  bool get showObpBluetoothEmulator {
    return (core.settings.getTrainerApp()?.supportsOpenBikeProtocol.contains(OpenBikeProtocolSupport.ble) == true) &&
        core.settings.getLastTarget() != Target.thisDevice;
  }

  bool get isRemoteControlEnabled {
    return core.settings.getRemoteControlEnabled() && showRemote;
  }

  bool get isRemoteKeyboardControlEnabled {
    return core.settings.getRemoteKeyboardControlEnabled() && showRemote;
  }

  bool get showMyWhooshLink =>
      core.settings.getTrainerApp() is MyWhoosh &&
      core.settings.getLastTarget() != null &&
      core.whooshLink.isCompatible(core.settings.getLastTarget()!);

  bool get showRemote => core.settings.getLastTarget() != Target.thisDevice && core.actionHandler is RemoteActions;

  bool get showForegroundMessage =>
      core.actionHandler is RemoteActions && !kIsWeb && Platform.isIOS && core.remotePairing.isConnected.value;

  AppInfo? get obpConnectedApp =>
      core.obpMdnsEmulator.connectedApp.value ?? core.obpBluetoothEmulator.connectedApp.value;

  bool get emulatorEnabled =>
      screenshotMode ||
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
      core.settings.getTrainerApp()?.supportsOpenBikeProtocol.isNotEmpty == true;

  bool get showLocalRemoteOptions =>
      core.actionHandler.supportedModes.isNotEmpty &&
      (showLocalControl || isRemoteControlEnabled || isRemoteKeyboardControlEnabled);

  bool get hasNoConnectionMethod =>
      !screenshotMode &&
      !isZwiftBleEnabled &&
      !isZwiftMdnsEnabled &&
      !showObpActions &&
      !(core.settings.getMyWhooshLinkEnabled() && showMyWhooshLink) &&
      !showLocalRemoteOptions;

  bool get hasRecommendedConnectionMethods =>
      showObpBluetoothEmulator ||
      showObpMdnsEmulator ||
      showLocalControl ||
      showZwiftBleEmulator ||
      showZwiftMsdnEmulator ||
      showMyWhooshLink;

  List<TrainerConnection> get connectedTrainerConnections => [
    if (isMyWhooshLinkEnabled) core.whooshLink,
    if (isObpMdnsEnabled) core.obpMdnsEmulator,
    if (isObpBleEnabled) core.obpBluetoothEmulator,
    if (isZwiftBleEnabled) core.zwiftEmulator,
    if (isZwiftMdnsEnabled) core.zwiftMdnsEmulator,
    if (isRemoteControlEnabled) core.remotePairing,
    if (isRemoteKeyboardControlEnabled) core.remoteKeyboardPairing,
  ].filter((e) => e.isConnected.value).toList();

  List<TrainerConnection> get enabledTrainerConnections => [
    if (isMyWhooshLinkEnabled) core.whooshLink,
    if (isObpMdnsEnabled) core.obpMdnsEmulator,
    if (isObpBleEnabled) core.obpBluetoothEmulator,
    if (isZwiftBleEnabled) core.zwiftEmulator,
    if (isZwiftMdnsEnabled) core.zwiftMdnsEmulator,
    if (isRemoteControlEnabled) core.remotePairing,
    if (isRemoteKeyboardControlEnabled) core.remoteKeyboardPairing,
  ];

  List<TrainerConnection> get trainerConnections => [
    if (showMyWhooshLink) core.whooshLink,
    if (showObpMdnsEmulator) core.obpMdnsEmulator,
    if (showObpBluetoothEmulator) core.obpBluetoothEmulator,
    if (showZwiftBleEmulator) core.zwiftEmulator,
    if (showZwiftMsdnEmulator) core.zwiftMdnsEmulator,
    if (showRemote) core.remotePairing,
    if (showRemote) core.remoteKeyboardPairing,
  ];

  Future<bool> isTrainerConnected() async {
    if (screenshotMode) {
      return true;
    } else if (showLocalControl && core.settings.getLocalEnabled()) {
      if (canRunAndroidService) {
        return isAndroidServiceRunning();
      } else {
        return true;
      }
    } else if (connectedTrainerConnections.isNotEmpty) {
      return true;
    } else {
      return false;
    }
  }

  void startEnabledConnectionMethod() async {
    if (screenshotMode) {
      return;
    }
    if (isZwiftBleEnabled &&
        await core.permissions.getRemoteControlRequirements().allGranted &&
        !core.zwiftEmulator.isStarted.value) {
      core.zwiftEmulator.startAdvertising(() {}).catchError((e, s) {
        recordError(e, s, context: 'Zwift BLE Emulator');
        core.settings.setZwiftBleEmulatorEnabled(false);
        core.connection.signalNotification(
          AlertNotification(LogLevel.LOGLEVEL_WARNING, 'Failed to start Zwift mDNS Emulator: $e'),
        );
      });
    }
    if (isZwiftMdnsEnabled && !core.zwiftMdnsEmulator.isStarted.value) {
      core.zwiftMdnsEmulator.startServer().catchError((e, s) {
        recordError(e, s, context: 'Zwift mDNS Emulator');
        core.settings.setZwiftMdnsEmulatorEnabled(false);
        core.connection.signalNotification(
          AlertNotification(LogLevel.LOGLEVEL_WARNING, 'Failed to start Zwift mDNS Emulator: $e'),
        );
      });
    }
    if (isObpMdnsEnabled && !core.obpMdnsEmulator.isStarted.value) {
      core.obpMdnsEmulator.startServer().catchError((e, s) {
        recordError(e, s, context: 'OBP mDNS Emulator');
        core.settings.setObpMdnsEnabled(false);
        core.connection.signalNotification(
          AlertNotification(LogLevel.LOGLEVEL_WARNING, 'Failed to start OpenBikeControl mDNS Emulator: $e'),
        );
      });
    }
    if (isObpBleEnabled &&
        await core.permissions.getRemoteControlRequirements().allGranted &&
        !core.obpBluetoothEmulator.isStarted.value) {
      core.obpBluetoothEmulator.startServer().catchError((e, s) {
        recordError(e, s, context: 'OBP BLE Emulator');
        core.settings.setObpBleEnabled(false);
        core.connection.signalNotification(
          AlertNotification(LogLevel.LOGLEVEL_WARNING, 'Failed to start OpenBikeControl BLE Emulator: $e'),
        );
      });
    }

    if (isMyWhooshLinkEnabled && !core.whooshLink.isStarted.value) {
      core.connection.startMyWhooshServer();
    }

    if (isRemoteControlEnabled && !core.remotePairing.isStarted.value) {
      core.remotePairing.startAdvertising().catchError((e, s) {
        recordError(e, s, context: 'Remote Pairing');
        core.settings.setRemoteControlEnabled(false);
        core.connection.signalNotification(
          AlertNotification(LogLevel.LOGLEVEL_WARNING, 'Failed to start Remote Control pairing: $e'),
        );
      });
    }

    if (isRemoteKeyboardControlEnabled && !core.remoteKeyboardPairing.isStarted.value) {
      core.remoteKeyboardPairing.startAdvertising().catchError((e, s) {
        recordError(e, s, context: 'Remote Keyboard Pairing');
        core.settings.setRemoteKeyboardControlEnabled(false);
        core.connection.signalNotification(
          AlertNotification(LogLevel.LOGLEVEL_WARNING, 'Failed to start Remote Keyboard Control pairing: $e'),
        );
      });
    }
  }
}
