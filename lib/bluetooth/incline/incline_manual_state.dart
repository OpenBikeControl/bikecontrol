import 'package:flutter/foundation.dart';

enum InclineMode { auto, manual }

/// Manual incline range in 0.01% units (-10% .. +20%) — the UI bound for manual
/// nudging. Per-device WIRE clamps live in each device's encoder.
const int kInclineManualMinGrade001 = -1000;
const int kInclineManualMaxGrade001 = 2000;

/// Pure auto/manual state for an incline device. `auto` follows the sim grade;
/// `manual` holds a user-set incline. All values are 0.01% signed. Notifies on
/// every change so the incline UI follows a button press as well as a tap.
class InclineManualState extends ChangeNotifier {
  InclineMode mode = InclineMode.auto;
  int grade001 = 0;

  /// One button press moves the held incline by 1% (100 units).
  static const int stepGrade001 = 100;

  void increase() => _manualDelta(stepGrade001);
  void decrease() => _manualDelta(-stepGrade001);

  void zero() {
    mode = InclineMode.manual;
    grade001 = 0;
    notifyListeners();
  }

  void setAuto() {
    if (mode == InclineMode.auto) return;
    mode = InclineMode.auto;
    notifyListeners();
  }

  /// Holds [grade001Pct] by hand. Used when the rider leaves auto: the incline
  /// stays where the grade had put it instead of jumping to the old held value.
  void holdAt(int grade001Pct) {
    mode = InclineMode.manual;
    grade001 = grade001Pct.clamp(kInclineManualMinGrade001, kInclineManualMaxGrade001);
    notifyListeners();
  }

  void _manualDelta(int delta) {
    mode = InclineMode.manual;
    grade001 = (grade001 + delta).clamp(kInclineManualMinGrade001, kInclineManualMaxGrade001);
    notifyListeners();
  }
}
