import 'package:bike_control/services/overlay/android_overlay_controller.dart';
import 'package:flutter_test/flutter_test.dart';

// The Android overlay window was a fixed 270x110 dp: with a larger system
// font the card's text outgrew it and got clipped.
void main() {
  test('window grows with the system font size, within bounds', () {
    expect(androidOverlayGrowth(0.85), 1.0);
    expect(androidOverlayGrowth(1.0), 1.0);
    expect(androidOverlayGrowth(1.3), closeTo(1.3, 1e-9));
    expect(androidOverlayGrowth(2.0), 1.5);
  });
}
