import 'package:bike_control/utils/rate_app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.britannio.in_app_review');
  final calls = <String>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return call.method == 'isAvailable' ? true : null;
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('Android opens the Play Store listing, never the quota-limited sheet', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await requestAppRating();
    expect(calls, ['openStoreListing']);
  });

  test('iOS asks for the in-app review sheet when available', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await requestAppRating();
    expect(calls, ['isAvailable', 'requestReview']);
  });
}
