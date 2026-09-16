import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:app_links/app_links.dart';
import 'package:bike_control/bluetooth/emulation/emulated_ble_platform.dart';
import 'package:bike_control/bluetooth/emulation/real_ble_platform.dart';
import 'package:bike_control/bluetooth/emulation/routing_ble_platform.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/services/overlay/desktop_overlay_window.dart';
import 'package:bike_control/services/overlay/overlay_entry_point.dart' as overlay_entry;
import 'package:bike_control/utils/actions/android.dart';
import 'package:bike_control/utils/actions/desktop.dart';
import 'package:bike_control/utils/actions/remote.dart';
import 'package:bike_control/utils/analytics/install_referrer_reporter.dart';
import 'package:bike_control/utils/demo_mode.dart';
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
import 'package:universal_ble/universal_ble.dart';
import 'package:window_manager/window_manager.dart' as wm;
import 'package:bike_control/services/app_update.dart';
import 'package:bike_control/widgets/title.dart' show packageInfoValue;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'pages/navigation.dart';
import 'utils/actions/base_actions.dart';
import 'utils/core.dart';

final navigatorKey = GlobalKey<NavigatorState>();
var screenshotMode = false;

/// True while the onboarding wizard route is on screen — toasts lift above
/// its sticky footer on mobile (see lib/widgets/ui/toast.dart).
var onboardingActive = false;

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

      // Debug builds route BLE through the emulation-capable platform so the
      // "Emulate device" menu can add fake peripherals next to real hardware.
      // Must run before Connection.initialize() — universal_ble callbacks
      // live on the platform instance.
      if (kDebugMode) {
        final emulatedBle = FakeUniversalBlePlatform();
        UniversalBle.setInstance(RoutingBlePlatform(real: createRealBlePlatform(), fake: emulatedBle));
        core.emulation.attach(emulatedBle);
      }

      // Detect sub-window engine and dispatch to the overlay entry point before
      // doing any heavy bootstrap. multi_window_native re-runs main() with
      // kTrainerOverlayRoute as the first positional arg — this applies to
      // both macOS and Windows now that we use multi_window_native on both.
      if (!kIsWeb && (Platform.isMacOS || Platform.isWindows) && args.contains(kTrainerOverlayRoute)) {
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

      // Start buffering the log before the bootstrap runs so any handled error
      // during startup (settings.init, plugin init) lands in lastLogEntries —
      // otherwise it's only wired in Connection.initialize(), which never runs
      // on the startup-recovery path, and the support mail ships empty logs.
      core.connection.startLogCapture();

      // Mount the app shell immediately and let it bootstrap itself. Blocking
      // on core.settings.init() (notifications, window_manager, Supabase, IAP,
      // sync) before runApp means a single plugin call that stalls in a release
      // build leaves the window black forever — the "won't launch" report.
      // BikeControlApp paints its themed shell from the first frame, shows a
      // splash while it initialises, then swaps in the real content in-place —
      // one app root throughout, so no black flash between splash and app.
      runApp(const BikeControlApp());
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

/// Whether an error [context] represents a genuinely uncaught failure (caught
/// only by the app's top-level guards) rather than an error that was handled in
/// a try/catch and merely funneled through [recordError]. Controls only the log
/// label: a handled error must not read as "App crashed" in support logs.
bool isFatalErrorContext(String context) => const {'Zone', 'PlatformDispatcher', 'Isolate'}.contains(context);

/// Whether [uri] is a Supabase OAuth callback that must be exchanged into a
/// session. Mirrors supabase_flutter's private `_isAuthCallbackDeeplink`
/// (without its auth-flow-type gating): the browser hands "Sign in with Apple"
/// (and Google / GitHub / Facebook) back as `bikecontrol://login/` carrying
/// either a PKCE `code` query param, an implicit `access_token` fragment, or an
/// `error_description` fragment.
///
/// Used by the desktop cold-start path in [_StarterState]: supabase_flutter
/// exchanges the *live* callback (app already running) on all non-web
/// platforms, but its cold-start `_handleInitialUri` is gated to `kIsWeb`, so
/// on Windows/macOS/Linux a callback that arrives as the initial deep link —
/// the exact repro when the user closes the app before completing sign-in — is
/// otherwise dropped and the session never established.
bool isSupabaseAuthCallbackUri(Uri uri) {
  return uri.fragment.contains('access_token') ||
      uri.queryParameters.containsKey('code') ||
      uri.fragment.contains('error_description');
}

/// Desktop cold-start handler for the OAuth callback deep link.
///
/// Closes the supabase_flutter gap described on [isSupabaseAuthCallbackUri] by
/// exchanging the *initial* link ourselves — exactly once — when the app was
/// NOT already running. The PKCE `code_verifier` persists in Supabase's local
/// storage, so a freshly launched instance can complete the exchange.
///
/// Deliberately does NOT touch the live `uriLinkStream` handler:
/// supabase_flutter already exchanges the live callback on non-web platforms,
/// and calling [exchangeSession] a second time would try to redeem an
/// already-consumed `code` and error.
///
/// Dependencies are injected as callbacks so the decision (exchange vs skip)
/// is unit-testable without booting Flutter or Supabase.
Future<void> handleDesktopColdStartAuthCallback({
  required Future<Uri?> Function() getInitialLink,
  required Future<void> Function(Uri uri) exchangeSession,
  required Future<void> Function() onSessionEstablished,
  Future<void> Function(Object error, StackTrace stack)? onError,
}) async {
  Uri? uri;
  try {
    uri = await getInitialLink();
  } catch (e, s) {
    await onError?.call(e, s);
    return;
  }

  if (uri == null || uri.scheme != 'bikecontrol' || !isSupabaseAuthCallbackUri(uri)) {
    return;
  }

  try {
    await exchangeSession(uri);
    await onSessionEstablished();
  } catch (e, s) {
    await onError?.call(e, s);
  }
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
        fatal: isFatalErrorContext(message),
        error: error.toString(),
        stack: stack,
        information: 'Context: $message',
      ),
    );
  };
}

