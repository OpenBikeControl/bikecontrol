import 'package:flutter/src/foundation/change_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BridgeUsageTracker {
  final SharedPreferences prefs;
  final Duration dailyLimit;

  BridgeUsageTracker({required this.prefs, required this.dailyLimit});

  ValueListenable<Duration> get usedTodayListenable => ValueNotifier(dailyLimit);

  /// Time used by bridge sessions today.
  Duration get usedToday => Duration.zero;

  /// How much of today's budget is left.
  Duration get remainingToday => dailyLimit;

  bool get isExhausted => false;

  bool get isCountingDown => false;

  get onBudgetExhausted => null;

  void startSession({required bool Function() isActive}) {}

  void stopSession() {}
}
