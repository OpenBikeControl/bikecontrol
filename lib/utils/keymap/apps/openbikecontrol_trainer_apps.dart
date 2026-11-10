import 'package:bike_control/utils/keymap/apps/supported_app.dart';

import '../keymap.dart';

/// A trainer app that implements the open OpenBikeControl protocol and needs
/// nothing beyond its connection methods, links and logo: button events arrive
/// over the protocol, so there is no keyboard keymap.
///
/// Apps with their own behaviour (default buttons, mDNS TXT entries, ...) keep
/// a class of their own, like [Grimpa] or [RideCave].
class OpenBikeControlTrainerApp extends SupportedApp {
  final List<(AppConnectionMethod, ConnectionSupport)> _connections;
  final String _logo;
  final String _officialUrl;
  final Set<TrainerConnectionType> _transports;

  OpenBikeControlTrainerApp({
    required super.name,
    required String logo,
    required String officialUrl,
    bool mdns = false,
    bool wifiTrainers = false,
  }) : _logo = logo,
       _officialUrl = officialUrl,
       _connections = [
         if (mdns) (AppConnectionMethod.obpMdns, ConnectionSupport.supported),
         (AppConnectionMethod.obpBle, ConnectionSupport.supported),
       ],
       _transports = {TrainerConnectionType.bluetooth, if (wifiTrainers) TrainerConnectionType.wifi},
       super(
         packageName: name,
         officialIntegration: true,
         keymap: Keymap(keyPairs: []),
       );

  @override
  List<(AppConnectionMethod, ConnectionSupport)> get connections => _connections;

  @override
  String? get logoAsset => 'assets/$_logo';

  /// An over-the-air patch can't add assets, so builds without the bundled logo
  /// load it from openbikecontrol.org.
  @override
  String? get logoUrl => 'https://openbikecontrol.org/implementations/$_logo';

  @override
  String? get officialUrl => _officialUrl;

  @override
  Set<TrainerConnectionType> get virtualShiftingTransports => _transports;

  /// The trainer apps listed as implemented in the OpenBikeControl protocol
  /// repository (https://github.com/OpenBikeControl/openbikecontrol-protocol).
  static List<OpenBikeControlTrainerApp> get all => [
    OpenBikeControlTrainerApp(name: 'icTrainer', logo: 'ictrainer.png', officialUrl: 'https://www.ictrainer.com'),
    OpenBikeControlTrainerApp(name: 'Auuki', logo: 'auuki.png', officialUrl: 'https://auuki.com'),
    OpenBikeControlTrainerApp(
      name: 'VoxVelo',
      logo: 'voxvelo.png',
      officialUrl: 'https://github.com/michidk/VoxVelo',
      mdns: true,
    ),
    OpenBikeControlTrainerApp(name: 'VeloWorkout', logo: 'veloworkout.png', officialUrl: 'https://veloworkout.com'),
    OpenBikeControlTrainerApp(name: 'Pedalparty', logo: 'pedalparty.png', officialUrl: 'https://pedalparty.cc'),
    OpenBikeControlTrainerApp(name: 'VeloPopuli', logo: 'velopopuli.png', officialUrl: 'https://velopopuli.com'),
    OpenBikeControlTrainerApp(
      name: 'Vieta',
      logo: 'vieta.png',
      officialUrl: 'https://vieta.cc',
      mdns: true,
      wifiTrainers: true,
    ),
    OpenBikeControlTrainerApp(name: 'DirtWatts', logo: 'dirtwatts.png', officialUrl: 'https://dirtwatts.com'),
    OpenBikeControlTrainerApp(name: 'WattLog.pro', logo: 'wattlog.png', officialUrl: 'https://wattlog.pro'),
    OpenBikeControlTrainerApp(name: 'REZVIVO', logo: 'rezvivo.png', officialUrl: 'https://rezvivo.com'),
    OpenBikeControlTrainerApp(name: 'OpenRadlr', logo: 'openradlr.png', officialUrl: 'https://openradlr.com'),
    OpenBikeControlTrainerApp(
      name: 'zwoTrainer',
      logo: 'zwotrainer.png',
      officialUrl: 'https://steffenr.github.io/zwo-trainer/',
    ),
    OpenBikeControlTrainerApp(
      name: 'Incyclist',
      logo: 'incyclist.png',
      officialUrl: 'https://incyclist.com',
      mdns: true,
      wifiTrainers: true,
    ),
    OpenBikeControlTrainerApp(
      name: 'Tour du Pain',
      logo: 'tour-du-pain.png',
      officialUrl: 'https://tourdupain.app',
    ),
  ];
}
