import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_key_detector_linux/media_key_detector_linux.dart';
import 'package:media_key_detector_platform_interface/media_key_detector_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MediaKeyDetectorLinux', () {
    const kPlatformName = 'Linux';
    late MediaKeyDetectorLinux mediaKeyDetector;
    late List<MethodCall> log;

    setUp(() async {
      mediaKeyDetector = MediaKeyDetectorLinux();

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
      MediaKeyDetectorLinux.registerWith();
      expect(MediaKeyDetectorPlatform.instance, isA<MediaKeyDetectorLinux>());
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
