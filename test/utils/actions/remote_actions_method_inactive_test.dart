import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show screenshotMode;
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/actions/remote.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A press whose only action is a keyboard key or a touch reaches the end of
/// [RemoteActions] when neither "Act as Bluetooth Keyboard" nor "Act as
/// Bluetooth Mouse" is on. The rider may well have a trainer app connected
/// (Biketerra over OpenBikeControl), so "No connection method active" was
/// wrong: the message has to name the method this press needed.
Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await AppLocalizations.load(const Locale('en'));

  const button = ControllerButton('eliteSquareRightShift1', action: InGameAction.shiftUp);

  // proGuard reaches Supabase.instance: an offline dummy one.
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      publishableKey: 'remote-actions-method-test-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        detectSessionInUri: false,
        autoRefreshToken: false,
      ),
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
    // Gets past "no connection method" and "no trainer connected", the way a
    // connected trainer app does.
    screenshotMode = true;
  });

  tearDown(() => screenshotMode = false);

  RemoteActions actionsWith(KeyPair keyPair) {
    final app = CustomApp(profileName: 'Test');
    app.keymap.keyPairs.add(keyPair);
    return RemoteActions()..supportedApp = app;
  }

  test('a keyboard key names Act as Bluetooth Keyboard', () async {
    final actions = actionsWith(
      KeyPair(buttons: [button], physicalKey: PhysicalKeyboardKey.keyW, logicalKey: LogicalKeyboardKey.keyW),
    );

    final result = await actions.performAction(button, isKeyDown: true, isKeyUp: true);

    expect(result, isA<NotHandled>());
    expect(result.message, isNot('No connection method active'));
    expect(result.message, contains(AppLocalizations.current.actAsBluetoothKeyboard));
  });

  test('a touch names Act as Bluetooth Mouse', () async {
    final actions = actionsWith(
      KeyPair(buttons: [button], physicalKey: null, logicalKey: null, touchPosition: const Offset(10, 20)),
    );

    final result = await actions.performAction(button, isKeyDown: true, isKeyUp: true);

    expect(result, isA<NotHandled>());
    expect(result.message, contains(AppLocalizations.current.enablePairingProcess));
  });
}
