import 'dart:convert';

import 'package:bike_control/bluetooth/devices/openbikecontrol/obc_mdns_emulator.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/training_peaks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/mdns/service_advertiser.dart';
import 'package:prop/utils/constants.dart';
import 'package:prop/utils/prefs.dart';
import 'package:prop/utils/self_advertisement_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration/harness/test_env.dart';
import 'recording_advertiser.dart';

/// Two riders, each with BikeControl on their own phone, on one LAN, each
/// with TrainingPeaks Virtual on their own Apple TV. Both phones used to
/// advertise the controller entry as "BikeControl" with serial 1234567890,
/// so mDNS renamed one to "BikeControl (2)" and TPV's controller link landed
/// on the other rider's phone.
Future<void> main() async {
  final env = await IntegrationEnv.setUp();
  late RecordingAdvertiser advertiser;

  /// Fresh prefs = a fresh install with its own install id.
  Future<void> freshInstall() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    propPrefs.initialize(core.settings.prefs);
    BikeControlMdnsMarkers.debugResetInstallId();
  }

  Future<AdvertisedService> advertise() async {
    await core.obpMdnsEmulator.startServer();
    final service = advertiser.services.single;
    await core.obpMdnsEmulator.stopServer();
    return service;
  }

  String txt(AdvertisedService s, String key) => utf8.decode(s.txt[key]!);

  setUp(() async {
    env.mdns.reset();
    await freshInstall();
    advertiser = RecordingAdvertiser();
    ServiceAdvertiser.instance = advertiser;
  });

  tearDown(() async {
    await core.obpMdnsEmulator.stopServer();
    ServiceAdvertiser.instance = NsdServiceAdvertiser();
    BikeControlMdnsMarkers.debugResetInstallId();
  });

  group('TrainingPeaks Virtual (DirCon) controller entry', () {
    test('two installs advertise different instance names and serials', () async {
      core.settings.setTrainerApp(TrainingPeaks());
      final first = await advertise();

      await freshInstall();
      core.settings.setTrainerApp(TrainingPeaks());
      final second = await advertise();

      expect(first.name, startsWith('BikeControl'));
      expect(second.name, startsWith('BikeControl'));
      expect(first.name, isNot(second.name));
      expect(txt(first, 'serial-number'), isNot(txt(second, 'serial-number')));
    });

    test('the name says which platform it runs on, plus four hex digits', () async {
      core.settings.setTrainerApp(TrainingPeaks());
      final service = await advertise();

      expect(service.name, matches(RegExp(r'^BikeControl (iOS|Android|macOS|Windows|Linux) [0-9A-F]{4}$')));
    });

    test('the in-app hint names the tile TPv shows', () async {
      core.settings.setTrainerApp(TrainingPeaks());
      final service = await advertise();

      expect(OpenBikeControlMdnsEmulator.controllerTileNameFor(TrainingPeaks()), service.name);
    });

    test('name and serial stay the same across restarts of one install', () async {
      core.settings.setTrainerApp(TrainingPeaks());
      final first = await advertise();
      final again = await advertise();

      expect(again.name, first.name);
      expect(txt(again, 'serial-number'), txt(first, 'serial-number'));
    });

    test('the serial is all digits, as DirCon clients parse it as a number', () async {
      core.settings.setTrainerApp(TrainingPeaks());
      final service = await advertise();

      expect(txt(service, 'serial-number'), matches(RegExp(r'^\d+$')));
    });

    test('only this install\'s entry counts as "this device"', () async {
      core.settings.setTrainerApp(TrainingPeaks());
      await core.obpMdnsEmulator.startServer();
      final name = advertiser.services.single.name;

      expect(SelfAdvertisementRegistry.instance.containsName(name), isTrue);
      expect(
        SelfAdvertisementRegistry.instance.containsName('BikeControl'),
        isFalse,
        reason: 'another phone\'s "BikeControl" is not this device',
      );
    });
  });

  test('MyWhoosh (OBC) keeps the plain "BikeControl" entry', () async {
    core.settings.setTrainerApp(MyWhoosh());
    final service = await advertise();

    expect(service.name, 'BikeControl');
    expect(OpenBikeControlMdnsEmulator.controllerTileNameFor(MyWhoosh()), 'BikeControl');
  });
}
