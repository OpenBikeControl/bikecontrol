import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/openbikecontrol/protocol_parser.dart';
import 'package:dartx/dartx.dart';

/// Reassembles an OpenBikeControl app-info message that a central may split
/// across several BLE write packets (e.g. TrainingPeaks on macOS).
///
/// Feed each write payload to [offer]. It returns the parsed [AppInfo] once the
/// accumulated buffer parses successfully, or null while the message is still
/// incomplete — in which case the fragment is retained and prepended to the
/// next write.
///
/// Every incomplete fragment is accumulated. A single prior-fragment buffer
/// could only ever stitch TWO writes together (it kept the first failed
/// fragment and dropped the middle one), so a message split across three or
/// more packets never reassembled; this keeps all fragments until one parses.
class AppInfoReassembler {
  /// Upper bound on buffered bytes. A valid app-info is ~100 bytes (32B appId +
  /// 32B version + headers + a handful of button ids), so anything past this is
  /// a corrupt/stuck stream — drop the stale prefix instead of poisoning every
  /// future parse and growing without bound.
  static const int _maxBufferedBytes = 512;

  final List<Uint8List> _fragments = [];

  /// The error from the most recent incomplete [offer], for diagnostics/logging.
  Object? lastError;

  /// Fragments currently buffered awaiting completion.
  int get pendingFragments => _fragments.length;

  /// Drop any buffered fragments — call when the central disconnects so a
  /// half-sent message can't bleed into the next connection.
  void reset() {
    _fragments.clear();
    lastError = null;
  }

  /// Offer the next write payload. Returns the parsed [AppInfo] once the
  /// accumulated buffer parses, or null while still incomplete.
  AppInfo? offer(Uint8List value) {
    try {
      final appInfo = OpenBikeProtocolParser.parseAppInfo(
        Uint8List.fromList([..._fragments.flatten(), ...value]),
      );
      _fragments.clear();
      lastError = null;
      return appInfo;
    } catch (e) {
      lastError = e;
      _fragments.add(value);
      // Bound the buffer: once the accumulation can no longer be any valid
      // message, restart from this write so a stuck/corrupt stream recovers
      // (and can't leak memory).
      if (_fragments.fold<int>(0, (sum, f) => sum + f.length) > _maxBufferedBytes) {
        _fragments
          ..clear()
          ..add(value);
      }
      return null;
    }
  }
}
