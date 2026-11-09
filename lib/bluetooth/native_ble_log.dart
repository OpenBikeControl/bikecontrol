import 'package:bike_control/utils/host_platform.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/utils/shared.dart' show Logger;
import 'package:universal_ble/universal_ble.dart';

/// Puts universal_ble's native errors and warnings into BikeControl's log, so
/// a support bundle shows what the Bluetooth layer caught and survived (e.g.
/// a peripheral callback that used to end the app on Windows, GH #451).
/// Without this they only reach stdout, which a release Windows app has none
/// of.
///
/// The same message repeating within [window] is written once, then once
/// more with a count when it comes back after the window — a callback failing
/// on every notification must not flood the shared "Logs:" buffer.
class NativeBleLog {
  NativeBleLog({void Function(String line)? sink, DateTime Function()? clock, this.window = const Duration(seconds: 30)})
    : _sink = sink ?? Logger.event,
      _clock = clock ?? DateTime.now;

  final void Function(String line) _sink;
  final DateTime Function() _clock;
  final Duration window;

  /// message -> when it was last written, and how often it was held back since.
  final Map<String, ({DateTime at, int held})> _seen = {};

  /// Bounds [_seen]: native messages carry hresults and ids, so in theory
  /// unbounded variety.
  static const _maxTracked = 100;

  void handle(BleLogLevel level, String message) {
    final now = _clock();
    final last = _seen[message];
    if (last != null && now.difference(last.at) < window) {
      _seen[message] = (at: last.at, held: last.held + 1);
      return;
    }
    if (_seen.length >= _maxTracked && last == null) _seen.remove(_seen.keys.first);
    _seen[message] = (at: now, held: 0);
    final tag = level == BleLogLevel.error ? 'error' : 'warning';
    final repeated = (last?.held ?? 0) > 0 ? ' (+${last!.held} more since last logged)' : '';
    _sink('BLE native $tag: $message$repeated');
  }

  /// Installs the handler on Windows, the one platform whose native log has
  /// nowhere else to go. Main engine only: a second engine (the overlay
  /// window) would write the same lines into its own, unshipped log.
  static void install() {
    if (kIsWeb || !HostPlatform.isWindows) return;
    UniversalBle.nativeLogHandler = NativeBleLog().handle;
  }
}
