// Pro devices are registered per platform; the backend takes linux since the
// Linux app sells Pro through Stripe.
import 'package:bike_control/services/device_identity_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('Linux registers as linux', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    expect(await DeviceIdentityService().currentPlatform(), 'linux');
  });

  test('Fuchsia has no platform to register as', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
    expect(await DeviceIdentityService().currentPlatform(), isNull);
  });
}
