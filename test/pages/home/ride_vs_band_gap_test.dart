// The gear numeral must not crowd the brand band above it. Barlow Condensed
// has almost no top bearing at display sizes and the numeral's line box is
// 0.8 em, so its ink can sit right under the band; these tests measure the
// painted ink, not the text box.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/home/virtual_shifting_card.dart';
import 'package:bike_control/widgets/ui/bk_skeleton.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../helpers/live_trainer.dart';
import '../../helpers/shell_harness.dart';
import 'package:golden_screenshot/golden_screenshot.dart';

import '../../widget_snapshot.dart';

/// The least room between the band's bottom edge and the top of the
/// numeral's ink.
const double _minGap = 24;

Future<void> main() async {
  await ensureSnapshotHarness();
  quietShellEnvironment();

  /// Band bottom → first painted row of the numeral (or its placeholder
  /// bone), in logical pixels.
  Future<double> bandToInk(WidgetTester tester) async {
    final number = find.byKey(const ValueKey('ride-vs-number')).first;
    final card = find.ancestor(of: number, matching: find.byType(VirtualShiftingCard)).first;
    final band = find.descendant(of: card, matching: find.byKey(const ValueKey('bk-brand-band-fill'))).first;
    final bandBottom = tester.getRect(band).bottom;
    final numberRect = tester.getRect(number);

    RenderObject? node = tester.renderObject(number);
    while (node != null && node is! RenderRepaintBoundary) {
      node = node.parent;
    }
    final boundary = node! as RenderRepaintBoundary;
    final origin = boundary.localToGlobal(Offset.zero);
    const ratio = 2.0;
    late Uint8List pixels;
    late int width;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: ratio);
      width = image.width;
      pixels = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
      image.dispose();
    });
    int at(int x, int y, int c) => pixels[(y * width + x) * 4 + c];

    // The card's own fill, just under the band at the numeral's left edge.
    final x0 = ((numberRect.left - origin.dx) * ratio).round();
    final x1 = ((numberRect.right - origin.dx) * ratio).round();
    final yBand = ((bandBottom - origin.dy) * ratio).round();
    final yEnd = ((numberRect.bottom - origin.dy) * ratio).round();
    final bg = [for (var c = 0; c < 3; c++) at(x0, yBand + 2, c)];
    for (var y = yBand + 2; y < yEnd; y++) {
      for (var x = x0; x < x1; x++) {
        var diff = 0;
        for (var c = 0; c < 3; c++) {
          diff += (at(x, y, c) - bg[c]).abs();
        }
        if (diff > 24) return y / ratio + origin.dy - bandBottom;
      }
    }
    fail('no numeral ink found under the band');
  }

  Future<void> pumpRide(WidgetTester tester, Size size, Brightness brightness) async {
    attachLiveTrainer();
    core.connection.hasDevices.value = true;
    await pumpShell(tester, size, brightness: brightness);
    await tester.loadAssets(alsoLoadTheseFonts: const [BkNumerals.family]);
    await tester.binding.reassembleApplication();
    await tester.pump(const Duration(seconds: 1));
  }

  for (final brightness in Brightness.values) {
    for (final size in const [Size(390, 844), Size(1180, 820)]) {
      testWidgets('Ride ${size.width.toInt()}x${size.height.toInt()} (${brightness.name}): '
          'the numeral sits >= $_minGap below the band', (tester) async {
        await pumpRide(tester, size, brightness);
        expect(await bandToInk(tester), greaterThanOrEqualTo(_minGap));
        await disposeShell(tester);
      });
    }
  }

  for (final layout in VsCardLayout.values) {
    final width = layout == VsCardLayout.stacked ? 380.0 : 358.0;
    Future<void> pumpCard(WidgetTester tester, Widget card) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width + 32, 900);
      addTearDown(tester.view.reset);
      final app = ShadcnApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        theme: snapshotTheme(Brightness.light),
        home: Align(
          alignment: Alignment.topCenter,
          child: RepaintBoundary(
            child: SizedBox(width: width, child: card),
          ),
        ),
      );
      await tester.pumpWidget(app);
      await tester.loadAssets(alsoLoadTheseFonts: const [BkNumerals.family]);
      await remountWithLoadedFonts(tester, app);
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('${layout.name} ERG: the target sits >= $_minGap below the band', (tester) async {
      final trainer = attachLiveTrainer(register: false);
      trainer.definition.setManualErgPower(250);
      await pumpCard(
        tester,
        VirtualShiftingCard(definition: trainer.definition, trainerName: 'KICKR CORE', layout: layout),
      );
      expect(trainer.definition.trainerMode.value, TrainerMode.ergMode);
      expect(await bandToInk(tester), greaterThanOrEqualTo(_minGap));
    });

    testWidgets('${layout.name} connecting: the placeholder sits >= $_minGap below the band', (tester) async {
      await pumpCard(tester, VirtualShiftingCard.connecting(trainerName: 'KICKR CORE', layout: layout));
      final number = find.byKey(const ValueKey('ride-vs-number'));
      final band = find.byKey(const ValueKey('bk-brand-band-fill'));
      final bone = find.descendant(of: number, matching: find.byType(BkBone));
      expect(tester.getRect(bone).top - tester.getRect(band).bottom, greaterThanOrEqualTo(_minGap));
    });
  }
}
