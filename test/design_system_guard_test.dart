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
      'lib/widgets/drivetrain/drivetrain_controls.dart',
      'lib/widgets/overlay/trainer_overlay_view.dart',
      // Painted into a fixed coordinate space / fixed-size ring or tile.
      'lib/widgets/drivetrain/drivetrain_view.dart',
      'lib/widgets/network_test/network_gauge.dart',
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

  group('page colours', () {
    // Pages take colours from colorScheme roles, BkStatusColors and the
    // helpers in lib/widgets/ui/colors.dart, so both themes keep their
    // contrast. A literal colour is allowed only where it is not UI chrome —
    // listed here with the exact tokens it may use. Fully transparent
    // (Color(0x00000000), Colors.transparent) is not a colour and is fine.
    const allowlist = {
      // Markers and key caps drawn over the rider's own screenshot of their
      // trainer app: they must read on arbitrary imagery, not on our grounds.
      'lib/pages/touch_area.dart': {'Colors.white', 'Colors.black', 'Colors.green', 'Colors.red'},
      // The scrim and play glyph over a video thumbnail.
      'lib/pages/help_center/widgets/instruction_videos_section.dart': {'Colors.black', 'Colors.white'},
    };
    final literal = RegExp(
      r'Color\(0x(?!00000000\))[0-9A-Fa-f]{8}\)|(?<![A-Za-z_])Colors\.(?!transparent\b)[A-Za-z]+|BKColor\.[A-Za-z]+',
    );

    test('no hard-coded colours in lib/pages outside the allowlist', () {
      final offenders = [
        for (final (path, line, text) in libLines())
          if (path.startsWith('lib/pages/') && !text.trimLeft().startsWith('//'))
            for (final m in literal.allMatches(text))
              if (!(allowlist[path]?.contains(m.group(0)) ?? false)) '$path:$line  ${m.group(0)}',
      ];
      expect(
        offenders,
        isEmpty,
        reason: 'Use colorScheme roles, BkStatusColors.of(context) or the helpers in lib/widgets/ui/colors.dart.',
      );
    });
  });

  group('page columns', () {
    // From 840 every section and every pushed page starts its content column
    // at the left edge, under the back arrow and title (BkPageColumn). A page
    // column floated in the middle of a wide window is the drift this
    // catches: Center around a ConstrainedBox of a page's width.
    const allowlist = {
      // A card inside the support chat's own column, not a page column.
      'lib/pages/support_chat/widgets/support_account_link_card.dart',
      // Drawers and dialogs: centred in their own surface on purpose.
      'lib/pages/help_center/widgets/instruction_videos_section.dart',
      'lib/pages/subscriptions/login.dart',
    };
    final centred = RegExp(
      r'Center\(\s*(?:heightFactor:[^,]*,\s*)?child: (?:ConstrainedBox|Container)\(\s*constraints: (?:const )?BoxConstraints\(maxWidth: (\d+)',
    );

    test('no page column is centred in the window', () {
      final offenders = <String>[];
      for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart') || file.path.startsWith('lib/gen/') || allowlist.contains(file.path)) continue;
        final source = file.readAsStringSync();
        for (final m in centred.allMatches(source)) {
          if (int.parse(m.group(1)!) >= 600) {
            final line = '\n'.allMatches(source.substring(0, m.start)).length + 1;
            offenders.add('${file.path}:$line  maxWidth ${m.group(1)}');
          }
        }
      }
      expect(offenders, isEmpty, reason: 'Wrap the page content in BkPageColumn (lib/widgets/ui/bk_page_column.dart).');
    });
  });
}
