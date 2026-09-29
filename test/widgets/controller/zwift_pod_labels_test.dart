// A Zwift pod's buttons read as a picture of that pod: no "P→" / "SB→" /
// "OO→" arrow labels (the side is the pod itself), and a single pod sits in
// the middle of its card.
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_play.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/widgets/controller/controller_canvas.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/button_widget.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

final _arrows = RegExp('[←→↑↓]');

void main() {
  final pods = [
    ZwiftPlay(
      BleDevice(name: 'Zwift Play', deviceId: 'l'),
      deviceType: ZwiftDeviceType.playLeft,
    ),
    ZwiftPlay(
      BleDevice(name: 'Zwift Play', deviceId: 'r'),
      deviceType: ZwiftDeviceType.playRight,
    ),
    ZwiftRide(BleDevice(name: 'Zwift Ride', deviceId: 'ride')),
  ];

  testWidgets('no Zwift button is labelled with an arrow', (tester) async {
    final buttons = {for (final d in pods) ...d.availableButtons, ...ZwiftButtons.values};
    await tester.pumpWidget(
      ShadcnApp(
        theme: BkTheme.build(Brightness.dark),
        home: Scaffold(
          child: Wrap(children: [for (final b in buttons) ButtonWidget(button: b, size: 40)]),
        ),
      ),
    );
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      expect(text.data ?? '', isNot(contains(_arrows)), reason: 'a pod label reads "${text.data}"');
    }
  });

  testWidgets('a single Play pod is centred in its canvas', (tester) async {
    for (final width in [326.0, 560.0]) {
      final device = pods[1];
      await tester.pumpWidget(
        ShadcnApp(
          theme: BkTheme.build(Brightness.dark),
          home: Scaffold(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: ControllerCanvas(
                  layout: device.controllerLayout!,
                  availableButtons: device.availableButtons,
                  buttonBuilder: (b) => SizedBox.square(key: ValueKey(b.name), dimension: 56),
                ),
              ),
            ),
          ),
        ),
      );
      final rects = [for (final b in device.availableButtons) tester.getRect(find.byKey(ValueKey(b.name)))];
      final left = rects.map((r) => r.left).reduce((a, b) => a < b ? a : b);
      final right = rects.map((r) => r.right).reduce((a, b) => a > b ? a : b);
      final canvas = tester.getRect(find.byType(ControllerCanvas));
      expect((left - canvas.left) - (canvas.right - right), closeTo(0, 8), reason: 'at $width: $left..$right');
    }
  });
}
