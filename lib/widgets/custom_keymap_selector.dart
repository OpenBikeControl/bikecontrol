import 'dart:async';

import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:swift_control/bluetooth/messages/click_notification.dart';
import 'package:swift_control/bluetooth/messages/notification.dart';
import 'package:swift_control/bluetooth/messages/play_notification.dart';
import 'package:swift_control/bluetooth/messages/ride_notification.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:swift_control/utils/keymap/keymap.dart';

import '../utils/keymap/apps/custom_app.dart';

Future<CustomApp?> showCustomKeymapDialog(BuildContext context, {required CustomApp customApp}) {
  return showDialog<CustomApp>(
    context: context,
    builder: (context) {
      return GearHotkeyDialog(customApp: customApp);
    },
  );
}

class GearHotkeyDialog extends StatefulWidget {
  final CustomApp customApp;
  const GearHotkeyDialog({super.key, required this.customApp});

  @override
  State<GearHotkeyDialog> createState() => _GearHotkeyDialogState();
}

class _GearHotkeyDialogState extends State<GearHotkeyDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Customize key map'),
      content: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton.icon(
            icon: Icon(Icons.add),
            onPressed: () async {
              await showDialog<void>(
                context: context,
                builder: (c) => HotKeyListenerDialog(customApp: widget.customApp, keyPair: null),
              );
              setState(() {});
            },
            label: Text('Add Key'),
          ),
          ...widget.customApp.keymap.keyPairs.map(
            (e) => ListTile(
              title: Text(e.buttons.joinToString(transform: (e) => e.name)),
              subtitle: Text('Currently: ${e.toString()}'),
              onTap: () async {
                await showDialog<void>(
                  context: context,
                  builder: (c) => HotKeyListenerDialog(customApp: widget.customApp, keyPair: e),
                );
                setState(() {});
              },
            ),
          ),
        ],
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(widget.customApp), child: Text("OK"))],
    );
  }
}

class HotKeyListenerDialog extends StatefulWidget {
  final CustomApp customApp;
  final KeyPair? keyPair;
  const HotKeyListenerDialog({super.key, required this.customApp, required this.keyPair});

  @override
  State<HotKeyListenerDialog> createState() => _HotKeyListenerState();
}

class _HotKeyListenerState extends State<HotKeyListenerDialog> {
  late StreamSubscription<BaseNotification> _actionSubscription;

  final FocusNode _focusNode = FocusNode();
  KeyDownEvent? _pressedKey;
  ZwiftButton? _pressedButton;

  @override
  void initState() {
    super.initState();
    _pressedButton = widget.keyPair?.buttons.firstOrNull;
    _actionSubscription = connection.actionStream.listen((data) {
      if (!mounted || widget.keyPair != null) {
        return;
      }
      if (data is ClickNotification) {
        setState(() {
          _pressedButton = data.buttonsClicked.singleOrNull;
        });
      }
      if (data is PlayNotification) {
        setState(() {
          _pressedButton = data.buttonsClicked.singleOrNull;
        });
      }
      if (data is RideNotification) {
        setState(() {
          _pressedButton = data.buttonsClicked.singleOrNull;
        });
      }
    });
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _actionSubscription.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _onKey(KeyEvent event) {
    setState(() {
      if (event is KeyDownEvent) {
        _pressedKey = event;
      } else if (event is KeyUpEvent) {
        widget.customApp.setKey(
          _pressedButton!,
          physicalKey: _pressedKey!.physicalKey,
          logicalKey: _pressedKey!.logicalKey,
        );
      }
    });
  }

  String _formatKey(KeyDownEvent? key) {
    return key?.logicalKey.keyLabel ?? 'Waiting...';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content:
          _pressedButton == null
              ? Text('Press a button on your Zwift device')
              : KeyboardListener(
                focusNode: _focusNode,
                autofocus: true,
                onKeyEvent: _onKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 20,
                  children: [
                    Text("Press a key on your keyboard to assign to ${_pressedButton.toString()}"),
                    Text(_formatKey(_pressedKey)),
                    PopupMenuButton<PhysicalKeyboardKey>(
                      tooltip: 'Drag or click for special keys',
                      itemBuilder:
                          (context) => [
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
                        widget.customApp.setKey(_pressedButton!, physicalKey: key, logicalKey: null);
                        Navigator.pop(context, key);
                      },
                      child: IgnorePointer(
                        child: ElevatedButton(onPressed: () {}, child: Text('Or choose special key')),
                      ),
                    ),
                  ],
                ),
              ),

      actions: [TextButton(onPressed: () => Navigator.of(context).pop(_pressedKey), child: Text("OK"))],
    );
  }
}
