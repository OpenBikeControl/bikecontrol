import 'dart:io';

import 'package:accessibility/accessibility.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:swift_control/pages/requirements.dart';
import 'package:swift_control/theme.dart';
import 'package:swift_control/utils/actions/android.dart';
import 'package:swift_control/utils/actions/desktop.dart';
import 'package:swift_control/utils/settings/settings.dart';

import 'bluetooth/connection.dart';
import 'utils/actions/base_actions.dart';

final connection = Connection();
late final BaseActions actionHandler;
final accessibilityHandler = Accessibility();
final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
final settings = Settings();

void main() {
  if (kIsWeb) {
    actionHandler = StubActions();
  } else if (Platform.isAndroid) {
    actionHandler = AndroidActions();
  } else {
    actionHandler = DesktopActions();
  }

  runApp(const SwiftPlayApp());
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
      themeMode: ThemeMode.system,
      home: const RequirementsPage(),
    );
  }
}
