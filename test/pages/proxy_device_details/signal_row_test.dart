import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/proxy_device_details/metric_card.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// One signal row on the Sensors page — presentational only: it renders the
/// [MetricSourceOption]s it is given. `live_metrics_section_test.dart` covers
/// which options exist and what they say.
Future<void> main() async {
  await AppLocalizations.load(const Locale('en'));

  Future<void> pump(WidgetTester tester, SignalRow row, {double width = 900}) async {
    final size = Size(width, 800);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(child: SingleChildScrollView(child: row)),
      ),
    );
  }

  MetricSourceOption option({
    required String id,
    required MetricSourceState state,
    bool selected = false,
    Future<void> Function()? onSelect,
    Future<void> Function()? onDisconnect,
  }) => MetricSourceOption(
    id: id,
    label: 'label $id',
    subtitle: 'subtitle for $id',
    state: state,
    selected: selected,
    onSelect: onSelect ?? () async {},
    onDisconnect: onDisconnect,
  );

  SignalRow row({List<MetricSourceOption>? sources, String? value = '142', bool replaced = false}) => SignalRow(
    icon: LucideIcons.heart,
    label: 'Heart rate',
    value: value,
    unit: 'bpm',
    sourceLabel: 'Wahoo KICKR',
    sourceDotColor: const Color(0xFF22A06B),
    replaced: replaced,
    sources: sources,
  );

  Color? dotColor(WidgetTester tester, String id) {
    final container = tester.widget<Container>(find.byKey(Key('metric-card-source-dot-$id')));
    return (container.decoration as BoxDecoration?)?.color;
  }

  group('nothing to choose between', () {
    for (final (name, sources) in [
      ('null', null),
      ('empty', <MetricSourceOption>[]),
      ('one entry', [option(id: 'trainer', state: MetricSourceState.trainer, selected: true)]),
    ]) {
      testWidgets('$name sources: label, source, value and unit — no list, no header button', (tester) async {
        await pump(tester, row(sources: sources));

        expect(find.text('Heart rate'), findsOneWidget);
        expect(find.text('Wahoo KICKR'), findsOneWidget);
        expect(find.text('142'), findsOneWidget);
        expect(find.text('bpm'), findsOneWidget);
        expect(find.byKey(const Key('metric-card-source-control')), findsNothing);
        expect(find.byKey(const Key('signal-row-header')), findsNothing);
      });
    }

    testWidgets('a null value reads "--"', (tester) async {
      await pump(tester, row(value: null));
      expect(find.text('--'), findsOneWidget);
    });
  });

  testWidgets('Replaced shows only when a sensor stands in for the trainer', (tester) async {
    await pump(tester, row());
    expect(find.byKey(const Key('signal-row-replaced')), findsNothing);

    await pump(tester, row(replaced: true));
    expect(find.byKey(const Key('signal-row-replaced')), findsOneWidget);
    expect(find.text(AppLocalizations.current.sensorReplacedTag.toUpperCase()), findsOneWidget);
  });

  group('the source list', () {
    final sources = [
      option(id: 'trainer', state: MetricSourceState.trainer),
      option(id: 'hr-1', state: MetricSourceState.connected, selected: true),
    ];

    testWidgets('stays open on a wide layout, every option with its subtitle', (tester) async {
      await pump(tester, row(sources: sources));

      expect(find.byKey(const Key('metric-card-source-control')), findsOneWidget);
      expect(find.text('subtitle for trainer'), findsOneWidget);
      expect(find.text('subtitle for hr-1'), findsOneWidget);
    });

    testWidgets('folds away on a phone, and the row header toggles it', (tester) async {
      await pump(tester, row(sources: sources), width: 390);
      expect(find.byKey(const Key('metric-card-source-control')), findsNothing);

      await tester.tap(find.byKey(const Key('signal-row-header')));
      await tester.pump();
      expect(find.byKey(const Key('metric-card-source-control')), findsOneWidget);

      await tester.tap(find.byKey(const Key('signal-row-header')));
      await tester.pump();
      expect(find.byKey(const Key('metric-card-source-control')), findsNothing);
    });

    testWidgets("tapping an option runs that option's own onSelect", (tester) async {
      final picked = <String>[];
      await pump(
        tester,
        row(
          sources: [
            option(id: 'trainer', state: MetricSourceState.trainer, onSelect: () async => picked.add('trainer')),
            option(id: 'hr-1', state: MetricSourceState.notConnected, onSelect: () async => picked.add('hr-1')),
          ],
        ),
      );

      await tester.tap(find.byKey(const Key('metric-card-source-option-hr-1')));
      await tester.pumpAndSettle();
      expect(picked, ['hr-1']);
    });

    testWidgets('each state has its own dot colour', (tester) async {
      await pump(
        tester,
        row(
          sources: [
            option(id: 'trainer', state: MetricSourceState.trainer, selected: true),
            option(id: 'a', state: MetricSourceState.connected),
            option(id: 'b', state: MetricSourceState.connecting),
            option(id: 'c', state: MetricSourceState.waitingForFirstReading),
            option(id: 'd', state: MetricSourceState.lost),
            option(id: 'e', state: MetricSourceState.notConnected),
          ],
        ),
      );

      final element = tester.element(find.byType(SignalRow));
      final cs = Theme.of(element).colorScheme;
      final status = BkStatusColors.of(element);
      expect(dotColor(tester, 'trainer'), cs.mutedForeground);
      expect(dotColor(tester, 'a'), status.success);
      expect(dotColor(tester, 'b'), status.warning);
      expect(dotColor(tester, 'c'), status.warning);
      expect(dotColor(tester, 'd'), status.danger);
      expect(dotColor(tester, 'e'), cs.mutedForeground);
    });

    testWidgets('long-press disconnects the selected sensor', (tester) async {
      var disconnected = false;
      await pump(
        tester,
        row(
          sources: [
            option(id: 'trainer', state: MetricSourceState.trainer),
            option(
              id: 'hr-1',
              state: MetricSourceState.connected,
              selected: true,
              onDisconnect: () async => disconnected = true,
            ),
          ],
        ),
      );

      await tester.longPress(find.byKey(const Key('metric-card-source-option-hr-1')));
      await tester.pumpAndSettle();
      expect(disconnected, isTrue);
    });

    testWidgets('a failing disconnect is handled, not left uncaught', (tester) async {
      await pump(
        tester,
        row(
          sources: [
            option(id: 'trainer', state: MetricSourceState.trainer),
            option(
              id: 'hr-1',
              state: MetricSourceState.connected,
              selected: true,
              onDisconnect: () async => throw StateError('disconnect failed'),
            ),
          ],
        ),
      );

      await tester.longPress(find.byKey(const Key('metric-card-source-option-hr-1')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(SmallProgressIndicator), findsNothing);
    });
  });

  testWidgets('the value uses tabular figures so a changing reading does not reflow the row', (tester) async {
    await pump(tester, row());
    final text = tester.widget<Text>(find.text('142'));
    expect(text.style?.fontFeatures, contains(const FontFeature.tabularFigures()));
  });
}
