import 'package:bike_control/pages/proxy_device_details/gear_ratios_editor_page.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../helpers/contrast.dart';

// The current gear's row used to be a hard-coded #EFF6FF wash: fine under
// dark text, but in dark mode the row text is near-white — white on
// near-white.
void main() {
  for (final brightness in Brightness.values) {
    final cs = BkTheme.build(brightness).colorScheme;

    test('$brightness: every row state keeps its text legible', () {
      for (final (isCurrent, isNeutral) in [(false, false), (true, false), (false, true), (true, true)]) {
        final c = gearRowColors(cs, isCurrent: isCurrent, isNeutral: isNeutral);
        final bg = Color.alphaBlend(c.background, cs.background);
        expect(contrast(cs.foreground, bg), greaterThanOrEqualTo(4.5),
            reason: 'row text on current=$isCurrent neutral=$isNeutral');
        final badgeBg = Color.alphaBlend(c.badgeBackground, bg);
        expect(contrast(c.badgeForeground, badgeBg), greaterThanOrEqualTo(4.5),
            reason: 'badge text on current=$isCurrent neutral=$isNeutral');
      }
    });

    test('$brightness: the current row stands out from a plain row', () {
      final plain = gearRowColors(cs, isCurrent: false, isNeutral: false);
      final current = gearRowColors(cs, isCurrent: true, isNeutral: false);
      expect(current.background, isNot(plain.background));
      expect(current.border, isNot(plain.border));
    });
  }
}
