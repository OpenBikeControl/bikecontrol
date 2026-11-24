import 'package:shadcn_flutter/shadcn_flutter.dart';

/// How tall the onboarding body's visible area is (the scroll viewport minus
/// its padding), for a step that wants to centre its content in it rather than
/// stack it from the top. Null outside the wizard's scroll area.
class OnboardingViewport extends InheritedWidget {
  const OnboardingViewport({super.key, required this.bodyHeight, required super.child});

  final double bodyHeight;

  static double? bodyHeightOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OnboardingViewport>()?.bodyHeight;

  @override
  bool updateShouldNotify(OnboardingViewport old) => old.bodyHeight != bodyHeight;
}
