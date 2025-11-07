import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_key_detector_platform_interface/media_key_detector_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const kPlatformName = 'platformName';

  group('$MethodChannelMediaKeyDetector', () {
    late MethodChannelMediaKeyDetector methodChannelMediaKeyDetector;
    final log = <MethodCall>[];

    setUp(() async {
      methodChannelMediaKeyDetector = MethodChannelMediaKeyDetector();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        methodChannelMediaKeyDetector.methodChannel,
        (methodCall) async {
          log.add(methodCall);
          switch (methodCall.method) {
            case 'getPlatformName':
              return kPlatformName;
            default:
              return null;
          }
        },
      );
    });

    tearDown(log.clear);

    test('getPlatformName', () async {
      final platformName =
          await methodChannelMediaKeyDetector.getPlatformName();
      expect(
        log,
        <Matcher>[isMethodCall('getPlatformName', arguments: null)],
      );
      expect(platformName, equals(kPlatformName));
    });
  });
}
