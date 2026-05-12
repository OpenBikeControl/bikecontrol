import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_window_native/multi_window_native_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelMultiWindowNative platform = MethodChannelMultiWindowNative();
  const MethodChannel channel = MethodChannel('com.coditas.multi_window_native/pluginChannel');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

   test('windowCount returns correct value', () async {
    final count = await platform.getMessengerCount();
    expect(count, 3);
  });
}
