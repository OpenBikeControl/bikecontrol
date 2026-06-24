import 'package:bike_control/services/overlay/ios_pip_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('bike_control/pip_ios');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'isSupported') return true;
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('isSupported returns the native boolean', () async {
    final pip = IosPipController();
    expect(await pip.isSupported(), true);
    expect(calls.single.method, 'isSupported');
  });

  test('start forwards the state map', () async {
    final pip = IosPipController();
    await pip.start({'gear': 7, 'maxGear': 12});
    expect(calls.single.method, 'start');
    expect(calls.single.arguments, {'gear': 7, 'maxGear': 12});
  });

  test('update forwards the state map', () async {
    final pip = IosPipController();
    await pip.update({'gear': 8});
    expect(calls.single.method, 'update');
    expect(calls.single.arguments, {'gear': 8});
  });

  test('stop invokes stop with no arguments', () async {
    final pip = IosPipController();
    await pip.stop();
    expect(calls.single.method, 'stop');
    expect(calls.single.arguments, isNull);
  });

  test('isSupported returns false when the channel throws', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'boom');
    });
    final pip = IosPipController();
    expect(await pip.isSupported(), false);
  });
}
