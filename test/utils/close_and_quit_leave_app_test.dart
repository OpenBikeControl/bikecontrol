import 'package:bike_control/utils/host_platform.dart';
import 'package:bike_control/utils/requirements/android.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Settings > "Close connections & quit app" ends with leaving the app. Flutter
/// ignores SystemNavigator.pop() on iOS, so there the row tore everything down
/// and then left the app open — a rider tapped it 13 times in 9 seconds and
/// wrote in that it doesn't work (support d103d226).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final pops = <MethodCall>[];
  final exits = <int>[];

  setUp(() {
    pops.clear();
    exits.clear();
    NotificationRequirement.exitProcess = exits.add;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemNavigator.pop') pops.add(call);
        return null;
      },
    );
  });

  tearDown(() {
    debugHostPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });

  test('on iOS the process exits', () async {
    debugHostPlatformOverride = TargetPlatform.iOS;

    await NotificationRequirement.leaveApp();

    expect(exits, [0]);
  });

  test('on Android the activity is popped, as before', () async {
    debugHostPlatformOverride = TargetPlatform.android;

    await NotificationRequirement.leaveApp();

    expect(pops, hasLength(1));
    expect(exits, isEmpty);
  });
}
