import 'dart:io';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/sensors/sensor_transport_requirements.dart';
import 'package:bike_control/utils/requirements/local_network.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/dircon_emulator.dart';

/// The platform grants the standalone transport needs before it can
/// advertise — the bridge pre-flights the same ones (`ConnectionCard` for
/// BLUETOOTH_ADVERTISE, `ensureLocalNetworkAccess` for Local Network); the
/// Broadcast switch must not skip them and then fail silently.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => AppLocalizations.load(const Locale('en')));

  test('bluetooth needs BLUETOOTH_ADVERTISE on Android only', () {
    final reqs = sensorTransportRequirements(RetrofitMode.bluetooth);
    if (Platform.isAndroid) {
      expect(reqs, [isA<BluetoothAdvertiseRequirement>()]);
    } else {
      expect(reqs, isEmpty);
    }
  });

  test('network needs Local Network on iOS/macOS only', () {
    final reqs = sensorTransportRequirements(RetrofitMode.wifi);
    if (Platform.isIOS || Platform.isMacOS) {
      expect(reqs, [isA<LocalNetworkRequirement>()]);
    } else {
      expect(reqs, isEmpty);
    }
  });

  test('proxy is not a sensor transport', () {
    expect(() => sensorTransportRequirements(RetrofitMode.proxy), throwsArgumentError);
  });
}
