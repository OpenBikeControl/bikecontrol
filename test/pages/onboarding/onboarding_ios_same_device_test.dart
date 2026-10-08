// On iOS, "This Device" means the trainer app runs on the same iPhone/iPad as
// BikeControl. Bluetooth cannot reach an app on the same device, so its tile
// must not be offered; the Local tile is shown (disabled, with its iOS note)
// so riders learn why it isn't an option.
import 'package:bike_control/pages/onboarding/onboarding_methods.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/host_platform.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../widget_snapshot.dart';

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(ensureSnapshotAppState);

  tearDown(() {
    debugHostPlatformOverride = null;
    core.actionHandler = StubActions();
  });

  test('iOS + This Device: Bluetooth hidden, Local shown but unavailable', () async {
    debugHostPlatformOverride = TargetPlatform.iOS;
    final SupportedApp app = Rouvy();
    core.settings.setTrainerApp(app);
    await core.settings.setLastTarget(Target.thisDevice);

    expect(onboardingMethodVisible(OnboardingMethod.bluetooth, app), isFalse,
        reason: 'Bluetooth cannot reach an app on the same device');
    expect(onboardingMethodVisible(OnboardingMethod.local, app), isTrue,
        reason: 'the Local tile is shown disabled with its iOS note');
    expect(onboardingMethodAvailable(OnboardingMethod.local), isFalse);
    expect(onboardingMethodVisible(OnboardingMethod.network, app), isTrue);
  });

  test('iOS + Other Device: Bluetooth offered, Local hidden', () async {
    debugHostPlatformOverride = TargetPlatform.iOS;
    final SupportedApp app = Rouvy();
    core.settings.setTrainerApp(app);
    await core.settings.setLastTarget(Target.otherDevice);

    expect(onboardingMethodVisible(OnboardingMethod.bluetooth, app), isTrue);
    expect(onboardingMethodVisible(OnboardingMethod.local, app), isFalse);
  });

  test('the Where step promises what the target really turns on', () {
    debugHostPlatformOverride = TargetPlatform.iOS;
    expect(onboardingWhereUsesLocal(Target.thisDevice), isFalse,
        reason: 'iOS has no Local method — same-device apps go over the network');
    expect(onboardingWhereUsesLocal(Target.otherDevice), isFalse);
    debugHostPlatformOverride = TargetPlatform.android;
    expect(onboardingWhereUsesLocal(Target.thisDevice), isTrue);
    expect(onboardingWhereUsesLocal(Target.otherDevice), isFalse);
  });
}
