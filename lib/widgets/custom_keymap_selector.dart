import 'dart:async';

import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:swift_control/bluetooth/messages/notification.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:swift_control/utils/keymap/keymap.dart';

import '../utils/keymap/apps/custom_app.dart';

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
  ControllerButton? _pressedButton;
  final Set<ModifierKey> _activeModifiers = {};

  @override
  void initState() {
    super.initState();
    _pressedButton = widget.keyPair?.buttons.firstOrNull;
    _actionSubscription = connection.actionStream.listen((data) {
      if (!mounted || widget.keyPair != null) {
        return;
      }
      if (data is ButtonNotification) {
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
      // Track modifier keys
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.shift || 
            event.logicalKey == LogicalKeyboardKey.shiftLeft || 
            event.logicalKey == LogicalKeyboardKey.shiftRight) {
          _activeModifiers.add(ModifierKey.shiftModifier);
        } else if (event.logicalKey == LogicalKeyboardKey.control || 
                   event.logicalKey == LogicalKeyboardKey.controlLeft || 
                   event.logicalKey == LogicalKeyboardKey.controlRight) {
          _activeModifiers.add(ModifierKey.controlModifier);
        } else if (event.logicalKey == LogicalKeyboardKey.alt || 
                   event.logicalKey == LogicalKeyboardKey.altLeft || 
                   event.logicalKey == LogicalKeyboardKey.altRight) {
          _activeModifiers.add(ModifierKey.altModifier);
        } else if (event.logicalKey == LogicalKeyboardKey.meta || 
                   event.logicalKey == LogicalKeyboardKey.metaLeft || 
                   event.logicalKey == LogicalKeyboardKey.metaRight) {
          _activeModifiers.add(ModifierKey.metaModifier);
        } else if (event.logicalKey == LogicalKeyboardKey.fn) {
          _activeModifiers.add(ModifierKey.functionModifier);
        } else {
          // Regular key pressed - record it along with active modifiers
          _pressedKey = event;
          widget.customApp.setKey(
            _pressedButton!,
            physicalKey: _pressedKey!.physicalKey,
            logicalKey: _pressedKey!.logicalKey,
            modifiers: _activeModifiers.toList(),
            touchPosition: widget.keyPair?.touchPosition,
          );
        }
      } else if (event is KeyUpEvent) {
        // Clear modifier when released
        if (event.logicalKey == LogicalKeyboardKey.shift || 
            event.logicalKey == LogicalKeyboardKey.shiftLeft || 
            event.logicalKey == LogicalKeyboardKey.shiftRight) {
          _activeModifiers.remove(ModifierKey.shiftModifier);
        } else if (event.logicalKey == LogicalKeyboardKey.control || 
                   event.logicalKey == LogicalKeyboardKey.controlLeft || 
                   event.logicalKey == LogicalKeyboardKey.controlRight) {
          _activeModifiers.remove(ModifierKey.controlModifier);
        } else if (event.logicalKey == LogicalKeyboardKey.alt || 
                   event.logicalKey == LogicalKeyboardKey.altLeft || 
                   event.logicalKey == LogicalKeyboardKey.altRight) {
          _activeModifiers.remove(ModifierKey.altModifier);
        } else if (event.logicalKey == LogicalKeyboardKey.meta || 
                   event.logicalKey == LogicalKeyboardKey.metaLeft || 
                   event.logicalKey == LogicalKeyboardKey.metaRight) {
          _activeModifiers.remove(ModifierKey.metaModifier);
        } else if (event.logicalKey == LogicalKeyboardKey.fn) {
          _activeModifiers.remove(ModifierKey.functionModifier);
        }
      }
    });
  }

  String _formatKey(KeyDownEvent? key) {
    if (key == null) {
      return _activeModifiers.isEmpty ? 'Waiting...' : '${_activeModifiers.map((m) => m.name.replaceAll('Modifier', '')).join('+')}+...';
    }
    
    if (_activeModifiers.isEmpty) {
      return key.logicalKey.keyLabel;
    }
    
    final modifierStrings = _activeModifiers.map((m) {
      return switch (m) {
        ModifierKey.shiftModifier => 'Shift',
        ModifierKey.controlModifier => 'Ctrl',
        ModifierKey.altModifier => 'Alt',
        ModifierKey.metaModifier => 'Meta',
        ModifierKey.functionModifier => 'Fn',
        _ => m.name,
      };
    });
    
    return '${modifierStrings.join('+')}+${key.logicalKey.keyLabel}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: _pressedButton == null
          ? Text('Press a button on your Click device')
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
                ],
              ),
            ),

      actions: [TextButton(onPressed: () => Navigator.of(context).pop(_pressedKey), child: Text("OK"))],
    );
  }
}
