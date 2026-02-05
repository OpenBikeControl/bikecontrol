import 'dart:async';
import 'dart:io';

import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    _actionSubscription = core.connection.actionStream.listen((data) {
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
        final wasModifier = _updateModifierState(event.logicalKey, add: true);
        // Regular key pressed - record it along with active modifiers
        if (!wasModifier) {
          if (_pressedKey?.logicalKey != event.logicalKey) {}
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
        _updateModifierState(event.logicalKey, add: false);
      }
    });
  }

  bool _updateModifierState(LogicalKeyboardKey key, {required bool add}) {
    ModifierKey? modifier;

    if (key == LogicalKeyboardKey.shift ||
        key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight) {
      modifier = ModifierKey.shiftModifier;
    } else if (key == LogicalKeyboardKey.control ||
        key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight) {
      modifier = ModifierKey.controlModifier;
    } else if (key == LogicalKeyboardKey.alt ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight) {
      modifier = ModifierKey.altModifier;
    } else if (key == LogicalKeyboardKey.meta ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight) {
      modifier = ModifierKey.metaModifier;
    } else if (key == LogicalKeyboardKey.fn) {
      modifier = ModifierKey.functionModifier;
    }

    if (modifier != null) {
      if (add) {
        _activeModifiers.add(modifier);
      } else {
        _activeModifiers.remove(modifier);
      }
      return true;
    }
    return false;
  }

  String _formatModifierName(ModifierKey m) {
    return switch (m) {
      ModifierKey.shiftModifier => 'Shift',
      ModifierKey.controlModifier => 'Ctrl',
      ModifierKey.altModifier => 'Alt',
      ModifierKey.metaModifier => 'Meta',
      ModifierKey.functionModifier => 'Fn',
      _ => m.name,
    };
  }

  String _formatKey(KeyDownEvent? key) {
    if (key == null) {
      return _activeModifiers.isEmpty
          ? AppLocalizations.current.waiting
          : '${_activeModifiers.map(_formatModifierName).join('+')}+...';
    }

    if (_activeModifiers.isEmpty) {
      return key.logicalKey.keyLabel;
    }

    final modifierStrings = _activeModifiers.map(_formatModifierName);

    return '${modifierStrings.join('+')}+${key.logicalKey.keyLabel}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: _pressedButton == null
          ? Text(AppLocalizations.current.pressButtonOnClickDevice)
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
                  Text(
                    AppLocalizations.current.pressKeyToAssign(_pressedButton?.displayName ?? _pressedButton.toString()),
                  ),
                  Text(_formatKey(_pressedKey)),
                  if (kDebugMode && (Platform.isAndroid || Platform.isIOS))
                    SizedBox(
                      height: 300,
                      width: 300,
                      child: ListView(
                        shrinkWrap: true,
                        children: LogicalKeyboardKey.knownLogicalKeys
                            .map(
                              (key) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                minVerticalPadding: 0,
                                title: Row(
                                  children: [
                                    Chip(label: Text(key.keyLabel)),
                                  ],
                                ),
                                onTap: () {
                                  setState(() {
                                    _pressedKey = KeyDownEvent(
                                      physicalKey: PhysicalKeyboardKey(0x80),
                                      logicalKey: key,
                                      character: null,
                                      timeStamp: Duration.zero,
                                    );
                                    widget.customApp.setKey(
                                      _pressedButton!,
                                      physicalKey: _pressedKey!.physicalKey,
                                      logicalKey: key,
                                      modifiers: _activeModifiers.toList(),
                                      touchPosition: widget.keyPair?.touchPosition,
                                    );
                                  });
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ),
                ],
              ),
            ),

      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(_pressedKey), child: Text(AppLocalizations.current.ok)),
      ],
    );
  }
}
