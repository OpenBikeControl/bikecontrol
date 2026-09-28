// The gear is the one thing a rider glances at the overlay for. It must never
// be shrunk to make room: at the default and the minimum window, at 1.0x and
// 1.3x text, with and without the -/+ buttons, it renders at its design size
// (36 px, growing with the text size) and larger than every reading, and the
// buttons stay inside the card.
import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/widgets/overlay/trainer_overlay_view.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart' show ScreenshotTester;
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  ValueNotifier<TrainerOverlayState> state({required bool controls}) => ValueNotifier(
    TrainerOverlayState(
      gear: 14,
      maxGear: 24,
      gearRatio: 3.53,
      mode: TrainerMode.simMode,
      powerW: 250,
      cadenceRpm: 90,
      ergTargetW: null,
      fields: {
        if (controls) OverlayField.controls,
        OverlayField.power,
        OverlayField.cadence,
        OverlayField.gearRatio,
      },
      frontShiftEnabled: false,
      frontRingLarge: false,
    ),
  );

  /// The size [text] is actually drawn at, relative to the card: font size ×
  /// text scaler × any scale transform (a FittedBox) between them.
  double renderedSize(WidgetTester tester, RenderParagraph paragraph) {
    final card = tester.renderObject<RenderBox>(find.byType(TrainerOverlayView));
    final scale = paragraph.getTransformTo(card).getMaxScaleOnAxis();
    return paragraph.textScaler.scale(paragraph.text.style!.fontSize!) * scale;
  }

  Widget overlay(double width, double textScale, bool controls) => ShadcnApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: TrainerOverlayView(
              state: state(controls: controls),
              onPrimaryDecrement: () {},
              onPrimaryIncrement: () {},
              onDragStart: () {},
            ),
          ),
        ),
      ),
    ),
  );

  for (final textScale in [1.0, 1.3]) {
    for (final controls in [true, false]) {
      for (final window in ['default', 'minimum']) {
        testWidgets('$window window, ${textScale}x text, controls: $controls', (tester) async {
          // Load the real fonts first: the window is sized from the measured
          // numeral, which the placeholder test font would overstate.
          await tester.pumpWidget(overlay(300, textScale, controls));
          await tester.loadAssets();
          final min = TrainerOverlayView.windowSize(TextScaler.linear(textScale), controls: controls).width;
          final width = window == 'minimum'
              ? min
              : (min > TrainerOverlayView.defaultWindowWidth ? min : TrainerOverlayView.defaultWindowWidth);
          await tester.pumpWidget(overlay(width, textScale, controls));
          await tester.binding.reassembleApplication();
          await tester.pump();

          expect(tester.takeException(), isNull, reason: 'no overflow');
          final card = tester.getRect(find.byType(TrainerOverlayView));
          if (controls) {
            for (final icon in [LucideIcons.minus, LucideIcons.plus]) {
              final button = tester.getRect(find.byIcon(icon));
              expect(
                card.left <= button.left && button.right <= card.right,
                isTrue,
                reason: '$icon at $button, card $card',
              );
            }
          }

          final gear = renderedSize(tester, tester.renderObject(find.text('14/24')));
          expect(gear, greaterThanOrEqualTo(36 * textScale - 0.01), reason: 'the gear is drawn at its design size');
          for (final metric in ['250 W', '90 rpm', '×3.53']) {
            final finder = find.text(metric);
            if (finder.evaluate().isEmpty) continue; // dropped for room — allowed
            expect(renderedSize(tester, tester.renderObject(finder)), lessThan(gear), reason: metric);
          }
          expect(find.text('250 W'), findsOneWidget, reason: 'power is the last reading to go');
        });
      }
    }
  }
}
