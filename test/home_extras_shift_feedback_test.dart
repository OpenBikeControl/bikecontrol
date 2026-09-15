// The two shift-feedback toggles live in the home page's "More options"
// section. The sound row is on every platform with a clip backend; the
// vibration row only where there is a haptics engine (phones/tablets) — this
// suite runs on desktop, so it asserts the desktop shape.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/home/home_extras.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'helpers/recording_shift_feedback.dart';
import 'widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  late RecordingShiftFeedback feedback;

  setUp(() {
    feedback = RecordingShiftFeedback();
    core.shiftFeedback = feedback;
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [
          ...ShadcnLocalizations.localizationsDelegates,
          OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        theme: ThemeData(colorScheme: ColorSchemes.lightSlate, radius: 0.7),
        home: SingleChildScrollView(child: HomeExtras(isMobile: false, onUpdate: () {})),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the sound toggle, hides the vibration toggle on desktop', (tester) async {
    await pump(tester);

    expect(find.text(AppLocalizations.current.shiftFeedbackSound), findsOneWidget);
    expect(find.text(AppLocalizations.current.shiftFeedbackHaptics), findsNothing);
  });

  testWidgets('flipping the sound switch asks the service to enable sound', (tester) async {
    await pump(tester);

    // The whole row is the button; tapping the title flips the switch.
    await tester.tap(find.text(AppLocalizations.current.shiftFeedbackSound));
    await tester.pumpAndSettle();

    expect(feedback.toggles, [('sound', true)]);
  });
}
