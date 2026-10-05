import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../helpers/contrast.dart';

void main() {
  group('light theme', () {
    final cs = BkTheme.build(Brightness.light).colorScheme;

    test('is the grouped palette: white cards on a grey page', () {
      expect(cs.background, const Color(0xFFF2F2F7));
      expect(cs.card, const Color(0xFFFFFFFF));
      expect(cs.popover, const Color(0xFFFFFFFF));
      expect(cs.foreground, const Color(0xFF1C1C1E));
    });

    test('body and secondary text read at >= 4.5:1 on the page, a card and a fill', () {
      for (final surface in [cs.background, cs.card, cs.muted, cs.secondary, cs.accent]) {
        expect(contrast(cs.foreground, surface), greaterThanOrEqualTo(4.5), reason: 'foreground on $surface');
        expect(contrast(cs.mutedForeground, surface), greaterThanOrEqualTo(4.5), reason: 'muted on $surface');
      }
      expect(contrast(cs.secondaryForeground, cs.secondary), greaterThanOrEqualTo(4.5));
      expect(contrast(cs.accentForeground, cs.accent), greaterThanOrEqualTo(4.5));
    });

    test('primary is the brand blue with white text; accent text clears 4.5:1 everywhere', () {
      expect(cs.primary, BKColor.main);
      expect(cs.primaryForeground, const Color(0xFFFFFFFF));
      expect(contrast(cs.primaryForeground, cs.primary), greaterThanOrEqualTo(4.5));
      expect(contrast(cs.primary, cs.card), greaterThanOrEqualTo(4.5));
      for (final surface in [cs.background, cs.card, cs.muted]) {
        expect(contrast(BkTheme.lightAccentText, surface), greaterThanOrEqualTo(4.5), reason: 'link on $surface');
      }
    });

    test('destructive buttons keep legible text', () {
      // ignore: deprecated_member_use
      expect(contrast(cs.destructiveForeground, cs.destructive), greaterThanOrEqualTo(4.5));
    });

    test('hairlines and fills are visible on both the page and a card', () {
      for (final surface in [cs.background, cs.card]) {
        expect(contrast(cs.border, surface), greaterThan(1.15), reason: 'border on $surface');
      }
      expect(contrast(cs.muted, cs.card), greaterThan(1.15));
    });
  });

  group('dark theme', () {
    final cs = BkTheme.build(Brightness.dark).colorScheme;

    test('is a tonal ladder: page, card, raised', () {
      expect(cs.background, const Color(0xFF101318));
      expect(cs.card, const Color(0xFF1B1F25));
      expect(cs.muted, const Color(0xFF262B33));
      expect(cs.foreground, const Color(0xFFFFFFFF));
      expect(cs.mutedForeground, const Color(0xFFA3A3A3));
      expect(cs.card.computeLuminance(), greaterThan(cs.background.computeLuminance()));
      expect(cs.muted.computeLuminance(), greaterThan(cs.card.computeLuminance()));
    });

    test('primary is a brand blue, not the slate near-white', () {
      expect(cs.primary, BkTheme.darkPrimary);
      expect(cs.primary.b, greaterThan(cs.primary.r));
      expect(contrast(cs.primaryForeground, cs.primary), greaterThanOrEqualTo(4.5));
    });

    test('body, secondary and accent text read at >= 4.5:1 on page, card and raised fills', () {
      for (final surface in [cs.background, cs.card, cs.muted, cs.popover]) {
        expect(contrast(cs.foreground, surface), greaterThanOrEqualTo(4.5), reason: 'foreground on $surface');
        expect(contrast(cs.mutedForeground, surface), greaterThanOrEqualTo(4.5), reason: 'muted on $surface');
        expect(contrast(cs.primary, surface), greaterThanOrEqualTo(4.5), reason: 'primary on $surface');
      }
      // ignore: deprecated_member_use
      expect(contrast(cs.destructiveForeground, cs.destructive), greaterThanOrEqualTo(4.5));
    });

    test('card and background are graphite with the same faint cool tint', () {
      for (final c in [cs.card, cs.background, cs.popover, cs.muted]) {
        expect(c.b - c.r, greaterThan(0), reason: '$c leans toward the brand blue');
        expect(c.b - c.r, lessThan(0.06), reason: '$c is tinted, not coloured');
      }
    });
  });

  testWidgets('accent text resolves per brightness', (tester) async {
    final seen = <Brightness, Color>{};
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        ShadcnApp(
          theme: BkTheme.build(brightness),
          home: Builder(
            builder: (context) {
              seen[brightness] = bkAccentText(context);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
    }
    expect(seen[Brightness.light], BkTheme.lightAccentText);
    expect(seen[Brightness.dark], BkTheme.darkPrimary);
  });

  test('success is the approved green in both brightnesses', () {
    expect(BkStatusColors.dark.success, const Color(0xFF22C55E));
    // #15803D is 4.49:1 on the grouped page; one notch darker clears 4.5.
    expect(contrast(BkStatusColors.light.success, BkTheme.lightColorScheme.background), greaterThanOrEqualTo(4.5));
  });

  test('both brightnesses share typography and radius', () {
    final light = BkTheme.build(Brightness.light);
    final dark = BkTheme.build(Brightness.dark);
    expect(light.radius, 0.7);
    expect(dark.radius, light.radius);
    expect(dark.typography.base.fontSize, light.typography.base.fontSize);
    expect(dark.scaling, light.scaling);
  });

  testWidgets('on a phone, controls scale 1.25x and text 1.1x', (tester) async {
    late ThemeData applied;
    await tester.pumpWidget(
      ShadcnApp(
        scaling: BkTheme.scaling,
        theme: BkTheme.build(Brightness.light),
        home: Builder(
          builder: (context) {
            applied = Theme.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    // flutter_test reports Android: the phone scaling applies.
    const geist = Typography.geist();
    expect(applied.scaling, closeTo(1.25, 0.001), reason: 'tap targets keep the mobile size');
    expect(applied.typography.base.fontSize, closeTo(geist.base.fontSize! * 1.1, 0.001));
    // The 11 px floor holds in rendered size.
    expect(applied.typography.caption.fontSize, greaterThanOrEqualTo(11));
  });

  test('desktop is unscaled', () {
    expect(BkTheme.scalingFor(TargetPlatform.macOS), AdaptiveScaling.desktop);
    expect(BkTheme.scalingFor(TargetPlatform.windows), AdaptiveScaling.desktop);
  });

  group('status colours', () {
    for (final brightness in Brightness.values) {
      final theme = BkTheme.build(brightness);
      final cs = theme.colorScheme;
      final status = BkStatusColors.forBrightness(brightness);

      test('$brightness: each status reads at >= 4.5:1 on the page, a card and its own wash', () {
        final roles = {
          'success': (status.success, status.successForeground, status.successWash),
          'warning': (status.warning, status.warningForeground, status.warningWash),
          'info': (status.info, status.infoForeground, status.infoWash),
          'danger': (status.danger, status.dangerForeground, status.dangerWash),
        };
        for (final MapEntry(key: name, value: (color, foreground, wash)) in roles.entries) {
          for (final surface in [cs.background, cs.card]) {
            expect(contrast(color, surface), greaterThanOrEqualTo(4.5), reason: '$name on $surface');
            final washed = Color.alphaBlend(wash, surface);
            expect(contrast(color, washed), greaterThanOrEqualTo(4.5), reason: '$name on its wash');
            expect(contrast(cs.foreground, washed), greaterThanOrEqualTo(4.5), reason: 'body text on the $name wash');
          }
          expect(contrast(foreground, color), greaterThanOrEqualTo(4.5), reason: '$name foreground on $name');
        }
      });
    }
  });

  for (final brightness in Brightness.values) {
    for (final on in [true, false]) {
      testWidgets('$brightness: ${on ? 'an on' : 'an off'} switch has a white thumb on the '
          '${on ? 'primary' : 'muted'} track', (tester) async {
        await tester.pumpWidget(
          ShadcnApp(
            theme: BkTheme.build(brightness),
            home: BkComponentThemes(
              child: Center(
                child: Switch(value: on, onChanged: (_) {}),
              ),
            ),
          ),
        );
        final cs = BkTheme.build(brightness).colorScheme;
        final thumb = tester
            .widgetList<Container>(find.descendant(of: find.byType(Switch), matching: find.byType(Container)))
            .map((c) => (c.decoration as BoxDecoration?)?.color)
            .whereType<Color>()
            .toList();
        // The track (an AnimatedContainer, itself a Container) comes first.
        expect(thumb.last, const Color(0xFFFFFFFF), reason: 'thumb');
        final track = tester
            .widgetList<AnimatedContainer>(
              find.descendant(of: find.byType(Switch), matching: find.byType(AnimatedContainer)),
            )
            .map((c) => (c.decoration as BoxDecoration?)?.color)
            .whereType<Color>()
            .single;
        if (on) {
          expect(track, cs.primary);
        } else {
          expect(track, BkComponentThemes.switchOffTrack(brightness));
          // The off track reads as a control on the page and on a card.
          for (final surface in [cs.background, cs.card]) {
            expect(contrast(track, surface), greaterThan(1.1), reason: 'off track on $surface');
          }
          // …and the white thumb stands off it.
          expect(contrast(const Color(0xFFFFFFFF), track), greaterThan(1.15), reason: 'thumb on off track');
        }
      });
    }
  }
}
