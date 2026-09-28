import 'package:bike_control/bluetooth/devices/gyroscope/gyroscope_steering.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/widgets/controller/steering_gauge.dart';
import 'package:bike_control/widgets/ui/animated_button_widget.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../widget_snapshot.dart';

// Tap-to-remap areas on the controller pictures were bare GestureDetectors:
// silent to screen readers and unreachable by keyboard.
Future<void> main() async {
  await ensureSnapshotHarness();

  final device = GyroscopeSteering();

  testWidgets('steering gauge halves are labelled remap buttons', (tester) async {
    final handle = tester.ensureSemantics();
    await captureWidget(
      tester,
      name: 'steering_gauge_a11y',
      width: 360,
      settle: false,
      builder: (_) => SteeringGauge(
        angle: ValueNotifier(0),
        calibrated: ValueNotifier(true),
        threshold: 5,
        device: device,
        leftButton: GyroscopeSteeringButtons.leftSteer,
        rightButton: GyroscopeSteeringButtons.rightSteer,
        keymap: Keymap(keyPairs: []),
        onUpdate: () {},
      ),
    );
    for (final button in [GyroscopeSteeringButtons.leftSteer, GyroscopeSteeringButtons.rightSteer]) {
      expect(
        find.semantics.byLabel(RegExp(RegExp.escape(button.displayName))),
        containsSemantics(isButton: true, hasTapAction: true, isFocusable: true),
      );
    }
    handle.dispose();
  });

  testWidgets('controller buttons with a remap popup are labelled buttons', (tester) async {
    final handle = tester.ensureSemantics();
    final button = GyroscopeSteeringButtons.leftSteer;
    await captureWidget(
      tester,
      name: 'animated_button_a11y',
      width: 200,
      settle: false,
      builder: (_) => Center(
        child: AnimatedButtonWidget(
          button: button,
          pressGeneration: 0,
          keymap: Keymap(keyPairs: []),
          device: device,
          onUpdate: () {},
        ),
      ),
    );
    expect(
      find.semantics.byLabel(RegExp(RegExp.escape(button.displayName))),
      containsSemantics(isButton: true, hasTapAction: true, isFocusable: true),
    );
    handle.dispose();
  });
}
