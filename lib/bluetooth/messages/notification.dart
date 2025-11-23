import 'package:dartx/dartx.dart';
import 'package:swift_control/utils/actions/base_actions.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:swift_control/widgets/keymap_explanation.dart';

class BaseNotification {}

class LogNotification extends BaseNotification {
  final String message;

  LogNotification(this.message);

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
  List<ControllerButton> buttonsClicked;

  ButtonNotification({this.buttonsClicked = const []});

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
