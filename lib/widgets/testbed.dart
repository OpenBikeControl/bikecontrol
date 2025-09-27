import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// A developer overlay that visualizes touches and keyboard events.
/// - Touch dots appear where you touch and fade out over [touchRevealDuration].
/// - Keyboard events are listed temporarily and fade out over [keyboardRevealDuration].
class Testbed extends StatefulWidget {
  const Testbed({
    super.key,
    this.enabled = true,
    this.showTouches = true,
    this.showKeyboard = true,
    this.touchRevealDuration = const Duration(seconds: 2),
    this.keyboardRevealDuration = const Duration(seconds: 2),
    this.maxKeyboardEvents = 6,
    this.touchColor = const Color(0xFF00BCD4), // cyan-ish
    this.keyboardBadgeColor = const Color(0xCC000000), // translucent black
    this.keyboardTextStyle = const TextStyle(color: Colors.white, fontSize: 12),
  });

  final bool enabled;
  final bool showTouches;
  final bool showKeyboard;

  final Duration touchRevealDuration;
  final Duration keyboardRevealDuration;
  final int maxKeyboardEvents;

  final Color touchColor;
  final Color keyboardBadgeColor;
  final TextStyle keyboardTextStyle;

  @override
  State<Testbed> createState() => _TestbedState();
}

class _TestbedState extends State<Testbed> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  // ----- Touch tracking -----
  final Map<int, _TouchSample> _active = <int, _TouchSample>{};
  final List<_TouchSample> _history = <_TouchSample>[];

  // ----- Keyboard tracking -----
  final List<_KeySample> _keys = <_KeySample>[];

  // Focus to receive key events without stealing focus from inputs.
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'TestbedFocus', canRequestFocus: true, skipTraversal: true);

    _ticker = createTicker((_) {
      // Cull expired touch and key samples.
      final now = DateTime.now();
      _history.removeWhere((s) => now.difference(s.timestamp) > widget.touchRevealDuration);
      _keys.removeWhere((k) => now.difference(k.timestamp) > widget.keyboardRevealDuration);

      if (mounted) setState(() {});
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent e) {
    if (!widget.enabled || !widget.showTouches) return;
    final sample = _TouchSample(
      pointer: e.pointer,
      position: e.position,
      timestamp: DateTime.now(),
      phase: _TouchPhase.down,
    );
    _active[e.pointer] = sample;
    _history.add(sample);
    setState(() {});
  }

  void _onPointerCancel(PointerCancelEvent e) {
    if (!widget.enabled || !widget.showTouches || !mounted) return;
    _active.remove(e.pointer);
    setState(() {});
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!widget.enabled || !widget.showKeyboard || event is KeyUpEvent) return KeyEventResult.ignored;

    final label = event.logicalKey.keyLabel;
    final keyName = label.isNotEmpty ? label : event.logicalKey.debugName ?? 'Key';
    final isDown = event is KeyDownEvent;
    final isUp = event is KeyUpEvent;

    // Filter out repeat KeyDowns if desired (optional).
    // Here we keep them; comment this block in to drop repeats:
    // if (event.repeat) return KeyEventResult.handled;

    final sample = _KeySample(
      text:
          '${isDown
              ? "↓"
              : isUp
              ? "↑"
              : "•"} $keyName',
      timestamp: DateTime.now(),
    );
    _keys.insert(0, sample);
    if (_keys.length > widget.maxKeyboardEvents) {
      _keys.removeLast();
    }
    setState(() {});
    // We don't want to prevent normal text input, so we return ignored.
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerCancel: _onPointerCancel,
      behavior: HitTestBehavior.translucent,
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        canRequestFocus: true,
        descendantsAreFocusable: true,
        onKeyEvent: _onKey,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            if (widget.showTouches)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _TouchesPainter(
                      now: DateTime.now(),
                      samples: _history,
                      duration: widget.touchRevealDuration,
                      color: widget.touchColor,
                    ),
                  ),
                ),
              ),
            if (widget.showKeyboard)
              Positioned(
                left: 12,
                bottom: 12,
                child: IgnorePointer(
                  child: _KeyboardOverlay(
                    items: _keys,
                    duration: widget.keyboardRevealDuration,
                    badgeColor: widget.keyboardBadgeColor,
                    textStyle: widget.keyboardTextStyle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ===== Touches =====

enum _TouchPhase { down, move, up }

class _TouchSample {
  _TouchSample({required this.pointer, required this.position, required this.timestamp, required this.phase});

  final int pointer;
  final Offset position;
  final DateTime timestamp;
  final _TouchPhase phase;
}

class _TouchesPainter extends CustomPainter {
  _TouchesPainter({required this.now, required this.samples, required this.duration, required this.color});

  final DateTime now;
  final List<_TouchSample> samples;
  final Duration duration;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

    for (final s in samples) {
      final age = now.difference(s.timestamp);
      if (age > duration) continue;

      final t = age.inMilliseconds / duration.inMilliseconds.clamp(1, 1 << 30);
      final fade = (1.0 - t).clamp(0.0, 1.0);

      // Two concentric circles: inner filled pulse + outer ring.
      final baseRadius = 22.0;
      final pulse = 1.0 + 0.5 * math.sin(t * math.pi); // subtle pulsing
      final rOuter = baseRadius * (1.0 + 0.35 * t);
      final rInner = baseRadius * 0.5 * pulse;

      // Outer ring (stroke, fading)
      paint
        ..style = PaintingStyle.stroke
        ..color = color.withOpacity(0.35 * fade);
      canvas.drawCircle(s.position, rOuter, paint);

      // Inner fill (stronger)
      final fill =
          Paint()
            ..style = PaintingStyle.fill
            ..color = color.withOpacity(0.35 + 0.35 * fade);
      canvas.drawCircle(s.position, rInner, fill);

      // Tiny center dot for precision
      final center =
          Paint()
            ..style = PaintingStyle.fill
            ..color = color.withOpacity(0.9 * fade);
      canvas.drawCircle(s.position, 2.5, center);
    }
  }

  @override
  bool shouldRepaint(covariant _TouchesPainter oldDelegate) {
    return oldDelegate.now != now ||
        oldDelegate.samples != samples ||
        oldDelegate.duration != duration ||
        oldDelegate.color != color;
  }
}

// ===== Keyboard overlay =====

class _KeySample {
  _KeySample({required this.text, required this.timestamp});
  final String text;
  final DateTime timestamp;
}

class _KeyboardOverlay extends StatelessWidget {
  const _KeyboardOverlay({
    super.key,
    required this.items,
    required this.duration,
    required this.badgeColor,
    required this.textStyle,
  });

  final List<_KeySample> items;
  final Duration duration;
  final Color badgeColor;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          _KeyboardToast(
            text: item.text,
            age: now.difference(item.timestamp),
            duration: duration,
            badgeColor: badgeColor,
            textStyle: textStyle,
          ),
      ],
    );
  }
}

class _KeyboardToast extends StatelessWidget {
  const _KeyboardToast({
    required this.text,
    required this.age,
    required this.duration,
    required this.badgeColor,
    required this.textStyle,
  });

  final String text;
  final Duration age;
  final Duration duration;
  final Color badgeColor;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    final t = (age.inMilliseconds / duration.inMilliseconds.clamp(1, 1 << 30)).clamp(0.0, 1.0);
    final fade = 1.0 - t;

    return Opacity(
      opacity: fade,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: textStyle),
      ),
    );
  }
}
