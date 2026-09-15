import 'package:bike_control/services/sensors/standalone_sensor_lifecycle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/sensor_definition.dart';
import 'package:prop/emulators/dircon_emulator.dart';

void main() {
  late List<String> calls;
  late List<RetrofitMode> startModes;
  late StandaloneSensorLifecycle lifecycle;

  setUp(() {
    calls = [];
    startModes = [];
    lifecycle = StandaloneSensorLifecycle(
      attachDefinition: (_) async => calls.add('attach'),
      startServer: (mode) async {
        startModes.add(mode);
        calls.add('start');
      },
      stopServer: () async => calls.add('stop'),
      detachDefinition: (_) async => calls.add('detach'),
    );
  });

  test('start attaches the definition before starting the server', () async {
    await lifecycle.start(SensorDefinition(), RetrofitMode.wifi);

    expect(calls, ['attach', 'start']);
    expect(startModes, [RetrofitMode.wifi]);
  });

  test('stop stops the server before detaching the definition', () async {
    await lifecycle.stop(SensorDefinition());

    expect(calls, ['stop', 'detach']);
  });
}
