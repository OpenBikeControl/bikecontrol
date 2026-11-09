import 'dart:typed_data';

/// One buzz: vibrate for [on] at [intensity] (0..1), then pause for [off].
class HapticPulse {
  const HapticPulse({required this.on, required this.intensity, this.off = Duration.zero});

  final Duration on;
  final double intensity;
  final Duration off;

  @override
  String toString() =>
      'HapticPulse(${on.inMilliseconds}ms @ ${intensity.toStringAsFixed(2)}, gap ${off.inMilliseconds}ms)';
}

/// An OpenBikeControl haptic feedback command
/// `[0x03, Pattern, Duration, Intensity]`, decoded into [pulses].
class ObcHapticCommand {
  const ObcHapticCommand._(this.pulses);

  /// Empty for the stop pattern (`0x00`).
  final List<HapticPulse> pulses;

  bool get isStop => pulses.isEmpty;

  static const int messageType = 0x03;

  /// Intensity used when the app sends `0x00` ("default").
  static const double defaultIntensity = 0.8;

  static const _maxTotal = Duration(milliseconds: 1000);

  /// Relative shape per pattern: (on ms, off ms, intensity factor) at the
  /// default length. A Duration byte rescales the whole shape.
  static const Map<int, List<(int, int, double)>> _shapes = {
    0x01: [(60, 0, 1)], // short
    0x02: [(60, 80, 1), (60, 0, 1)], // double
    0x03: [(60, 80, 1), (60, 80, 1), (60, 0, 1)], // triple
    0x04: [(400, 0, 1)], // long
    0x05: [(50, 60, 0.4), (60, 60, 0.7), (90, 0, 1)], // success: crescendo
    0x06: [(80, 80, 1), (80, 0, 1)], // warning: two short
    0x07: [(60, 60, 1), (60, 60, 1), (60, 0, 1)], // error: three short
  };

  /// Null when [data] isn't a haptic command or uses a reserved pattern.
  static ObcHapticCommand? parse(Uint8List data) {
    if (data.length < 4 || data[0] != messageType) return null;
    final pattern = data[1];
    if (pattern == 0x00) return const ObcHapticCommand._([]);
    final shape = _shapes[pattern];
    if (shape == null) return null;

    final intensity = data[3] == 0 ? defaultIntensity : data[3] / 255;
    final defaultTotal = shape.fold(0, (sum, s) => sum + s.$1 + s.$2);
    final requested = data[2] == 0 ? defaultTotal : data[2] * 10;
    final total = requested.clamp(1, _maxTotal.inMilliseconds);
    final scale = total / defaultTotal;

    Duration ms(int v) => Duration(milliseconds: (v * scale).round());
    return ObcHapticCommand._([
      for (final (on, off, factor) in shape)
        HapticPulse(on: ms(on), off: ms(off), intensity: (intensity * factor).clamp(0.0, 1.0)),
    ]);
  }
}
