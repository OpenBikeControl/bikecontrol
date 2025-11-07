import 'package:flutter_test/flutter_test.dart';
import 'package:media_key_detector/media_key_detector.dart';
import 'package:media_key_detector_platform_interface/media_key_detector_platform_interface.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockMediaKeyDetectorPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements MediaKeyDetectorPlatform {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MediaKeyDetector', () {
    late MediaKeyDetectorPlatform mediaKeyDetectorPlatform;

    setUp(() {
      mediaKeyDetectorPlatform = MockMediaKeyDetectorPlatform();
      MediaKeyDetectorPlatform.instance = mediaKeyDetectorPlatform;
    });

    group('getPlatformName', () {
      test('returns correct name when platform implementation exists',
          () async {
        const platformName = '__test_platform__';
        when(
          () => mediaKeyDetectorPlatform.getPlatformName(),
        ).thenAnswer((_) async => platformName);

        final actualPlatformName = await getPlatformName();
        expect(actualPlatformName, equals(platformName));
      });

      test('throws exception when platform implementation is missing',
          () async {
        when(
          () => mediaKeyDetectorPlatform.getPlatformName(),
        ).thenAnswer((_) async => null);

        expect(getPlatformName, throwsException);
      });
    });
  });
}
