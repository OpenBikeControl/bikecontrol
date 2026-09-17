import 'dart:io';

import 'package:bike_control/main.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // No plugin registrant runs under `flutter test`, so path_provider falls
  // back to its method channel; answer it with a temp dir.
  late Directory supportDir;
  setUp(() {
    supportDir = Directory.systemTemp.createTempSync('bikecontrol_crash_log');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => supportDir.path,
    );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    supportDir.deleteSync(recursive: true);
  });

  test('crash log lives in the app support directory, not the process cwd', () async {
    final file = await crashLogFile();

    // The process cwd is `/` inside an iOS sandbox, so `//app.log` is not
    // writable; the support directory always is.
    expect(file.path, '${supportDir.path}/app.log');
    expect(file.path, isNot(startsWith(Directory.current.path)));
  });
}
