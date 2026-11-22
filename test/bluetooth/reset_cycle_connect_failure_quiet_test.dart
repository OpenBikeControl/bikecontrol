// Support log (Android, Zwift Click V2 left in the restart unlock mode): every
// minute ClickLogic restarts the left puck. Its last advertisement is still in
// the scan right then, so BikeControl tries to connect while the puck is
// rebooting, and that attempt fails (`deviceNotFound` / "Failed to connect").
// The successful reconnect after a restart is silent, but the failed one showed
// a red "Couldn't connect" toast every minute. A connect that fails while the
// device is restarting on purpose is part of that cycle: log it, don't alert.
import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:bike_control/bluetooth/emulation/emulated_ble_platform.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:prop/prop.dart' show LogLevel;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

class _FakeLocalNotificationsPlatform extends FlutterLocalNotificationsPlatform {
  @override
  Future<void> show({required int id, String? title, String? body, String? payload}) async {}

  @override
  Future<void> cancel({required int id}) async {}

  @override
  Future<void> cancelAll() async {}
}

/// A controller whose connect fails the way the rebooting puck's did.
class _RebootingPuck extends BluetoothDevice {
  _RebootingPuck({required this.resetting, required String id})
    : super(
        BleDevice(deviceId: id, name: 'Puck'),
        availableButtons: const [],
      );

  final bool resetting;

  @override
  bool get isResetting => resetting;

  @override
  Future<void> connectUpstream() async {
    throw UniversalBleException(
      code: UniversalBleErrorCode.deviceNotFound,
      message: 'Unknown deviceId: EC:1A:EA:ED:8D:D1',
      details: 'DEVICE_NOT_FOUND',
    );
  }

  @override
  Future<void> handleServices(List<BleService> services) async {}

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppLocalizations.load(const Locale('en'));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
    core.connection.devices.clear();
    UniversalBle.setInstance(FakeUniversalBlePlatform());
    FlutterLocalNotificationsPlatform.instance = _FakeLocalNotificationsPlatform();
  });

  tearDown(() async {
    core.connection.devices.clear();
    await core.connection.stop();
  });

  Future<List<BaseNotification>> connectAndCollect(_RebootingPuck puck) async {
    final notifications = <BaseNotification>[];
    final sub = core.connection.actionStream.listen(notifications.add);
    addTearDown(sub.cancel);
    core.connection.addDevices([puck]);
    await pumpEventQueue();
    return notifications;
  }

  Iterable<AlertNotification> alerts(List<BaseNotification> n) =>
      n.whereType<AlertNotification>().where((a) => a.level != LogLevel.LOGLEVEL_INFO);

  test('a connect that fails while the device is restarting on purpose stays a log line', () async {
    final notifications = await connectAndCollect(_RebootingPuck(resetting: true, id: 'EC:1A:EA:ED:8D:D1'));

    expect(alerts(notifications), isEmpty, reason: 'the restart cycle must not raise an error toast');
    expect(
      notifications.whereType<LogNotification>().map((n) => n.message),
      contains(contains('connect attempt failed')),
      reason: 'support still sees the failed attempt in the log',
    );
  });

  test('a connect that fails outside a restart still tells the rider', () async {
    final notifications = await connectAndCollect(_RebootingPuck(resetting: false, id: 'EC:1A:EA:ED:8D:D2'));

    expect(alerts(notifications), isNotEmpty);
  });
}
