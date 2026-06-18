import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:app_links/app_links.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/services/overlay/desktop_overlay_window.dart';
import 'package:bike_control/services/overlay/overlay_entry_point.dart' as overlay_entry;
import 'package:bike_control/utils/actions/android.dart';
import 'package:bike_control/utils/actions/desktop.dart';
import 'package:bike_control/utils/actions/remote.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/requirements/windows.dart';
import 'package:bike_control/widgets/menu.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as m;
import 'package:multi_window_native/multi_window_native.dart';
import 'package:prop/mdns/service_advertiser.dart';
import 'package:prop/utils/shared.dart' show Logger;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:window_manager/window_manager.dart' as wm;

import 'pages/navigation.dart';
import 'utils/actions/base_actions.dart';
import 'utils/core.dart';

final navigatorKey = GlobalKey<NavigatorState>();
var screenshotMode = false;

/// Locale to render in [screenshotMode]. Lets the screenshot test produce
/// localized store screenshots; defaults to English when unset.
Locale? screenshotLocale;

/// Android overlay isolate entry point. Must live in this library because
/// flutter_overlay_window's `DartEntrypoint(bundlePath, "overlayMain")` only
/// resolves symbols in the default Dart library (the one with `main()`).
/// `@pragma('vm:entry-point')` alone is not enough — the symbol also has to
/// be findable by the 2-arg DartEntrypoint constructor.
@pragma('vm:entry-point')
void overlayMain() {
  overlay_entry.runOverlayApp();
}

/// Convention used to identify the trainer-overlay sub-window. `main(args)`
/// receives this as the first arg when `MultiWindowNative.createWindow`
/// spawns a sub-process for the overlay.
const String kTrainerOverlayRoute = 'trainer-overlay';

