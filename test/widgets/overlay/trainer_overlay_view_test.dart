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
  }) {
    return ValueNotifier(TrainerOverlayState(
      gear: gear, maxGear: maxGear, gearRatio: 2.43, mode: mode,
      powerW: powerW, cadenceRpm: cadenceRpm, ergTargetW: null, fields: fields,
    ));
  }

  testWidgets('renders gear N / M and mode pill', (tester) async {
    await tester.pumpWidget(
      ShadcnApp(
        home: Scaffold(
          child: TrainerOverlayView(state: mkState(), onModeToggle: null),
        ),
      ),
    );
    expect(find.text('14 / 24'), findsOneWidget);
    expect(find.text('SIM'), findsOneWidget);
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
}
