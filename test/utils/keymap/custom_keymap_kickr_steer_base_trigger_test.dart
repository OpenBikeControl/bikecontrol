import 'package:bike_control/bluetooth/devices/base_device.dart';
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
import 'package:supabase_flutter/supabase_flutter.dart';

/// The KICKR BIKE's steer buttons are saved as plain `leftSteer`/`rightSteer`
/// and reload as the Elite Sterzo's buttons of that name, which the KICKR page
/// can't reach. So before 7.7 every start appended fresh pairs for the KICKR
/// behind the old ones, and the rider's edits only ever changed those: the
/// saved list holds one snapshot of the mapping per start, oldest first.
///
/// A Base rider (one trigger per button) who once had Steer on a click and
/// later moved it to the long press then got, on 7.7.0, the oldest click and
/// the oldest long press back: a tap steered, and the hold was refused as a
/// second trigger.
Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await AppLocalizations.load(const Locale('en'));

  const kickrLeft = WahooKickrShiftButtons.leftSteer;
  const kickrRight = WahooKickrShiftButtons.rightSteer;
  final steer = {kickrLeft: InGameAction.steerLeft, kickrRight: InGameAction.steerRight};

  // proGuard reaches Supabase.instance: an offline dummy one.
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      publishableKey: 'kickr-steer-base-trigger-test-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        detectSessionInUri: false,
        autoRefreshToken: false,
      ),
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({'trainer_app': 'MyWhoosh'});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
  });

  KeyPair pair(ControllerButton button, ButtonTrigger trigger, [InGameAction? action]) =>
      KeyPair(buttons: [button], physicalKey: null, logicalKey: null, trigger: trigger, inGameAction: action);

  /// What 7.6.x left saved, start by start, for each steer button:
  /// - a start where the rider left Steer on a single click,
  /// - the next start's appended default (Navigate on a click) and the long
  ///   press the rider added,
  /// - a later start's appended default, which the rider cleared, and the
  ///   long press set again (single click: none, long press: Steer).
  List<String> saved76() => [
    for (final button in [kickrLeft, kickrRight]) ...[
      pair(button, ButtonTrigger.singleClick, steer[button]),
      pair(button, ButtonTrigger.singleClick, button.action),
      pair(button, ButtonTrigger.longPress, steer[button]),
      pair(button, ButtonTrigger.singleClick),
      pair(button, ButtonTrigger.longPress, steer[button]),
    ],
  ].map((p) => p.encode()).toList();

  /// An app start: reload the saved keymap, connect the KICKR BIKE.
  CustomApp start(List<String> saved) {
    final app = CustomApp(profileName: 'MyWhoosh')..decodeKeymap(saved);
    core.actionHandler.init(app);
    app.keymap.addNewButtons([kickrLeft, kickrRight]);
    return app;
  }

  /// What 7.7.0 saved after starting on [saved]: the oldest pair per trigger
  /// copied onto the KICKR's buttons and appended.
  List<String> polluted77(List<String> saved) => [
    ...saved,
    for (final button in [kickrLeft, kickrRight]) ...[
      pair(button, ButtonTrigger.singleClick, steer[button]).encode(),
      pair(button, ButtonTrigger.longPress, steer[button]).encode(),
    ],
  ];

  void expectRiderMapping(CustomApp app) {
    for (final button in [kickrLeft, kickrRight]) {
      final click = app.keymap.getKeyPair(button, trigger: ButtonTrigger.singleClick);
      expect(click == null || click.hasNoAction, isTrue, reason: '$button: a tap must not steer');
      expect(app.keymap.getKeyPair(button, trigger: ButtonTrigger.longPress)?.inGameAction, steer[button]);
    }
  }

  test('the rider\'s latest mapping comes back from a 7.6 keymap', () {
    expectRiderMapping(start(saved76()));
  });

  test('a keymap 7.7.0 already rewrote is repaired on the next start', () {
    expectRiderMapping(start(polluted77(saved76())));
  });

  test('the mapping stays put over further starts', () {
    var app = start(polluted77(saved76()));
    int? count;
    for (var i = 0; i < 3; i++) {
      app = start(app.encodeKeymap());
      expectRiderMapping(app);
      count ??= app.keymap.keyPairs.length;
      expect(app.keymap.keyPairs.length, count);
    }
  });

  test('a later edit survives the next start', () {
    final app = start(saved76());
    app.keymap.getKeyPair(kickrLeft, trigger: ButtonTrigger.singleClick)!.inGameAction = InGameAction.shiftUp;

    final next = start(app.encodeKeymap());

    expect(next.keymap.getKeyPair(kickrLeft, trigger: ButtonTrigger.singleClick)?.inGameAction, InGameAction.shiftUp);
  });

  test('without Pro the hold is not refused as a second trigger', () {
    final app = start(polluted77(saved76()));
    final actions = StubActions()..supportedApp = app;

    for (final button in [kickrLeft, kickrRight]) {
      final hold = app.keymap.getKeyPair(button, trigger: ButtonTrigger.longPress)!;
      expect(actions.proGuard(button: button, trigger: ButtonTrigger.longPress, keyPair: hold), isA<NotHandled>());
    }
  });

  test('on the KICKR BIKE a hold steers and a tap is no single click', () async {
    start(polluted77(saved76()));
    final stubActions = core.actionHandler as StubActions;
    final device = _KickrSteerDevice();
    addTearDown(device.disconnect);

    await device.handleButtonsClicked([kickrLeft]);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    await device.handleButtonsClicked([]);
    expect(stubActions.performedActions.map((a) => a.trigger).toSet(), {ButtonTrigger.longPress});

    stubActions.performedActions.clear();
    await device.handleButtonsClicked([kickrRight]);
    await device.handleButtonsClicked([]);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    // Only a long press is mapped, so a tap is a short hold, as before 7.6.1.
    expect(stubActions.performedActions.where((a) => a.trigger != ButtonTrigger.longPress), isEmpty);
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
