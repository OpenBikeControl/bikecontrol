import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/services/screen_recording/screen_recording_service.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness/test_env.dart';

/// Minimal concrete BaseActions so the REAL performAction handler runs
/// (BaseActions is abstract only on cleanup()).
class _TestActions extends BaseActions {
  _TestActions() : super(supportedModes: const []);
  @override
  void cleanup() {}
}

class _FakeBackend implements ScreenRecorderBackend {
  bool available = true;
  int starts = 0;
  int stops = 0;
  @override
  Future<bool> isAvailable() async => available;
  @override
  Future<bool> ensurePermission() async => true;
  @override
  Future<bool> start() async {
    starts++;
    return true;
  }

  @override
  Future<String?> stop() async {
    stops++;
    return '/tmp/x.mp4';
  }
}

Future<void> main() async {
  final env = await IntegrationEnv.setUp();
  late _TestActions actions;
  late _FakeBackend backend;

  const button = ControllerButton('screenRecTestBtn');

  setUp(() async {
    await env.resetState();
    // Screen recording is a Pro action; enable Pro so proGuard lets the handler run.
    IAPManager.instance.setProForTesting(enabled: true);
    backend = _FakeBackend();
    core.screenRecording = ScreenRecordingService(backend: backend);

    final app = Zwift();
    app.keymap.keyPairs.add(
      KeyPair(buttons: const [button], physicalKey: null, logicalKey: null, inGameAction: InGameAction.screenRecording),
    );
    actions = _TestActions()..supportedApp = app;
    core.actionHandler = actions;
  });

  test('key-down toggles recording on and returns started', () async {
    final result = await actions.performAction(button, isKeyDown: true, isKeyUp: false);
    expect(result, isA<Success>());
    expect(result.message, AppLocalizations.current.screenRecordingStarted);
    expect(backend.starts, 1);
  });

  test('key-up is ignored (no double toggle)', () async {
    final result = await actions.performAction(button, isKeyDown: false, isKeyUp: true);
    expect(result, isA<Ignored>());
    expect(backend.starts, 0);
  });

  test('second key-down stops and saves', () async {
    await actions.performAction(button, isKeyDown: true, isKeyUp: false);
    final result = await actions.performAction(button, isKeyDown: true, isKeyUp: false);
    expect(result, isA<Success>());
    expect(backend.stops, 1);
  });

  test('unsupported device returns Ignored not-supported', () async {
    backend.available = false;
    final result = await actions.performAction(button, isKeyDown: true, isKeyUp: false);
    expect(result, isA<Ignored>());
    expect(result.message, AppLocalizations.current.screenRecordingNotSupported);
  });

  test('non-Pro user is blocked by the Pro gate (recording never starts)', () async {
    IAPManager.instance.setProForTesting(enabled: false);
    final result = await actions.performAction(button, isKeyDown: true, isKeyUp: false);
    expect(result, isA<Error>());
    expect((result as Error).type, ErrorType.proRequired);
    expect(backend.starts, 0);
  });
}
