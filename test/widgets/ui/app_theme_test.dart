import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../helpers/contrast.dart';

void main() {
  group('light theme', () {
    final cs = BkTheme.build(Brightness.light).colorScheme;

    test('muted text reads at >= 4.5:1 on white and on the activity rail', () {
      expect(contrast(cs.mutedForeground, const Color(0xFFFFFFFF)), greaterThanOrEqualTo(4.5));
      expect(contrast(cs.mutedForeground, const Color(0xFFF8FAFB)), greaterThanOrEqualTo(4.5));
      expect(contrast(cs.mutedForeground, cs.background), greaterThanOrEqualTo(4.5));
    });

    test('primary is the brand blue and its foreground is legible on it', () {
      expect(cs.primary, BKColor.main);
      expect(contrast(cs.primaryForeground, cs.primary), greaterThanOrEqualTo(4.5));
      expect(contrast(cs.primary, cs.background), greaterThanOrEqualTo(4.5));
    });
  });

  group('dark theme', () {
    final cs = BkTheme.build(Brightness.dark).colorScheme;

    test('primary is a brand blue, not the slate near-white', () {
      expect(cs.primary.b, greaterThan(cs.primary.r));
      expect(contrast(cs.primary, cs.background), greaterThanOrEqualTo(4.5));
      expect(contrast(cs.primary, cs.card), greaterThanOrEqualTo(4.5));
      expect(contrast(cs.primaryForeground, cs.primary), greaterThanOrEqualTo(4.5));
    });

    test('muted text reads at >= 4.5:1 on background and card', () {
      expect(contrast(cs.mutedForeground, cs.background), greaterThanOrEqualTo(4.5));
      expect(contrast(cs.mutedForeground, cs.card), greaterThanOrEqualTo(4.5));
    });

    test('card and background come from one neutral family', () {
      for (final c in [cs.card, cs.background, cs.popover]) {
        expect((c.r - c.b).abs(), lessThan(0.02), reason: '$c is tinted, not neutral');
      }
    });
  });

  test('both brightnesses share typography and radius', () {
    final light = BkTheme.build(Brightness.light);
    final dark = BkTheme.build(Brightness.dark);
    expect(light.radius, 0.7);
    expect(dark.radius, light.radius);
    expect(dark.typography.base.fontSize, light.typography.base.fontSize);
    expect(dark.scaling, light.scaling);
  });

  testWidgets('on a phone, shadcn scales controls 1.25x and text is not shrunk', (tester) async {
    late ThemeData applied;
    await tester.pumpWidget(
      ShadcnApp(
        theme: BkTheme.build(Brightness.light),
        home: Builder(builder: (context) {
          applied = Theme.of(context);
          return const SizedBox();
        }),
      ),
    );
    // flutter_test reports Android: ShadcnApp's mobile scaling applies.
    expect(applied.scaling, closeTo(1.25, 0.001));
    expect(applied.typography.base.fontSize, closeTo(const Typography.geist().base.fontSize! * 1.25, 0.001));
  });
}
