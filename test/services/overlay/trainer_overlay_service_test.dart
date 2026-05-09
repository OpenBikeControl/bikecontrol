import 'package:bike_control/services/overlay/trainer_overlay_controller.dart';
import 'package:bike_control/services/overlay/trainer_overlay_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('returns NoOpOverlayController on web/test platforms', () {
    if (kIsWeb) {
      final c = TrainerOverlayService.forCurrentPlatform();
      expect(c, isA<NoOpOverlayController>());
    } else {
      final c1 = TrainerOverlayService.forCurrentPlatform();
      final c2 = TrainerOverlayService.forCurrentPlatform();
      expect(identical(c1, c2), isTrue);
    }
  });
}
