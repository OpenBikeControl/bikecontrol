import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/widgets/keymap/mapping.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_pill_button.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Said in the action picker under a hold-only action
/// ([InGameAction.requiresHold]) picked for a single or double click: why it
/// does next to nothing there, and one tap to move it to the long press.
class HoldActionWarning extends StatelessWidget {
  const HoldActionWarning({super.key, required this.action, required this.onAssignToLongPress});

  final InGameAction action;
  final VoidCallback? onAssignToLongPress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = BkStatusColors.of(context);
    return Container(
      key: const ValueKey('hold-action-warning'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: status.warningWash,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: status.warning.withAlpha(110)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(LucideIcons.triangleAlert, size: 18, color: status.warning),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 10,
              children: [
                Text(
                  holdActionWarningText(context, action),
                  style: context.typography.small.copyWith(color: cs.foreground),
                ),
                if (onAssignToLongPress != null)
                  BkPillButton.secondary(
                    key: const ValueKey('hold-action-assign-long-press'),
                    expand: false,
                    onPressed: onAssignToLongPress,
                    child: Text(context.i18n.holdAssignToLongPress),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The compact sign on a mapping row whose action only works while held but
/// sits on a click — so the misconfiguration shows without opening the row.
/// Rows that label themselves add [holdActionMarkerLabel] to their label;
/// elsewhere [announce] lets the marker say it.
class HoldActionMarker extends StatelessWidget {
  const HoldActionMarker({super.key, this.size = 14, this.announce = false});

  final double size;
  final bool announce;

  @override
  Widget build(BuildContext context) {
    final icon = ExcludeSemantics(
      child: Icon(
        LucideIcons.triangleAlert,
        key: const ValueKey('hold-action-marker'),
        size: size,
        color: BkStatusColors.of(context).warning,
      ),
    );
    return announce ? Semantics(label: holdActionMarkerLabel(context), child: icon) : icon;
  }
}

/// Whether any trigger of [button] in [keymap] has a hold-only action on a click.
bool mappingHasHoldActionOnClick(Keymap keymap, ControllerButton button) =>
    keymap.getKeyPairs(button).any((kp) => kp.holdActionOnClick);

/// What a marked row adds to its accessible label.
String holdActionMarkerLabel(BuildContext context) => context.i18n.holdOnlyWhileHeld;
