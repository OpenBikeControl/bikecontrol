import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/widgets/overlay/trainer_overlay_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  ValueNotifier<TrainerOverlayState> mkState({
    int gear = 14,
    int maxGear = 24,
    int? powerW = 178,
    int? cadenceRpm = 86,
    Set<OverlayField> fields = const {OverlayField.power, OverlayField.cadence},
    TrainerMode mode = TrainerMode.simMode,
    bool frontShiftEnabled = false,
    bool frontRingLarge = false,
  }) {
    return ValueNotifier(
      TrainerOverlayState(
        gear: gear,
        maxGear: maxGear,
        gearRatio: 2.43,
        mode: mode,
        powerW: powerW,
        cadenceRpm: cadenceRpm,
        ergTargetW: null,
        fields: fields,
        frontShiftEnabled: frontShiftEnabled,
        frontRingLarge: frontRingLarge,
      ),
    );
  }

  testWidgets('renders gear/total and mode pill', (tester) async {
    await tester.pumpWidget(
      ShadcnApp(
        home: Scaffold(
          child: TrainerOverlayView(state: mkState(), onModeToggle: null),
        ),
      ),
    );
    expect(find.text('14/24'), findsOneWidget);
    expect(find.text('SIM'), findsOneWidget);
  });

  testWidgets('renders 2×N position notation when front shift is on', (tester) async {
    await tester.pumpWidget(
      ShadcnApp(
        home: Scaffold(
          child: TrainerOverlayView(
            state: mkState(frontShiftEnabled: true, frontRingLarge: true),
            onModeToggle: null,
          ),
        ),
      ),
    );
    expect(find.text('2×14'), findsOneWidget);
    expect(find.text('14/24'), findsNothing);
  });

  testWidgets('hides power when not selected', (tester) async {
    await tester.pumpWidget(
      ShadcnApp(
        home: Scaffold(
          child: TrainerOverlayView(
            state: mkState(fields: const {OverlayField.cadence}),
            onModeToggle: null,
          ),
        ),
      ),
    );
    expect(find.textContaining('W'), findsNothing);
    expect(find.textContaining('rpm'), findsOneWidget);
  });

  testWidgets('shows -- for null power and cadence', (tester) async {
    await tester.pumpWidget(
      ShadcnApp(
        home: Scaffold(
          child: TrainerOverlayView(
            state: mkState(powerW: null, cadenceRpm: null),
            onModeToggle: null,
          ),
        ),
      ),
    );
    expect(find.textContaining('--'), findsWidgets);
  });

  testWidgets('the -/gear/+ row fits its desktop window at 1.3x text with every field on', (tester) async {
    final needed = TrainerOverlayView.windowSize(const TextScaler.linear(1.3)).width;
    final window = needed > TrainerOverlayView.defaultWindowWidth ? needed : TrainerOverlayView.defaultWindowWidth;
    await tester.pumpWidget(
      ShadcnApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: Scaffold(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: window,
                child: TrainerOverlayView(
                  state: mkState(
                    fields: const {
                      OverlayField.controls,
                      OverlayField.power,
                      OverlayField.cadence,
                      OverlayField.gearRatio,
                    },
                  ),
                  onPrimaryDecrement: () {},
                  onPrimaryIncrement: () {},
                  onDragStart: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull, reason: 'no overflow');
    final card = tester.getRect(find.byType(TrainerOverlayView));
    for (final icon in [LucideIcons.minus, LucideIcons.plus]) {
      final button = tester.getRect(find.byIcon(icon));
      expect(card.left <= button.left && button.right <= card.right, isTrue, reason: '$icon at $button, card $card');
    }
    expect(find.text('14/24'), findsOneWidget);
  });
}
