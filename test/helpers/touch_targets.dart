import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The action buttons on screen: shadcn's filled and outlined variants
/// (primary, secondary, outline, destructive), however they were built.
/// Ghost, link and text buttons are inline affordances and not included.
Finder actionButtons() => find.byWidgetPredicate((w) {
  if (w is! Button) return false;
  final style = w.style;
  final variance = style is ButtonStyle ? style.variance : style;
  return const [
    ButtonVariance.primary,
    ButtonVariance.secondary,
    ButtonVariance.outline,
    ButtonVariance.destructive,
  ].contains(variance);
});

/// Android's minimum touch target: every action button on screen is at least
/// 48×48 logical px. Returns the offenders, described, for a readable failure.
List<String> actionButtonsBelowAndroidTarget(WidgetTester tester) => [
  for (final element in actionButtons().evaluate())
    if (element.size case final size? when size.width < 47.5 || size.height < 47.5)
      '${element.widget.toStringShort()} ${size.width.toStringAsFixed(1)}×${size.height.toStringAsFixed(1)} '
          '"${find.descendant(of: find.byWidget(element.widget), matching: find.byType(Text)).evaluate().map((e) => (e.widget as Text).data).join(' ')}"',
];

/// Any tappable, found however: each of [targets] is at least 48×48 logical
/// px. Returns the offenders, described, for a readable failure.
List<String> targetsBelowAndroidMinimum(WidgetTester tester, List<Finder> targets) => [
  for (final target in targets)
    if (tester.getSize(target) case final size when size.width < 47.5 || size.height < 47.5)
      '$target ${size.width.toStringAsFixed(1)}×${size.height.toStringAsFixed(1)}',
];
