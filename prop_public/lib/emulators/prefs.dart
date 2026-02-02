//INFO: This is a stub - contact me if you need the full implementation.

import 'package:shared_preferences/shared_preferences.dart';

final propPrefs = PropPrefs();

class PropPrefs {
  late final SharedPreferences _prefs;

  void initialize(SharedPreferences prefs) {
    _prefs = prefs;
  }

  DateTime? getZwiftClickV2LastUnlock(String deviceId) {
    final key = 'clickV2_$deviceId';
    final timestamp = _prefs.getInt('${key}_unlock_date');
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  void setZwiftClickV2LastUnlock(String deviceId, DateTime dateTime) {
    final key = 'clickV2_$deviceId';
    _prefs.setInt("${key}_unlock_date", dateTime.millisecondsSinceEpoch);
  }
}
