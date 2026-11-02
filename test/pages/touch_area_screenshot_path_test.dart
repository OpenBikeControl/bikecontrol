import 'dart:io';

import 'package:bike_control/pages/touch_area.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('touch_area_screenshot_test');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('keeps the cached screenshot directly in the temp dir when the keymap name has a slash', () async {
    final file = touchAreaScreenshotFile(tempDir, 'Rouvy Di2/Dictation');

    expect(file.parent.path, tempDir.path);

    final picked = File('${tempDir.path}/picked.png')..writeAsBytesSync([1, 2, 3]);
    await picked.copy(file.path);
    expect(file.readAsBytesSync(), [1, 2, 3]);
  });

  test('replaces characters that are not allowed in file names', () {
    final file = touchAreaScreenshotFile(tempDir, r'a\b:c*d?e"f<g>h|i');

    expect(file.parent.path, tempDir.path);
    expect(file.uri.pathSegments.last, 'a_b_c_d_e_f_g_h_i_screenshot.png');
  });

  test('keeps plain app names unchanged', () {
    expect(touchAreaScreenshotFile(tempDir, 'Rouvy').path, '${tempDir.path}/Rouvy_screenshot.png');
  });

  test('falls back to temp when no app is selected', () {
    expect(touchAreaScreenshotFile(tempDir, null).path, '${tempDir.path}/temp_screenshot.png');
  });
}
