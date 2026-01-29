import 'package:bike_control/bluetooth/devices/trainer_connection.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/prop.dart' hide RideButtonMask;

class FtmsMdnsEmulator extends TrainerConnection {
  static const String connectionTitle = 'Zwift Network Emulator';

  late final ClickEmulator clickEmulator = ClickEmulator();
  var lastMessageId = 0;

  FtmsMdnsEmulator()
    : super(
        title: connectionTitle,
        supportedActions: [
          InGameAction.shiftUp,
          InGameAction.shiftDown,
          InGameAction.uturn,
          InGameAction.steerLeft,
          InGameAction.steerRight,
          InGameAction.openActionBar,
          InGameAction.usePowerUp,
          InGameAction.select,
          InGameAction.back,
          InGameAction.rideOnBomb,
        ],
      ) {
    clickEmulator.isStarted.addListener(() {
      isStarted.value = clickEmulator.isStarted.value;
    });
    clickEmulator.isConnected.addListener(() {
      isConnected.value = clickEmulator.isConnected.value;
      if (isConnected.value) {
        core.connection.signalNotification(
          AlertNotification(LogLevel.LOGLEVEL_INFO, AppLocalizations.current.connected),
        );
      } else {
        core.connection.signalNotification(
          AlertNotification(LogLevel.LOGLEVEL_INFO, AppLocalizations.current.disconnected),
        );
      }
    });
  }

  Future<void> startServer() async {
    return clickEmulator.startServer();
  }

  void stop() {
    clickEmulator.stop();
  }

  @override
  Future<ActionResult> sendAction(KeyPair keyPair, {required bool isKeyDown, required bool isKeyUp}) async {
    final button = switch (keyPair.inGameAction) {
      InGameAction.shiftUp => RideButtonMask.SHFT_UP_R_BTN,
      InGameAction.shiftDown => RideButtonMask.SHFT_UP_L_BTN,
      InGameAction.uturn => RideButtonMask.DOWN_BTN,
      InGameAction.steerLeft => RideButtonMask.LEFT_BTN,
      InGameAction.steerRight => RideButtonMask.RIGHT_BTN,
      InGameAction.openActionBar => RideButtonMask.UP_BTN,
      InGameAction.usePowerUp => RideButtonMask.Y_BTN,
      InGameAction.select => RideButtonMask.A_BTN,
      InGameAction.back => RideButtonMask.B_BTN,
      InGameAction.rideOnBomb => RideButtonMask.Z_BTN,
      _ => null,
    };

    if (button == null) {
      return NotHandled('Action ${keyPair.inGameAction!.name} not supported by Zwift Emulator');
    }

    if (isKeyDown) {
      final status = RideKeyPadStatus()
        ..buttonMap = (~button.mask) & 0xFFFFFFFF
        ..analogPaddles.clear();

      final bytes = status.writeToBuffer();

      clickEmulator.writeNotification(bytes);
    }

    if (isKeyUp) {
      clickEmulator.writeNotification(
        Uint8List.fromList([0x08, 0xFF, 0xFF, 0xFF, 0xFF, 0x0F]),
      );
    }
    if (kDebugMode) {
      print('Sent action up $isKeyUp vs down $isKeyDown ${keyPair.inGameAction!.title} to Zwift Emulator');
    }
    return Success('Sent action ${isKeyDown ? 'down' : ''} ${isKeyUp ? 'up' : ''}: ${keyPair.inGameAction!.title}');
  }
}

class FtmsMdnsConstants {
  static const DC_RC_REQUEST_COMPLETED_SUCCESSFULLY = 0; // Request completed successfully
  static const DC_RC_UNKNOWN_MESSAGE_TYPE = 1; // Unknown Message Type
  static const DC_RC_UNEXPECTED_ERROR = 2; // Unexpected Error
  static const DC_RC_SERVICE_NOT_FOUND = 3; // Service Not Found
  static const DC_RC_CHARACTERISTIC_NOT_FOUND = 4; // Characteristic Not Found
  static const DC_RC_CHARACTERISTIC_OPERATION_NOT_SUPPORTED =
      5; // Characteristic Operation Not Supported (See Characteristic Properties)
  static const DC_RC_CHARACTERISTIC_WRITE_FAILED_INVALID_SIZE =
      6; // Characteristic Write Failed – Invalid characteristic data size
  static const DC_RC_UNKNOWN_PROTOCOL_VERSION =
      7; // Unknown Protocol Version – the command contains a protocol version that the device does not recognize

  static const DC_MESSAGE_DISCOVER_SERVICES = 0x01; // Discover Services
  static const DC_MESSAGE_DISCOVER_CHARACTERISTICS = 0x02; // Discover Characteristics
  static const DC_MESSAGE_READ_CHARACTERISTIC = 0x03; // Read Characteristic
  static const DC_MESSAGE_WRITE_CHARACTERISTIC = 0x04; // Write Characteristic
  static const DC_MESSAGE_ENABLE_CHARACTERISTIC_NOTIFICATIONS = 0x05; // Enable Characteristic Notifications
  static const DC_MESSAGE_CHARACTERISTIC_NOTIFICATION = 0x06; // Characteristic Notification
}
