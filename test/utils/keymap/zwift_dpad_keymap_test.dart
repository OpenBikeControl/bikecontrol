import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/ride_controller_press.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Zwift gets a Zwift Ride: its D-pad moves through the menus and its paddles
/// steer. A D-pad press navigates, holding it steers.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
  });

  test('Zwift: a D-pad press navigates, holding it steers', () {
    final keymap = Zwift().keymap;
    InGameAction? on(ControllerButton button, ButtonTrigger trigger) =>
        keymap.getKeyPair(button, trigger: trigger)?.inGameAction;

    expect(on(ZwiftButtons.navigationLeft, ButtonTrigger.singleClick), InGameAction.navigateLeft);
    expect(on(ZwiftButtons.navigationLeft, ButtonTrigger.longPress), InGameAction.steerLeft);
    expect(on(ZwiftButtons.navigationRight, ButtonTrigger.singleClick), InGameAction.navigateRight);
    expect(on(ZwiftButtons.navigationRight, ButtonTrigger.longPress), InGameAction.steerRight);
  });

  test('as a Ride, the LEFT/RIGHT caption belongs to navigating, not steering', () {
    core.settings.setTrainerApp(Zwift());
    expect(RideControllerPress.caption(InGameAction.navigateLeft), 'Left');
    expect(RideControllerPress.caption(InGameAction.navigateRight), 'Right');
    expect(RideControllerPress.caption(InGameAction.steerLeft), isNull);
    expect(RideControllerPress.caption(InGameAction.uturn), 'Down');
  });

  test('other apps keep steering on LEFT/RIGHT', () {
    core.settings.setTrainerApp(MyWhoosh());
    expect(RideControllerPress.caption(InGameAction.steerLeft), 'Left');
    expect(RideControllerPress.caption(InGameAction.navigateLeft), isNull);
  });

  test('connecting a controller fills in only buttons Zwift does not map at all', () {
    core.settings.setTrainerApp(Zwift());
    final keymap = Zwift().keymap;
    keymap.addNewButtons(ZwiftButtons.values);

    // Y is mapped on a long press only: no "Menu" click (Zwift has none).
    expect(keymap.getKeyPairs(ZwiftButtons.y).map((k) => (k.trigger, k.inGameAction)), [
      (ButtonTrigger.longPress, InGameAction.usePowerUp),
    ]);
    // Z keeps a single Ride On, not a second copy of it.
    expect(keymap.getKeyPairs(ZwiftButtons.z), hasLength(1));
    // The power buttons do nothing in Zwift, rather than UI toggle.
    expect(keymap.getKeyPair(ZwiftButtons.onOffLeft)?.inGameAction, isNull);
    expect(keymap.getKeyPair(ZwiftButtons.onOffRight)?.inGameAction, isNull);
  });
}
