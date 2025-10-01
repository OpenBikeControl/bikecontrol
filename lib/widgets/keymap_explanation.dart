import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/keymap/keymap.dart';

import '../pages/touch_area.dart';

class KeymapExplanation extends StatelessWidget {
  final Keymap keymap;
  final VoidCallback onUpdate;
  const KeymapExplanation({super.key, required this.keymap, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final connectedDevice = connection.devices.firstOrNull;

    final availableKeypairs = keymap.keyPairs.filter(
      (e) => connectedDevice?.availableButtons.containsAny(e.buttons) == true,
    );

    final keyboardGroups = availableKeypairs
        .filter((e) => e.physicalKey != null)
        .groupBy((element) => '${element.physicalKey?.usbHidUsage}-${element.isLongPress}');
    final touchGroups = availableKeypairs
        .filter((e) => e.physicalKey == null && e.touchPosition != Offset.zero)
        .groupBy((element) => '${element.touchPosition.dx}-${element.touchPosition.dy}-${element.isLongPress}');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        if (keymap.keyPairs.isEmpty)
          Text('No key mappings found. Please customize the keymap.')
        else
          Table(
            border: TableBorder.all(color: Theme.of(context).colorScheme.primaryContainer),
            children: [
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      'Button on your ${connectedDevice?.device.name ?? connectedDevice?.runtimeType}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      'Action',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              for (final pair in keyboardGroups.entries) ...[
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final keyPair in pair.value)
                            for (final button in keyPair.buttons)
                              if (connectedDevice?.availableButtons.contains(button) == true)
                                IntrinsicWidth(child: KeyWidget(label: button.name)),
                        ],
                      ),
                    ),
                    Padding(padding: const EdgeInsets.all(6), child: KeypairExplanation(keyPair: pair.value.first)),
                  ],
                ),
              ],
              for (final pair in touchGroups.entries) ...[
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Row(
                        spacing: 8,
                        children: [
                          for (final keyPair in pair.value)
                            for (final button in keyPair.buttons)
                              if (connectedDevice?.availableButtons.contains(button) == true)
                                KeyWidget(label: button.name),
                        ],
                      ),
                    ),
                    Padding(padding: const EdgeInsets.all(6), child: KeypairExplanation(keyPair: pair.value.first)),
                  ],
                ),
              ],
            ],
          ),
      ],
    );
  }
}

class KeyWidget extends StatelessWidget {
  final String label;
  const KeyWidget({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return IntrinsicWidth(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        constraints: BoxConstraints(minWidth: 30),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.primary),
          borderRadius: BorderRadius.circular(4),
          color: Theme.of(context).colorScheme.primaryContainer,
        ),
        child: Center(
          child: Text(
            label.splitByUpperCase(),
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

extension SplitByUppercase on String {
  String splitByUpperCase() {
    return replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (match) => '${match.group(1)} ${match.group(2)}').capitalize();
  }
}
