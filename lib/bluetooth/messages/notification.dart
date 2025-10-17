import 'package:dartx/dartx.dart';
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
