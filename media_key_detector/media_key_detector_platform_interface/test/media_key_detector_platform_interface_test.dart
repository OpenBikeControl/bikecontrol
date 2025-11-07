import 'package:flutter_test/flutter_test.dart';
import 'package:media_key_detector_platform_interface/media_key_detector_platform_interface.dart';

class MediaKeyDetectorMock extends MediaKeyDetectorPlatform {
  static const mockPlatformName = 'Mock';
  bool isPlaying = false;

  @override
  Future<String?> getPlatformName() async => mockPlatformName;

  @override
  void addListener(void Function(MediaKey mediaKey) listener) {}

  @override
  Future<bool> getIsPlaying() async {
    return isPlaying;
  }

  @override
  Future<void> setIsPlaying({required bool isPlaying}) async {
    this.isPlaying = isPlaying;
  }

  @override
  void initialize() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('MediaKeyDetectorPlatformInterface', () {
    late MediaKeyDetectorPlatform mediaKeyDetectorPlatform;

    setUp(() {
      mediaKeyDetectorPlatform = MediaKeyDetectorMock();
      MediaKeyDetectorPlatform.instance = mediaKeyDetectorPlatform;
    });

    group('getPlatformName', () {
      test('returns correct name', () async {
        expect(
          await MediaKeyDetectorPlatform.instance.getPlatformName(),
          equals(MediaKeyDetectorMock.mockPlatformName),
        );
      });
    });
  });
}
