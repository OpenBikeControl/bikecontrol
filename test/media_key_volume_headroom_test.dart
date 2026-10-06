import 'package:bike_control/utils/media_key_handler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('volumeWithHeadroom', () {
    test('lifts a muted volume so volume-down still registers', () {
      expect(volumeWithHeadroom(0.0), 0.1);
    });

    test('lowers a full volume so volume-up still registers', () {
      expect(volumeWithHeadroom(1.0), 0.9);
    });

    test('leaves a volume with headroom untouched', () {
      expect(volumeWithHeadroom(0.42), 0.42);
    });
  });

  group('isVolumeKeyChange', () {
    test('a 2 % Windows volume step is a key press', () {
      expect(isVolumeKeyChange(0.12, 0.1), isTrue);
      expect(isVolumeKeyChange(0.08, 0.1), isTrue);
    });

    test('float rounding after setVolume is not a key press', () {
      expect(isVolumeKeyChange(0.10000000149, 0.1), isFalse);
    });
  });
}
