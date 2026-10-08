// Ride's "Your buttons" card for a steering input (phone steering, Elite
// Sterzo / Rizer): an analog angle, not buttons. It says what it does, shows
// the live angle and the two actions the angle drives, and never offers to
// "tap a button" or a press's single / double / long triggers.
import 'package:bike_control/bluetooth/devices/gyroscope/gyroscope_steering.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/widgets/home/your_buttons.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  Keymap steeringKeymap() => Keymap(
    keyPairs: [
      KeyPair(
        buttons: [GyroscopeSteeringButtons.leftSteer],
        physicalKey: null,
        logicalKey: null,
        inGameAction: InGameAction.steerLeft,
        trigger: ButtonTrigger.longPress,
      ),
      KeyPair(
        buttons: [GyroscopeSteeringButtons.rightSteer],
        physicalKey: null,
        logicalKey: null,
        inGameAction: InGameAction.steerRight,
        trigger: ButtonTrigger.longPress,
      ),
    ],
  );

  Future<AppLocalizations> pump(
    WidgetTester tester,
    GyroscopeSteering device, {
    ControllerPress press = (button: null, generation: 0),
    bool wide = false,
  }) async {
    await AppLocalizations.load(const Locale('de'));
    addTearDown(() => AppLocalizations.load(const Locale('en')));
    tester.view.physicalSize = Size(wide ? 900 : 390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ShadcnApp(
        locale: const Locale('de'),
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        theme: BkTheme.build(Brightness.dark),
        home: Scaffold(
          child: SingleChildScrollView(
            child: ControllerButtonsCard(
              device: device,
              keymap: steeringKeymap(),
              presses: ValueNotifier(press),
              onUpdate: () {},
              onEdit: () {},
              wide: wide,
              showButtonList: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return AppLocalizations.current;
  }

  GyroscopeSteering calibratedPhone({double angle = 8}) {
    final device = GyroscopeSteering()..isConnected = true;
    device.isCalibratedNotifier.value = true;
    device.steeringAngle.value = angle;
    return device;
  }

  testWidgets('says what steering does instead of "tap a button"', (tester) async {
    final l = await pump(tester, calibratedPhone());
    expect(find.text(l.rideTapButtonHint), findsNothing);
    expect(find.text(l.rideClickButtonHint), findsNothing);
    expect(find.text(l.steeringRideHint), findsOneWidget);
  });

  testWidgets('names the two actions the angle drives', (tester) async {
    final l = await pump(tester, calibratedPhone());
    expect(find.text(l.actionSteerLeft), findsOneWidget);
    expect(find.text(l.actionSteerRight), findsOneWidget);
  });

  testWidgets('shows the live angle and follows it', (tester) async {
    final device = calibratedPhone(angle: 8);
    await pump(tester, device);
    expect(find.byKey(const ValueKey('steering-angle-readout')), findsOneWidget);
    expect(find.text('8°'), findsOneWidget);
    device.steeringAngle.value = -14;
    await tester.pump();
    expect(find.text('14°'), findsOneWidget);
  });

  testWidgets('no last-press strip, button list or remap targets', (tester) async {
    final l = await pump(
      tester,
      calibratedPhone(),
      press: (button: GyroscopeSteeringButtons.leftSteer, generation: 1),
      wide: true,
    );
    expect(find.byType(LastPressStrip), findsNothing);
    expect(find.byKey(const ValueKey('ride-button-list')), findsNothing);
    expect(find.text(l.rideChange), findsNothing);
    expect(find.bySemanticsLabel(RegExp(RegExp.escape(GyroscopeSteeringButtons.leftSteer.displayName))), findsNothing);
  });

  testWidgets('phone steering recalibrates from the card', (tester) async {
    final device = calibratedPhone();
    final l = await pump(tester, device);
    await tester.tap(find.text(l.steeringRecalibrate));
    await tester.pump();
    expect(device.steeringCalibrated.value, isFalse);
    expect(find.text(l.steeringCalibrating), findsOneWidget);
  });
}
