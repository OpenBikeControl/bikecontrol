import 'dart:convert';
import 'dart:io';

import 'package:bike_control/bluetooth/devices/trainer_connection.dart';
import 'package:prop/utils/resilient_tcp_server.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:bike_control/widgets/apps/mywhoosh_link_tile.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/prop.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class WhooshLink extends TrainerConnection {
  ResilientTcpServer? _server;

  WhooshLink()
    : super(
        title: AppLocalizations.current.connectUsingMyWhooshLink,
        type: ConnectionMethodType.network,
        supportedActions: [
          InGameAction.shiftUp,
          InGameAction.shiftDown,
          InGameAction.cameraAngle,
          InGameAction.emote,
          InGameAction.uturn,
          InGameAction.tuck,
          InGameAction.steerLeft,
          InGameAction.steerRight,
        ],
      );

  void stopServer() async {
    await _server?.stop();
    _server = null;
    isConnected.value = false;
    isStarted.value = false;
    if (kDebugMode) {
      print('Server stopped.');
    }
  }

  Future<void> startServer() async {
    isStarted.value = true;
    // MyWhoosh Link is a fixed-port contract (21587): the MyWhoosh app
    // connects to this exact port, so there is NO port fallback here — a
    // blocked port must fail loudly (the caller surfaces the error).
    final server = ResilientTcpServer(
      preferredPort: 21587,
      onClientConnected: (socket) {
        if (kDebugMode) {
          print('Client connected: ${socket.remoteAddress.address}:${socket.remotePort}');
        }
        SharedLogic.keepAlive();
        core.connection.signalNotification(
          AlertNotification(LogLevel.LOGLEVEL_INFO, AppLocalizations.current.myWhooshLinkConnected),
        );
        isConnected.value = true;
      },
      onData: (socket, data) {
        try {
          if (kDebugMode) {
            // TODO we could check if virtual shifting is enabled
            final message = utf8.decode(data);
            print('Received message: $message');
          }
        } catch (_) {}
      },
      onClientDisconnected: () {
        if (kDebugMode) {
          print('Client disconnected');
        }
        SharedLogic.stopKeepAlive();
        isConnected.value = false;
        core.connection.signalNotification(
          AlertNotification(LogLevel.LOGLEVEL_WARNING, 'MyWhoosh Link disconnected'),
        );
      },
    );
    try {
      await server.start();
    } catch (e) {
      if (kDebugMode) {
        print('Failed to start server: $e');
      }
      isConnected.value = false;
      isStarted.value = false;
      rethrow;
    }
    _server = server;
    if (kDebugMode) {
      print('Server started on port ${server.boundPort}');
    }
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
      InGameAction.tuck => {
        'MessageType': 'Controls',
        'InGameControls': {
          'Tuck': 'true',
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
      return Ignored(
        'No Action sent on key down for action: ${keyPair.inGameAction}',
        button: keyPair.buttons.firstOrNull,
      );
    } else if (jsonObject != null) {
      final jsonString = jsonEncode(jsonObject);
      _server?.client?.writeln(jsonString);
      return Success(
        'Sent action to MyWhoosh: ${keyPair.inGameAction} ${keyPair.inGameActionValue ?? ''}',
        button: keyPair.buttons.firstOrNull,
      );
    } else {
      return NotHandled(
        'No action available for button: ${keyPair.inGameAction}',
        button: keyPair.buttons.firstOrNull,
      );
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

  @override
  Widget getTile({bool small = false}) => MyWhooshLinkTile(small: small);
}
