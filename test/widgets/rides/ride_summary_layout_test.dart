// The ride summary's four numbers and the recording line on a phone, with the
// real fonts and the phone's 1.1× text: no stat runs into the next, "Ø" sits
// in the label, nothing overflows, and the recording line's "started
// automatically" is never cut off.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/widgets/rides/ride_recording_line.dart';
import 'package:bike_control/widgets/rides/ride_summary_card.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart' show ScreenshotTester;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../helpers/ride_fixtures.dart';
import '../../helpers/ride_rig.dart';
import '../../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();
  setUp(RideRig.reset);

  Future<AppLocalizations> pump(
    WidgetTester tester,
    Widget child, {
    required double width,
    String locale = 'de',
  }) async {
    tester.view.physicalSize = Size(width, 1400) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final l = await AppLocalizations.load(Locale(locale));
    addTearDown(() => AppLocalizations.load(const Locale('en')));
    await tester.pumpWidget(
      ShadcnApp(
        locale: Locale(locale),
        theme: BkTheme.build(Brightness.light),
        scaling: BkTheme.mobileScaling,
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: DrawerOverlay(
          child: Scaffold(
            child: SingleChildScrollView(padding: const EdgeInsets.all(12), child: child),
          ),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Real fonts, so the checks measure what riders see.
    await tester.loadAssets();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return l;
  }

  /// Whether [p] draws all of its text: nothing cut at maxLines, no
  /// ellipsis, and not squeezed by a FittedBox.
  void expectWhole(WidgetTester tester, RenderParagraph p, String what) {
    expect(p.didExceedMaxLines, isFalse, reason: '$what is cut off');
    final painter = TextPainter(
      text: p.text,
      textDirection: TextDirection.ltr,
      textScaler: p.textScaler,
      maxLines: p.maxLines,
    )..layout(maxWidth: p.constraints.maxWidth);
    expect(painter.width, lessThanOrEqualTo(p.size.width + 0.5), reason: '$what is wider than its box');
    painter.dispose();
    final scale = p.getTransformTo(null).getMaxScaleOnAxis();
    expect(scale, closeTo(1, 0.001), reason: '$what is scaled down');
  }

  final rides = {
    'short': (const Duration(minutes: 42, seconds: 18), 223),
    'long': (const Duration(hours: 2, minutes: 4, seconds: 18), 260),
  };

  for (final locale in ['de', 'en', 'fr']) {
    for (final width in [390.0, 360.0]) {
      for (final MapEntry(key: name, value: (moving, watts)) in rides.entries) {
        testWidgets('$locale @ $width, $name ride: the four numbers keep apart', (tester) async {
          final rig = await RideRig.install(prefs: const {'health_rides_prompt_dismissed': true});
          final ride = await saveSampleRide(rig.repository, moving: moving, avgWatts: watts);
          await rig.prefs.setSummaryRide(ride.fileName);
          await rig.service.start(detect: false);
          final l = await pump(tester, const RideSummaryCard(), width: width, locale: locale);
          expect(tester.takeException(), isNull);

          final keys = ['duration', 'distance', 'power', 'work'];
          final rects = <String, Rect>{};
          for (final k in keys) {
            final stat = find.byKey(ValueKey('ride-summary-$k'));
            expect(stat, findsOneWidget, reason: k);
            final paragraphs = find.descendant(of: stat, matching: find.byType(RichText));
            expect(paragraphs, findsNWidgets(2), reason: '$k: value and label');
            final value = tester.renderObject<RenderParagraph>(paragraphs.first);
            final label = tester.renderObject<RenderParagraph>(paragraphs.last);
            expectWhole(tester, value, '$k value');
            expectWhole(tester, label, '$k label');
            final vr = tester.getRect(paragraphs.first);
            final lr = tester.getRect(paragraphs.last);
            expect(lr.top, greaterThanOrEqualTo(vr.bottom - 0.5), reason: '$k: label below the value');
            rects[k] = vr.expandToInclude(lr);
            if (k == 'power') {
              expect(value.text.toPlainText(), isNot(contains('Ø')), reason: 'Ø belongs to the label');
              expect(label.text.toPlainText(), l.miniWorkoutSummaryAvgPower);
            }
          }

          final card = tester.getRect(find.byKey(const ValueKey('ride-summary-card')));
          for (final k in keys) {
            expect(
              card.contains(rects[k]!.topLeft) && card.contains(rects[k]!.bottomRight - const Offset(.1, .1)),
              isTrue,
              reason: '$k inside the card',
            );
          }
          for (var i = 0; i < keys.length; i++) {
            for (var j = i + 1; j < keys.length; j++) {
              final a = rects[keys[i]]!, b = rects[keys[j]]!;
              final sameRow = a.top < b.bottom && b.top < a.bottom;
              if (sameRow) {
                final gap = a.left < b.left ? b.left - a.right : a.left - b.right;
                expect(gap, greaterThanOrEqualTo(12), reason: '${keys[i]} / ${keys[j]} need 12 px between them');
              } else {
                expect(a.overlaps(b), isFalse, reason: '${keys[i]} / ${keys[j]} overlap');
              }
            }
          }
          rig.service.discard();
        });
      }
    }
  }

  testWidgets('de @ 390: the recording line shows "automatisch gestartet" whole', (tester) async {
    final l = await pump(
      tester,
      RideRecordingLine(
        paused: false,
        elapsed: ValueNotifier(const Duration(minutes: 12, seconds: 34)),
        startedAutomatically: true,
        onFinish: () {},
        onDiscard: () {},
      ),
      width: 390,
    );
    expect(tester.takeException(), isNull);
    final sub = find.textContaining(l.ridesAutoStarted, findRichText: true);
    expect(sub, findsOneWidget);
    expectWhole(tester, tester.renderObject<RenderParagraph>(sub), 'subtitle');
  });
}
