// Two phones on one LAN, each advertising its own "BikeControl <platform>
// XXXX" controller tile: before the trainer app is connected at all, the
// App card's hint has to say which of those tiles is this device.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show screenshotMode;
import 'package:bike_control/pages/home/chain_state.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/apps/training_peaks.dart';
import 'package:bike_control/widgets/home/chain_labels.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pending = SetupStep(id: SetupStepId.appConnected, done: false);

Future<void> _pump(WidgetTester tester, SupportedApp app, SetupStep step) async {
  core.settings.setTrainerApp(app);
  await tester.pumpWidget(
    ShadcnApp(
      localizationsDelegates: const [AppLocalizations.delegate],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      theme: ThemeData(colorScheme: ColorSchemes.lightSlate, radius: 0.5),
      home: Scaffold(
        child: Builder(
          builder: (context) => Text(chainStepText(context, step, appName: app.name).hint ?? ''),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    screenshotMode = true;
  });
  tearDown(() => screenshotMode = false);

  testWidgets('a DirCon app not connected yet names this device\'s controller tile', (tester) async {
    await _pump(tester, TrainingPeaks(), _pending);

    expect(find.textContaining('“BikeControl iOS 7519”'), findsOneWidget);
  });

  testWidgets('an app with one plain BikeControl entry keeps the generic hint', (tester) async {
    await _pump(tester, MyWhoosh(), _pending);

    final l = AppLocalizations.of(tester.element(find.byType(Text).first));
    expect(find.text(l.chainStepAppConnectedHint), findsOneWidget);
  });
}
