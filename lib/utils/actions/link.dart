import 'package:swift_control/main.dart';
import 'package:swift_control/utils/actions/base_actions.dart';
import 'package:swift_control/utils/keymap/buttons.dart';

class LinkActions extends BaseActions {
  LinkActions() : super(supportedModes: [SupportedMode.keyboard]);

  @override
  Future<String> performAction(ControllerButton action, {bool isKeyDown = true, bool isKeyUp = false}) async {
    final inGameAction = settings.getInGameActionForButton(action);
    if (inGameAction == null) {
      return 'No action defined for button: $action';
    }
    return whooshLink.sendAction(inGameAction);
  }
}
