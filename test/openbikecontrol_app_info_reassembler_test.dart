import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/openbikecontrol/app_info_reassembler.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/protocol_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A complete, valid app-info message. No buttons keeps the fixture
  // independent of the button-id table while still exercising appId/version.
  final complete = OpenBikeProtocolParser.encodeAppInfo(
    appId: 'TrainingPeaks',
    appVersion: '6.0',
    supportedButtons: [],
  );

  /// Split [data] into [count] roughly-equal fragments, mimicking an app that
  /// dribbles the app-info write across several BLE packets. Each strict prefix
  /// fails to parse, so feeding the fragments in order drives the reassembler.
  List<Uint8List> fragment(Uint8List data, int count) {
    final size = (data.length / count).ceil();
    return [
      for (var i = 0; i < data.length; i += size)
        Uint8List.sublistView(data, i, (i + size) > data.length ? data.length : i + size),
    ];
  }

  test('parses a complete single write immediately', () {
    final r = AppInfoReassembler();

    final info = r.offer(complete);

    expect(info, isNotNull);
    expect(info!.appId, 'TrainingPeaks');
    expect(info.appVersion, '6.0');
    expect(r.pendingFragments, 0, reason: 'buffer is cleared on success');
  });

  test('reassembles a message split across two writes', () {
    final parts = fragment(complete, 2);
    expect(parts.length, 2);
    final r = AppInfoReassembler();

    expect(r.offer(parts[0]), isNull, reason: 'first fragment is incomplete');
    expect(r.pendingFragments, 1);

    final info = r.offer(parts[1]);
    expect(info, isNotNull);
    expect(info!.appId, 'TrainingPeaks');
    expect(r.pendingFragments, 0);
  });

  test('reassembles a message split across THREE writes (single-buffer regression)', () {
    // The previous single prior-fragment buffer kept only the FIRST failed
    // fragment and dropped the middle one, so a three-packet app-info
    // (TrainingPeaks on macOS) never reconnected. Every fragment must be kept.
    final parts = fragment(complete, 3);
    expect(parts.length, 3);
    final r = AppInfoReassembler();

    expect(r.offer(parts[0]), isNull);
    expect(r.offer(parts[1]), isNull);
    expect(r.pendingFragments, 2, reason: 'every incomplete fragment is retained');

    final info = r.offer(parts[2]);
    expect(info, isNotNull, reason: 'all three fragments reassemble');
    expect(info!.appId, 'TrainingPeaks');
    expect(r.pendingFragments, 0);
  });

  test('resets after a success so the next message is not polluted by old fragments', () {
    final r = AppInfoReassembler();

    final first = fragment(complete, 2);
    expect(r.offer(first[0]), isNull);
    expect(r.offer(first[1]), isNotNull);

    // A different message reusing the same reassembler must parse cleanly.
    final second = OpenBikeProtocolParser.encodeAppInfo(
      appId: 'Rouvy',
      appVersion: '1.2',
      supportedButtons: [],
    );
    final secondParts = fragment(second, 2);
    expect(r.offer(secondParts[0]), isNull);

    final info = r.offer(secondParts[1]);
    expect(info, isNotNull);
    expect(info!.appId, 'Rouvy');
  });

  test('exposes the parse error while a message is incomplete', () {
    final r = AppInfoReassembler();

    expect(r.offer(fragment(complete, 2)[0]), isNull);
    expect(r.lastError, isA<ProtocolParseException>());
  });
}
