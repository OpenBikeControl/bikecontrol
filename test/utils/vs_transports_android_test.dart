import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The trainer app may run on an Android device next to a BikeControl on
  // anything else, so what its Android build can find is asked separately
  // from what the build on BikeControl's own platform can.
  test('MyWhoosh for Android finds trainers over Bluetooth only, wherever BikeControl runs', () {
    expect(MyWhoosh().virtualShiftingTransportsOnAndroid, {TrainerConnectionType.bluetooth});
    expect(MyWhoosh().virtualShiftingTransports, contains(TrainerConnectionType.wifi));
  });

  test('an app without a platform difference finds the same on Android', () {
    final app = Zwift();
    expect(app.virtualShiftingTransportsOnAndroid, app.virtualShiftingTransports);
  });
}
