import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:prop/prop.dart';
import 'package:bike_control/utils/actions/base_actions.dart' as actions;
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/widgets/ui/button_widget.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../bluetooth/messages/notification.dart';

/// A developer overlay that visualizes touches and keyboard events.
/// - Touch dots appear where you touch and fade out over [touchRevealDuration].
/// - Keyboard events are listed temporarily and fade out over [keyboardRevealDuration].
class Testbed extends StatefulWidget {
  const Testbed({
    super.key,
    this.enabled = true,
    this.showTouches = true,
    this.showKeyboard = true,
    this.touchRevealDuration = const Duration(seconds: 3),
    this.keyboardRevealDuration = const Duration(seconds: 3),
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

class _TestbedState extends State<Testbed> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  late StreamSubscription<BaseNotification> _actionSubscription;

  // ----- Touch tracking -----
  final Map<int, _TouchSample> _active = <int, _TouchSample>{};
  final List<_TouchSample> _history = <_TouchSample>[];

  // ----- Keyboard tracking -----
  final List<_KeySample> _keys = <_KeySample>[];
  final List<_ActionSample> _actions = <_ActionSample>[];

  // Focus to receive key events without stealing focus from inputs.
  late final FocusNode _focusNode;
  bool _isMobile = false;

  Offset? _lastMove;

  bool _isInBackground = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _isMobile = MediaQuery.sizeOf(context).width < 600;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isInBackground = state == AppLifecycleState.paused || state == AppLifecycleState.hidden;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _focusNode = FocusNode(debugLabel: 'TestbedFocus', canRequestFocus: true, skipTraversal: true);
    _actionSubscription = core.connection.actionStream.listen((data) async {
      if (!mounted || (_isInBackground && data is! AlertNotification)) {
        return;
      }
      if (data is ButtonNotification && data.buttonsClicked.isNotEmpty) {
        if (core.settings.getShowOnboarding()) {
          final button = data.buttonsClicked.first;
          final sample = _KeySample(
            button: button,
            text: '🔘 ${button.name}',
            timestamp: DateTime.now(),
          );
          _keys.insert(0, sample);
          if (_keys.length > widget.maxKeyboardEvents) {
            _keys.removeLast();
          }
        } else if (core.actionHandler.supportedApp == null) {
          buildToast(context, level: LogLevel.LOGLEVEL_WARNING, title: context.i18n.selectTrainerAppAndTarget);
        } else {
          final button = data.buttonsClicked.first;
          if (core.actionHandler.supportedApp is! CustomApp &&
              core.actionHandler.supportedApp?.keymap.getKeyPair(button) == null) {
            buildToast(
              context,
              level: LogLevel.LOGLEVEL_WARNING,
              titleWidget: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '${context.i18n.useCustomKeymapForButton} '),
                    WidgetSpan(
                      child: ButtonWidget(button: button),
                    ),
                    TextSpan(
                      text: context.i18n.button,
                    ),
                  ],
                ),
              ),
            );
          } else {
            /*final isMobile = MediaQuery.sizeOf(context).width < 600;
            buildToast(
              context,
              location: isMobile ? ToastLocation.topCenter : ToastLocation.bottomRight,
              titleWidget: Wrap(children: data.buttonsClicked.map((button) => ButtonWidget(button: button)).toList()),
            );*/
            final sample = _KeySample(
              button: button,
              text: '🔘 ${button.name}',
              timestamp: DateTime.now(),
            );
            _keys.insert(0, sample);
            if (_keys.length > widget.maxKeyboardEvents) {
              _keys.removeLast();
            }
          }
        }
      } else if (data is ActionNotification && data.result is! actions.Ignored) {
        buildToast(
          context,
          location: ToastLocation.bottomLeft,
          level: data.result is actions.Error ? LogLevel.LOGLEVEL_WARNING : LogLevel.LOGLEVEL_INFO,
          title: data.result.message,
          duration: Duration(seconds: 1),
        );
      } else if (data is AlertNotification) {
        buildToast(
          context,
          location: ToastLocation.bottomRight,
          level: data.level,
          title: data.alertMessage,
          closeTitle: data.buttonTitle ?? 'Close',
          onClose: data.onTap,
        );
      }
    });

    _ticker = createTicker((_) {
      // Cull expired touch and key samples.
      final now = DateTime.now();
      _keys.removeWhere((s) => now.difference(s.timestamp) > widget.touchRevealDuration);
      _history.removeWhere((s) => now.difference(s.timestamp) > widget.touchRevealDuration);
      _actions.removeWhere((k) => now.difference(k.timestamp) > widget.keyboardRevealDuration);

      if (mounted) {
        setState(() {});
      }
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent e) {
    if (!widget.enabled ||
        !widget.showTouches ||
        ((_lastMove ?? Offset.zero) - e.position).distance < 5 ||
        (e.kind != PointerDeviceKind.unknown && e.kind != PointerDeviceKind.mouse)) {
      return;
    }
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

  void _onPointerHover(PointerHoverEvent e) {
    Future<void>.delayed(Duration(milliseconds: 30)).then((_) {
      // delay a bit for better detection of a real click vs fake one
      _lastMove = e.position;
    });
  }

  void _onPointerUp(PointerUpEvent e) {
    if (!widget.enabled ||
        !widget.showTouches ||
        ((_lastMove ?? Offset.zero) - e.position).distance < 5 ||
        (e.kind != PointerDeviceKind.unknown && e.kind != PointerDeviceKind.mouse)) {
      return;
    }
    final sample = _TouchSample(
      pointer: e.pointer,
      position: e.position,
      timestamp: DateTime.now(),
      phase: _TouchPhase.up,
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

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerHover: _onPointerHover,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      behavior: HitTestBehavior.translucent,
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        canRequestFocus: true,
        descendantsAreFocusable: true,
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
                right: 12,
                bottom: _isMobile && !core.settings.getShowOnboarding() ? 92 : 12,
                child: IgnorePointer(
                  child: _KeyboardOverlay(
                    items: _keys,
                    duration: widget.keyboardRevealDuration,
                    badgeColor: widget.keyboardBadgeColor,
                    textStyle: widget.keyboardTextStyle,
                  ),
                ),
              ),
            if (widget.showKeyboard)
              Positioned(
                right: 12,
                bottom: 12,
                child: IgnorePointer(
                  child: _ActionOverlay(
                    items: _actions,
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
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final s in samples) {
      final age = now.difference(s.timestamp);
      if (age > duration) continue;

      final color = s.phase == _TouchPhase.down ? this.color : Colors.red;

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
      final fill = Paint()
        ..style = PaintingStyle.fill
        ..color = color.withOpacity(0.35 + 0.35 * fade);
      canvas.drawCircle(s.position, rInner, fill);

      // Tiny center dot for precision
      final center = Paint()
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
  _KeySample({required this.text, required this.timestamp, this.button});
  final ControllerButton? button;
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
            item: item,
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
    required this.item,
    required this.age,
    required this.duration,
    required this.badgeColor,
    required this.textStyle,
  });

  final _KeySample item;
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
        child: item.button != null ? ButtonWidget(button: item.button!) : Text(item.text, style: textStyle),
      ),
    );
  }
}

// ===== Action overlay =====

class _ActionSample {
  _ActionSample({required this.text, required this.timestamp, required this.isError});
  final String text;
  final DateTime timestamp;
  final bool isError;
}

class _ActionOverlay extends StatelessWidget {
  const _ActionOverlay({
    super.key,
    required this.items,
    required this.duration,
    required this.badgeColor,
    required this.textStyle,
  });

  final List<_ActionSample> items;
  final Duration duration;
  final Color badgeColor;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final item in items)
          _ActionToast(
            item: item,
            age: now.difference(item.timestamp),
            duration: duration,
            badgeColor: badgeColor,
            textStyle: textStyle,
          ),
      ],
    );
  }
}

class _ActionToast extends StatelessWidget {
  const _ActionToast({
    required this.item,
    required this.age,
    required this.duration,
    required this.badgeColor,
    required this.textStyle,
  });

  final _ActionSample item;
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
        decoration: BoxDecoration(
          color: item.isError ? Colors.red.withOpacity(0.8) : badgeColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(item.text, style: textStyle),
      ),
    );
  }
}
