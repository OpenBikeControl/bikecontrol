import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_emulator.dart';
import 'package:swift_control/utils/actions/base_actions.dart';
import 'package:swift_control/utils/settings/settings.dart';

import '../bluetooth/connection.dart';
import '../bluetooth/devices/link/link.dart';

final core = Core();

class Core {
  late BaseActions actionHandler;
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final settings = Settings();
  final whooshLink = WhooshLink();
  final connection = Connection();

  final zwiftEmulator = ZwiftEmulator();
}
