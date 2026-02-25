import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:app_links/app_links.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/onboarding.dart';
import 'package:bike_control/utils/actions/android.dart';
import 'package:bike_control/utils/actions/desktop.dart';
import 'package:bike_control/utils/actions/remote.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/menu.dart';
import 'package:bike_control/widgets/testbed.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

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
        recordError(error, stack, context: 'Isolate');
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
        recordError(error, stack, context: 'PlatformDispatcher');
        // Return true means "handled"
        return true;
      };

      WidgetsFlutterBinding.ensureInitialized();

      final error = await core.settings.init();

      if (error != null) {
        recordError(error, null, context: 'SettingsInit');
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

Future<void> recordError(
  Object error,
  StackTrace? stack, {
  required String context,
}) async {
  if (kDebugMode) {
    print('Error in $context: $error');
    if (stack != null) {
      debugPrintStack(stackTrace: stack);
    }
  }
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
    core.connection.signalNotification(LogNotification('App crashed: $error'));
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
  final BCPage page;
  final String? error;
  const BikeControlApp({super.key, this.error, this.page = BCPage.devices, this.customChild});

  @override
  State<BikeControlApp> createState() => _BikeControlAppState();
}

class _BikeControlAppState extends State<BikeControlApp> {
  BCPage? _showPage;

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
        colorScheme: ColorSchemes.darkNeutral.copyWith(
          card: () => Color(0xFF001A29),
          background: () => Color(0xFF232323),
          muted: () => Color(0xFF3A3A3A),
          border: () => Color(0xFF3A3A3A),
        ),
      ),
      theme: ThemeData(
        colorScheme: ColorSchemes.lightNeutral.copyWith(
          card: () => BKColor.background,
        ),
      ),
      //themeMode: ThemeMode.light,
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
              child: _Starter(
                child: Stack(
                  children: [
                    widget.customChild ??
                        (AnimatedSwitcher(
                          duration: Duration(milliseconds: 600),
                          child: core.settings.getShowOnboarding()
                              ? OnboardingPage(
                                  onComplete: () {
                                    setState(() {
                                      if (core.obpMdnsEmulator.connectedApp.value == null) {
                                        _showPage = BCPage.trainer;
                                      } else {
                                        _showPage = BCPage.devices;
                                      }
                                    });
                                  },
                                )
                              : Navigation(page: _showPage ?? widget.page),
                        )),
                    Positioned.fill(child: Testbed()),
                  ],
                ),
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
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb) {
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
