import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keypress_simulator_platform_interface/src/keypress_simulator_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelKeyPressSimulator platform = MethodChannelKeyPressSimulator();
  const MethodChannel channel = MethodChannel(
    'dev.leanflutter.plugins/keypress_simulator',
  );

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'isAccessAllowed') return true;
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('isAccessAllowed', () async {
    expect(await platform.isAccessAllowed(), true);
  });
}
