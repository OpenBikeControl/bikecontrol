import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The wizard's accent: the theme's brand primary, which is the brand blue in
/// light mode and a lifted brand blue in dark mode (see `BkTheme`).
Color onboardingAccent(BuildContext context) => Theme.of(context).colorScheme.primary;

/// Content drawn on top of [onboardingAccent]. White on the light brand blue;
/// near-black on dark mode's lifted blue, where white only reached ~2.6:1.
Color onboardingOnAccent(BuildContext context) => Theme.of(context).colorScheme.primaryForeground;
