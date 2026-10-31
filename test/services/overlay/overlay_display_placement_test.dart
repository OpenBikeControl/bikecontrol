import 'package:bike_control/services/overlay/overlay_display_placement.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const laptop = Rect.fromLTWH(0, 25, 1512, 920);
  const external = Rect.fromLTWH(1512, 0, 2560, 1440);

  group('overlayPositionOnDisplays', () {
    test('leaves an overlay alone on a connected display', () {
      expect(
        overlayPositionOnDisplays(const Rect.fromLTWH(2000, 300, 200, 100), [laptop, external]),
        isNull,
      );
    });

    test('leaves an overlay alone that the rider can still grab at a screen edge', () {
      expect(
        overlayPositionOnDisplays(const Rect.fromLTWH(1400, 300, 200, 100), [laptop]),
        isNull,
      );
    });

    test('moves an overlay left on a removed display to the nearest edge of the remaining one', () {
      expect(
        overlayPositionOnDisplays(const Rect.fromLTWH(2000, 300, 200, 100), [laptop]),
        const Offset(1312, 300),
      );
    });

    test('moves an overlay with only a sliver left on screen fully back', () {
      expect(
        overlayPositionOnDisplays(const Rect.fromLTWH(1500, 300, 200, 100), [laptop]),
        const Offset(1312, 300),
      );
    });

    test('picks the closest of several remaining displays', () {
      const left = Rect.fromLTWH(-1920, 0, 1920, 1080);
      expect(
        overlayPositionOnDisplays(const Rect.fromLTWH(-3000, 300, 200, 100), [laptop, left]),
        const Offset(-1920, 300),
      );
    });

    test('keeps the top-left corner reachable when the display is smaller than the overlay', () {
      expect(
        overlayPositionOnDisplays(
          const Rect.fromLTWH(5000, 5000, 400, 300),
          [const Rect.fromLTWH(0, 0, 300, 200)],
        ),
        Offset.zero,
      );
    });

    test('does nothing when no display is reported', () {
      expect(overlayPositionOnDisplays(const Rect.fromLTWH(2000, 300, 200, 100), const []), isNull);
    });
  });

  group('OverlayDisplayWatcher', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    late List<Map<Object?, Object?>> setBoundsCalls;
    late List<Map<String, Object?>> displays;

    Map<String, Object?> display(Rect r) => {
      'id': '${r.left}',
      'name': 'display',
      'size': {'width': r.width, 'height': r.height},
      'visiblePosition': {'dx': r.left, 'dy': r.top},
      'visibleSize': {'width': r.width, 'height': r.height},
    };

    setUp(() {
      setBoundsCalls = [];
      displays = [display(laptop), display(external)];
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(const MethodChannel('window_manager'), (call) async {
        switch (call.method) {
          case 'getBounds':
            return {'x': 2000.0, 'y': 300.0, 'width': 200.0, 'height': 100.0};
          case 'setBounds':
            setBoundsCalls.add(call.arguments as Map<Object?, Object?>);
        }
        return null;
      });
      messenger.setMockMethodCallHandler(
        const MethodChannel('dev.leanflutter.plugins/screen_retriever'),
        (call) async => {'displays': displays},
      );
    });

    test('moves the overlay when its display is disconnected', () async {
      displays = [display(laptop)];

      await OverlayDisplayWatcher().ensureVisible();

      expect(setBoundsCalls, hasLength(1));
      expect(setBoundsCalls.single['x'], 1312.0);
      expect(setBoundsCalls.single['y'], 300.0);
    });

    test('does not move the overlay while its display is connected', () async {
      await OverlayDisplayWatcher().ensureVisible();

      expect(setBoundsCalls, isEmpty);
    });

    test('rechecks when the system reports a display change', () async {
      displays = [display(laptop)];

      OverlayDisplayWatcher().onScreenEvent('display-removed');
      await pumpEventQueue();

      expect(setBoundsCalls, hasLength(1));
    });
  });
}
