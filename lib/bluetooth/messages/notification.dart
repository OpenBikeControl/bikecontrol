import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/widgets/keymap_explanation.dart';
import 'package:bike_control/widgets/ui/connection_method.dart' show ConnectionMethodType;
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/prop.dart';

class BaseNotification {}

class LogNotification extends BaseNotification {
  final String message;

  LogNotification(this.message) {
    Logger.debug('LogNotification: $message');
  }

  @override
  String toString() {
    return message;
  }
}

class BluetoothAvailabilityNotification extends BaseNotification {
  final bool isAvailable;

  BluetoothAvailabilityNotification(this.isAvailable);

  @override
  String toString() {
    return 'Bluetooth is ${isAvailable ? "available" : "unavailable"}';
  }
}

class ButtonNotification extends BaseNotification {
  final BaseDevice device;
  final List<ControllerButton> buttonsClicked;

  ButtonNotification({this.buttonsClicked = const [], required this.device});

  @override
  String toString() {
    return 'Buttons: ${buttonsClicked.joinToString(transform: (e) => e.name.splitByUpperCase())}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ButtonNotification &&
          runtimeType == other.runtimeType &&
          buttonsClicked.contentEquals(other.buttonsClicked);

  @override
  int get hashCode => buttonsClicked.hashCode;
}

class ActionNotification extends BaseNotification {
  final ActionResult result;

  ActionNotification(this.result);

  @override
  String toString() {
    return result.message;
  }
}

class AlertNotification extends LogNotification {
  final LogLevel level;
  final String alertMessage;
  final VoidCallback? onTap;
  final String? buttonTitle;

  /// Transport this alert relates to, used to pick the activity-log icon
  /// (WiFi vs Bluetooth). Null for alerts unrelated to a trainer connection.
  final ConnectionMethodType? connectionType;

  AlertNotification(
    this.level,
    this.alertMessage, {
    this.onTap,
    this.buttonTitle,
    this.connectionType,
  }) : super(alertMessage);

  /// Builds the `<app> connected/disconnected` alert shown when a trainer app
  /// attaches to or leaves one of our emulators. Names the app when [appName]
  /// is known and tags the alert with [type] so the activity log shows the
  /// matching transport icon.
  factory AlertNotification.connection({
    required bool connected,
    required ConnectionMethodType type,
    String? appName,
  }) {
    final l10n = AppLocalizations.current;
    final String message;
    if (connected) {
      message = appName != null ? l10n.connectedTo(appName) : l10n.connected;
    } else {
      message = appName != null ? l10n.disconnectedFrom(appName) : l10n.disconnected;
    }
    return AlertNotification(LogLevel.LOGLEVEL_INFO, message, connectionType: type);
  }

  @override
  String toString() {
    return 'Warning: $alertMessage';
  }
}
