import 'dart:convert';
import 'dart:io';

import 'package:bike_control/bluetooth/devices/trainer_connection.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/prop.dart';

class WhooshLink extends TrainerConnection {
  Socket? _socket;
  ServerSocket? _server;

  static const String connectionTitle = 'MyWhoosh Link';

  WhooshLink()
    : super(
        title: connectionTitle,
        supportedActions: [
          InGameAction.shiftUp,
          InGameAction.shiftDown,
          InGameAction.cameraAngle,
          InGameAction.emote,
          InGameAction.uturn,
          InGameAction.steerLeft,
          InGameAction.steerRight,
        ],
      );

  void stopServer() async {
    await _socket?.close();
    await _server?.close();
    isConnected.value = false;
    isStarted.value = false;
    if (kDebugMode) {
      print('Server stopped.');
    }
  }

  Future<void> startServer() async {
    isStarted.value = true;
    try {
      // Create and bind server socket
      _server = await ServerSocket.bind(
        InternetAddress.anyIPv6,
        21587,
        shared: true,
        v6Only: false,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Failed to start server: $e');
      }
      isConnected.value = false;
      isStarted.value = false;
      rethrow;
    }
    if (kDebugMode) {
      print('Server started on port ${_server!.port}');
    }

    // Accept connection
    _server!.listen(
      (Socket socket) async {
        await SharedLogic.keepAlive();
        _socket = socket;
        core.connection.signalNotification(
          AlertNotification(LogLevel.LOGLEVEL_INFO, AppLocalizations.current.myWhooshLinkConnected),
        );
        isConnected.value = true;
        if (kDebugMode) {
          print('Client connected: ${socket.remoteAddress.address}:${socket.remotePort}');
        }

        // Listen for data from the client
        socket.listen(
          (List<int> data) {
            try {
              if (kDebugMode) {
                // TODO we could check if virtual shifting is enabled
                final message = utf8.decode(data);
                print('Received message: $message');
              }
            } catch (_) {}
          },
          onDone: () {
            print('Client disconnected: $socket');

            SharedLogic.stopKeepAlive();
            isConnected.value = false;
            core.connection.signalNotification(
              AlertNotification(LogLevel.LOGLEVEL_WARNING, 'MyWhoosh Link disconnected'),
            );
          },
        );
      },
    );
  }

  @override
  Future<ActionResult> sendAction(KeyPair keyPair, {required bool isKeyDown, required bool isKeyUp}) async {
    final jsonObject = switch (keyPair.inGameAction) {
      InGameAction.shiftUp => {
        'MessageType': 'Controls',
        'InGameControls': {
          'GearShifting': '1',
        },
      },
      InGameAction.shiftDown => {
        'MessageType': 'Controls',
        'InGameControls': {
          'GearShifting': '-1',
        },
      },
      InGameAction.cameraAngle => {
        'MessageType': 'Controls',
        'InGameControls': {
          'CameraAngle': '${keyPair.inGameActionValue}',
        },
      },
      InGameAction.emote => {
        'MessageType': 'Controls',
        'InGameControls': {
          'Emote': '${keyPair.inGameActionValue}',
        },
      },
      InGameAction.uturn => {
        'MessageType': 'Controls',
        'InGameControls': {
          'UTurn': 'true',
        },
      },
      InGameAction.steerLeft => {
        'MessageType': 'Controls',
        'InGameControls': {
          'Steering': isKeyDown ? '-1' : '0',
        },
      },
      InGameAction.steerRight => {
        'MessageType': 'Controls',
        'InGameControls': {
          'Steering': isKeyDown ? '1' : '0',
        },
      },
      InGameAction.increaseResistance => null,
      InGameAction.decreaseResistance => null,
      InGameAction.navigateLeft => null,
      InGameAction.navigateRight => null,
      InGameAction.toggleUi => null,
      _ => null,
    };

    final supportsIsKeyUpActions = [
      InGameAction.steerLeft,
      InGameAction.steerRight,
    ];
    if (jsonObject != null && !isKeyDown && !supportsIsKeyUpActions.contains(keyPair.inGameAction)) {
      return Ignored('No Action sent on key down for action: ${keyPair.inGameAction}');
    } else if (jsonObject != null) {
      final jsonString = jsonEncode(jsonObject);
      _socket?.writeln(jsonString);
      return Success('Sent action to MyWhoosh: ${keyPair.inGameAction} ${keyPair.inGameActionValue ?? ''}');
    } else {
      return NotHandled('No action available for button: ${keyPair.inGameAction}');
    }
  }

  bool isCompatible(Target target) {
    return kIsWeb
        ? false
        : switch (target) {
            Target.thisDevice => !Platform.isWindows,
            _ => true,
          };
  }
}
