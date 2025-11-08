import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_key_detector_platform_interface/media_key_detector_platform_interface.dart';
import 'package:media_key_detector_windows/media_key_detector_windows.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MediaKeyDetectorWindows', () {
    const kPlatformName = 'Windows';
    late MediaKeyDetectorWindows mediaKeyDetector;
    late List<MethodCall> log;

    setUp(() async {
      mediaKeyDetector = MediaKeyDetectorWindows();

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
      MediaKeyDetectorWindows.registerWith();
      expect(MediaKeyDetectorPlatform.instance, isA<MediaKeyDetectorWindows>());
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
