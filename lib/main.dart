import 'dart:io';

import 'package:accessibility/accessibility.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:swift_control/pages/requirements.dart';
import 'package:swift_control/theme.dart';
import 'package:swift_control/utils/actions/android.dart';
import 'package:swift_control/utils/actions/desktop.dart';
import 'package:swift_control/utils/actions/link.dart';
import 'package:swift_control/utils/actions/remote.dart';
import 'package:swift_control/utils/settings/settings.dart';

import 'bluetooth/connection.dart';
import 'link/link.dart';
import 'utils/actions/base_actions.dart';

final connection = Connection();
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
  local,
  remote,
  link,
}

Future<void> initializeActions(ConnectionType connectionType) async {
  if (kIsWeb) {
    actionHandler = StubActions();
  } else if (Platform.isAndroid) {
    actionHandler = switch (connectionType) {
      ConnectionType.local => AndroidActions(),
      ConnectionType.remote => RemoteActions(),
      ConnectionType.link => LinkActions(),
    };
  } else if (Platform.isIOS) {
    actionHandler = switch (connectionType) {
      ConnectionType.local => throw UnimplementedError('Local actions are not supported on iOS'),
      ConnectionType.remote => RemoteActions(),
      ConnectionType.link => LinkActions(),
    };
  } else {
    actionHandler = switch (connectionType) {
      ConnectionType.local => DesktopActions(),
      ConnectionType.remote => RemoteActions(),
      ConnectionType.link => LinkActions(),
    };
  }
}

class SwiftPlayApp extends StatelessWidget {
  const SwiftPlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SwiftControl',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      home: const RequirementsPage(),
    );
  }
}
