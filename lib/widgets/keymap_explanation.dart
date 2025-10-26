import 'dart:async';

import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/pages/device.dart';
import 'package:swift_control/utils/actions/base_actions.dart';
import 'package:swift_control/utils/keymap/apps/custom_app.dart';
import 'package:swift_control/utils/keymap/keymap.dart';
import 'package:swift_control/widgets/button_widget.dart';
import 'package:swift_control/widgets/custom_keymap_selector.dart';

import '../pages/touch_area.dart';

class KeymapExplanation extends StatefulWidget {
  final Keymap keymap;
  final VoidCallback onUpdate;
  const KeymapExplanation({super.key, required this.keymap, required this.onUpdate});

  @override
  State<KeymapExplanation> createState() => _KeymapExplanationState();
}

class _KeymapExplanationState extends State<KeymapExplanation> {
  late StreamSubscription<void> _updateStreamListener;

  @override
  void initState() {
    super.initState();
    _updateStreamListener = widget.keymap.updateStream.listen((_) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    super.dispose();
    _updateStreamListener.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final allAvailableButtons = connection.devices.flatMap((e) => e.availableButtons).distinct();

    final availableKeypairs = widget.keymap.keyPairs.filter(
      (e) => allAvailableButtons.containsAny(e.buttons),
    );

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
                    'Button on your ${connection.devices.isEmpty ? 'Device' : connection.devices.joinToString(transform: (d) => d.name.screenshot)}',
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
            for (final keyPair in availableKeypairs) ...[
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final button in keyPair.buttons) IntrinsicWidth(child: ButtonWidget(button: button)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: _ButtonEditor(keyPair: keyPair, onUpdate: widget.onUpdate),
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

class _ButtonEditor extends StatelessWidget {
  final KeyPair keyPair;
  final VoidCallback onUpdate;
  const _ButtonEditor({required this.onUpdate, super.key, required this.keyPair});

  @override
  Widget build(BuildContext context) {
    final actions = [
      if (actionHandler.supportedModes.contains(SupportedMode.keyboard))
        PopupMenuItem<PhysicalKeyboardKey>(
          value: null,
          child: ListTile(
            leading: Icon(Icons.keyboard_alt_outlined),
            title: const Text('Simulate Keyboard shortcut'),
            trailing: keyPair.physicalKey != null ? Checkbox(value: true, onChanged: null) : null,
          ),
          onTap: () async {
            await showDialog<void>(
              context: context,
              barrierDismissible: false, // enable Escape key
              builder: (c) =>
                  HotKeyListenerDialog(customApp: actionHandler.supportedApp! as CustomApp, keyPair: keyPair),
            );
            onUpdate();
          },
        ),
      if (actionHandler.supportedModes.contains(SupportedMode.touch))
        PopupMenuItem<PhysicalKeyboardKey>(
          value: null,
          child: ListTile(
            title: const Text('Simulate Touch'),
            leading: Icon(Icons.touch_app_outlined),
            trailing: keyPair.physicalKey == null && keyPair.touchPosition != Offset.zero
                ? Checkbox(value: true, onChanged: null)
                : null,
          ),
          onTap: () async {
            if (keyPair.touchPosition == Offset.zero) {
              keyPair.touchPosition = Offset(50, 50);
            }
            keyPair.physicalKey = null;
            keyPair.logicalKey = null;
            await Navigator.of(context).push<bool?>(
              MaterialPageRoute(
                builder: (c) => TouchAreaSetupPage(
                  keyPair: keyPair,
                ),
              ),
            );
            onUpdate();
          },
        ),

      if (actionHandler.supportedModes.contains(SupportedMode.media))
        PopupMenuItem<PhysicalKeyboardKey>(
          child: PopupMenuButton<PhysicalKeyboardKey>(
            padding: EdgeInsets.zero,
            itemBuilder: (context) => [
              PopupMenuItem<PhysicalKeyboardKey>(
                value: PhysicalKeyboardKey.mediaPlayPause,
                child: const Text('Media: Play/Pause'),
              ),
              PopupMenuItem<PhysicalKeyboardKey>(
                value: PhysicalKeyboardKey.mediaStop,
                child: const Text('Media: Stop'),
              ),
              PopupMenuItem<PhysicalKeyboardKey>(
                value: PhysicalKeyboardKey.mediaTrackPrevious,
                child: const Text('Media: Previous'),
              ),
              PopupMenuItem<PhysicalKeyboardKey>(
                value: PhysicalKeyboardKey.mediaTrackNext,
                child: const Text('Media: Next'),
              ),
              PopupMenuItem<PhysicalKeyboardKey>(
                value: PhysicalKeyboardKey.audioVolumeUp,
                child: const Text('Media: Volume Up'),
              ),
              PopupMenuItem<PhysicalKeyboardKey>(
                value: PhysicalKeyboardKey.audioVolumeDown,
                child: const Text('Media: Volume Down'),
              ),
            ],
            onSelected: (key) {
              keyPair.physicalKey = key;
              keyPair.logicalKey = null;

              onUpdate();
            },
            child: ListTile(
              leading: Icon(Icons.music_note_outlined),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (keyPair.isSpecialKey) Checkbox(value: true, onChanged: null),
                  Icon(Icons.arrow_right),
                ],
              ),
              title: Text('Simulate Media key'),
            ),
          ),
        ),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (keyPair.buttons.isNotEmpty && (keyPair.physicalKey != null || keyPair.touchPosition != Offset.zero))
          Expanded(
            child: KeypairExplanation(
              keyPair: keyPair,
            ),
          )
        else
          Text('No action assigned'),

        PopupMenuButton<PhysicalKeyboardKey>(
          enabled: true,
          itemBuilder: (context) => [
            if (actions.length > 1) ...actions,
            PopupMenuItem<PhysicalKeyboardKey>(
              value: null,
              onTap: () {
                keyPair.isLongPress = !keyPair.isLongPress;
                onUpdate();
              },
              child: CheckboxListTile(
                value: keyPair.isLongPress,
                onChanged: (value) {
                  keyPair.isLongPress = value ?? false;

                  onUpdate();
                  Navigator.of(context).pop();
                },
                title: const Text('Long Press Mode (vs. repeating)'),
              ),
            ),
          ],
          onSelected: (key) {
            keyPair.physicalKey = key;
            keyPair.logicalKey = null;

            onUpdate();
          },
          icon: Icon(Icons.edit),
        ),
      ],
    );
  }
}

extension SplitByUppercase on String {
  String splitByUpperCase() {
    return replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (match) => '${match.group(1)} ${match.group(2)}').capitalize();
  }
}
