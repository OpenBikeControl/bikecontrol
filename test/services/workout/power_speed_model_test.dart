import 'dart:math' as math;

import 'package:bike_control/services/workout/power_speed_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Speed (km/h) at which [powerW] exactly balances the road forces.
double steadyKph(double powerW, double massKg, double gradePct) {
  const g = PowerSpeedModel.gravity;
  final theta = math.atan(gradePct / 100);
  double need(double v) =>
      (PowerSpeedModel.rollingResistance * massKg * g * math.cos(theta) +
          massKg * g * math.sin(theta) +
          0.5 * PowerSpeedModel.airDensity * PowerSpeedModel.dragArea * v * v) *
      v;
  var lo = 0.0, hi = 40.0;
  for (var i = 0; i < 100; i++) {
    final mid = (lo + hi) / 2;
    if (need(mid) < powerW * (1 - PowerSpeedModel.drivetrainLoss)) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return lo * 3.6;
}

double ride(PowerSpeedModel model, {required double powerW, double gradePct = 0, double massKg = 85, int seconds = 600}) {
  var kph = 0.0;
  for (var i = 0; i < seconds; i++) {
    kph = model.step(powerW: powerW, gradePct: gradePct, massKg: massKg, seconds: 1);
  }
  return kph;
}

void main() {
  test('settles at the speed where power balances rolling, gravity and air drag', () {
    expect(ride(PowerSpeedModel(), powerW: 200), closeTo(steadyKph(200, 85, 0), 0.1));
    expect(ride(PowerSpeedModel(), powerW: 300, gradePct: 5), closeTo(steadyKph(300, 85, 5), 0.1));
  });

  test('200 W on the flat lands in a realistic road-bike range', () {
    final kph = ride(PowerSpeedModel(), powerW: 200);
    expect(kph, inInclusiveRange(24, 32));
  });

  test('a heavier rider climbs slower at the same power', () {
    final light = ride(PowerSpeedModel(), powerW: 250, gradePct: 6, massKg: 70);
    final heavy = ride(PowerSpeedModel(), powerW: 250, gradePct: 6, massKg: 100);
    expect(heavy, lessThan(light));
  });

  test('freewheeling downhill speeds up, on the flat it slows down', () {
    final down = PowerSpeedModel();
    ride(down, powerW: 200);
    final before = down.speedKph;
    expect(ride(down, powerW: 0, gradePct: -6, seconds: 20), greaterThan(before));

    final flat = PowerSpeedModel();
    ride(flat, powerW: 200);
    expect(ride(flat, powerW: 0, seconds: 20), lessThan(before));
  });

  test('never goes backwards on a steep climb without power', () {
    final model = PowerSpeedModel();
    expect(ride(model, powerW: 0, gradePct: 15, seconds: 30), 0);
  });

  test('a long gap counts as at most two seconds', () {
    final a = PowerSpeedModel()..step(powerW: 300, gradePct: 0, massKg: 85, seconds: 60);
    final b = PowerSpeedModel()..step(powerW: 300, gradePct: 0, massKg: 85, seconds: 2);
    expect(a.speedKph, b.speedKph);
  });

  test('reset stops the bike', () {
    final model = PowerSpeedModel();
    ride(model, powerW: 200);
    model.reset();
    expect(model.speedKph, 0);
  });
}
