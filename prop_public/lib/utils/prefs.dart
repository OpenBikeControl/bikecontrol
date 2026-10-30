//INFO: This is a stub - contact me if you need the full implementation.

import 'package:shared_preferences/shared_preferences.dart';

final propPrefs = PropPrefs();

class PropPrefs {
  late SharedPreferences _prefs;

  void initialize(SharedPreferences prefs) {
    _prefs = prefs;
  }

  DateTime? getZwiftClickV2LastUnlock(String deviceId, {String keyPrefix = 'clickV2'}) {
    final key = '${keyPrefix}_$deviceId';
    final timestamp = _prefs.getInt('${key}_unlock_date');
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  void setZwiftClickV2LastUnlock(String deviceId, DateTime dateTime, {String keyPrefix = 'clickV2'}) {
    final key = '${keyPrefix}_$deviceId';
    _prefs.setInt("${key}_unlock_date", dateTime.millisecondsSinceEpoch);
  }

  bool notSureIfUnlocked(String deviceId, {String keyPrefix = 'clickV2'}) {
    return _prefs.getBool('${keyPrefix}_${deviceId}_notSure') ?? false;
  }

  void setNotSureIfUnlocked(String deviceId, bool value, {String keyPrefix = 'clickV2'}) {
    _prefs.setBool('${keyPrefix}_${deviceId}_notSure', value);
  }
}
