import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/widgets/overlay/overlay_app.dart';
import 'package:bike_control/widgets/overlay/trainer_overlay_view.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

// The overlay runs in its own engine. It used to get a bare ShadcnApp: the
// default slate theme, always light, and no localizations.
void main() {
  ValueNotifier<TrainerOverlayState> state({TrainerMode mode = TrainerMode.simMode}) => ValueNotifier(
    TrainerOverlayState(
      gear: 14,
      maxGear: 24,
      gearRatio: 2.43,
      mode: mode,
      powerW: 1234,
      cadenceRpm: 118,
      ergTargetW: 250,
      fields: const {OverlayField.power, OverlayField.cadence, OverlayField.gearRatio, OverlayField.controls},
    ),
  );

  for (final brightness in Brightness.values) {
    testWidgets('follows the platform brightness with the app theme ($brightness)', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      late BuildContext ctx;
      await tester.pumpWidget(OverlayShadcnApp(home: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      })));
      await tester.pumpAndSettle();
      final theme = Theme.of(ctx);
      expect(theme.brightness, brightness);
      expect(theme.colorScheme.primary, BkTheme.build(brightness).colorScheme.primary);
      expect(theme.radius, AdaptiveScaling.mobile.scale(BkTheme.build(brightness)).radius);
      expect(AppLocalizations.maybeOf(ctx), isNotNull);
    });
  }

  for (final mode in [TrainerMode.simMode, TrainerMode.ergMode]) {
    testWidgets('+/- are labelled in $mode', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(OverlayShadcnApp(
        home: Center(child: TrainerOverlayView(state: state(mode: mode), onPrimaryDecrement: () {}, onPrimaryIncrement: () {})),
      ));
      await tester.pumpAndSettle();
      final (down, up) = mode == TrainerMode.ergMode ? ('Decrease', 'Increase') : ('Shift Down', 'Shift Up');
      expect(find.semantics.byLabel(down), containsSemantics(isButton: true, hasTapAction: true));
      expect(find.semantics.byLabel(up), containsSemantics(isButton: true, hasTapAction: true));
      handle.dispose();
    });
  }

  testWidgets('Android overlay card does not overflow at 1.3x text', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(OverlayShadcnApp(
        home: Center(child: TrainerOverlayView(state: state(), onPrimaryDecrement: () {}, onPrimaryIncrement: () {})),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
