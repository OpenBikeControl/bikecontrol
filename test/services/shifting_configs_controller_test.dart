import 'package:bike_control/models/shifting_config.dart';
import 'package:bike_control/services/shifting_configs_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  Future<ShiftingConfigsController> fresh() async {
    final prefs = await SharedPreferences.getInstance();
    final c = ShiftingConfigsController(prefs);
    await c.init();
    return c;
  }

  group('ShiftingConfigsController', () {
    test('starts empty when no storage is present', () async {
      final c = await fresh();
      expect(c.all, isEmpty);
    });

    test('activeFor returns a synthesised default when no config exists', () async {
      final c = await fresh();
      final active = c.activeFor('KICKR');
      expect(active.name, 'Default');
      expect(active.trainerKey, 'KICKR');
      expect(active.mode, VirtualShiftingMode.targetPower);
    });

    test('save persists and reload returns the saved config', () async {
      final c = await fresh();
      await c.upsert(
        ShiftingConfig.defaults(trainerKey: 'KICKR').copyWith(name: 'Race', bikeWeightKg: 8.2),
      );
      final prefs = await SharedPreferences.getInstance();
      final c2 = ShiftingConfigsController(prefs);
      await c2.init();
      final race = c2.configsFor('KICKR').firstWhere((e) => e.name == 'Race');
      expect(race.bikeWeightKg, 8.2);
    });

    test('setActive enforces at most one active per trainerKey', () async {
      final c = await fresh();
      await c.upsert(ShiftingConfig.defaults(trainerKey: 'KICKR').copyWith(name: 'A'));
      await c.upsert(ShiftingConfig.defaults(trainerKey: 'KICKR', isActive: false).copyWith(name: 'B'));
      await c.setActive(trainerKey: 'KICKR', name: 'B');
      final actives = c.configsFor('KICKR').where((e) => e.isActive).toList();
      expect(actives.length, 1);
      expect(actives.single.name, 'B');
    });

    test('remove prevents deleting the last config for a trainer', () async {
      final c = await fresh();
      await c.upsert(ShiftingConfig.defaults(trainerKey: 'KICKR'));
      expect(() => c.remove(trainerKey: 'KICKR', name: 'Default'), throwsStateError);
    });

    test('remove re-elects a successor active when active is removed', () async {
      final c = await fresh();
      await c.upsert(ShiftingConfig.defaults(trainerKey: 'KICKR').copyWith(name: 'A'));
      await c.upsert(ShiftingConfig.defaults(trainerKey: 'KICKR', isActive: false).copyWith(name: 'B'));
      await c.remove(trainerKey: 'KICKR', name: 'A');
      final remaining = c.configsFor('KICKR');
      expect(remaining.length, 1);
      expect(remaining.single.name, 'B');
      expect(remaining.single.isActive, true);
    });
  });
}
