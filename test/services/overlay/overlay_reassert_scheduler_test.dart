import 'package:bike_control/services/overlay/overlay_reassert_scheduler.dart';
import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/services/overlay/trainer_overlay_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';

/// Records `reassert()` calls and lets the test drive `isShowing`.
class _FakeController implements TrainerOverlayController {
  int reasserts = 0;
  final ValueNotifier<bool> _showing = ValueNotifier(true);
  set showing(bool v) => _showing.value = v;

  @override
  ValueListenable<bool> get isShowing => _showing;

  @override
  Future<void> reassert() async => reasserts++;

  @override
  Future<OverlayShowResult> show(FitnessBikeDefinition def, Set<OverlayField> fields,
          {LiveDefinition? liveDef}) async =>
      const OverlayShowResult.ok();
  @override
  Future<void> hide() async {}
  @override
  void updateFields(Set<OverlayField> fields) {}
  @override
  void updateOpacity(double opacity) {}
}

void main() {
  const debounce = Duration(milliseconds: 20);
  // Comfortably past the debounce so the trailing timer has fired.
  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 60));

  late _FakeController controller;
  late ValueNotifier<bool> connected;
  bool enabled = true;
  OverlayReassertScheduler make() => OverlayReassertScheduler(
        controller,
        isEnabled: () => enabled,
        debounce: debounce,
      );

  setUp(() {
    controller = _FakeController();
    connected = ValueNotifier(false);
    enabled = true;
  });

  test('re-tops on the false→true edge when enabled and showing', () async {
    make().watch(connected);

    connected.value = true; // trainer app connected

    await settle();
    expect(controller.reasserts, 1);
  });

  test('does nothing on the true→false edge', () async {
    connected.value = true;
    final s = make()..watch(connected); // start already-connected: last=true

    connected.value = false; // trainer app dropped

    await settle();
    expect(controller.reasserts, 0);
    s.dispose();
  });

  test('collapses a flapping reconnect into a single re-top', () async {
    make().watch(connected);

    // Rapid connect/disconnect/connect within one debounce window.
    connected.value = true;
    connected.value = false;
    connected.value = true;

    await settle();
    expect(controller.reasserts, 1);
  });

  test('skips the re-top while the overlay is turned off', () async {
    enabled = false;
    make().watch(connected);

    connected.value = true;

    await settle();
    expect(controller.reasserts, 0);
  });

  test('skips the re-top when the overlay is not currently showing', () async {
    controller.showing = false;
    make().watch(connected);

    connected.value = true;

    await settle();
    expect(controller.reasserts, 0);
  });

  test('re-tops again on a later reconnect once the first has settled', () async {
    make().watch(connected);

    connected.value = true;
    await settle();
    connected.value = false;
    connected.value = true;
    await settle();

    expect(controller.reasserts, 2);
  });

  test('a second trainer connecting also triggers a re-top', () async {
    final second = ValueNotifier(false);
    make()
      ..watch(connected)
      ..watch(second);

    second.value = true;

    await settle();
    expect(controller.reasserts, 1);
  });

  test('watch is idempotent per listenable', () async {
    final s = make()
      ..watch(connected)
      ..watch(connected); // second watch must not double-fire

    connected.value = true;

    await settle();
    expect(controller.reasserts, 1);
    s.dispose();
  });

  test('a pending re-top does not fire after dispose', () async {
    final s = make()..watch(connected);

    connected.value = true; // schedules the debounced re-top
    s.dispose(); // ...but we tear down before it fires

    await settle();
    expect(controller.reasserts, 0);
  });

  test('dispose stops watching for further edges', () async {
    final s = make()..watch(connected);
    s.dispose();

    connected.value = true;

    await settle();
    expect(controller.reasserts, 0);
  });
}
