import 'package:bike_control/bluetooth/emulation/emulated_ble_platform.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_ble/universal_ble.dart';

import 'harness/test_env.dart';

class _RecordingBlePlatform extends FakeUniversalBlePlatform {
  PlatformConfig? scanConfig;

  @override
  Future<void> startScan({ScanFilter? scanFilter, PlatformConfig? platformConfig}) async {
    scanConfig = platformConfig;
    await super.startScan(scanFilter: scanFilter, platformConfig: platformConfig);
  }
}

void main() async {
  final env = await IntegrationEnv.setUp();
  late _RecordingBlePlatform ble;

  setUp(() async {
    await env.resetState();
    ble = _RecordingBlePlatform();
    UniversalBle.setInstance(ble);
  });

  tearDown(() async {
    await env.resetConnection();
    UniversalBle.setInstance(env.ble);
  });

  test('Android 低延迟扫描同时接收旧式与扩展广播', () async {
    await core.connection.performScanning();

    expect(ble.scanConfig?.android?.legacy, isFalse);
    expect(ble.scanConfig?.android?.scanMode, AndroidScanMode.lowLatency);
  });
}
