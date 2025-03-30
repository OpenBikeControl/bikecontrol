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
  final Set<PhysicalKeyboardKey> _pressedKeys = {};
  Set<PhysicalKeyboardKey>? _gearUpHotkey;
  Set<PhysicalKeyboardKey>? _gearDownHotkey;

  String _mode = 'up'; // 'up' or 'down'

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  void _onKey(KeyEvent event) {
    setState(() {
      if (event is KeyDownEvent) {
        _pressedKeys.add(event.physicalKey);
      } else if (event is KeyUpEvent) {
        if (_pressedKeys.isNotEmpty) {
          if (_mode == 'up') {
            _gearUpHotkey = {..._pressedKeys};
            _mode = 'down';
          } else {
            _gearDownHotkey = {..._pressedKeys};
            widget.keymap.increase = _gearUpHotkey!.first;
            widget.keymap.decrease = _gearDownHotkey!.first;
            Navigator.of(context).pop(widget.keymap);
          }
          _pressedKeys.clear();
        }
      }
    });
  }

  String _formatKeys(Set<PhysicalKeyboardKey>? keys) {
    if (keys == null || keys.isEmpty) return 'Not set';
    return keys.map((k) => k.debugName ?? k).join(' + ');
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
              subtitle: Text(_formatKeys(_gearUpHotkey)),
            ),
            ListTile(
              leading: Icon(Icons.arrow_downward),
              title: Text("Gear Down Hotkey"),
              subtitle: Text(_formatKeys(_gearDownHotkey)),
            ),
            if (_pressedKeys.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text("Recording: ${_formatKeys(_pressedKeys)}", style: TextStyle(color: Colors.blue)),
              ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(null), child: Text("Cancel"))],
    );
  }
}
