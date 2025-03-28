import 'package:accessibility/accessibility.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:swift_control/pages/requirements.dart';
import 'package:swift_control/theme.dart';
import 'package:swift_control/utils/connection.dart';

import 'utils/actions/base_actions.dart';

final connection = Connection();
final actionHandler = ActionHandler();
final accessibilityHandler = Accessibility();
final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() {
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
