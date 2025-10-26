import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:swift_control/link/link.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/pages/device.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:swift_control/widgets/button_widget.dart';

class InGameActionsCustomizer extends StatefulWidget {
  const InGameActionsCustomizer({super.key});

  @override
  State<InGameActionsCustomizer> createState() => _InGameActionsCustomizerState();
}

class _InGameActionsCustomizerState extends State<InGameActionsCustomizer> {
  @override
  Widget build(BuildContext context) {
    final connectedDevice = connection.devices.firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        Table(
          border: TableBorder.symmetric(
            borderRadius: BorderRadius.circular(9),
            inside: BorderSide(
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            outside: BorderSide(
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
          ),
          children: [
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    'Button on your ${connectedDevice?.name.screenshot ?? connectedDevice?.runtimeType ?? 'device'}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    'Action on MyWhoosh',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            for (final button in connectedDevice?.availableButtons ?? <ControllerButton>[]) ...[
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Row(
                      children: [
                        ButtonWidget(button: button),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Row(
                      children: [
                        if (MediaQuery.sizeOf(context).width < 1800)
                          Expanded(child: _buildDropdownButton(button, true))
                        else
                          _buildDropdownButton(button, false),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildDropdownButton(ControllerButton button, bool expand) {
    final value = WhooshLink.supportedActions.contains(settings.getInGameActionForButton(button))
        ? settings.getInGameActionForButton(button)
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButton<InGameAction>(
          isExpanded: expand,
          items: WhooshLink.supportedActions
              .map(
                (ingame) => DropdownMenuItem(
                  value: ingame,
                  child: Text(ingame.toString()),
                ),
              )
              .toList(),
          padding: EdgeInsets.zero,
          menuWidth: 250,
          value: value,
          onChanged: (action) {
            settings.setInGameActionForButton(
              button,
              action!,
            );
            setState(() {});
          },
        ),
        if (value?.possibleValues != null)
          DropdownButton<int>(
            items: value!.possibleValues!
                .map((val) => DropdownMenuItem<int>(value: val, child: Text(val.toString())))
                .toList(),
            value: settings.getInGameActionForButtonValue(button),
            onChanged: (val) {
              settings.setInGameActionForButtonValue(
                button,
                value,
                val!,
              );
              setState(() {});
            },
            hint: Text('Value'),
          ),
      ],
    );
  }
}
