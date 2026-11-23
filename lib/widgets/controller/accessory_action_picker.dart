import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/widgets/controller/controller_canvas.dart';
import 'package:bike_control/widgets/controller/trigger_assignment_popup.dart';
import 'package:bike_control/widgets/ui/button_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Where an accessory action sits: a controller, one of its buttons and the
/// press that fires it.
typedef AccessoryActionSlot = ({BaseDevice controller, ControllerButton button, ButtonTrigger trigger});

/// Puts [action] on a button (a null button takes it off).
typedef AccessoryActionAssign =
    Future<void> Function(BaseDevice controller, ControllerButton? button, ButtonTrigger? trigger);

/// An accessory action's button picker: each connected controller's own
/// picture with its buttons. Tapping a button asks for single, double or long
/// press, then puts the action there and closes.
class AccessoryActionPicker extends StatelessWidget {
  const AccessoryActionPicker({
    super.key,
    required this.action,
    required this.controllers,
    required this.assigned,
    required this.onAssign,
  });

  final InGameAction action;
  final List<BaseDevice> controllers;
  final AccessoryActionSlot? assigned;
  final AccessoryActionAssign onAssign;

  static const double _buttonSize = 48;

  Future<void> _assign(
    BuildContext context,
    BaseDevice controller,
    ControllerButton? button,
    ButtonTrigger? trigger,
  ) async {
    await onAssign(controller, button, trigger);
    if (context.mounted) await closeDrawer(context);
  }

  void _pickTrigger(BuildContext context, BuildContext buttonContext, BaseDevice controller, ControllerButton button) {
    final keymap = core.actionHandler.supportedApp?.keymap;
    if (keymap == null) return;
    showDropdown<void>(
      context: buttonContext,
      consumeOutsideTaps: true,
      builder: (_) => DropdownMenu(
        children: [
          MenuLabel(
            child: ButtonWidget(button: button, size: 42, keymap: keymap),
          ),
          for (final trigger in ButtonTrigger.values)
            MenuButton(
              key: ValueKey('accessory-trigger-${trigger.name}'),
              onPressed: (_) => _assign(context, controller, button, trigger),
              child: TriggerAssignmentLabel(trigger: trigger, keymap: keymap, button: button),
            ),
        ],
      ),
    );
  }

  Widget _button(BuildContext context, BaseDevice controller, ControllerButton button) {
    final cs = Theme.of(context).colorScheme;
    final isAssigned = assigned != null && assigned!.controller == controller && assigned!.button.name == button.name;
    return Builder(
      key: ValueKey('accessory-pick-${button.name}'),
      builder: (buttonContext) => Button.ghost(
        style: ButtonStyle.ghost().withPadding(padding: EdgeInsets.zero),
        onPressed: () => _pickTrigger(context, buttonContext, controller, button),
        // The button the action is on now wears a ring over its face.
        child: Container(
          foregroundDecoration: isAssigned
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: cs.primary, width: 3),
                )
              : null,
          child: ButtonWidget(button: button, size: _buttonSize, keymap: core.actionHandler.supportedApp?.keymap),
        ),
      ),
    );
  }

  Widget _picture(BuildContext context, BaseDevice controller) {
    final layout = controller.controllerLayout;
    final buttons = controller.availableButtons;
    if (layout != null) {
      return ControllerCanvas(
        layout: layout,
        availableButtons: buttons,
        buttonBuilder: (button) => _button(context, controller, button),
        buttonSize: _buttonSize,
      );
    }
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      alignment: WrapAlignment.center,
      children: [for (final button in buttons) _button(context, controller, button)],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.i18n;
    final slot = assigned;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(action.title).large.semiBold,
            const Gap(4),
            Text(l.accessoryActionPickButton).small.muted,
            for (final controller in controllers) ...[
              const Gap(20),
              if (controllers.length > 1) ...[Text(controller.displayName(context)).small.semiBold, const Gap(8)],
              _picture(context, controller),
            ],
            if (slot != null) ...[
              const Gap(20),
              Button.ghost(
                key: const ValueKey('accessory-action-remove'),
                onPressed: () => _assign(context, slot.controller, null, null),
                leading: const Icon(LucideIcons.x, size: 16),
                child: Text(l.accessoryActionRemove(slot.button.displayName)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
