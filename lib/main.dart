import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/gen/app_localizations.dart';
import 'package:swift_control/utils/actions/android.dart';
import 'package:swift_control/utils/actions/desktop.dart';
import 'package:swift_control/utils/actions/remote.dart';
import 'package:swift_control/widgets/menu.dart';
import 'package:swift_control/widgets/testbed.dart';

import 'pages/navigation.dart';
import 'utils/actions/base_actions.dart';
import 'utils/core.dart';

final navigatorKey = GlobalKey<NavigatorState>();
var screenshotMode = false;

void main() async {
  // setup crash reporting

  // Catch errors that happen in other isolates
  if (!kIsWeb) {
    Isolate.current.addErrorListener(
      RawReceivePort((dynamic pair) {
        final List<dynamic> errorAndStack = pair as List<dynamic>;
        final error = errorAndStack.first;
        final stack = errorAndStack.last as StackTrace?;
        _recordError(error, stack, context: 'Isolate');
      }).sendPort,
    );
  }

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

      final error = await core.settings.init();

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
    final fileLength = await file.length();
    if (fileLength > 5 * 1024 * 1024) {
      // If log file exceeds 5MB, truncate it
      final lines = await file.readAsLines();
      final half = lines.length ~/ 2;
      final truncatedLines = lines.sublist(half);
      await file.writeAsString(truncatedLines.join('\n'));
    }

    await file.writeAsString(crashData.toString(), mode: FileMode.append);
    core.connection.lastLogEntries.add((date: DateTime.now(), entry: 'App crashed: $error'));
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
    core.actionHandler = StubActions();
  } else if (Platform.isAndroid) {
    core.actionHandler = switch (connectionType) {
      ConnectionType.local => AndroidActions(),
      ConnectionType.remote => RemoteActions(),
      ConnectionType.unknown => StubActions(),
    };
  } else if (Platform.isIOS) {
    core.actionHandler = switch (connectionType) {
      ConnectionType.local => StubActions(),
      ConnectionType.remote => RemoteActions(),
      ConnectionType.unknown => StubActions(),
    };
  } else {
    core.actionHandler = switch (connectionType) {
      ConnectionType.local => DesktopActions(),
      ConnectionType.remote => RemoteActions(),
      ConnectionType.unknown => StubActions(),
    };
  }
  core.actionHandler.init(core.settings.getKeyMap());
}

class SwiftPlayApp extends StatelessWidget {
  final String? error;
  const SwiftPlayApp({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    return ShadcnApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      menuHandler: PopoverOverlayHandler(),
      popoverHandler: PopoverOverlayHandler(),
      title: AppLocalizations.current.appName,
      darkTheme: ThemeData(colorScheme: ColorSchemes.darkDefaultColor),
      theme: ThemeData(
        colorScheme: ColorSchemes.lightDefaultColor.copyWith(
          card: () => Color(0xFFFCFCFC),
        ),
      ),
      home: error != null
          ? Text(AppLocalizations.current.appStartError(error!))
          : ToastLayer(
              key: ValueKey('Test'),
              padding: isMobile ? EdgeInsets.only(bottom: 60, left: 24, right: 24, top: 60) : null,
              child: Stack(
                children: [
                  Navigation(),
                  Positioned.fill(child: Testbed()),
                ],
              ),
            ),
    );
  }
}
