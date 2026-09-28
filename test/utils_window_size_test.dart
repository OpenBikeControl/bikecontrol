import 'package:bike_control/utils/window_size.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('size classes split at 600 and 840', () {
    expect(WindowSize.fromWidth(390), WindowSize.compact);
    expect(WindowSize.fromWidth(599.9), WindowSize.compact);
    expect(WindowSize.fromWidth(600), WindowSize.medium);
    expect(WindowSize.fromWidth(839.9), WindowSize.medium);
    expect(WindowSize.fromWidth(840), WindowSize.expanded);
  });

  test('legacy layout switches keep their exact widths', () {
    // Moving any of these onto a size-class edge would change a layout
    // riders already use at that width.
    expect(Breakpoints.twoPane, 800);
    expect(Breakpoints.networkValueColumn, 640);
    expect(Breakpoints.keymapSideBySide, 860);
    expect(Breakpoints.onboardingAppGridWide, 560);
    expect(Breakpoints.clickV2Narrow, 380);
  });

  test('the desktop minimum window still fits the compact layout', () {
    expect(Breakpoints.minDesktopWindow.width, lessThan(Breakpoints.compact));
    expect(Breakpoints.minDesktopWindow.width, greaterThanOrEqualTo(360));
  });
}
