import 'package:bike_control/widgets/ui/colors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The hover wash every tappable card surface shares (`HoverCardButton`,
/// `SettingTile`, `ChainCard`, the button editor's tiles).
void main() {
  Future<BuildContext> pumpTheme(WidgetTester tester, ColorScheme colorScheme) async {
    late BuildContext captured;
    await tester.pumpWidget(
      ShadcnApp(
        theme: ThemeData(colorScheme: colorScheme),
        home: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox();
          },
        ),
      ),
    );
    return captured;
  }

  // The app's own dark overrides (main.dart): a near-black navy card and a
  // mid-grey border — the pair that turned `border.withLuminance(0.94)` into
  // a near-white wash over dark cards.
  final appDark = ColorSchemes.darkSlate.copyWith(
    card: () => const Color(0xFF001A29),
    border: () => const Color(0xFF3A3A3A),
  );

  testWidgets('dark mode: the hover wash stays dark — a slight lift off the card, not a bright fill', (tester) async {
    final context = await pumpTheme(tester, appDark);
    final hover = bkCardHover(context);

    expect(hover.computeLuminance(), lessThan(0.1));
    expect(hover.computeLuminance(), greaterThan(appDark.card.computeLuminance()));
  });

  testWidgets('light mode: the existing soft grey is unchanged', (tester) async {
    final context = await pumpTheme(tester, ColorSchemes.lightSlate);

    expect(bkCardHover(context), ColorSchemes.lightSlate.border.withLuminance(0.94));
  });
}
