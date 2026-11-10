import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const names = [
    'icTrainer',
    'Auuki',
    'VoxVelo',
    'VeloWorkout',
    'Pedalparty',
    'VeloPopuli',
    'Vieta',
    'DirtWatts',
    'WattLog.pro',
    'REZVIVO',
    'OpenRadlr',
    'zwoTrainer',
    'Incyclist',
    'Tour du Pain',
  ];

  SupportedApp byName(String name) => SupportedApp.supportedApps.singleWhere((app) => app.name == name);

  test('the OpenBikeControl trainer apps are registered once as official apps', () {
    for (final name in names) {
      expect(byName(name).officialIntegration, isTrue, reason: name);
    }
  });

  test('they connect via OpenBikeControl over Bluetooth, VoxVelo, Vieta and Incyclist also over the network', () {
    for (final name in names) {
      final app = byName(name);
      expect(app.supportLevel(AppConnectionMethod.obpBle), ConnectionSupport.supported, reason: name);
      final mdns = name == 'VoxVelo' || name == 'Vieta' || name == 'Incyclist';
      expect(app.supportLevel(AppConnectionMethod.obpMdns), mdns ? ConnectionSupport.supported : isNull, reason: name);
      // OBC delivers button events over the protocol, so there is no keyboard map.
      expect(app.keymap.keyPairs, isEmpty, reason: name);
    }
  });

  test('only Vieta and Incyclist find trainers over Wi-Fi as well', () {
    for (final name in names) {
      expect(
        byName(name).virtualShiftingTransports,
        name == 'Vieta' || name == 'Incyclist'
            ? {TrainerConnectionType.bluetooth, TrainerConnectionType.wifi}
            : {TrainerConnectionType.bluetooth},
        reason: name,
      );
    }
  });

  test('they ship a logo, with a fallback URL for patched builds, and link to an https site', () {
    for (final name in names) {
      final app = byName(name);
      expect(app.logoAsset, startsWith('assets/'), reason: name);
      expect(
        app.logoUrl,
        'https://openbikecontrol.org/implementations/${app.logoAsset!.substring('assets/'.length)}',
        reason: name,
      );
      expect(app.officialUrl, startsWith('https://'), reason: name);
    }
  });
}
