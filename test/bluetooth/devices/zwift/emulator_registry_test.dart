import 'package:bike_control/bluetooth/devices/zwift/emulator_registry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/dircon_emulator.dart';

void main() {
  setUp(() {
    EmulatorRegistry.instance.sharedTrainerEmulator.value = null;
  });

  test('resolveFor returns the standalone when no trainer is registered', () {
    final standalone = DirconEmulator();
    expect(
      EmulatorRegistry.instance.resolveFor(standalone: standalone),
      same(standalone),
    );
  });

  test('resolveFor returns the trainer when one is registered', () {
    final standalone = DirconEmulator();
    final trainer = DirconEmulator();
    EmulatorRegistry.instance.sharedTrainerEmulator.value = trainer;

    expect(
      EmulatorRegistry.instance.resolveFor(standalone: standalone),
      same(trainer),
    );
  });

  test('clearing sharedTrainerEmulator falls back to standalone', () {
    final standalone = DirconEmulator();
    final trainer = DirconEmulator();
    EmulatorRegistry.instance.sharedTrainerEmulator.value = trainer;
    EmulatorRegistry.instance.sharedTrainerEmulator.value = null;

    expect(
      EmulatorRegistry.instance.resolveFor(standalone: standalone),
      same(standalone),
    );
  });

  test('sharedTrainerEmulator is observable', () {
    final trainer = DirconEmulator();
    final observed = <DirconEmulator?>[];
    void listener() =>
        observed.add(EmulatorRegistry.instance.sharedTrainerEmulator.value);
    EmulatorRegistry.instance.sharedTrainerEmulator.addListener(listener);

    EmulatorRegistry.instance.sharedTrainerEmulator.value = trainer;
    EmulatorRegistry.instance.sharedTrainerEmulator.value = null;

    EmulatorRegistry.instance.sharedTrainerEmulator.removeListener(listener);
    expect(observed, [trainer, null]);
  });
}
