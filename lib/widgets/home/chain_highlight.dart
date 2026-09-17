/// The highlight a chain card plays when the rider is pointed at it: who asks
/// for it, how it moves, and when it keeps still. The card itself draws it —
/// see `ChainCard.highlight`.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Tells chain cards to jump out.
///
/// One tick per card, keyed by the card's link id: bumping a card's tick plays
/// its highlight once. The page owns it, because only the page knows why a
/// card should jump out — the banner's "Show" for every outstanding card, or a
/// single card with something to say.
class ChainHighlightController {
  final Map<String, ValueNotifier<int>> _ticks = {};

  /// What the card for [linkId] listens to.
  ValueListenable<int> tickFor(String linkId) => _tick(linkId);

  /// Plays the highlight once on the card of every id in [linkIds].
  void play(Iterable<String> linkIds) {
    for (final id in linkIds) {
      _tick(id).value++;
    }
  }

  ValueNotifier<int> _tick(String linkId) => _ticks.putIfAbsent(linkId, () => ValueNotifier(0));

  void dispose() {
    for (final tick in _ticks.values) {
      tick.dispose();
    }
    _ticks.clear();
  }
}

/// Whether the rider asked for less motion: the highlight then keeps the card
/// still, and the banner's "Show" jumps to the cards instead of scrolling.
///
/// Android's "Remove animations" reaches MediaQuery; iOS's Reduce Motion only
/// arrives as its own platform flag, which MediaQuery does not carry.
bool prefersReducedMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) || View.of(context).platformDispatcher.accessibilityFeatures.reduceMotion;

/// The highlight's three beats: the card pulses, then shakes, and its accent
/// border fades out once the movement has stopped.
const int _pulseMs = 250;
const int _shakeMs = 250;
const int _fadeMs = 600;

/// One highlight, start to finish.
const Duration chainHighlightDuration = Duration(milliseconds: _pulseMs + _shakeMs + _fadeMs);

/// How much bigger the card gets at the top of the pulse.
const double _pulseGrowth = 0.03;

/// How far the shake goes to either side, and how often.
const double _shakeOffset = 4;
const int _shakeCycles = 3;

/// How the card is moved [progress] (0–1) of the way through a highlight: the
/// pulse, then the shake, then nothing while the border fades.
Matrix4 chainHighlightMotion(double progress) {
  final ms = progress * chainHighlightDuration.inMilliseconds;
  if (ms < _pulseMs) {
    // Up and back down in one arc.
    final scale = 1 + _pulseGrowth * math.sin(math.pi * ms / _pulseMs);
    return Matrix4.diagonal3Values(scale, scale, 1);
  }
  if (ms < _pulseMs + _shakeMs) {
    final shake = (ms - _pulseMs) / _shakeMs;
    return Matrix4.translationValues(_shakeOffset * math.sin(2 * math.pi * _shakeCycles * shake), 0, 0);
  }
  return Matrix4.identity();
}

/// How strong the accent border is [progress] (0–1) of the way through a
/// highlight: full while the card moves, then fading out.
double chainHighlightBorderOpacity(double progress) {
  final ms = progress * chainHighlightDuration.inMilliseconds;
  if (ms <= _pulseMs + _shakeMs) return 1;
  final fade = ((ms - _pulseMs - _shakeMs) / _fadeMs).clamp(0.0, 1.0);
  return 1 - Curves.easeOut.transform(fade);
}
