import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:swift_control/pages/requirements.dart';
import 'package:swift_control/theme.dart';
import 'package:swift_control/utils/actions/android.dart';
import 'package:swift_control/utils/actions/desktop.dart';
import 'package:swift_control/utils/actions/remote.dart';
import 'package:swift_control/utils/settings/settings.dart';
import 'package:swift_control/widgets/menu.dart';

import 'bluetooth/connection.dart';
import 'bluetooth/devices/link/link.dart';
import 'utils/actions/base_actions.dart';

final connection = Connection();
final navigatorKey = GlobalKey<NavigatorState>();
late BaseActions actionHandler;
final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
final settings = Settings();
final whooshLink = WhooshLink();
var screenshotMode = false;

void main() async {
  // setup crash reporting

  // Catch errors that happen in other isolates
  Isolate.current.addErrorListener(
    RawReceivePort((dynamic pair) {
      final List<dynamic> errorAndStack = pair as List<dynamic>;
      final error = errorAndStack.first;
      final stack = errorAndStack.last as StackTrace?;
      _recordError(error, stack, context: 'Isolate');
    }).sendPort,
  );

  runZonedGuarded<Future<void>>(
    () async {
      // Catch Flutter framework errors (build/layout/paint)
      FlutterError.onError = (FlutterErrorDetails details) {
        _recordFlutterError(details);
        // Optionally forward to default behavior in debug:
        FlutterError.presentError(details);
      };

      // Catch errors from platform dispatcher (async)
      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        _recordError(error, stack, context: 'PlatformDispatcher');
        // Return true means "handled"
        return true;
      };

      WidgetsFlutterBinding.ensureInitialized();

      final error = await settings.init();

      runApp(SwiftPlayApp(error: error));
    },
    (Object error, StackTrace stack) {
      // Zone-level uncaught errors (async, timers, futures)
      _recordError(error, stack, context: 'Zone');
    },
  );
}

Future<void> _recordFlutterError(FlutterErrorDetails details) async {
  await _persistCrash(
    type: 'flutter',
    error: details.exceptionAsString(),
    stack: details.stack,
    information: details.informationCollector?.call().join('\n'),
  );
}

Future<void> _recordError(
  Object error,
  StackTrace? stack, {
  required String context,
}) async {
  await _persistCrash(
    type: 'dart',
    error: error.toString(),
    stack: stack,
    information: 'Context: $context',
  );
}

Future<void> _persistCrash({
  required String type,
  required String error,
  StackTrace? stack,
  String? information,
}) async {
  try {
    final timestamp = DateTime.now().toIso8601String();
    final crashData = StringBuffer()
      ..writeln('--- $timestamp ---')
      ..writeln('Type: $type')
      ..writeln('Error: $error')
      ..writeln('Stack: ${stack ?? 'no stack'}')
      ..writeln('Info: ${information ?? ''}')
      ..writeln(debugText())
      ..writeln()
      ..writeln();

    final directory = await _getLogDirectory();
    final file = File('${directory.path}/app.logs');
    await file.writeAsString(crashData.toString(), mode: FileMode.append);
  } catch (_) {
    // Avoid throwing from the crash logger
  }
}

// Minimal implementation; customize per platform if needed.
Future<Directory> _getLogDirectory() async {
  // On mobile, you might choose applicationDocumentsDirectory via platform channel,
  // but staying pure Dart, use currentDirectory as a placeholder.
  return Directory.current;
}

enum ConnectionType {
  unknown,
  local,
  remote,
}

Future<void> initializeActions(ConnectionType connectionType) async {
  if (kIsWeb) {
    actionHandler = StubActions();
  } else if (Platform.isAndroid) {
    actionHandler = switch (connectionType) {
      ConnectionType.local => AndroidActions(),
      ConnectionType.remote => RemoteActions(),
      ConnectionType.unknown => StubActions(),
    };
  } else if (Platform.isIOS) {
    actionHandler = switch (connectionType) {
      ConnectionType.local => StubActions(),
      ConnectionType.remote => RemoteActions(),
      ConnectionType.unknown => StubActions(),
    };
  } else {
    actionHandler = switch (connectionType) {
      ConnectionType.local => DesktopActions(),
      ConnectionType.remote => RemoteActions(),
      ConnectionType.unknown => StubActions(),
    };
  }
  actionHandler.init(settings.getKeyMap());
}

class SwiftPlayApp extends StatelessWidget {
  final String? error;
  const SwiftPlayApp({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'BikeControl',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: error != null
          ? Text('There was an error starting the App. Please contact support:\n$error')
          : const RequirementsPage(),
    );
  }
}
