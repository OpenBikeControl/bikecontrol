// BETA / EXPER. mark a connection method or device as not finished yet. That
// is information, not danger: a neutral badge, legible in both themes.
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/beta_pill.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../helpers/contrast.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('$brightness: BETA is a neutral badge that clears 4.5:1 on a card', (tester) async {
      final cs = BkTheme.build(brightness).colorScheme;
      await tester.pumpWidget(
        ShadcnApp(
          theme: BkTheme.build(brightness),
          home: BkComponentThemes(
            child: ColoredBox(
              color: cs.card,
              child: const Center(child: BetaPill()),
            ),
          ),
        ),
      );
      expect(find.byType(DestructiveBadge), findsNothing);
      final text = tester.renderObject<RenderParagraph>(find.text('BETA'));
      final bg = paintedBackgroundOf(text, cs.card);
      expect(bg, isNot(cs.destructive));
      final fg = Color.alphaBlend(text.text.style!.color!, bg);
      expect(contrast(fg, bg), greaterThanOrEqualTo(4.5));
    });
  }
}
