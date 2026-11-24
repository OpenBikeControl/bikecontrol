import 'package:bike_control/utils/keymap/apps/supported_app.dart';

/// Each trainer app's entry slug on smarttrainerapps.com, keyed by
/// [SupportedApp.name]. Apps without an entry there (the Wahoo app, the custom
/// app) are left out.
const _smartTrainerAppsSlugs = {
  'MyWhoosh': 'mywhoosh',
  'Zwift': 'zwift',
  'TrainingPeaks Virtual': 'trainingpeaks-virtual',
  'Biketerra': 'biketerra',
  'Rouvy': 'rouvy',
  'Strappo': 'strappo',
  'Ride Cave': 'ride-cave',
  'Velotoss': 'velotoss',
  'Grimpa': 'grimpa',
  'icTrainer': 'ictrainer',
  'Auuki': 'auuki',
  'VoxVelo': 'voxvelo',
  'VeloWorkout': 'veloworkout',
  'Pedalparty': 'pedalparty',
  'VeloPopuli': 'velopopuli',
  'Vieta': 'vieta',
  'DirtWatts': 'dirtwatts',
  'WattLog.pro': 'wattlog-pro',
  'REZVIVO': 'rezvivo',
  'OpenRadlr': 'openradlr',
  'zwoTrainer': 'zwotrainer',
  'Incyclist': 'incyclist',
  'Tour du Pain': 'tour-du-pain',
  'Rampida': 'rampida',
  'Everycol': 'everycol',
  'PedalCraft': 'pedalcraft',
  'suffer.online': 'suffer-online',
  'Kardiacs': 'kardiacs',
  'Sueur': 'sueur',
  'TrainerKit': 'trainerkit',
  'Pedal Mania': 'pedal-mania',
  'Warp': 'ridewarp',
  'hupser': 'hupser',
  'SaddleOut': 'saddleout',
  'Tacx Training': 'tacx-training',
  'FulGaz': 'fulgaz',
};

/// The app's smarttrainerapps.com entry, tagged so visits from BikeControl
/// show up in the site's stats; null when it has no entry.
Uri? smartTrainerAppsUrl(SupportedApp app) {
  final slug = _smartTrainerAppsSlugs[app.name];
  if (slug == null) return null;
  return Uri.https('smarttrainerapps.com', '/apps/$slug/', {'ref': 'bikecontrol'});
}

/// A discount code a trainer app offers BikeControl riders.
class RiderDeal {
  const RiderDeal({required this.code, required this.percentOff});

  final String code;
  final int percentOff;
}

/// Grimpa's affiliate deal: [RiderDeal.percentOff] off the first Grimpa Plus
/// purchase. Null for every other app.
RiderDeal? riderDealFor(SupportedApp app) => switch (app.name) {
  'Grimpa' => const RiderDeal(code: 'BIKECONTROL', percentOff: 20),
  _ => null,
};
