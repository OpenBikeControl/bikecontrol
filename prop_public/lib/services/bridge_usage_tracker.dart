import 'package:flutter/src/foundation/change_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BridgeUsageTracker {
  final SharedPreferences prefs;
  final Duration dailyLimit;

  BridgeUsageTracker({required this.prefs, required this.dailyLimit});

  ValueListenable<Duration> get usedTodayListenable => ValueNotifier(dailyLimit);

  bool get isExhausted => false;

  get onBudgetExhausted => null;

  void startSession({required bool Function() isActive}) {}

  void stopSession() {}
}
