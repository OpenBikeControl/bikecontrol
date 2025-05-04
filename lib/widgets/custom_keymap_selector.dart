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
                  ],
                ),
              ),

      actions: [TextButton(onPressed: () => Navigator.of(context).pop(_pressedKey), child: Text("OK"))],
    );
  }
}
