import '../emulation_profile.dart';
import 'elite_profiles.dart';
import 'misc_profiles.dart';
import 'wahoo_profiles.dart';
import 'zwift_profiles.dart';

/// Every device the debug "Emulate device" menu can add: controllers first,
/// then steering, then accessories.
List<EmulationProfile> get allEmulationProfiles => [
      zwiftClickProfile,
      zwiftClickV2LeftProfile,
      zwiftClickV2RightProfile,
      zwiftPlayLeftProfile,
      zwiftPlayRightProfile,
      zwiftPlayFw2Profile,
      zwiftRideProfile,
      eliteSquareProfile,
      wahooKickrBikeShiftProfile,
      cycplusBc2Profile,
      thinkRiderVs200Profile,
      sramAxsProfile,
      openBikeControlProfile,
      shimanoDi2Profile,
      eliteSterzoProfile,
      eliteRizerProfile,
      wahooKickrClimbProfile,
      wahooKickrHeadwindProfile,
      heartRateStrapProfile,
      cadenceSensorProfile,
      powerMeterProfile,
    ];
