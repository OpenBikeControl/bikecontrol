import 'dart:convert';

import 'package:bike_control/services/overlay/desktop_overlay_window.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final payload = jsonEncode({'x': 120.0, 'y': 40.0, 'opacity': 0.4});

  test('Windows ordering: the payload comes first (argsJson < routeName < theme)', () {
    final r = decodeOverlayLaunchArgs([payload, 'trainer-overlay', 'dark']);
    expect(r.position, const Offset(120, 40));
    expect(r.opacity, 0.4);
  });

  test('macOS ordering: the payload comes last', () {
    final r = decodeOverlayLaunchArgs(['trainer-overlay', 'light', payload]);
    expect(r.position, const Offset(120, 40));
    expect(r.opacity, 0.4);
  });

  test('no saved position still carries the opacity', () {
    final r = decodeOverlayLaunchArgs([
      jsonEncode({'opacity': 0.6}),
      'trainer-overlay',
      'dark',
    ]);
    expect(r.position, isNull);
    expect(r.opacity, 0.6);
  });

  test('payload without opacity keeps the position', () {
    final r = decodeOverlayLaunchArgs([
      'trainer-overlay',
      jsonEncode({'x': 1, 'y': 2}),
      'dark',
    ]);
    expect(r.position, const Offset(1, 2));
    expect(r.opacity, isNull);
  });

  test('no payload decodes to nothing', () {
    final r = decodeOverlayLaunchArgs(['trainer-overlay', 'dark']);
    expect(r.position, isNull);
    expect(r.opacity, isNull);
  });

  test('a broken payload is skipped and a later valid one is used', () {
    final r = decodeOverlayLaunchArgs(['{not json', 'trainer-overlay', payload]);
    expect(r.position, const Offset(120, 40));
    expect(r.opacity, 0.4);
  });
}