@pragma('vm:entry-point')
Future<void> main(List<String> args) async {
  // Route Logger.recordError (app + prop) into print/persist from the start.
  installLoggerErrorListener();

  // Catch errors that happen in other isolates
  if (!kIsWeb) {
    Isolate.current.addErrorListener(
      RawReceivePort((dynamic pair) {
        final List<dynamic> errorAndStack = pair as List<dynamic>;
        final error = errorAndStack.first;
        final stack = errorAndStack.last as StackTrace?;
        recordError(error, stack, context: 'Isolate');
      }).sendPort,
    );
  }

  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Detect sub-window engine and dispatch to the overlay entry point before
      // doing any heavy bootstrap. multi_window_native re-runs main() with
      // kTrainerOverlayRoute as the first positional arg — this applies to
      // both macOS and Windows now that we use multi_window_native on both.
      if (!kIsWeb && (Platform.isMacOS || Platform.isWindows) &&
          args.contains(kTrainerOverlayRoute)) {
        await wm.windowManager.ensureInitialized();
        await wm.windowManager.waitUntilReadyToShow();
        final windowId = await wm.windowManager.getId();
        MultiWindowNative.init(windowId);
        await runDesktopOverlayWindow(windowId, args);
        return;
      }

      // Desktop and Android advertise mDNS via the in-process responder
      // (dedicated hostname with a single A record) instead of the OS
      // responder, which attaches every host address — including IPv6
      // link-locals that Mono-based trainer apps (TrainingPeaks) cannot
      // connect to ("No route to host"). On Android the responder's socket
      // acquires a WifiManager multicast lock so queries are received. iOS
      // stays on the OS responder (no multicast-networking entitlement).
      if (!kIsWeb) {
        ServiceAdvertiser.instance = ServiceAdvertiser.platformDefault();
      }

      // Catch Flutter framework errors (build/layout/paint)
      FlutterError.onError = (FlutterErrorDetails details) {
        _recordFlutterError(details);
        // Optionally forward to default behavior in debug:
        FlutterError.presentError(details);
      };

      // Catch errors from platform dispatcher (async)
      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        recordError(error, stack, context: 'PlatformDispatcher');
        // Return true means "handled"
        return true;
      };

      final error = await core.settings.init();

      if (error != null) {
        recordError(error, null, context: 'SettingsInit');
      } else {
        await core.shiftingConfigs.init();
      }

      // Initialise multi_window_native for the main window (macOS + Windows).
      if (!kIsWeb && (Platform.isMacOS || Platform.isWindows)) {
        try {
          await wm.windowManager.ensureInitialized();
          final mainWindowId = await wm.windowManager.getId();
          MultiWindowNative.init(mainWindowId);
        } catch (e, s) {
          recordError(e, s, context: 'MultiWindowNative.init(main)');
        }
      }

      runApp(BikeControlApp(error: error));
    },
    (Object error, StackTrace stack) {
      if (kDebugMode) {
        print('App crashed: $error');
        debugPrintStack(stackTrace: stack);
      }
      recordError(error, stack, context: 'Zone');
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

/// Record a handled error. Funnels through [Logger.recordError]; the listener
/// installed by [installLoggerErrorListener] prints and persists the entry
/// (which also feeds the debug log support chats attach).
Future<void> recordError(
  Object error,
  StackTrace? stack, {
  required String context,
}) async {
  installLoggerErrorListener();
  Logger.recordError(context, error, stack);
}

bool _loggerErrorListenerInstalled = false;

/// Wire [Logger.onRecordError] to the app's error pipeline — every
/// [Logger.recordError] (including calls from inside prop) prints in debug
/// builds and runs [_persistCrash], which both persists the crash entry and
/// feeds [Connection.lastLogEntries] — the "Logs:" section of the
/// support-chat / feedback debug text. Idempotent.
void installLoggerErrorListener() {
  if (_loggerErrorListenerInstalled) return;
  _loggerErrorListenerInstalled = true;
  Logger.onRecordError = (String message, Object error, StackTrace? stack) {
    if (kDebugMode) {
      print('Error in $message: $error');
      if (stack != null) {
        debugPrintStack(stackTrace: stack);
      }
    }
    unawaited(
      _persistCrash(
        type: 'dart',
        error: error.toString(),
        stack: stack,
        information: 'Context: $message',
      ),
    );
  };
}

Future<void> _persistCrash({
  required String type,
  required String error,
  StackTrace? stack,
  String? information,
}) async {
  try {
    core.connection.signalNotification(LogNotification('App crashed $type: $error${stack != null ? '\n$stack' : ''}'));

    final timestamp = DateTime.now().toIso8601String();
    final crashData = StringBuffer()
      ..writeln('--- $timestamp ---')
      ..writeln('Type: $type')
      ..writeln('Error: $error')
      ..writeln('Stack: ${stack ?? 'no stack'}')
      ..writeln('Info: ${information ?? ''}')
      ..writeln(await debugText())
      ..writeln()
      ..writeln();

    final directory = await _getLogDirectory();
    final file = File('${directory.path}/app.log');
    if (file.existsSync()) {
      final fileLength = await file.length();
      if (fileLength > 5 * 1024 * 1024) {
        // If log file exceeds 5MB, truncate it
        try {
          final lines = file.readAsLinesSync();
          final half = lines.length ~/ 2;
          final truncatedLines = lines.sublist(half);
          await file.writeAsString(truncatedLines.join('\n'));
        } catch (e) {
          if (kDebugMode) {
            print('Failed to truncate log file: $e');
          }
          file.deleteSync();
        }
      }
    }

    await file.writeAsString(crashData.toString(), mode: FileMode.append);
  } catch (error) {
    if (kDebugMode) {
      print('Failed to write crash log: $error');
    }
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

void initializeActions(ConnectionType connectionType) {
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

class BikeControlApp extends StatefulWidget {
  final Widget? customChild;
  final String? error;
  const BikeControlApp({super.key, this.error, this.customChild});

  @override
  State<BikeControlApp> createState() => _BikeControlAppState();
}

class _BikeControlAppState extends State<BikeControlApp> {
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    return ShadcnApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      menuHandler: OverlayHandler.popover,
      popoverHandler: OverlayHandler.popover,
      localizationsDelegates: [
        ...ShadcnLocalizations.localizationsDelegates,
        OtherLocalizationsDelegate(),
        AppLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      title: 'BikeControl',
      darkTheme: ThemeData(
        colorScheme: ColorSchemes.darkSlate.copyWith(
          card: () => Color(0xFF001A29),
          background: () => Color(0xFF232323),
          muted: () => Color(0xFF3A3A3A),
          border: () => Color(0xFF3A3A3A),
          secondary: () => Color(0xFF3A3A3A),
        ),
      ),
      locale: screenshotMode ? (screenshotLocale ?? const Locale('en')) : null,
      theme: ThemeData(
        colorScheme: ColorSchemes.lightSlate.copyWith(
          mutedForeground: () => Color(0xFFA1A1AA),
          primary: () => BKColor.main,
        ),
        typography: Typography.geist().scale(isMobile ? 0.9 : 1),
        radius: 0.7,
      ),
      materialTheme: MediaQuery.platformBrightnessOf(context) == Brightness.dark ? m.ThemeData.dark() : m.ThemeData(),
      //themeMode: ThemeMode.dark,
      home: widget.error != null
          ? Center(
              child: Text(
                'There was an error starting the App. Please contact support:\n${widget.error}',
                style: TextStyle(color: Colors.white),
              ),
            )
          : ToastLayer(
              key: ValueKey('Test'),
              padding: isMobile ? EdgeInsets.only(bottom: 60, left: 24, right: 24, top: 60) : null,
              child: m.Builder(
                builder: (context) {
                  return ComponentTheme<CardTheme>(
                    data: CardTheme(
                      borderWidth: 1.5,
                    ),
                    child: ComponentTheme<DividerTheme>(
                      data: Theme.of(context).brightness == Brightness.dark
                          ? DividerTheme(
                              color: Theme.of(context).colorScheme.border,
                            )
                          : DividerTheme(),
                      child: _Starter(
                        child: widget.customChild ?? Navigation(),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _Starter extends StatefulWidget {
  final Widget child;
  const _Starter({super.key, required this.child});

  @override
  State<_Starter> createState() => _StarterState();
}

class _StarterState extends State<_Starter> with WidgetsBindingObserver {
  final _appLinks = AppLinks();

  StreamSubscription<Uri>? _deeplinkSubscription;

  @override
  void initState() {
    super.initState();

    core.connection.initialize();
    core.reviewPromptService.start();
    WindowsProtocolHandler().registerForOutsideStoreBuild('bikecontrol');
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb && !screenshotMode) {
      // It will handle app links while the app is already started - be it in
      // the foreground or in the background.
      _deeplinkSubscription = _appLinks.uriLinkStream.listen(
        (Uri? uri) {
          if (uri != null) {
            if (uri.scheme == "bikecontrol") {
              IAPManager.instance.refreshEntitlementsOnAppStart();
            }
          }
        },
        onError: (Object err, StackTrace stackTrace) {
          if (kDebugMode) {
            print('Error handling deep link: $err');
            debugPrintStack(stackTrace: stackTrace);
          }
          recordError(err, stackTrace, context: 'DeepLink');
        },
      );
    }
    unawaited(IAPManager.instance.refreshEntitlementsOnAppStart());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _deeplinkSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(IAPManager.instance.refreshEntitlementsOnResume());
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class OtherLocalizationsDelegate extends LocalizationsDelegate<ShadcnLocalizations> {
  const OtherLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.delegate.supportedLocales.map((e) => e.languageCode).contains(locale.languageCode);

  @override
  Future<ShadcnLocalizations> load(Locale locale) async {
    return SynchronousFuture<ShadcnLocalizations>(lookupShadcnLocalizations(Locale('en')));
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<ShadcnLocalizations> old) => false;
}
