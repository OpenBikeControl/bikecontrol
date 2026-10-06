import 'package:bike_control/services/rides/ride_zones.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('power zones (Coggan, % of FTP)', () {
    test('each edge belongs to the lower zone', () {
      // FTP 200: 55 % = 110 W, 75 % = 150, 90 % = 180, 105 % = 210,
      // 120 % = 240, 150 % = 300.
      final seconds = powerZoneSeconds({
        0: 1,
        110: 2,
        111: 3, // 55.5 % rounds to 56: Endurance
        150: 4,
        151: 5,
        180: 6,
        210: 7,
        240: 8,
        300: 9,
        301: 10,
      }, ftpWatts: 200);
      expect(seconds, [3, 3 + 4, 5 + 6, 7, 8, 9, 10]);
    });

    test('seven zones, all empty without power', () {
      expect(powerZoneSeconds({}, ftpWatts: 250), List.filled(7, 0));
      expect(PowerZone.values, hasLength(7));
    });
  });

  group('heart rate zones (% of max)', () {
    test('five zones from 50 %; below that is in none', () {
      // Max 200: 50 % = 100, 60 % = 120, 70 % = 140, 80 % = 160, 90 % = 180.
      final seconds = heartRateZoneSeconds({
        90: 100,
        100: 1,
        120: 2,
        121: 3,
        140: 4,
        160: 5,
        180: 6,
        181: 7,
        205: 8,
      }, maxHeartRateBpm: 200);
      expect(seconds, [1 + 2, 3 + 4, 5, 6, 7 + 8]);
      expect(HeartRateZone.values, hasLength(5));
    });
  });
}
