import 'package:bike_control/bluetooth/incline/manual_incline_device.dart';
import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:bike_control/widgets/ui/bk_icon_button.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// "4.5%" / "-2.0%" for an incline in 0.01% units, "–" before the first write.
String formatIncline001(int? grade001) => grade001 == null ? '–' : '${(grade001 / 100).toStringAsFixed(1)}%';

/// The grade the incline controller last read, null before it started.
ValueListenable<int?> _sourceGrade() => core.connection.inclineController?.sourceGrade ?? ValueNotifier<int?>(null);

/// What the incline is doing right now, in one line.
String inclineStatusText(BuildContext context, {required bool followsGrade, required int? sourceGrade}) {
  if (!followsGrade) return context.i18n.inclineHeldByHand;
  return sourceGrade == null ? context.i18n.inclineWaitingForGradient : context.i18n.inclineFollowsGradient;
}

/// An incline device's page section (Elite Rizer, KICKR Climb): the incline
/// it was last set to and why, whether it follows the trainer app's gradient,
/// and − / 0% / + to set it by hand.
class InclineSection extends StatelessWidget {
  const InclineSection({super.key, required this.device});

  final ManualInclineDevice device;

  static const double _indent = BkGroupedSection.inset + BkIconTile.size + BkGroupedRow.gap;

  Future<void> _apply(InGameAction action) async {
    try {
      await device.applyInclineAction(action);
    } catch (e, s) {
      recordError(e, s, context: 'InclineSection: $action failed');
    }
  }

  Future<void> _setFollow(bool follow) async {
    if (follow) return _apply(InGameAction.inclineAutoMode);
    // Leaving auto holds the incline where the grade had put it.
    device.inclineState.holdAt(device.inclineApplied.value ?? device.inclineState.grade001);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.i18n;
    final sourceGrade = _sourceGrade();
    return ListenableBuilder(
      listenable: Listenable.merge([device.inclineState, device.inclineApplied, sourceGrade]),
      builder: (context, _) {
        final follows = device.followsGrade;
        return BkGroupedSection(
          header: l.inclineActions,
          dividerIndent: _indent,
          children: [
            BkGroupedRow(
              key: const ValueKey('incline-current'),
              icon: LucideIcons.mountain,
              title: l.inclineCurrent,
              subtitle: inclineStatusText(context, followsGrade: follows, sourceGrade: sourceGrade.value),
              trailing: Text(
                formatIncline001(device.inclineApplied.value),
                style: context.typography.base.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            BkGroupedRow(
              key: const ValueKey('incline-follow'),
              icon: LucideIcons.trendingUp,
              title: l.inclineFollowGradient,
              subtitle: l.inclineFollowGradientBody,
              trailing: Switch(value: follows, onChanged: _setFollow),
              onPressed: () => _setFollow(!follows),
            ),
            BkGroupedRow(
              key: const ValueKey('incline-manual'),
              icon: LucideIcons.slidersHorizontal,
              title: l.inclineSetByHand,
              subtitle: l.inclineSetByHandBody,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: [
                  BkIconButton.outline(
                    key: const ValueKey('incline-down'),
                    icon: const Icon(LucideIcons.minus),
                    label: InGameAction.inclineDecrease.title,
                    onPressed: () => _apply(InGameAction.inclineDecrease),
                  ),
                  BkIconButton.outline(
                    key: const ValueKey('incline-zero'),
                    icon: const Text('0%'),
                    label: InGameAction.inclineZero.title,
                    onPressed: () => _apply(InGameAction.inclineZero),
                  ),
                  BkIconButton.outline(
                    key: const ValueKey('incline-up'),
                    icon: const Icon(LucideIcons.plus),
                    label: InGameAction.inclineIncrease.title,
                    onPressed: () => _apply(InGameAction.inclineIncrease),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Ride tab: one quiet line under an incline device's card — "Incline 4.5% ·
/// Follows the gradient from your trainer app".
class InclineRideReadout extends StatelessWidget {
  const InclineRideReadout({super.key, required this.device});

  final ManualInclineDevice device;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sourceGrade = _sourceGrade();
    return ListenableBuilder(
      listenable: Listenable.merge([device.inclineState, device.inclineApplied, sourceGrade]),
      builder: (context, _) => Row(
        spacing: 6,
        children: [
          Icon(LucideIcons.mountain, size: 14, color: cs.mutedForeground),
          Flexible(
            child: Text(
              '${context.i18n.inclineRideReadout(formatIncline001(device.inclineApplied.value))} · '
              '${inclineStatusText(context, followsGrade: device.followsGrade, sourceGrade: sourceGrade.value)}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.typography.xSmall.copyWith(color: cs.mutedForeground),
            ),
          ),
        ],
      ),
    );
  }
}
