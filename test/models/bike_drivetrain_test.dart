import 'package:bike_control/models/bike_drivetrain.dart';
import 'package:bike_control/models/shifting_config.dart';
import 'package:bike_control/pages/proxy_device_details/drivetrain_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = ShiftingConfig.defaults(trainerKey: 'kickr');

  CassetteOption cassette(String id) => cassettes.firstWhere((c) => c.id == id);

  group('ratios', () {
    test('1× 42 on an 11-speed 11-34: eleven gears, easiest first, no front shift', () {
      final d = BikeDrivetrain.tryCreate([42], cassette('shimano-11-11-34').cogs)!;
      expect(d.isDouble, isFalse);
      expect(d.ratios.length, 11);
      expect(d.ratios.first, closeTo(42 / 34, 1e-9));
      expect(d.ratios.last, closeTo(42 / 11, 1e-9));
      for (var i = 1; i < d.ratios.length; i++) {
        expect(d.ratios[i], greaterThan(d.ratios[i - 1]));
      }

      final cfg = d.applyTo(base.copyWith(smallChainringTeeth: 36, largeChainringTeeth: 52, frontShiftEnabled: true));
      expect(cfg.maxGear, 11);
      expect(cfg.gearRatios, d.ratios);
      expect(cfg.frontShiftEnabled, isFalse);
      // A 1× crank does not touch the virtual front derailleur's rings.
      expect(cfg.smallChainringTeeth, 36);
      expect(cfg.largeChainringTeeth, 52);
      expect(cfg.bikeDrivetrain, d);
    });

    test('2× 50/34 on a 12-speed 11-34: small-ring ratios, the big ring lands on 50/cog', () {
      final cogs = cassette('shimano-12-11-34').cogs;
      final d = BikeDrivetrain.tryCreate([50, 34], cogs)!;
      expect(d.isDouble, isTrue);
      final cfg = d.applyTo(base);
      expect(cfg.maxGear, 12);
      expect(cfg.frontShiftEnabled, isTrue);
      expect(cfg.smallChainringTeeth, 34);
      expect(cfg.largeChainringTeeth, 50);
      final descending = cogs.reversed.toList();
      for (var i = 0; i < 12; i++) {
        expect(cfg.gearRatios![i], closeTo(34 / descending[i], 1e-9));
        // FitnessBikeDefinition's big ring multiplies by large / small.
        expect(cfg.gearRatios![i] * 50 / 34, closeTo(50 / descending[i], 1e-9));
      }
    });

    test('chainrings are accepted in either order', () {
      final a = BikeDrivetrain.tryCreate([34, 50], [11, 12, 13])!;
      expect(a.chainrings, [50, 34]);
      expect(a, BikeDrivetrain.tryCreate([50, 34], [13, 12, 11]));
    });

    test('SRAM 10-33 and Campagnolo 11-29', () {
      final sram = BikeDrivetrain.tryCreate([48, 35], cassette('sram-12-10-33').cogs)!;
      expect(sram.ratios.length, 12);
      expect(sram.ratios.first, closeTo(35 / 33, 1e-9));
      expect(sram.ratios.last, closeTo(35 / 10, 1e-9));
      final campa = BikeDrivetrain.tryCreate([53, 39], cassette('campagnolo-12-11-29').cogs)!;
      expect(campa.ratios.first, closeTo(39 / 29, 1e-9));
      expect(campa.ratios.last, closeTo(39 / 11, 1e-9));
    });
  });

  group('custom cogs', () {
    test('parses any separator, sorts and drops duplicates', () {
      expect(BikeDrivetrain.parseCogs('34-11,12 13 13'), [11, 12, 13, 34]);
      expect(BikeDrivetrain.parseCogs(' 11 – 28 '), [11, 28]);
    });

    test('nothing usable is null', () {
      expect(BikeDrivetrain.parseCogs(''), isNull);
      expect(BikeDrivetrain.parseCogs('abc'), isNull);
      expect(BikeDrivetrain.parseCogs('11-x-28'), isNull);
    });
  });

  group('limits', () {
    test('1 to 30 cogs', () {
      expect(BikeDrivetrain.tryCreate([42], []), isNull);
      expect(BikeDrivetrain.tryCreate([42], [17]), isNotNull);
      expect(BikeDrivetrain.tryCreate([42], List.generate(30, (i) => 10 + i)), isNotNull);
      expect(BikeDrivetrain.tryCreate([42], List.generate(31, (i) => 10 + i)), isNull);
    });

    test('chainrings 20 to 60 teeth', () {
      expect(BikeDrivetrain.tryCreate([19], [17]), isNull);
      expect(BikeDrivetrain.tryCreate([61], [17]), isNull);
      expect(BikeDrivetrain.tryCreate([20], [17]), isNotNull);
      expect(BikeDrivetrain.tryCreate([60, 20], [17]), isNotNull);
      expect(BikeDrivetrain.tryCreate([61, 34], [17]), isNull);
    });

    test('cogs 9 to 52 teeth', () {
      expect(BikeDrivetrain.tryCreate([42], [8, 17]), isNull);
      expect(BikeDrivetrain.tryCreate([42], [17, 53]), isNull);
      expect(BikeDrivetrain.tryCreate([42], [9, 52]), isNotNull);
    });

    test('a double needs two different rings, and no more than two', () {
      expect(BikeDrivetrain.tryCreate([34, 34], [17]), isNull);
      expect(BikeDrivetrain.tryCreate([50, 39, 30], [17]), isNull);
      expect(BikeDrivetrain.tryCreate([], [17]), isNull);
    });
  });

  group('json', () {
    test('round trip through ShiftingConfig', () {
      final d = BikeDrivetrain.tryCreate([50, 34], cassette('shimano-12-11-34').cogs)!;
      final cfg = d.applyTo(base);
      final back = ShiftingConfig.fromJson(cfg.toJson());
      expect(back.bikeDrivetrain, d);
      expect(back, cfg);
    });

    test('without one, and with a broken one, it is null', () {
      expect(ShiftingConfig.fromJson(base.toJson()).bikeDrivetrain, isNull);
      expect(base.toJson().containsKey('bikeDrivetrain'), isFalse);
      final json = base.toJson()..['bikeDrivetrain'] = {'chainrings': [70], 'cogs': [11]};
      expect(ShiftingConfig.fromJson(json).bikeDrivetrain, isNull);
      final junk = base.toJson()..['bikeDrivetrain'] = 'x';
      expect(ShiftingConfig.fromJson(junk).bikeDrivetrain, isNull);
    });

    test('copyWith keeps or clears it', () {
      final cfg = BikeDrivetrain.tryCreate([42], [11, 13, 15])!.applyTo(base);
      expect(cfg.copyWith(gradeSmoothing: false).bikeDrivetrain, cfg.bikeDrivetrain);
      expect(cfg.copyWith(clearBikeDrivetrain: true).bikeDrivetrain, isNull);
    });
  });

  group('matches', () {
    test('the curve it made, and not once a gear was edited', () {
      final d = BikeDrivetrain.tryCreate([50, 34], cassette('shimano-12-11-30').cogs)!;
      final ratios = List<double>.of(d.ratios);
      expect(d.matches(ratios), isTrue);
      ratios[3] += 0.05;
      expect(d.matches(ratios), isFalse);
      expect(d.matches(ratios.sublist(1)), isFalse);
    });
  });

  group('catalog', () {
    test('every entry is valid and has as many cogs as its speeds', () {
      for (final c in cassettes) {
        expect(c.cogs.length, c.speeds, reason: c.id);
        expect(BikeDrivetrain.tryCreate([42], c.cogs), isNotNull, reason: c.id);
        expect(List.of(c.cogs)..sort(), c.cogs, reason: '${c.id} ascending');
        expect(c.cogs.toSet().length, c.cogs.length, reason: '${c.id} unique');
      }
      for (final k in cranksets) {
        expect(BikeDrivetrain.tryCreate(k.chainrings, [17]), isNotNull, reason: k.label);
      }
      expect(cassettes.map((c) => c.id).toSet().length, cassettes.length);
    });
  });
}
