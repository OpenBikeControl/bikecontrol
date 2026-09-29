import 'package:flutter/widgets.dart';

/// Whether the rider asked for less motion: looping decorations stand still,
/// highlights keep the card still, and scrolls jump instead of animating.
///
/// Android's "Remove animations" reaches MediaQuery; iOS's Reduce Motion only
/// arrives as its own platform flag, which MediaQuery does not carry.
bool prefersReducedMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) || View.of(context).platformDispatcher.accessibilityFeatures.reduceMotion;
