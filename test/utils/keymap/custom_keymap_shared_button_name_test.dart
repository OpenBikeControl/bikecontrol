import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/elite/elite_sterzo.dart';
import 'package:bike_control/bluetooth/devices/wahoo/wahoo_kickr_bike_shift.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A saved keymap stores a button by name only, and some names belong to
/// more than one controller: the KICKR BIKE's steer buttons and the Elite
/// Sterzo's are both `leftSteer`/`rightSteer`. Reloading must keep the
/// rider's mapping on the controller that is actually connected, instead of
/// handing it the button's built-in default.
Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await AppLocalizations.load(const Locale('en'));

  const kickrLeft = WahooKickrShiftButtons.leftSteer;
  const kickrRight = WahooKickrShiftButtons.rightSteer;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'trainer_app': 'MyWhoosh'});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
  });

  /// Saves and reloads [app], then connects the KICKR BIKE, as an app start does.
  CustomApp restart(CustomApp app) {
    final reloaded = CustomApp(profileName: app.profileName)..decodeKeymap(app.encodeKeymap());
    core.actionHandler.init(reloaded);
    reloaded.keymap.addNewButtons([kickrLeft, kickrRight]);
    return reloaded;
  }

  /// The rider's setup: steer on a long press only, nothing on a click.
  CustomApp riderKeymap() {
    final app = CustomApp(profileName: 'MyWhoosh');
    core.actionHandler.init(app);
    for (final (button, action) in [(kickrLeft, InGameAction.steerLeft), (kickrRight, InGameAction.steerRight)]) {
      app.keymap.addKeyPair(
        KeyPair(buttons: [button], physicalKey: null, logicalKey: null, trigger: ButtonTrigger.singleClick),
      );
      app.keymap.addKeyPair(
        KeyPair(
          buttons: [button],
          physicalKey: null,
          logicalKey: null,
          trigger: ButtonTrigger.longPress,
          inGameAction: action,
        ),
      );
    }
    return app;
  }

  test('KICKR BIKE steer long press survives restarts', () {
    var app = riderKeymap();
    int? count;

    for (var i = 0; i < 3; i++) {
      app = restart(app);
      // The first start copies the mapping onto the KICKR's buttons; later
      // starts must not keep adding to it.
      count ??= app.keymap.keyPairs.length;
      expect(app.keymap.getKeyPair(kickrLeft, trigger: ButtonTrigger.longPress)?.inGameAction, InGameAction.steerLeft);
      expect(
        app.keymap.getKeyPair(kickrRight, trigger: ButtonTrigger.longPress)?.inGameAction,
        InGameAction.steerRight,
      );
      expect(app.keymap.getKeyPair(kickrLeft, trigger: ButtonTrigger.singleClick)?.hasNoAction, isTrue);
      expect(app.keymap.keyPairs.length, count);
    }
  });

  test('a keymap that already picked up the Navigate default keeps the rider\'s own pairs', () {
    // What 7.6.1 saved after a restart: the rider's pairs, then the steer
    // button's default (Navigate Left/Right on a click) appended behind them.
    final saved = riderKeymap();
    for (final button in [kickrLeft, kickrRight]) {
      saved.keymap.addKeyPair(
        KeyPair(
          buttons: [button],
          physicalKey: null,
          logicalKey: null,
          trigger: ButtonTrigger.singleClick,
          inGameAction: button.action,
        ),
      );
    }

    final app = restart(saved);

    expect(app.keymap.getKeyPair(kickrLeft, trigger: ButtonTrigger.longPress)?.inGameAction, InGameAction.steerLeft);
    expect(app.keymap.getKeyPair(kickrLeft, trigger: ButtonTrigger.singleClick)?.hasNoAction, isTrue);
  });

  test('holding the KICKR BIKE steer button after a restart steers', () async {
    final app = restart(riderKeymap());
    final stubActions = core.actionHandler as StubActions;
    final device = _KickrSteerDevice();
    addTearDown(device.disconnect);
    expect(identical(core.actionHandler.supportedApp, app), isTrue);

    await device.handleButtonsClicked([kickrRight]);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    await device.handleButtonsClicked([]);

    expect(stubActions.performedActions.map((a) => a.trigger).toSet(), {ButtonTrigger.longPress});
  });

  test('the Sterzo keeps its own mapping beside the KICKR BIKE', () {
    final app = CustomApp(profileName: 'Both')
      ..decodeKeymap([
        KeyPair(
          buttons: [SterzoButtons.leftSteer],
          physicalKey: null,
          logicalKey: null,
          trigger: ButtonTrigger.longPress,
          inGameAction: InGameAction.steerLeft,
        ).encode(),
      ]);
    core.actionHandler.init(app);
    app.keymap.addNewButtons([SterzoButtons.leftSteer, kickrLeft]);

    expect(
      app.keymap.getKeyPair(SterzoButtons.leftSteer, trigger: ButtonTrigger.longPress)?.inGameAction,
      InGameAction.steerLeft,
    );
    expect(app.keymap.getKeyPair(kickrLeft, trigger: ButtonTrigger.longPress)?.inGameAction, InGameAction.steerLeft);
  });
}

class _KickrSteerDevice extends BaseDevice {
  _KickrSteerDevice()
    : super(
        'KICKR BIKE',
        uniqueId: 'kickr-bike',
        availableButtons: WahooKickrShiftButtons.values,
        icon: Icons.gamepad,
      );

  @override
  Future<void> connect() async {}
}
