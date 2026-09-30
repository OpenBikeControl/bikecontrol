import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/widgets/overlay/overlay_app.dart';
import 'package:bike_control/widgets/overlay/trainer_overlay_view.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_tappable.dart';
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
      fields: const {OverlayField.gearRatio, OverlayField.controls},
    ),
  );

  for (final brightness in Brightness.values) {
    testWidgets('follows the platform brightness with the app theme ($brightness)', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      late BuildContext ctx;
      await tester.pumpWidget(
        OverlayShadcnApp(
          home: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final theme = Theme.of(ctx);
      expect(theme.brightness, brightness);
      expect(theme.colorScheme.primary, BkTheme.build(brightness).colorScheme.primary);
      expect(theme.radius, BkTheme.mobileScaling.scale(BkTheme.build(brightness)).radius);
      expect(AppLocalizations.maybeOf(ctx), isNotNull);
    });
  }

  for (final mode in [TrainerMode.simMode, TrainerMode.ergMode]) {
    testWidgets('+/- are labelled in $mode', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        OverlayShadcnApp(
          home: Center(
            child: TrainerOverlayView(
              state: state(mode: mode),
              onPrimaryDecrement: () {},
              onPrimaryIncrement: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final (down, up) = mode == TrainerMode.ergMode ? ('Decrease', 'Increase') : ('Shift Down', 'Shift Up');
      expect(find.semantics.byLabel(down), isSemantics(isButton: true, hasTapAction: true));
      expect(find.semantics.byLabel(up), isSemantics(isButton: true, hasTapAction: true));
      handle.dispose();
    });
  }

  testWidgets('Android overlay card does not overflow at 1.3x text', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        OverlayShadcnApp(
          home: Center(
            child: TrainerOverlayView(state: state(), onPrimaryDecrement: () {}, onPrimaryIncrement: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('one row: - , the gear with its GEAR label, + , then the mode and readings', (tester) async {
    await tester.pumpWidget(
      OverlayShadcnApp(
        home: Center(
          child: TrainerOverlayView(state: state(), onPrimaryDecrement: () {}, onPrimaryIncrement: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final gear = tester.getRect(find.text('14'));
    final minus = tester.getRect(find.byIcon(LucideIcons.minus));
    final plus = tester.getRect(find.byIcon(LucideIcons.plus));
    final label = tester.getRect(find.text('GEAR'));
    final pill = tester.getRect(find.text('SIM'));
    expect(minus.right, lessThanOrEqualTo(gear.left), reason: '- before the gear');
    expect(plus.left, greaterThanOrEqualTo(gear.right), reason: '+ after the gear');
    expect((minus.center.dy - plus.center.dy).abs(), lessThan(1));
    expect(label.top, greaterThanOrEqualTo(gear.bottom - 4), reason: 'the label sits under the numeral');
    expect(pill.left, greaterThan(plus.right), reason: 'mode and readings sit after +');
  });

  testWidgets('Android: a rounded pill in the card colour, not the page colour', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(
        OverlayShadcnApp(
          home: Center(
            child: TrainerOverlayView(state: state(), onPrimaryDecrement: () {}, onPrimaryIncrement: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final surface = tester.widget<Container>(
        find.descendant(of: find.byType(TrainerOverlayView), matching: find.byType(Container)).first,
      );
      final decoration = surface.decoration! as BoxDecoration;
      final card = BkTheme.build(Brightness.dark).colorScheme.card;
      expect(decoration.color!.withAlpha(255), card.withAlpha(255));
      expect(decoration.color!.a, greaterThanOrEqualTo(0.9));
      final height = tester.getSize(find.byType(TrainerOverlayView)).height;
      final radius = (decoration.borderRadius! as BorderRadius).topLeft.x;
      expect(radius, greaterThanOrEqualTo(height / 2), reason: "fully rounded ends");
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  // The −/+ circles are a thumb target over the trainer app on a phone; on a
  // desktop, under a mouse, the smaller circle keeps the window compact.
  for (final (platform, minimum) in [(TargetPlatform.android, 48.0), (TargetPlatform.macOS, 44.0)]) {
    testWidgets('−/+ are at least ${minimum.toInt()} px on ${platform.name}', (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      try {
        await tester.pumpWidget(
          OverlayShadcnApp(
            home: Center(
              child: TrainerOverlayView(state: state(), onPrimaryDecrement: () {}, onPrimaryIncrement: () {}),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final icon in [LucideIcons.minus, LucideIcons.plus]) {
          final circle = tester.getSize(
            find.ancestor(of: find.byIcon(icon), matching: find.byType(BkTappable)).first,
          );
          expect(circle.width, greaterThanOrEqualTo(minimum), reason: '$icon');
          expect(circle.height, greaterThanOrEqualTo(minimum), reason: '$icon');
        }
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  test('the touch window makes room for the larger circles', () {
    final touch = TrainerOverlayView.windowSize(TextScaler.noScaling, touch: true);
    final desktop = TrainerOverlayView.windowSize(TextScaler.noScaling, touch: false);
    expect(touch.width - desktop.width, 2 * (TrainerOverlayView.touchHit - TrainerOverlayView.pointerHit));
    expect(touch.height, greaterThanOrEqualTo(TrainerOverlayView.touchHit));
  });
}
