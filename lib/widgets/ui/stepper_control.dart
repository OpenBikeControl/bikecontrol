import 'package:shadcn_flutter/shadcn_flutter.dart';

class StepperControl extends StatelessWidget {
  final double value;
  final double step;
  final double min;
  final double max;
  final String Function(double) format;
  final ValueChanged<double> onChanged;

  const StepperControl({
    super.key,
    required this.value,
    required this.step,
    required this.min,
    required this.max,
    required this.format,
    required this.onChanged,
  });

  double _clamp(double v) => v < min ? min : (v > max ? max : v);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.muted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.ghost(
            key: const ValueKey('stepper-minus'),
            icon: const Icon(LucideIcons.minus, size: 14),
            onPressed: value > min ? () => onChanged(_clamp(value - step)) : null,
          ),
          SizedBox(
            width: 64,
            child: Center(
              child: Text(
                format(value),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          IconButton.ghost(
            key: const ValueKey('stepper-plus'),
            icon: const Icon(LucideIcons.plus, size: 14),
            onPressed: value < max ? () => onChanged(_clamp(value + step)) : null,
          ),
        ],
      ),
    );
  }
}
