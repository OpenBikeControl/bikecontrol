import 'dart:io';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate, installLoggerErrorListener;
import 'package:bike_control/pages/navigation.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/utils/shared.dart' show Logger;
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Takes the network away (blog and update checks fail at once) and logs
/// recordError instead of starting the app's full diagnostics gather.
void quietShellEnvironment() {
  HttpOverrides.global = _NoNetwork();
  installLoggerErrorListener();
  Logger.onRecordError = (message, error, _) => debugPrint('recordError($message): $error');
}

/// Pumps the real [Navigation] shell at [size] (logical pixels).
Future<void> pumpShell(
  WidgetTester tester,
  Size size, {
  double pixelRatio = 1,
  bool reduceMotion = false,
  Brightness brightness = Brightness.dark,
}) async {
  tester.view.devicePixelRatio = pixelRatio;
  tester.view.physicalSize = size * pixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ShadcnApp(
      debugShowCheckedModeBanner: false,
      menuHandler: OverlayHandler.popover,
      popoverHandler: OverlayHandler.popover,
      localizationsDelegates: [
        ...ShadcnLocalizations.localizationsDelegates,
        const OtherLocalizationsDelegate(),
        AppLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      scaling: BkTheme.scaling,
      theme: BkTheme.build(brightness),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
          child: const Navigation(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

/// Unmounts the shell and lets its timers run out.
Future<void> disposeShell(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

class _NoNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => throw const SocketException('no network in tests');
}
