// A support screenshot taken from a page pushed over Home (a device page, the
// setup wizard) shows that page, not Home underneath it.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bike_control/services/overview_screenshot.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../widget_snapshot.dart';

const _home = Color(0xFFD02020);
const _pushed = Color(0xFF2040D0);

Future<Color> _centerPixel(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final x = image.width ~/ 2;
  final y = image.height ~/ 2;
  final i = (y * image.width + x) * 4;
  final color = Color.fromARGB(data.getUint8(i + 3), data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2));
  image.dispose();
  return color;
}

Future<void> main() async {
  await ensureSnapshotHarness();

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(300, 600);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ShadcnApp(
        debugShowCheckedModeBanner: false,
        home: ScreenshotScaffold(
          headers: const [],
          child: const ColoredBox(color: _home, child: SizedBox.expand(key: ValueKey('home'))),
        ),
      ),
    );
    await tester.pump();
  }

  Future<Color> capture(WidgetTester tester, BuildContext context) async {
    late Color color;
    await tester.runAsync(() async {
      final attachment = await captureCurrentScreenScreenshot(context);
      expect(attachment, isNotNull);
      color = await _centerPixel(attachment!.file.bytes!);
    });
    return color;
  }

  testWidgets('on Home it captures Home', (tester) async {
    await pumpApp(tester);
    final color = await capture(tester, tester.element(find.byKey(const ValueKey('home'))));
    expect(color, _home);
  });

  testWidgets('on a pushed page it captures that page, not Home', (tester) async {
    await pumpApp(tester);
    Navigator.of(tester.element(find.byKey(const ValueKey('home')))).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => const ColoredBox(color: _pushed, child: SizedBox.expand(key: ValueKey('pushed'))),
      ),
    );
    await tester.pumpAndSettle();
    final color = await capture(tester, tester.element(find.byKey(const ValueKey('pushed'))));
    expect(color, _pushed);
  });
}
