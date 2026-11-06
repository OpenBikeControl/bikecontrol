// The daily virtual shifting trial: when it counts as over for a trainer, and
// when the rider gets a heads-up that it is about to end.
import 'package:bike_control/bluetooth/devices/proxy/vs_trial_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/dircon_emulator.dart' show RetrofitMode;

void main() {
  group('vsTrialOver', () {
    test('over once today\'s budget is used up, shifting through BikeControl without Pro', () {
      expect(vsTrialOver(mode: RetrofitMode.wifi, isPro: false, exhausted: true), isTrue);
      expect(vsTrialOver(mode: RetrofitMode.bluetooth, isPro: false, exhausted: true), isTrue);
    });

    test('not while budget is left', () {
      expect(vsTrialOver(mode: RetrofitMode.wifi, isPro: false, exhausted: false), isFalse);
    });

    test('never with Pro', () {
      expect(vsTrialOver(mode: RetrofitMode.wifi, isPro: true, exhausted: true), isFalse);
    });

    test('never when the trainer app does the shifting itself', () {
      expect(vsTrialOver(mode: RetrofitMode.proxy, isPro: false, exhausted: true), isFalse);
    });
  });

  group('vsTrialEndingSoon', () {
    test('warns once, with two minutes or less left', () {
      expect(vsTrialEndingSoon(remaining: const Duration(minutes: 2), alreadyWarned: false), isTrue);
      expect(vsTrialEndingSoon(remaining: const Duration(seconds: 30), alreadyWarned: false), isTrue);
    });

    test('not with more than two minutes left', () {
      expect(vsTrialEndingSoon(remaining: const Duration(minutes: 2, seconds: 1), alreadyWarned: false), isFalse);
    });

    test('not twice', () {
      expect(vsTrialEndingSoon(remaining: const Duration(minutes: 1), alreadyWarned: true), isFalse);
    });

    test('not once it is over: that has its own message', () {
      expect(vsTrialEndingSoon(remaining: Duration.zero, alreadyWarned: false), isFalse);
    });
  });

  group('trainerConnectGate', () {
    TrainerConnectGate gate({
      RetrofitMode mode = RetrofitMode.wifi,
      bool isPro = false,
      bool trialExpired = false,
      bool vsBudgetExhausted = false,
    }) => trainerConnectGate(
      mode: mode,
      isPro: isPro,
      trialExpired: trialExpired,
      vsBudgetExhausted: vsBudgetExhausted,
    );

    test('virtual shifting runs on the daily trial once the trial period is over', () {
      // Website build without Base, or a store build past its trial period.
      expect(gate(mode: RetrofitMode.wifi, trialExpired: true), TrainerConnectGate.allow);
      expect(gate(mode: RetrofitMode.bluetooth, trialExpired: true), TrainerConnectGate.allow);
    });

    test('virtual shifting within the trial period', () {
      expect(gate(mode: RetrofitMode.wifi), TrainerConnectGate.allow);
    });

    test('virtual shifting with Base bought but no Pro', () {
      // Base ends the trial period without being Pro: same daily trial.
      expect(gate(mode: RetrofitMode.wifi, trialExpired: false), TrainerConnectGate.allow);
      expect(gate(mode: RetrofitMode.wifi, vsBudgetExhausted: true), TrainerConnectGate.vsTrialOverToday);
    });

    test('virtual shifting once today\'s budget is used up', () {
      expect(gate(mode: RetrofitMode.wifi, vsBudgetExhausted: true), TrainerConnectGate.vsTrialOverToday);
      expect(
        gate(mode: RetrofitMode.bluetooth, trialExpired: true, vsBudgetExhausted: true),
        TrainerConnectGate.vsTrialOverToday,
      );
    });

    test('Pro connects in any mode', () {
      for (final mode in RetrofitMode.values) {
        expect(gate(mode: mode, isPro: true, trialExpired: true, vsBudgetExhausted: true), TrainerConnectGate.allow);
      }
    });

    test('proxy mode needs Pro once the trial period is over', () {
      expect(gate(mode: RetrofitMode.proxy, trialExpired: true), TrainerConnectGate.goPro);
      expect(gate(mode: RetrofitMode.proxy, trialExpired: true, vsBudgetExhausted: true), TrainerConnectGate.goPro);
    });

    test('proxy mode within the trial period ignores the virtual shifting budget', () {
      expect(gate(mode: RetrofitMode.proxy), TrainerConnectGate.allow);
      expect(gate(mode: RetrofitMode.proxy, vsBudgetExhausted: true), TrainerConnectGate.allow);
    });
  });
}
