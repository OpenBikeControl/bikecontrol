import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_key_detector_macos/media_key_detector_macos.dart';
import 'package:media_key_detector_platform_interface/media_key_detector_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MediaKeyDetectorMacOS', () {
    const kPlatformName = 'MacOS';
    late MediaKeyDetectorMacOS mediaKeyDetector;
    late List<MethodCall> log;

    setUp(() async {
      mediaKeyDetector = MediaKeyDetectorMacOS();

      log = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(mediaKeyDetector.methodChannel,
              (methodCall) async {
        log.add(methodCall);
        switch (methodCall.method) {
          case 'getPlatformName':
            return kPlatformName;
          default:
            return null;
        }
      });
    });

    test('can be registered', () {
      MediaKeyDetectorMacOS.registerWith();
      expect(MediaKeyDetectorPlatform.instance, isA<MediaKeyDetectorMacOS>());
    });

    test('getPlatformName returns correct name', () async {
      final name = await mediaKeyDetector.getPlatformName();
      expect(
        log,
        <Matcher>[isMethodCall('getPlatformName', arguments: null)],
      );
      expect(name, equals(kPlatformName));
    });
  });
}
