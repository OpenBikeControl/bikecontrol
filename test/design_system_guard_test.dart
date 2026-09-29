import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-level guards that keep the design system from drifting back.
///
/// They read `lib/` rather than render anything: the drift they catch (a
/// literal font size, an icon from another set) looks fine in isolation and
/// only shows up as inconsistency across screens.
void main() {
  Iterable<(String, int, String)> libLines() sync* {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (f) => f.path.endsWith('.dart') && !f.path.startsWith('lib/gen/'),
        );
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        yield (file.path, i + 1, lines[i]);
      }
    }
  }

  group('type scale', () {
    // Text sizes come from the theme's Geist typography (lib/widgets/ui/
    // type_scale.dart). These files draw text at geometry-driven sizes or run
    // outside the app theme, and keep literal sizes on purpose.
    const allowlist = {
      // Recovery screen shown when start-up fails, before the app theme exists.
      'lib/main.dart',
      // Gear numerals: the one deliberate display size.
      'lib/pages/proxy_device_details/gear_hero_card.dart',
      'lib/widgets/drivetrain/drivetrain_controls.dart',
      'lib/widgets/overlay/trainer_overlay_view.dart',
      // Painted into a fixed coordinate space / fixed-size ring or tile.
      'lib/widgets/drivetrain/drivetrain_view.dart',
      'lib/widgets/network_test/network_gauge.dart',
      'lib/pages/proxy_device_details/front_shift_visual.dart',
      'lib/widgets/ui/button_widget.dart',
      // Debug-only key-press overlay.
      'lib/widgets/testbed.dart',
      // Defines the scale itself.
      'lib/widgets/ui/type_scale.dart',
    };
    final literal = RegExp(r'fontSize:\s*[0-9]');
    final number = RegExp(r'fontSize:\s*(?:[^,)]*\?\s*)?([0-9.]+)');

    test('no literal font sizes outside the allowlist', () {
      final offenders = [
        for (final (path, line, text) in libLines())
          if (!allowlist.contains(path) && literal.hasMatch(text)) '$path:$line  ${text.trim()}',
      ];
      expect(offenders, isEmpty, reason: 'Use context.typography.<step> (see type_scale.dart) instead.');
    });

    test('nothing is drawn below the 11 px floor', () {
      final offenders = [
        for (final (path, line, text) in libLines())
          for (final m in number.allMatches(text))
            if (double.parse(m.group(1)!) < 11) '$path:$line  ${text.trim()}',
      ];
      expect(offenders, isEmpty);
    });
  });

  group('icon set', () {
    // Lucide (shadcn_flutter's LucideIcons) is the app's one icon set. A glyph
    // from another set is allowed only where Lucide has no equivalent — a
    // brand logo — and is listed here with the one icon it may use.
    const allowlist = {
      'lib/pages/help_center/widgets/contact_community_section.dart': {'Icons.reddit_outlined'},
    };
    final foreign = RegExp(r'(?<![A-Za-z])(?:Icons|BootstrapIcons|RadixIcons)\.[A-Za-z_0-9]+');

    test('only Lucide icons outside the allowlist', () {
      final offenders = [
        for (final (path, line, text) in libLines())
          for (final m in foreign.allMatches(text))
            if (!(allowlist[path]?.contains(m.group(0)) ?? false)) '$path:$line  ${m.group(0)}',
      ];
      expect(offenders, isEmpty, reason: 'Use the LucideIcons equivalent.');
    });
  });
}
