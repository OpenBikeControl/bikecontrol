import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/openbikecontrol.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/apps/training_peaks.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SupportedApp.virtualGearAmount', () {
    test('defaults to 24 for every app except MyWhoosh', () {
      expect(Zwift().virtualGearAmount, 24);
      expect(Rouvy().virtualGearAmount, 24);
      expect(TrainingPeaks().virtualGearAmount, 24);
      expect(OpenBikeControl().virtualGearAmount, 24);
    });

    test('MyWhoosh reports 30 virtual gears', () {
      expect(MyWhoosh().virtualGearAmount, 30);
    });
  });
}
