import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/action_groups.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The head of one [ActionGroup] in the action picker: a tinted icon in the
/// group's hue and its name, so the groups stay apart while scrolling.
class ActionGroupTitle extends StatelessWidget {
  const ActionGroupTitle({super.key, required this.group});

  final ActionGroup group;

  static IconData iconOf(ActionGroup group) => switch (group) {
    ActionGroup.gears => LucideIcons.cog,
    ActionGroup.trainer => LucideIcons.zap,
    ActionGroup.workout => LucideIcons.timer,
    ActionGroup.ride => LucideIcons.bike,
    ActionGroup.navigate => LucideIcons.move,
    ActionGroup.view => LucideIcons.eye,
    ActionGroup.controller => LucideIcons.gamepad2,
    ActionGroup.system => LucideIcons.settings2,
  };

  static Color hueOf(ActionGroup group) => switch (group) {
    ActionGroup.gears => const Color(0xFF7CB342),
    ActionGroup.trainer => const Color(0xFFF59E0B),
    ActionGroup.workout => const Color(0xFFEC4899),
    ActionGroup.ride => const Color(0xFF14B8A6),
    ActionGroup.navigate => const Color(0xFF3B8EF0),
    ActionGroup.view => const Color(0xFFA27BEF),
    ActionGroup.controller => const Color(0xFFD97757),
    ActionGroup.system => const Color(0xFF94A3B8),
  };

  static String nameOf(BuildContext context, ActionGroup group) {
    final l = context.i18n;
    return switch (group) {
      ActionGroup.gears => l.actionGroupGears,
      ActionGroup.trainer => l.actionGroupTrainer,
      ActionGroup.workout => l.actionGroupWorkout,
      ActionGroup.ride => l.actionGroupRide,
      ActionGroup.navigate => l.actionGroupNavigate,
      ActionGroup.view => l.actionGroupView,
      ActionGroup.controller => l.actionGroupController,
      ActionGroup.system => l.actionGroupSystem,
    };
  }

  @override
  Widget build(BuildContext context) {
    final hue = hueOf(group);
    return Semantics(
      header: true,
      child: Row(
        spacing: 8,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: hue.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(iconOf(group), size: 14, color: hue),
          ),
          Text(nameOf(context, group)).small.semiBold,
        ],
      ),
    );
  }
}
