import 'dart:io';

import 'package:bike_control/utils/actions/screenshot_folder.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('defaultScreenshotDirectory', () {
    test('Windows uses the Pictures folder in the user profile, not the launch folder', () {
      expect(
        defaultScreenshotDirectory(environment: {'USERPROFILE': r'C:\Users\rider'}, isWindows: true),
        r'C:\Users\rider\Pictures',
      );
    });

    test('macOS uses ~/Pictures', () {
      expect(
        defaultScreenshotDirectory(environment: {'HOME': '/Users/rider'}, isWindows: false),
        '/Users/rider/Pictures',
      );
    });

    test('returns null when the home folder is unknown', () {
      expect(defaultScreenshotDirectory(environment: const {}, isWindows: true), isNull);
    });
  });

  group('chooseScreenshotDirectory', () {
    late Directory tmp;

    setUp(() => tmp = Directory.systemTemp.createTempSync('bc_shot_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('returns the folder the user picks', () async {
      final picked = await chooseScreenshotDirectory(
        current: null,
        fallback: tmp.path,
        pick: ({String? initialDirectory, String? dialogTitle}) async => r'D:\DATEN\Bilder\Screenshots',
      );
      expect(picked, r'D:\DATEN\Bilder\Screenshots');
    });

    test('opens the picker at the current folder when one is set', () async {
      final current = Directory('${tmp.path}${Platform.pathSeparator}current')..createSync();
      String? initial;
      await chooseScreenshotDirectory(
        current: current.path,
        fallback: tmp.path,
        pick: ({String? initialDirectory, String? dialogTitle}) async {
          initial = initialDirectory;
          return null;
        },
      );
      expect(initial, current.path);
    });

    test('opens the picker at the fallback when nothing is set yet', () async {
      String? initial;
      await chooseScreenshotDirectory(
        current: null,
        fallback: tmp.path,
        pick: ({String? initialDirectory, String? dialogTitle}) async {
          initial = initialDirectory;
          return null;
        },
      );
      expect(initial, tmp.path);
    });

    test('cancelling returns null', () async {
      final picked = await chooseScreenshotDirectory(
        current: tmp.path,
        fallback: tmp.path,
        pick: ({String? initialDirectory, String? dialogTitle}) async => null,
      );
      expect(picked, isNull);
    });
  });

  group('saveScreenshotFile', () {
    late Directory tmp;

    setUp(() => tmp = Directory.systemTemp.createTempSync('bc_shot_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('writes the file before returning', () async {
      final file = await saveScreenshotFile(tmp.path, [1, 2, 3], DateTime(2026, 11, 17, 12, 5, 4));
      expect(file.existsSync(), isTrue);
      expect(file.readAsBytesSync(), [1, 2, 3]);
      expect(file.path.endsWith('BikeControl 2026-11-17T12-05-04.jpg'), isTrue);
    });

    test('throws when the folder cannot be written', () async {
      final blocker = File('${tmp.path}${Platform.pathSeparator}not_a_folder')..writeAsStringSync('x');
      await expectLater(
        saveScreenshotFile(blocker.path, [1], DateTime(2026)),
        throwsA(isA<FileSystemException>()),
      );
    });
  });

  group('screenshotImage', () {
    // One blue pixel as Windows GetDIBits / macOS return it: B, G, R, A.
    final bluePixelBgra = [255, 0, 0, 255];

    for (final platform in [TargetPlatform.windows, TargetPlatform.macOS]) {
      test('$platform reads the capture as BGRA, so blue stays blue', () {
        final pixel = screenshotImage(bytes: bluePixelBgra, width: 1, height: 1, platform: platform).getPixel(0, 0);
        expect((pixel.r, pixel.g, pixel.b), (0, 0, 255));
      });
    }

    test('Linux reads the capture as RGBA', () {
      final pixel = screenshotImage(
        bytes: [0, 0, 255, 255],
        width: 1,
        height: 1,
        platform: TargetPlatform.linux,
      ).getPixel(0, 0);
      expect((pixel.r, pixel.g, pixel.b), (0, 0, 255));
    });
  });
}
