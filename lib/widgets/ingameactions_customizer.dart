import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/pages/device.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:swift_control/widgets/keymap_explanation.dart';

class IngameactionsCustomizer extends StatefulWidget {
  const IngameactionsCustomizer({super.key});

  @override
  State<IngameactionsCustomizer> createState() => _IngameactionsCustomizerState();
}

class _IngameactionsCustomizerState extends State<IngameactionsCustomizer> {
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
                    'Button on your ${connectedDevice?.device.name?.screenshot ?? connectedDevice?.runtimeType ?? 'device'}',
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
                        IntrinsicWidth(child: ButtonWidget(button: button)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Row(
                      children: [
                        DropdownButton<InGameAction>(
                          isDense: true,
                          items: InGameAction.values
                              .map(
                                (ingame) => DropdownMenuItem(
                                  value: ingame,
                                  child: Text(ingame.toString()),
                                ),
                              )
                              .toList(),
                          value: settings.getInGameActionForButton(button),
                          onChanged: (action) {
                            settings.setInGameActionForButton(
                              button,
                              action!,
                            );
                            setState(() {});
                          },
                        ),
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
}