/// True while [_persistCrash] is gathering [debugText] for an entry. An error
/// recorded in that window — above all `debugText.diagnostics` timing out
/// because the diagnostics gather hangs — is still logged and persisted, but
/// without a debug text of its own: gathering again would hang and time out
/// the same way, record the next timeout, and repeat every 6 s for the rest of
/// the process.
bool _gatheringCrashDebugText = false;

Future<void> _persistCrash({
  required String type,
  required String error,
  bool fatal = false,
  StackTrace? stack,
  String? information,
}) async {
  try {
    // Only genuinely-uncaught errors read as "App crashed"; handled errors
    // (caught + recorded) read as "Handled error" so support logs aren't
    // misread as crashes.
    final label = fatal ? 'App crashed' : 'Handled error';
    core.connection.signalNotification(LogNotification('$label $type: $error${stack != null ? '\n$stack' : ''}'));

    final timestamp = DateTime.now().toIso8601String();
    String debugTextValue;
    if (_gatheringCrashDebugText) {
      debugTextValue = 'Debug text: skipped (recorded while another crash entry was gathering it)';
    } else {
      _gatheringCrashDebugText = true;
      try {
        // A limit of its own, above debugText's 3 s + 6 s, so the guard is
        // released even if debugText ever awaits something without one.
        debugTextValue = await debugText(includeDiscovery: false).timeout(const Duration(seconds: 12));
      } catch (e, s) {
        // The guard is still set, so this entry is persisted without a gather.
        recordError(e, s, context: 'persistCrash.debugText');
        debugTextValue = 'Exception $e';
      } finally {
        _gatheringCrashDebugText = false;
      }
    }
    final crashData = StringBuffer()
      ..writeln('--- $timestamp ---')
      ..writeln('Type: $type')
      ..writeln('Error: $error')
      ..writeln('Stack: ${stack ?? 'no stack'}')
      ..writeln('Info: ${information ?? ''}')
      ..writeln(debugTextValue)
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
    // Avoid throwing from the crash logger. A plain recordError here would
    // loop: a write that keeps failing re-enters this function once per
    // failure. Forwarding it behind a guard, like the debug-text one above,
    // is a possible follow-up.
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
  // The keymap ('app') and the trainer app ('trainer_app') are independent
  // prefs. If the keymap one is missing we'd otherwise run with a null
  // supportedApp: no buttons get registered and every press errors out.
  core.actionHandler.init(core.settings.getKeyMap() ?? core.settings.getTrainerApp());
}

/// Shown when the app can't finish starting up. Offers the two things that
/// actually recover it — installing a waiting update (a Shorebird patch or a
/// store version) and mailing the diagnostic logs to support. Kept English-only
/// and self-contained so it stays dependable on the failure path.
class _StartupRecovery extends StatefulWidget {
  const _StartupRecovery({this.error});

  final Object? error;

  @override
  State<_StartupRecovery> createState() => _StartupRecoveryState();
}

class _StartupRecoveryState extends State<_StartupRecovery> {
  static const _supportEmail = 'support@bikecontrol.app';
  static const _ink = Color(0xFF10202B);
  static const _muted = Color(0xFF44586A);

  bool _checking = false;
  bool _checked = false;
  AppUpdate? _update;

  @override
  void initState() {
    super.initState();
    // Look for an update straight away — the most common fix is a patch that is
    // already downloaded and one restart away.
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    setState(() => _checking = true);
    AppUpdate? update;
    try {
      update = await checkForAppUpdate().timeout(const Duration(seconds: 15));
    } catch (e, s) {
      recordError(e, s, context: 'Recovery update check');
    }
    if (!mounted) return;
    setState(() {
      _checking = false;
      _checked = true;
      _update = update;
    });
  }

  /// Assemble a diagnostic report that is safe to build on the startup-failure
  /// path. The app isn't initialised here, so [debugText] often throws a
  /// LateInitializationError — every piece is guarded independently so one
  /// failure can't blank the whole report, and the actual startup failure and
  /// the captured logs are always included even if the full bundle can't be.
  Future<String> _gatherDiagnostics() async {
    final buffer = StringBuffer();

    // The failure itself — the single most useful line, always first.
    buffer.writeln('Startup failure: ${widget.error ?? 'timed out before the app finished starting'}');

    try {
      buffer.writeln('Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
    } catch (_) {}
    try {
      final version = packageInfoValue?.version;
      if (version != null) buffer.writeln('App Version: $version');
    } catch (_) {}

    // Logs captured since startup: startLogCapture() runs before the bootstrap,
    // so a handled error during init (with its stack) lands here even when the
    // app never mounted.
    try {
      final entries = core.connection.lastLogEntries;
      if (entries.isNotEmpty) {
        buffer.writeln('\nLogs:');
        for (final e in entries) {
          buffer.writeln('${e.date.toString().split('.').first} - ${e.entry}');
        }
      }
    } catch (_) {}

    // The full bundle. debugText() is defensive (each field guarded, awaited
    // calls bounded), so it returns even half-initialised; the outer timeout is
    // a last resort so the mail button can never hang.
    try {
      final full = await debugText(includeDiscovery: false).timeout(const Duration(seconds: 12));
      buffer.writeln('\n$full');
    } catch (e) {
      buffer.writeln('\n(full diagnostics unavailable: $e)');
    }

    return buffer.toString();
  }

  Future<void> _emailSupport() async {
    final logs = await _gatherDiagnostics();
    final version = packageInfoValue?.version ?? '';
    final subject = Uri.encodeComponent("BikeControl won't start${version.isEmpty ? '' : ' ($version)'}");
    final body = Uri.encodeComponent('Describe what happened here.\n\n--- diagnostic logs ---\n$logs');
    final mail = Uri.parse('mailto:$_supportEmail?subject=$subject&body=$body');
    try {
      if (await launchUrl(mail)) return;
    } catch (_) {}
    // Some desktop mail clients reject long mailto bodies — fall back to
    // sharing the logs as a file the rider can attach to a mail by hand.
    await _shareLogs(logs);
  }

  Future<void> _shareLogs(String logs) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/bikecontrol-startup-logs.txt');
      await file.writeAsString(logs);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'BikeControl startup logs',
          text: 'Please send to $_supportEmail',
        ),
      );
    } catch (e, s) {
      recordError(e, s, context: 'Recovery share logs');
    }
  }

  Widget _updateSection() {
    if (_checking) {
      return const Row(
        children: [
          SizedBox(width: 18, height: 18, child: m.CircularProgressIndicator(strokeWidth: 2, color: BKColor.main)),
          SizedBox(width: 12),
          Text('Checking for updates…', style: TextStyle(color: _muted)),
        ],
      );
    }
    final update = _update;
    if (update != null) {
      final label = update.isPatch ? 'An update is ready to install.' : 'Version ${update.version} is available.';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, color: _ink),
          ),
          const SizedBox(height: 10),
          m.FilledButton.icon(
            onPressed: () => applyAppUpdate(update),
            icon: Icon(update.isPatch ? m.Icons.restart_alt : m.Icons.open_in_new, size: 18),
            label: Text(update.isPatch ? 'Restart to update' : 'Open the store'),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_checked)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text("You're on the latest version.", style: TextStyle(color: _muted)),
          ),
        m.FilledButton.icon(
          onPressed: _checkForUpdates,
          icon: const Icon(m.Icons.system_update_alt, size: 18),
          label: Text(_checked ? 'Check again' : 'Check for updates'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(m.Icons.error_outline, size: 44, color: BKColor.main),
              const SizedBox(height: 16),
              const Text(
                "BikeControl couldn't finish starting up",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _ink),
              ),
              const SizedBox(height: 8),
              const Text(
                'Installing a waiting update usually fixes this. If it keeps happening, send us the logs and we’ll help.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: _muted),
              ),
              const SizedBox(height: 24),
              _updateSection(),
              const SizedBox(height: 12),
              m.OutlinedButton.icon(
                onPressed: _emailSupport,
                icon: const Icon(m.Icons.mail_outline, size: 18),
                label: const Text('Email support with logs'),
              ),
              const SizedBox(height: 8),
              const Text(
                _supportEmail,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: _muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BikeControlApp extends StatefulWidget {
  final Widget? customChild;
  final String? error;
  const BikeControlApp({super.key, this.error, this.customChild});

  @override
  State<BikeControlApp> createState() => _BikeControlAppState();
}

class _BikeControlAppState extends State<BikeControlApp> {
  /// How long the bootstrap may run before we assume it has stalled and show
  /// the recovery screen. A healthy start is well under this; the real content
  /// still swaps in if the bootstrap finishes later.
  static const _bootstrapTimeout = Duration(seconds: 10);

  bool _ready = false;
  Object? _bootstrapError;
  bool _stalled = false;
  Timer? _stallTimer;

  @override
  void initState() {
    super.initState();
    // Tests, screenshots and embedded (customChild) usage initialise elsewhere
    // and render their content straight away — only the real app boot runs the
    // splash/recovery gate.
    if (widget.customChild != null || screenshotMode || widget.error != null) {
      _ready = true;
      return;
    }
    _stallTimer = Timer(_bootstrapTimeout, () {
      if (mounted && !_ready) setState(() => _stalled = true);
    });
    _bootstrap();
  }

  @override
  void dispose() {
    _stallTimer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final error = await core.settings.init();
      if (error != null) {
        recordError(error, null, context: 'SettingsInit');
        if (mounted) setState(() => _bootstrapError = error);
        return;
      }
      await core.shiftingConfigs.init();

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

      // Attribute this install back to the ad that produced it. Android only:
      // no other store passes a referrer through to the app. Fire-and-forget,
      // because nothing here should ever delay startup.
      if (!kIsWeb && Platform.isAndroid && core.settings.isInitialized) {
        unawaited(
          InstallReferrerReporter(
            source: PlayInstallReferrerSource(),
            prefs: core.settings.prefs,
            send: (body) async {
              await core.supabase.functions.invoke('track-analytics', body: body);
            },
          ).reportOnce().catchError((Object e, StackTrace s) {
            recordError(e, s, context: 'InstallReferrerReporter.reportOnce');
          }),
        );
      }

      if (mounted) setState(() => _ready = true);
    } catch (e, s) {
      recordError(e, s, context: 'Startup bootstrap');
      if (mounted) setState(() => _bootstrapError = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    // Rebuild the whole app whenever the in-app language override changes so a
    // language switch takes effect immediately. Defaults to null (=follow the
    // OS language), which is also what an uninitialised Settings reports during
    // the splash — so this is safe before core.settings.init() completes.
    return ValueListenableBuilder<Locale?>(
      valueListenable: core.settings.localeListenable,
      builder: (context, localeOverride, _) => ShadcnApp(
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
        locale: demoLocaleOverride.isNotEmpty
            ? Locale(demoLocaleOverride)
            : (screenshotMode ? (screenshotLocale ?? const Locale('en')) : localeOverride),
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
        // Swap splash → content in place inside the always-mounted ShadcnApp so
        // the themed background is painted the whole time — no black flash while
        // the real content takes over from the splash. The Builder gives _home a
        // context *below* ShadcnApp, where its Theme is available.
        home: m.Builder(
          builder: (context) => AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _home(context, isMobile),
          ),
        ),
      ),
    );
  }

  Widget _home(BuildContext context, bool isMobile) {
    final background = Theme.of(context).colorScheme.background;

    if (widget.error != null) {
      return Container(
        key: const ValueKey('startup-error'),
        color: background,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Text(
          'There was an error starting the App. Please contact support:\n${widget.error}',
          textAlign: TextAlign.center,
        ),
      );
    }

    if (!_ready) {
      if (_bootstrapError != null || _stalled) {
        return Container(
          key: const ValueKey('startup-recovery'),
          color: background,
          child: _StartupRecovery(error: _bootstrapError),
        );
      }
      return Container(
        key: const ValueKey('startup-splash'),
        color: background,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 30,
          height: 30,
          child: m.CircularProgressIndicator(strokeWidth: 2.4, color: BKColor.main),
        ),
      );
    }

    return ToastLayer(
      key: const ValueKey('Test'),
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
    core.feedbackPromptService.start();
    unawaited(core.shiftFeedback.prepare());
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

      // Cold-start OAuth callback: on desktop, supabase_flutter only exchanges
      // the initial deep link on web, so a callback that arrives while the app
      // was closed (user shut the app before completing "Sign in with Apple")
      // never becomes a session. Exchange it ourselves. The live stream above
      // is left untouched — supabase_flutter handles the app-already-running
      // case, and a second exchange would redeem an already-consumed code.
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        unawaited(
          handleDesktopColdStartAuthCallback(
            getInitialLink: _appLinks.getInitialLink,
            exchangeSession: (uri) => core.supabase.auth.getSessionFromUrl(uri),
            onSessionEstablished: IAPManager.instance.refreshEntitlementsOnAppStart,
            onError: (e, s) => recordError(e, s, context: 'Desktop cold-start auth callback'),
          ),
        );
      }
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
