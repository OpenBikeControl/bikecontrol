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

  group('brand band', () {
    // The blue→teal band is a signature, not decoration: Ride's virtual
    // shifting header and the two plan cards (Settings, the sidebar). Never
    // on buttons or state indicators.
    const allowed = {
      'lib/widgets/ui/bk_brand_band.dart',
      'lib/widgets/home/virtual_shifting_card.dart',
      'lib/pages/settings/settings_page.dart',
      'lib/pages/shell/app_shell.dart',
    };
    // Where the band's colours are defined, and the mark's disc, which is the
    // app icon's own gradient (not a band).
    const tokenHomes = {'lib/widgets/ui/app_theme.dart', 'lib/widgets/ui/bk_brand_mark.dart'};
    final use = RegExp(r'BkBrandBand\(|\.bandStart\b|\.bandEnd\b');

    test('only the shifting card header and the plan cards wear the band', () {
      final offenders = [
        for (final (path, line, text) in libLines())
          if (!allowed.contains(path) && !tokenHomes.contains(path) && use.hasMatch(text))
            '$path:$line  ${text.trim()}',
      ];
      expect(offenders, isEmpty, reason: 'The brand band is reserved; see DESIGN.md.');
    });

    test('each allowed file wears it once', () {
      for (final path in allowed.skip(1)) {
        expect('BkBrandBand('.allMatches(File(path).readAsStringSync()).length, 1, reason: path);
      }
    });
  });

  group('brand mark', () {
    // The handlebar mark is the one brand asset in the app chrome; it is an
    // SVG asset, drawn white on the band gradient, next to the wordmark.
    test('the mark is an asset and is drawn only by BkBrandMark', () {
      expect(File('assets/brand/bikecontrol_mark.svg').existsSync(), isTrue);
      final offenders = [
        for (final (path, line, text) in libLines())
          if (path != 'lib/widgets/ui/bk_brand_mark.dart' && text.contains('bikecontrol_mark.svg')) '$path:$line',
      ];
      expect(offenders, isEmpty);
    });
  });

  group('page columns', () {
    // From 840 the shell's sections (Ride, Devices, Activity, Settings) start
    // at the left edge beside the sidebar. A page pushed on top of the shell
    // centres its content column in the window (BkPageColumn), and its header
    // (BkPageHeader) insets the back arrow and title to the same column.
    const shellSections = [
      'lib/pages/overview.dart',
      'lib/pages/home/home_page.dart',
      'lib/pages/devices/devices_page.dart',
      'lib/pages/activity/activity_log.dart',
      'lib/pages/activity/activity_section.dart',
      'lib/pages/settings/settings_page.dart',
    ];
    // Pushed pages with a header but full-width content on purpose: a chat
    // thread and the log viewer use the whole window.
    const fullWidthPages = {
      'lib/pages/support_chat/support_chat_page.dart',
      'lib/pages/support_chat/support_thread_page.dart',
      'lib/widgets/logviewer.dart',
    };
    // Pushed pages whose column lives in the body widget they host.
    const columnInBody = {
      'lib/pages/trainer_connection_settings.dart': 'lib/pages/trainer.dart',
    };
    // Hand-rolled centred columns: drawers and dialogs centred in their own
    // surface, and a card inside the support chat's own column.
    const handRolledAllowlist = {
      'lib/pages/support_chat/widgets/support_account_link_card.dart',
      'lib/pages/help_center/widgets/instruction_videos_section.dart',
      'lib/pages/subscriptions/login.dart',
    };
    final centred = RegExp(
      r'Center\(\s*(?:heightFactor:[^,]*,\s*)?child: (?:ConstrainedBox|Container)\(\s*constraints: (?:const )?BoxConstraints\(maxWidth: (\d+)',
    );
    Iterable<File> sources() => Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.startsWith('lib/gen/'));

    test('BkPageColumn centres its column', () {
      final source = File('lib/widgets/ui/bk_page_column.dart').readAsStringSync();
      expect(source, contains('Alignment.topCenter'));
      expect(source, isNot(contains('AlignmentDirectional.topStart')));
    });

    bool bodyHasColumn(String path) {
      final body = columnInBody[path];
      return body != null && File(body).readAsStringSync().contains('BkPageColumn(');
    }

    test('every pushed page with a header wraps its content in BkPageColumn', () {
      final offenders = [
        for (final file in sources())
          if (!fullWidthPages.contains(file.path) && file.path != 'lib/widgets/ui/bk_page_header.dart')
            if (file.readAsStringSync() case final source when source.contains('BkPageHeader('))
              if (!source.contains('BkPageColumn(') && !bodyHasColumn(file.path)) file.path,
      ];
      expect(offenders, isEmpty, reason: 'Wrap the page content in BkPageColumn (lib/widgets/ui/bk_page_column.dart).');
    });

    test('a page with a wider or narrower column gives its header the same width', () {
      final custom = RegExp(r'BkPageColumn\(\s*maxWidth:');
      final offenders = [
        for (final file in sources())
          if (file.readAsStringSync() case final source when custom.hasMatch(source))
            if (source.contains('BkPageHeader(') && !source.contains('columnWidth:')) file.path,
      ];
      expect(offenders, isEmpty, reason: 'Pass the column\'s maxWidth to BkPageHeader(columnWidth: ...).');
    });

    test('the shell\'s sections stay left-aligned', () {
      final offenders = <String>[];
      for (final path in shellSections) {
        final source = File(path).readAsStringSync();
        if (source.contains('BkPageColumn(')) offenders.add('$path  BkPageColumn');
        for (final m in centred.allMatches(source)) {
          if (int.parse(m.group(1)!) >= 600) offenders.add('$path  centred maxWidth ${m.group(1)}');
        }
      }
      expect(offenders, isEmpty, reason: 'Sections start at the left edge beside the sidebar.');
    });

    test('no hand-rolled centred page column', () {
      final offenders = <String>[];
      for (final file in sources()) {
        if (handRolledAllowlist.contains(file.path)) continue;
        final source = file.readAsStringSync();
        for (final m in centred.allMatches(source)) {
          if (int.parse(m.group(1)!) >= 600) {
            final line = '\n'.allMatches(source.substring(0, m.start)).length + 1;
            offenders.add('${file.path}:$line  maxWidth ${m.group(1)}');
          }
        }
      }
      expect(offenders, isEmpty, reason: 'Use BkPageColumn (lib/widgets/ui/bk_page_column.dart).');
    });
  });
}
