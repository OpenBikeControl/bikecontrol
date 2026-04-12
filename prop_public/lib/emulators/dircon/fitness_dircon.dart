import 'package:prop/emulators/dircon/dircon.dart';

class FitnessDircon extends DirCon {
  /// Fitness Machine Service UUID (0x1826)
  static const String FITNESS_MACHINE_SERVICE_UUID = '00001826-0000-1000-8000-00805f9b34fb';

  /// Heart Rate Service UUID (0x180D)
  static const String HEART_RATE_SERVICE_UUID = '0000180d-0000-1000-8000-00805f9b34fb';

  /// Battery Service UUID (0x180F)
  static const String BATTERY_SERVICE_UUID = '0000180f-0000-1000-8000-00805f9b34fb';

  /// Cycling Power Service UUID (0x1818)
  static const String CYCLING_POWER_SERVICE_UUID = '00001818-0000-1000-8000-00805f9b34fb';

  FitnessDircon({required super.socket});
}
