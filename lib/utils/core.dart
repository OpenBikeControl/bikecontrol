import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:keypress_simulator/keypress_simulator.dart';
import 'package:swift_control/bluetooth/devices/openbikeprotocol/obp_mdns_emulator.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_emulator.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/actions/android.dart';
import 'package:swift_control/utils/actions/base_actions.dart';
import 'package:swift_control/utils/actions/remote.dart';
import 'package:swift_control/utils/keymap/apps/my_whoosh.dart';
import 'package:swift_control/utils/settings/settings.dart';

import '../bluetooth/connection.dart';
import '../bluetooth/devices/link/link.dart';
import 'requirements/multi.dart';

final core = Core();

class Core {
  late BaseActions actionHandler;
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final settings = Settings();
  final connection = Connection();

  final whooshLink = WhooshLink();
  final zwiftEmulator = ZwiftEmulator();
  final obpMdnsEmulator = OpenBikeProtocolMdnsEmulator();

  final logic = CoreLogic();
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

  bool get shouldStartZwiftEmulator {
    return core.settings.getZwiftEmulatorEnabled() && showZwiftEmulator;
  }

  bool get showZwiftEmulator {
    return core.settings.getTrainerApp()?.supportsZwiftEmulation == true;
  }

  bool get showObpMdnsEmulator {
    return core.settings.getTrainerApp()?.supportsOpenBikeProtocol == true || kDebugMode;
  }

  bool get showMyWhooshLink =>
      core.settings.getTrainerApp() is MyWhoosh && core.whooshLink.isCompatible(core.settings.getLastTarget()!);

  bool get showRemote => core.settings.getLastTarget() != Target.thisDevice && core.actionHandler is RemoteActions;

  bool get showForegroundMessage =>
      core.actionHandler is RemoteActions &&
      !kIsWeb &&
      Platform.isIOS &&
      (core.actionHandler as RemoteActions).isConnected;

  Future<bool> isTrainerConnected() async {
    if (showLocalControl) {
      if (canRunAndroidService) {
        return isAndroidServiceRunning();
      } else {
        return await keyPressSimulator.isAccessAllowed();
      }
    } else if (showMyWhooshLink) {
      return core.whooshLink.isConnected.value;
    } else if (showObpMdnsEmulator) {
      return core.obpMdnsEmulator.isConnected.value != null;
    } else if (showZwiftEmulator) {
      return core.zwiftEmulator.isConnected.value;
    } else if (showRemote && core.actionHandler is RemoteActions) {
      return (core.actionHandler as RemoteActions).isConnected;
    } else {
      return false;
    }
  }
}
