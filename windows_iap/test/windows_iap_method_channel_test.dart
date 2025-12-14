import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_iap/windows_iap_method_channel.dart';

void main() {
  MethodChannelWindowsIap platform = MethodChannelWindowsIap();
  const MethodChannel channel = MethodChannel('windows_iap');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getPlatformVersion', () async {
    // expect(await platform.getPlatformVersion(), '42');
  });
}
