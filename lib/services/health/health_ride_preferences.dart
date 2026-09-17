import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Trainer apps that may already write the ride to Apple Health themselves
/// when they run on this iPhone/iPad. Saving from BikeControl too would put
/// the same ride into Health twice.
bool mayAlreadySaveToHealth(SupportedApp? app) => app is Zwift || app is Rouvy;

/// Whether rides should be recorded automatically and written to Apple Health.
///
/// Until the rider decides ([explicitChoice] null) the default depends on the
/// trainer app: off when an app that may write the ride itself runs on this
/// device, on otherwise. Pro-only, and only where Health exists.
bool resolveSaveRidesToHealth({
  required bool platformSupported,
  required bool isPro,
  required bool? explicitChoice,
  required SupportedApp? trainerApp,
  required Target? target,
}) {
  if (!platformSupported || !isPro) return false;
  if (explicitChoice != null) return explicitChoice;
  return !(mayAlreadySaveToHealth(trainerApp) && target == Target.thisDevice);
}

/// Persisted state of the "Save rides to Apple Health" feature.
class HealthRidePreferences extends ChangeNotifier {
  HealthRidePreferences(this._prefs);

  final SharedPreferences _prefs;

  static const _explicitKey = 'health_rides_enabled';
  static const _rideDetectedKey = 'health_rides_ride_detected';
  static const _promptDismissedKey = 'health_rides_prompt_dismissed';

  /// The rider's own answer from the toggle or the home prompt; null while
  /// undecided, which is when the per-app default applies.
  bool? get explicitChoice => _prefs.getBool(_explicitKey);

  Future<void> setExplicitChoice(bool enabled) async {
    await _prefs.setBool(_explicitKey, enabled);
    notifyListeners();
  }

  /// A ride with a connected trainer has been seen — the home prompt's cue.
  bool get rideDetected => _prefs.getBool(_rideDetectedKey) ?? false;

  Future<void> setRideDetected() async {
    await _prefs.setBool(_rideDetectedKey, true);
    notifyListeners();
  }

  bool get promptDismissed => _prefs.getBool(_promptDismissedKey) ?? false;

  Future<void> setPromptDismissed() async {
    await _prefs.setBool(_promptDismissedKey, true);
    notifyListeners();
  }
}
