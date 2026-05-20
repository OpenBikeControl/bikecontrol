import 'package:bike_control/bluetooth/devices/zwift/emulator_registry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/dircon_emulator.dart';

void main() {
  setUp(() {
    EmulatorRegistry.instance.sharedTrainerEmulator.value = null;
  });

  test('resolveFor returns trainer when registered', () {
    final standalone = DirconEmulator();
    final trainer = DirconEmulator();
    EmulatorRegistry.instance.sharedTrainerEmulator.value = trainer;
    expect(
      EmulatorRegistry.instance.resolveFor(standalone: standalone),
      same(trainer),
    );
  });

  test('resolveFor returns standalone when no trainer is registered', () {
    final standalone = DirconEmulator();
    expect(
      EmulatorRegistry.instance.resolveFor(standalone: standalone),
      same(standalone),
    );
  });

  test('registry rebind: trainer arrival then departure resolves correctly', () {
    final standalone = DirconEmulator();
    final trainer = DirconEmulator();

    // Initially no trainer — resolves to standalone.
    expect(
      EmulatorRegistry.instance.resolveFor(standalone: standalone),
      same(standalone),
    );

    // Trainer connects.
    EmulatorRegistry.instance.sharedTrainerEmulator.value = trainer;
    expect(
      EmulatorRegistry.instance.resolveFor(standalone: standalone),
      same(trainer),
    );

    // Trainer disconnects.
    EmulatorRegistry.instance.sharedTrainerEmulator.value = null;
    expect(
      EmulatorRegistry.instance.resolveFor(standalone: standalone),
      same(standalone),
    );
  });

  test('registry listener fires when sharedTrainerEmulator changes', () {
    final trainer = DirconEmulator();
    final events = <DirconEmulator?>[];

    void listener() {
      events.add(EmulatorRegistry.instance.sharedTrainerEmulator.value);
    }

    EmulatorRegistry.instance.sharedTrainerEmulator.addListener(listener);

    EmulatorRegistry.instance.sharedTrainerEmulator.value = trainer;
    EmulatorRegistry.instance.sharedTrainerEmulator.value = null;

    EmulatorRegistry.instance.sharedTrainerEmulator.removeListener(listener);

    expect(events, [trainer, null]);
  });

  // The full ZwiftClickV2 flow requires UniversalBle/BLE plumbing that is
  // unavailable in `flutter test`. Cross-emulator rebind correctness is
  // exercised by the manual device verification checklist (Task 9).
}
