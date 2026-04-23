import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/openbikecontrol.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/apps/training_peaks.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SupportedApp.supportedTrainerConnectionTypes', () {
    test('defaults to both bluetooth and wifi for every app except MyWhoosh', () {
      expect(
        Zwift().supportedTrainerConnectionTypes,
        unorderedEquals([TrainerConnectionType.bluetooth, TrainerConnectionType.wifi]),
      );
      expect(
        Rouvy().supportedTrainerConnectionTypes,
        unorderedEquals([TrainerConnectionType.bluetooth, TrainerConnectionType.wifi]),
      );
      expect(
        TrainingPeaks().supportedTrainerConnectionTypes,
        unorderedEquals([TrainerConnectionType.bluetooth, TrainerConnectionType.wifi]),
      );
      expect(
        OpenBikeControl().supportedTrainerConnectionTypes,
        unorderedEquals([TrainerConnectionType.bluetooth, TrainerConnectionType.wifi]),
      );
    });

    test('MyWhoosh reports only bluetooth', () {
      expect(MyWhoosh().supportedTrainerConnectionTypes, equals([TrainerConnectionType.bluetooth]));
    });
  });
}
