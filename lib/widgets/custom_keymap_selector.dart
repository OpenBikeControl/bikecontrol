import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:swift_control/utils/keymap/keymap.dart';

Future<Keymap?> showCustomKeymapDialog(BuildContext context, {required Keymap keymap}) {
  return showDialog<Keymap>(
    context: context,
    builder: (context) {
      return GearHotkeyDialog(keymap: keymap);
    },
  );
}

class GearHotkeyDialog extends StatefulWidget {
  final Keymap keymap;
  const GearHotkeyDialog({super.key, required this.keymap});

  @override
  State<GearHotkeyDialog> createState() => _GearHotkeyDialogState();
}

class _GearHotkeyDialogState extends State<GearHotkeyDialog> {
  final FocusNode _focusNode = FocusNode();
  KeyDownEvent? _pressedKey;
  KeyDownEvent? _gearUpHotkey;
  KeyDownEvent? _gearDownHotkey;

  String _mode = 'up'; // 'up' or 'down'

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  void _onKey(KeyEvent event) {
    setState(() {
      if (event is KeyDownEvent) {
        _pressedKey = event;
      } else if (event is KeyUpEvent) {
        if (_pressedKey != null) {
          if (_mode == 'up') {
            _gearUpHotkey = _pressedKey;
            _mode = 'down';
          } else {
            _gearDownHotkey = _pressedKey;
            widget.keymap.increase = KeyPair(
              physicalKey: _gearUpHotkey!.physicalKey,
              logicalKey: _gearUpHotkey!.logicalKey,
            );
            widget.keymap.decrease = KeyPair(
              physicalKey: _gearDownHotkey!.physicalKey,
              logicalKey: _gearDownHotkey!.logicalKey,
            );
            Navigator.of(context).pop(widget.keymap);
          }
          _pressedKey = null;
        }
      }
    });
  }

  String _formatKey(KeyDownEvent? key) {
    return key?.logicalKey.keyLabel ?? 'Not set';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Set Gear Hotkeys'),
      content: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Step 1: Press a hotkey for **Gear Up**."),
            Text("Step 2: Press a hotkey for **Gear Down**."),
            SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.arrow_upward),
              title: Text("Gear Up Hotkey"),
              subtitle: Text(_formatKey(_gearUpHotkey)),
            ),
            ListTile(
              leading: Icon(Icons.arrow_downward),
              title: Text("Gear Down Hotkey"),
              subtitle: Text(_formatKey(_gearDownHotkey)),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(null), child: Text("Cancel"))],
    );
  }
}
