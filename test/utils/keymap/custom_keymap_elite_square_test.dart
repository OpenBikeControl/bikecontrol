import 'package:bike_control/bluetooth/devices/elite/elite_square.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A custom keymap must keep the rider's Elite Square Y/A/B/Z mappings across
/// restarts: reloading the profile and connecting the Square must neither lose
/// them nor append the trainer app's defaults again.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'trainer_app': 'TrainingPeaks Virtual'});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
  });

  /// Saves and reloads [app], then connects the Square, as an app start does.
  CustomApp restart(CustomApp app) {
    final reloaded = CustomApp(profileName: app.profileName)..decodeKeymap(app.encodeKeymap());
    core.actionHandler.supportedApp = reloaded;
    reloaded.keymap.addNewButtons(EliteSquareButtons.values);
    return reloaded;
  }

  test('Square Y/A/B/Z mappings survive restarts without growing the keymap', () {
    var app = CustomApp(profileName: 'Mine');
    core.actionHandler.supportedApp = app;
    app.keymap.addNewButtons(EliteSquareButtons.values);
    app.setKey(
      EliteSquareButtons.y,
      physicalKey: null,
      logicalKey: null,
      inGameAction: InGameAction.trainerIntensityUp,
    );
    final count = app.keymap.keyPairs.length;

    for (var i = 0; i < 3; i++) {
      app = restart(app);
      expect(app.keymap.getKeyPair(EliteSquareButtons.y)?.inGameAction, InGameAction.trainerIntensityUp);
      expect(app.keymap.keyPairs.length, count);
    }
  });

  test('a profile saved with bare y/a/b/z names keeps the first (own) mapping', () {
    // What older builds stored: the rider's mapping, then the defaults that
    // were appended on later starts.
    final legacy = CustomApp(profileName: 'Old')
      ..decodeKeymap([
        KeyPair(
          buttons: const [ControllerButton('y')],
          physicalKey: null,
          logicalKey: null,
          inGameAction: InGameAction.trainerIntensityUp,
        ).encode(),
        KeyPair(
          buttons: const [ControllerButton('y')],
          physicalKey: null,
          logicalKey: null,
          inGameAction: InGameAction.menu,
          touchPosition: const Offset(58.5, 84.3),
        ).encode(),
      ]);

    final app = restart(legacy);

    final pair = app.keymap.getKeyPair(EliteSquareButtons.y);
    expect(pair?.inGameAction, InGameAction.trainerIntensityUp);
    expect(pair?.touchPosition, Offset.zero);
    expect(restart(app).keymap.keyPairs.length, app.keymap.keyPairs.length);
  });

  test('Zwift right-controller Y is unaffected by the Square', () {
    final app = CustomApp(profileName: 'Zwift')
      ..decodeKeymap([
        KeyPair(
          buttons: const [ZwiftButtons.y],
          physicalKey: null,
          logicalKey: null,
          inGameAction: InGameAction.trainerIntensityDown,
        ).encode(),
      ]);
    core.actionHandler.supportedApp = app;
    app.keymap.addNewButtons([ZwiftButtons.y]);

    expect(app.keymap.getKeyPairs(ZwiftButtons.y), hasLength(1));
    expect(app.keymap.getKeyPair(ZwiftButtons.y)?.inGameAction, InGameAction.trainerIntensityDown);
  });
}
