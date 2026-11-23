import 'package:bike_control/utils/keymap/apps/supported_app.dart';

import '../keymap.dart';

/// The Wahoo app ("Wahoo: Ride, Run, Train"; not SYSTM).
///
/// It takes no controller input, so BikeControl is a trainer to it and does
/// the virtual shifting itself. On the network it only lists trainers named
/// like Wahoo's own, so the bridge advertises under such a name while this app
/// is selected ([wahooAdvertisementNameFor]).
class WahooApp extends SupportedApp {
  @override
  List<(AppConnectionMethod, ConnectionSupport)> get connections => const [];

  @override
  String? get officialUrl => 'https://www.wahoofitness.com/wahoo-app';

  WahooApp()
    : super(
        name: 'Wahoo App',
        packageName: 'WahooApp',
        officialIntegration: false,
        keymap: Keymap(keyPairs: []),
      );

  /// "Wahoo KICKR" plus four or five hex digits: the trainer's own trailing
  /// identifier with a "B" (for Bridge) appended, or "BC" plus three digits
  /// derived from the trainer name. Stable per trainer, never the trainer's
  /// own name.
  static String wahooAdvertisementNameFor(String? trainerName) {
    final name = trainerName?.trim() ?? '';
    final tokens = name.split(RegExp(r'[\s_-]+')).where((t) => t.isNotEmpty).toList();
    final last = tokens.length > 1 ? tokens.last : null;
    String id;
    if (last != null && RegExp(r'^[0-9a-fA-F]{4}$').hasMatch(last)) {
      id = '${last.toUpperCase()}B';
    } else {
      // FNV-1a: String.hashCode isn't guaranteed stable across runs.
      var hash = 0x811c9dc5;
      for (final unit in name.codeUnits) {
        hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
      }
      id = 'BC${(hash & 0xFFF).toRadixString(16).toUpperCase().padLeft(3, '0')}';
    }
    final candidate = 'Wahoo KICKR $id';
    if (candidate.toLowerCase() != name.toLowerCase()) return candidate;
    // The trainer already carries this exact name; pick a neighbour.
    final bumped = (int.parse(id, radix: 16) + 1) & 0xFFFFF;
    return 'Wahoo KICKR ${bumped.toRadixString(16).toUpperCase().padLeft(5, '0')}';
  }
}
