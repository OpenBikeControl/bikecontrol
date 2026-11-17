import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';

/// Where riders learn to let their trainer app shift instead (no limit).
const vsWithoutBikeControlGuideUrl = 'https://bikecontrol.app/blog/virtual-shifting-with-and-without-bikecontrol';

/// The daily limit on BikeControl's virtual shifting, in words that fit the
/// rider. Someone who bought Base paid for unlimited buttons: "trial" and a
/// bare "Pro removes the daily limit" read to them as a limit on what they
/// bought. Their copy says the buttons stay unlimited and leads with the way
/// to shift without any limit; Pro comes last.
class VsTrialCopy {
  const VsTrialCopy(this.l10n, {required this.ownsBase});

  /// For the rider on this device right now.
  factory VsTrialCopy.current(AppLocalizations l10n) => VsTrialCopy(l10n, ownsBase: riderOwnsBaseWithoutPro());

  final AppLocalizations l10n;

  /// Bought Base, no Pro on this device.
  final bool ownsBase;

  String minutesLeftToday(int minutes) =>
      ownsBase ? l10n.vsBaseMinutesLeftToday(minutes) : l10n.bridgeMinutesRemainingToday(minutes);

  String endingSoonTitle(int minutes) =>
      ownsBase ? l10n.vsBaseEndingSoonTitle(minutes) : l10n.bridgeTrialEndingSoonTitle(minutes);

  String get endingSoonBody => ownsBase ? l10n.vsBaseEndingSoonBody : l10n.bridgeTrialEndingSoonBody;

  String get overTitle => ownsBase ? l10n.vsBaseOverTitle : l10n.bridgeTrialTimeOverTitle;

  /// The minutes ran out while the trainer app was connected.
  String get overMidRideBody => ownsBase ? l10n.vsBaseOverBody : l10n.bridgeTrialTimeOverBody;

  /// The trainer was connected with the minutes already gone.
  String get alreadyOverBody => ownsBase ? l10n.vsBaseAlreadyOverBody : l10n.bridgeTrialAlreadyOverBody;
}

/// Bought Base (unlimited buttons) but has no Pro on this device.
bool riderOwnsBaseWithoutPro() {
  final iap = IAPManager.instance;
  return iap.isPurchased.value && !iap.isProEnabledForCurrentDevice;
}
