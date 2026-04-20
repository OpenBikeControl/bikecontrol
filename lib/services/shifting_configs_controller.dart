import 'dart:async';
import 'dart:convert';

import 'package:bike_control/models/shifting_config.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShiftingConfigsController extends ChangeNotifier {
  static const String storageKey = 'shifting_configs';

  final SharedPreferences _prefs;
  final List<ShiftingConfig> _configs = [];

  ShiftingConfigsController(this._prefs);

  List<ShiftingConfig> get all => List.unmodifiable(_configs);

  List<ShiftingConfig> configsFor(String trainerKey) =>
      _configs.where((c) => c.trainerKey == trainerKey).toList(growable: false);

  ShiftingConfig activeFor(String trainerKey) {
    final forTrainer = configsFor(trainerKey);
    final active = forTrainer.where((c) => c.isActive);
    if (active.isNotEmpty) return active.first;
    if (forTrainer.isNotEmpty) return forTrainer.first;
    return ShiftingConfig.defaults(trainerKey: trainerKey);
  }

  Future<void> init() async {
    _configs
      ..clear()
      ..addAll(_readStored());
  }

  Future<void> upsert(ShiftingConfig config) async {
    final idx = _configs.indexWhere(
      (c) => c.trainerKey == config.trainerKey && c.name == config.name,
    );
    if (idx >= 0) {
      _configs[idx] = config;
    } else {
      _configs.add(config);
    }
    if (config.isActive) {
      _enforceSingleActive(config.trainerKey, config.name);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> setActive({required String trainerKey, required String name}) async {
    for (var i = 0; i < _configs.length; i++) {
      final c = _configs[i];
      if (c.trainerKey != trainerKey) continue;
      _configs[i] = c.copyWith(isActive: c.name == name);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> remove({required String trainerKey, required String name}) async {
    final forTrainer = configsFor(trainerKey);
    if (forTrainer.length <= 1) {
      throw StateError('Cannot remove the last ShiftingConfig for trainer "$trainerKey"');
    }
    final removedWasActive = forTrainer.firstWhere((c) => c.name == name).isActive;
    _configs.removeWhere((c) => c.trainerKey == trainerKey && c.name == name);
    if (removedWasActive) {
      final survivors = configsFor(trainerKey);
      if (survivors.isNotEmpty) {
        final idx = _configs.indexOf(survivors.first);
        _configs[idx] = survivors.first.copyWith(isActive: true);
      }
    }
    await _persist();
    notifyListeners();
  }

  Future<void> rename({required String trainerKey, required String from, required String to}) async {
    final idx = _configs.indexWhere((c) => c.trainerKey == trainerKey && c.name == from);
    if (idx < 0) return;
    _configs[idx] = _configs[idx].copyWith(name: to);
    await _persist();
    notifyListeners();
  }

  Future<void> duplicate({required String trainerKey, required String sourceName, required String newName}) async {
    final source = _configs.firstWhere(
      (c) => c.trainerKey == trainerKey && c.name == sourceName,
      orElse: () => ShiftingConfig.defaults(trainerKey: trainerKey),
    );
    await upsert(source.copyWith(name: newName, isActive: false));
  }

  /// Replace the in-memory list from a synced payload and persist locally.
  Future<void> hydrateFromSync(List<ShiftingConfig> configs) async {
    _configs
      ..clear()
      ..addAll(configs);
    await _persist();
    notifyListeners();
  }

  /// Returns the current list as a JSON-encoded string, suitable for `UserSettings`.
  String toStoredJson() => jsonEncode(_configs.map((c) => c.toJson()).toList());

  /// Parses a JSON-encoded list produced by [toStoredJson].
  static List<ShiftingConfig> parseStoredJson(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(ShiftingConfig.fromJson)
        .toList(growable: false);
  }

  void _enforceSingleActive(String trainerKey, String activeName) {
    for (var i = 0; i < _configs.length; i++) {
      final c = _configs[i];
      if (c.trainerKey != trainerKey) continue;
      final shouldBeActive = c.name == activeName;
      if (c.isActive != shouldBeActive) {
        _configs[i] = c.copyWith(isActive: shouldBeActive);
      }
    }
  }

  List<ShiftingConfig> _readStored() {
    final raw = _prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      return parseStoredJson(raw);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _persist() async {
    await _prefs.setString(storageKey, toStoredJson());
  }
}
