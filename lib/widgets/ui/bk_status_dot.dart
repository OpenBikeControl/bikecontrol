import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

enum BkStatusTone { success, warning, danger, neutral }

/// A status as a coloured dot plus words ("● Connected"), the design's
/// replacement for tinted status pills. The words carry the meaning; the dot
/// only reinforces it.
class BkStatusDot extends StatelessWidget {
  const BkStatusDot({super.key, required this.label, this.tone = BkStatusTone.success});

  final String label;
  final BkStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final status = BkStatusColors.of(context);
    final color = switch (tone) {
      BkStatusTone.success => status.success,
      BkStatusTone.warning => status.warning,
      BkStatusTone.danger => status.danger,
      BkStatusTone.neutral => Theme.of(context).colorScheme.mutedForeground,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        SizedBox.square(
          dimension: 7,
          child: DecoratedBox(decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        ),
        Flexible(
          child: Text(
            label,
            style: context.typography.xSmall.copyWith(color: color, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
