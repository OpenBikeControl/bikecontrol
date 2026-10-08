// The desktop overlay window is as wide as what it shows: the gear (or ERG
// target), the mode over the readings the rider turned on, and the drag
// handle at the edge — no room kept for readings that are off. Each reading
// keeps room for its widest value (four-digit watts, three-digit rpm), so the
// window doesn't change while the numbers do; it changes when a reading is
// turned on or off.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/widgets/overlay/overlay_app.dart';
import 'package:bike_control/widgets/overlay/overlay_window_fit.dart';
import 'package:bike_control/widgets/overlay/trainer_overlay_view.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart' show ScreenshotTester;
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  TrainerOverlayState state(
    Set<OverlayField> fields, {
    TrainerMode mode = TrainerMode.simMode,
    int? power = 0,
    int? cadence = 0,
    double ratio = 1.0,
    bool frontShift = false,
  }) => TrainerOverlayState(
    gear: 11,
    maxGear: 24,
    gearRatio: ratio,
    mode: mode,
    powerW: power,
    cadenceRpm: cadence,
    ergTargetW: 250,
    fields: fields,
    frontShiftEnabled: frontShift,
  );

  // The desktop window: mouse-sized −/+ and no phone scaling.
  final desktop = TargetPlatformVariant.only(TargetPlatform.macOS);

  const combos = <String, Set<OverlayField>>{
    'power + cadence': {OverlayField.power, OverlayField.cadence},
    'power only': {OverlayField.power},
    'nothing but the gear': {},
    'power, cadence, ratio': {OverlayField.power, OverlayField.cadence, OverlayField.gearRatio},
    'controls + power + cadence': {OverlayField.controls, OverlayField.power, OverlayField.cadence},
  };

  /// Pumps the overlay as the desktop window shows it, at the width it asks
  /// for; returns that size.
  Future<Size> pumpFitted(WidgetTester tester, TrainerOverlayState s, {Size? at}) async {
    final notifier = ValueNotifier(s);
    Size? fitted;
    Widget app() => OverlayShadcnApp(
      home: Builder(
        builder: (context) {
          fitted = at ?? TrainerOverlayView.fitWindowSizeOf(context, s);
          return Scaffold(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox.fromSize(
                size: fitted,
                child: TrainerOverlayView(
                  state: notifier,
                  onModeToggle: () {},
                  onDragStart: () {},
                  onPrimaryDecrement: () {},
                  onPrimaryIncrement: () {},
                ),
              ),
            ),
          );
        },
      ),
    );
    await tester.pumpWidget(app());
    await tester.loadAssets(alsoLoadTheseFonts: const ['BarlowCondensed']);
    await remountWithLoadedFonts(tester, app());
    await tester.pump();
    return fitted!;
  }

  /// The empty room between the end of the side column (the mode pill and
  /// the readings) and the drag handle's slot.
  double slack(WidgetTester tester) {
    final view = find.byType(TrainerOverlayView);
    // Icons are text too; the handle's own glyph isn't content.
    final icons = find.descendant(of: view, matching: find.byType(Icon));
    final glyphs = find.descendant(of: icons, matching: find.byType(RichText)).evaluate().toSet();
    final texts = find
        .descendant(of: view, matching: find.byType(RichText))
        .evaluate()
        .where((e) => !glyphs.contains(e))
        .map((e) {
          final box = e.renderObject! as RenderBox;
          return box.localToGlobal(Offset.zero).dx + box.size.width;
        });
    final contentEnd = texts.reduce((a, b) => a > b ? a : b);
    final handle = tester.getRect(find.byIcon(LucideIcons.gripVertical));
    // The handle's 16 px slot is centred on its 14 px icon, after a 6 px gap.
    return handle.center.dx - 8 - 6 - contentEnd;
  }

  setUp(() async {
    await AppLocalizations.load(const Locale('de'));
  });
  tearDown(() async {
    await AppLocalizations.load(const Locale('en'));
  });

  for (final mode in [TrainerMode.simMode, TrainerMode.ergMode]) {
    for (final MapEntry(key: name, value: fields) in combos.entries) {
      testWidgets('${mode.name}, $name: no more than 16 px of empty room, every reading shown', (tester) async {
        await pumpFitted(tester, state(fields, mode: mode, power: 1999, cadence: 120, ratio: 3.53));
        expect(tester.takeException(), isNull, reason: 'no overflow');
        final s = slack(tester);
        expect(s, greaterThanOrEqualTo(-0.5), reason: 'the content fits');
        expect(s, lessThanOrEqualTo(16), reason: 'no room kept for what is off');
        if (fields.contains(OverlayField.power)) {
          expect(find.textContaining('1999', findRichText: true), findsOneWidget);
        }
        if (fields.contains(OverlayField.cadence)) {
          expect(find.textContaining('120', findRichText: true), findsOneWidget);
        }
        if (mode == TrainerMode.simMode && fields.contains(OverlayField.gearRatio)) {
          expect(find.textContaining('3.53', findRichText: true), findsOneWidget);
        }
      }, variant: desktop);
    }
  }

  testWidgets('the window keeps its size while the values change', (tester) async {
    for (final fields in combos.values) {
      final quiet = await pumpFitted(tester, state(fields, power: null, cadence: null));
      final busy = await pumpFitted(tester, state(fields, power: 1999, cadence: 199, ratio: 4.88));
      final zero = await pumpFitted(tester, state(fields, power: 0, cadence: 0, ratio: 1.0));
      expect(busy, quiet, reason: '$fields');
      expect(zero, quiet, reason: '$fields');
    }
  }, variant: desktop);

  testWidgets('turning a reading off makes the window narrower', (tester) async {
    final all = await pumpFitted(tester, state(combos['power, cadence, ratio']!));
    final two = await pumpFitted(tester, state(combos['power + cadence']!));
    final one = await pumpFitted(tester, state(combos['power only']!));
    expect(two.width, lessThan(all.width));
    expect(one.width, lessThan(two.width));
  }, variant: desktop);

  testWidgets('the gear never shrinks to fit the window', (tester) async {
    await pumpFitted(tester, state(const {}, frontShift: true));
    final paragraph = tester.renderObject<RenderParagraph>(find.text('1×11'));
    expect(paragraph.text.style!.fontSize, TrainerOverlayView.gearSize);
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(tester.takeException(), isNull);
  }, variant: desktop);

  testWidgets('the window follows the fields as they are toggled', (tester) async {
    final notifier = ValueNotifier(state(combos['power + cadence']!));
    final sizes = <Size>[];
    await tester.pumpWidget(
      OverlayShadcnApp(
        home: OverlayWindowFit(state: notifier, onSize: sizes.add, child: const SizedBox()),
      ),
    );
    await tester.pump();
    expect(sizes, hasLength(1));
    notifier.value = state(combos['power + cadence']!, power: 321, cadence: 99);
    await tester.pump();
    expect(sizes, hasLength(1), reason: 'values alone never resize it');
    notifier.value = state(combos['power, cadence, ratio']!);
    await tester.pump();
    expect(sizes, hasLength(2));
    expect(sizes.last.width, greaterThan(sizes.first.width));
  }, variant: desktop);
}
