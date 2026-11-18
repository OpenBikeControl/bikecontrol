/// Decides when to warn that today's button presses are running out, so the
/// limit never arrives as buttons that silently stop mid-ride.
///
/// Fires once per day, the first time the presses left drop to [threshold].
class CommandLimitHeadsUp {
  static const int threshold = 10;

  String? _warnedDay;

  /// [remaining] is `IAPManager.commandsRemainingToday`: -1 when unlimited.
  /// Zero is left to the limit-reached alert.
  bool shouldWarn({required int remaining, required DateTime now}) {
    if (remaining <= 0 || remaining > threshold) return false;
    final day = '${now.year}-${now.month}-${now.day}';
    if (_warnedDay == day) return false;
    _warnedDay = day;
    return true;
  }
}
