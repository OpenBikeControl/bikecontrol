import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A button the app's own keymap doesn't cover inherits its hard-coded default
/// action — but only when the selected app can actually perform it. A Click
/// V2's Z defaults to Zwift's Ride On bomb, which MyWhoosh has no equivalent
/// for.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> select(String app) async {
    SharedPreferences.setMockInitialValues({'trainer_app': app});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
  }

  test('MyWhoosh: Z gets no Ride On bomb', () async {
    await select('MyWhoosh');
    final keymap = MyWhoosh().keymap;
    keymap.addNewButtons([ZwiftButtons.z]);

    final pair = keymap.getKeyPair(ZwiftButtons.z);
    expect(pair, isNotNull, reason: 'the button is still listed, just unassigned');
    expect(pair!.inGameAction, isNull);
    expect(pair.trigger, ButtonTrigger.singleClick);
  });

  test('MyWhoosh: a default it can perform is kept', () async {
    await select('MyWhoosh');
    final keymap = MyWhoosh().keymap;
    keymap.addNewButtons([ZwiftButtons.a]);

    expect(keymap.getKeyPair(ZwiftButtons.a)?.inGameAction, InGameAction.select);
  });

  test('Zwift keeps the Ride On bomb', () async {
    await select('Zwift');
    final keymap = Zwift().keymap;
    keymap.addNewButtons([ZwiftButtons.z]);

    expect(keymap.getKeyPair(ZwiftButtons.z)?.inGameAction, InGameAction.rideOnBomb);
  });

  test('Rouvy keeps the Z default it renames', () async {
    await select('Rouvy');
    expect(Rouvy().offeredInGameActions, contains(InGameAction.rideOnBomb));
  });
}
