import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Trainer apps that may already write the ride to Apple Health / Health
/// Connect themselves when they run on this device. Saving from BikeControl
/// too would put the same ride into Health twice.
bool mayAlreadySaveToHealth(SupportedApp? app) => app is Zwift || app is Rouvy;

/// The first-ride Health question offers "Nein" as the default when such an
/// app runs on this device.
bool healthDefaultsToNo(SupportedApp? app, Target? target) =>
    mayAlreadySaveToHealth(app) && target == Target.thisDevice;

/// Persisted state of ride recording: the automatic setting, the Health
/// answer, which ride the summary card shows, and the rider's FTP and max
/// heart rate for zones.
class RidePreferences extends ChangeNotifier {
  RidePreferences(this._prefs);

  final SharedPreferences _prefs;

  static const _autoRecordKey = 'rides_auto_record';

  /// Shared with the earlier "Save rides to Apple Health" toggle, so a rider
  /// who already said yes (or no) is not asked again.
  static const _saveToHealthKey = 'health_rides_enabled';
  static const _healthAnsweredKey = 'health_rides_prompt_dismissed';
  static const _summaryRideKey = 'rides_summary_card';
  static const _ftpKey = 'rides_ftp_watts';
  static const _maxHeartRateKey = 'rides_max_heart_rate_bpm';

  /// "Record rides automatically". On unless the rider turned it off.
  bool get autoRecord => _prefs.getBool(_autoRecordKey) ?? true;

  Future<void> setAutoRecord(bool enabled) async {
    await _prefs.setBool(_autoRecordKey, enabled);
    notifyListeners();
  }

  /// Every recorded ride goes to Apple Health / Health Connect; null while
  /// the rider has not answered.
  bool? get saveToHealth => _prefs.getBool(_saveToHealthKey);

  Future<void> setSaveToHealth(bool enabled) async {
    await _prefs.setBool(_saveToHealthKey, enabled);
    notifyListeners();
  }

  /// The first-ride question was answered (it is asked once).
  bool get healthQuestionAnswered => _prefs.getBool(_healthAnsweredKey) ?? false;

  Future<void> setHealthQuestionAnswered() async {
    await _prefs.setBool(_healthAnsweredKey, true);
    notifyListeners();
  }

  /// The ride the summary card on Ride shows (its file name), until the
  /// rider dismisses it or the next ride starts.
  String? get summaryRide => _prefs.getString(_summaryRideKey);

  Future<void> setSummaryRide(String? fileName) async {
    if (fileName == null) {
      await _prefs.remove(_summaryRideKey);
    } else {
      await _prefs.setString(_summaryRideKey, fileName);
    }
    notifyListeners();
  }

  /// Functional threshold power for power zones; null until the rider sets it.
  int? get ftpWatts => _prefs.getInt(_ftpKey);

  Future<void> setFtpWatts(int? watts) => _setOptionalInt(_ftpKey, watts);

  /// Max heart rate for heart rate zones; null until the rider sets it.
  int? get maxHeartRateBpm => _prefs.getInt(_maxHeartRateKey);

  Future<void> setMaxHeartRateBpm(int? bpm) => _setOptionalInt(_maxHeartRateKey, bpm);

  Future<void> _setOptionalInt(String key, int? value) async {
    if (value == null) {
      await _prefs.remove(key);
    } else {
      await _prefs.setInt(key, value);
    }
    notifyListeners();
  }
}
