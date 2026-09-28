import 'dart:async';

import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Reusable building blocks for a staged "guided operation" sheet — a step
/// rail, a tone-washed icon badge, and an animated progress checklist. These
/// are deliberately free of any device/feature specifics so other setup flows
/// can compose them.

/// A compact "step N of [count]" progress rail: [count] dots with the active
/// one widened and tinted with the theme's primary colour. Text is omitted on
/// purpose — the widened dot carries the position without needing localized
/// copy.
class StepRail extends StatelessWidget {
  final int step;
  final int count;
  const StepRail({super.key, required this.step, this.count = 2});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Text(
          'Step $step of $count'.toUpperCase(),
          style: context.typography.xSmall.copyWith(color: scheme.mutedForeground),
        ).bold,
        Gap(12),
        for (var i = 1; i <= count; i++) ...[
          if (i > 1) const Gap(6),
          Container(
            width: i == step ? 18 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: i == step ? scheme.primary : scheme.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ],
    );
  }
}

/// A 58px tone-washed circular icon badge with a pop-in on mount (skipped under
/// reduced motion). [tone] colours the icon; [wash] fills the circle behind it.
class StageBadge extends StatelessWidget {
  final IconData icon;
  final Color tone;
  final Color wash;
  final bool reduceMotion;
  const StageBadge({
    super.key,
    required this.icon,
    required this.tone,
    required this.wash,
    required this.reduceMotion,
  });

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      width: 58,
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: wash, shape: BoxShape.circle),
      child: Icon(icon, size: 28, color: tone),
    );
    if (reduceMotion) return badge;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1.0),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: badge,
    );
  }
}

/// A progress checklist. When [autoAdvance] is on, a cosmetic timer advances the
/// "current" row every ~650ms (the real driver is the caller changing stages).
/// Under reduced motion the timer and spinner are skipped (a static in-progress
/// marker is shown). [doneColor]/[checkColor] style the completed marker.
class ProgressChecklist extends StatefulWidget {
  final List<String> items;
  final bool reduceMotion;
  final int initialStep;
  final bool autoAdvance;
  final Color doneColor;
  final Color checkColor;
  const ProgressChecklist({
    super.key,
    required this.items,
    required this.reduceMotion,
    this.initialStep = 0,
    this.autoAdvance = true,
    this.doneColor = const Color(0xFF22C55E),
    this.checkColor = const Color(0xFFFFFFFF),
  });

  @override
  State<ProgressChecklist> createState() => _ProgressChecklistState();
}

class _ProgressChecklistState extends State<ProgressChecklist> {
  late int _current = widget.initialStep;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.autoAdvance && !widget.reduceMotion) {
      _timer = Timer.periodic(const Duration(milliseconds: 650), (t) {
        if (!mounted) return;
        if (_current >= widget.items.length - 1) {
          t.cancel();
          return;
        }
        setState(() => _current++);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < widget.items.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                _marker(i, scheme),
                const Gap(12),
                Expanded(
                  child: Text(
                    widget.items[i],
                    style: context.typography.small.copyWith(
                      fontWeight: FontWeight.w600,
                      color: i > _current ? scheme.mutedForeground.withValues(alpha: 0.4) : scheme.foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _marker(int i, ColorScheme scheme) {
    const double d = 20;
    if (i < _current) {
      return Container(
        width: d,
        height: d,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: widget.doneColor, shape: BoxShape.circle),
        child: Icon(LucideIcons.check, size: 12, color: widget.checkColor),
      );
    }
    if (i == _current) {
      if (widget.reduceMotion) {
        return Container(
          width: d,
          height: d,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: scheme.primary, width: 2.5),
          ),
        );
      }
      return SizedBox(
        width: d,
        height: d,
        child: CircularProgressIndicator(size: d, strokeWidth: 2.5, color: scheme.primary),
      );
    }
    return Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: scheme.border, width: 2),
      ),
    );
  }
}
