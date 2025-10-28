import 'dart:io';

import 'package:accessibility/accessibility.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:swift_control/pages/requirements.dart';
import 'package:swift_control/theme.dart';
import 'package:swift_control/utils/actions/android.dart';
import 'package:swift_control/utils/actions/desktop.dart';
import 'package:swift_control/utils/actions/remote.dart';
import 'package:swift_control/utils/settings/settings.dart';

import 'bluetooth/connection.dart';
import 'bluetooth/devices/link/link.dart';
import 'utils/actions/base_actions.dart';

final connection = Connection();
final navigatorKey = GlobalKey<NavigatorState>();
late BaseActions actionHandler;
final accessibilityHandler = Accessibility();
final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
final settings = Settings();
final whooshLink = WhooshLink();
const screenshotMode = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const SwiftPlayApp());
}

enum ConnectionType {
  unknown,
  local,
  remote,
  zwift,
}

Future<void> initializeActions(ConnectionType connectionType) async {
  if (kIsWeb) {
    actionHandler = StubActions();
  } else if (Platform.isAndroid) {
    actionHandler = switch (connectionType) {
      ConnectionType.local => AndroidActions(),
      ConnectionType.zwift => AndroidActions(),
      ConnectionType.remote => RemoteActions(),
      ConnectionType.unknown => StubActions(),
    };
  } else if (Platform.isIOS) {
    actionHandler = switch (connectionType) {
      ConnectionType.local => StubActions(),
      ConnectionType.zwift => StubActions(),
      ConnectionType.remote => RemoteActions(),
      ConnectionType.unknown => StubActions(),
    };
  } else {
    actionHandler = switch (connectionType) {
      ConnectionType.local => DesktopActions(),
      ConnectionType.zwift => DesktopActions(),
      ConnectionType.remote => RemoteActions(),
      ConnectionType.unknown => StubActions(),
    };
  }
  actionHandler.init(settings.getSupportedApp());
}

class SwiftPlayApp extends StatelessWidget {
  const SwiftPlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'SwiftControl',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      home: const RequirementsPage(),
    );
  }
}
