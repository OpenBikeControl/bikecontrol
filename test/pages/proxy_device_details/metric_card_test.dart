import 'dart:async';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/proxy_device_details/metric_card.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The tile itself — presentational only, and deliberately dumb: it renders
/// whatever [MetricSourceOption]s it is given, inline as a vertical list on a
/// wide tile, or behind a compact picker (a popover anchored to the tile) on
/// a narrow one. `live_metrics_section_test.dart` covers deciding WHICH
/// options exist and what their state (and subtitle) resolves to (including
/// the connect/disconnect ordering); this file covers HOW [MetricCard]
/// renders a given list, including the inline/picker layout switch.
Future<void> main() async {
  await AppLocalizations.load(const Locale('en'));

  /// Two cards side by side inside a [width]-wide harness — exactly how
  /// `LiveMetricsSection` lays the grid out (`Row(children: [cardA, cardB])`
  /// inside a column of that width) — rather than one card alone with
  /// unconstrained width, which would hide a truncation/overflow bug that
  /// only shows up once the tile is actually half-width.
  ///
  /// [width] defaults to a realistic PHONE width (360, matching this
  /// section's own signals-grid usage) — each card lands well under
  /// `MetricCard._sideBySideBreakpoint`'s 240px content-width threshold, so
  /// the sources (when present) collapse into the compact picker. Passing a
  /// wider [width] pushes each card's content width above that threshold,
  /// where the list renders inline beside the value instead — every test
  /// that exercises the inline rows directly uses 900.
  Future<void> pump(WidgetTester tester, MetricCard card, {MetricCard? second, double width = 360}) async {
    // A `SizedBox(width: ...)` alone can't narrow anything here: `Scaffold`
    // gives its child TIGHT constraints matching the (default 800×600) test
    // surface, and a tight incoming constraint always wins over a `SizedBox`'s
    // own requested width (`BoxConstraints.enforce`) — so the actual surface
    // size has to change for [width] to mean anything. Matches the idiom
    // `network_troubleshooting_layout_test.dart` already uses for the same
    // reason.
    final size = Size(width, 800);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size),
        child: ShadcnApp(
          localizationsDelegates: const [AppLocalizations.delegate],
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          home: Scaffold(
            child: Row(children: [card, second ?? const _FillerCard()]),
          ),
        ),
      ),
    );
  }

  Color? dotColor(WidgetTester tester, String id) {
    final container = tester.widget<Container>(find.byKey(Key('metric-card-source-dot-$id')));
    return (container.decoration as BoxDecoration?)?.color;
  }

  MetricSourceOption option({
    required String id,
    required String label,
    String? subtitle,
    required MetricSourceState state,
    bool selected = false,
    Future<void> Function()? onSelect,
    Future<void> Function()? onDisconnect,
  }) => MetricSourceOption(
    id: id,
    label: label,
    subtitle: subtitle ?? 'subtitle for $id',
    state: state,
    selected: selected,
    onSelect: onSelect ?? () async {},
    onDisconnect: onDisconnect,
  );

  const baseCard = MetricCard(
    icon: LucideIcons.heart,
    iconColor: Color(0xFFEF4444),
    label: 'HEART',
    value: '142',
    unit: 'bpm',
  );

  group('THE INVARIANT: no sources', () {
    testWidgets('null sources renders label, value and unit with no control at all', (tester) async {
      await pump(tester, baseCard);

      expect(find.text('HEART'), findsOneWidget);
      expect(find.text('142'), findsOneWidget);
      expect(find.text('bpm'), findsOneWidget);
      expect(find.byKey(const Key('metric-card-source-control')), findsNothing);
      expect(find.byKey(const Key('metric-card-source-picker')), findsNothing);
      // No source list, no divider either — a divider with nothing to
      // separate would be a stray line on the tile's pristine, no-sensors
      // rendering.
      expect(find.byKey(const Key('metric-card-source-divider')), findsNothing);
    });

    testWidgets('an empty source list also renders no control', (tester) async {
      await pump(
        tester,
        MetricCard(
          icon: baseCard.icon,
          iconColor: baseCard.iconColor,
          label: baseCard.label,
          value: baseCard.value,
          unit: baseCard.unit,
          sources: const [],
        ),
      );

      expect(find.byKey(const Key('metric-card-source-control')), findsNothing);
      expect(find.byKey(const Key('metric-card-source-picker')), findsNothing);
    });

    testWidgets('a single-entry list (nothing to choose between) also renders no control', (tester) async {
      // A rider with no external sensors must see the tile exactly as it
      // renders with null/empty sources — a list of just "Trainer" would be
      // an affordance with nothing behind it.
      await pump(
        tester,
        MetricCard(
          icon: baseCard.icon,
          iconColor: baseCard.iconColor,
          label: baseCard.label,
          value: baseCard.value,
          unit: baseCard.unit,
          sources: [option(id: 'trainer', label: 'Trainer', state: MetricSourceState.trainer, selected: true)],
        ),
      );

      expect(find.byKey(const Key('metric-card-source-control')), findsNothing);
      expect(find.byKey(const Key('metric-card-source-picker')), findsNothing);
      expect(find.byKey(const Key('metric-card-source-option-trainer')), findsNothing);
    });

    testWidgets('a null value renders the unchanged "--" placeholder, still no control', (tester) async {
      await pump(
        tester,
        const MetricCard(
          key: Key('under-test'),
          icon: LucideIcons.heart,
          iconColor: Color(0xFFEF4444),
          label: 'HEART',
          value: null,
          unit: 'bpm',
        ),
      );

      // The filler card is also valueless ("--" is its own unchanged
      // placeholder too), so this scopes to the tile under test rather than
      // asserting a global count that would pass for the wrong reason.
      expect(
        find.descendant(of: find.byKey(const Key('under-test')), matching: find.text('--')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('metric-card-source-control')), findsNothing);
    });
  });

  group('Source header (direct author feedback: "add a small \'Source\' header")', () {
    testWidgets('renders above the list when a list is shown', (tester) async {
      await pump(
        tester,
        MetricCard(
          icon: baseCard.icon,
          iconColor: baseCard.iconColor,
          label: baseCard.label,
          value: baseCard.value,
          unit: baseCard.unit,
          sources: [
            option(id: 'trainer', label: 'Trainer', state: MetricSourceState.trainer, selected: true),
            option(id: 'hr-1', label: 'HR6 0050789', state: MetricSourceState.notConnected),
          ],
        ),
        width: 900,
      );

      expect(find.byKey(const Key('metric-card-source-header')), findsOneWidget);
      final headerTop = tester.getTopLeft(find.byKey(const Key('metric-card-source-header'))).dy;
      final firstRowTop = tester.getTopLeft(find.byKey(const Key('metric-card-source-option-trainer'))).dy;
      expect(headerTop, lessThan(firstRowTop));
    });

    testWidgets('does not render when there is no list at all (THE INVARIANT is unchanged)', (tester) async {
      await pump(tester, baseCard);

      expect(find.byKey(const Key('metric-card-source-header')), findsNothing);
    });

    testWidgets('does not render for a single-entry (nothing-to-choose) list', (tester) async {
      await pump(
        tester,
        MetricCard(
          icon: baseCard.icon,
          iconColor: baseCard.iconColor,
          label: baseCard.label,
          value: baseCard.value,
          unit: baseCard.unit,
          sources: [option(id: 'trainer', label: 'Trainer', state: MetricSourceState.trainer, selected: true)],
        ),
      );

      expect(find.byKey(const Key('metric-card-source-header')), findsNothing);
    });
  });

  group('sources render as a list, not a toggle', () {
    testWidgets('Trainer plus every source render as their own row, each with its own subtitle', (tester) async {
      await pump(
        tester,
        MetricCard(
          icon: baseCard.icon,
          iconColor: baseCard.iconColor,
          label: baseCard.label,
          value: baseCard.value,
          unit: baseCard.unit,
          sources: [
            option(
              id: 'trainer',
              label: 'Trainer',
              subtitle: "The trainer's own built-in reading.",
              state: MetricSourceState.trainer,
              selected: true,
            ),
            option(
              id: 'hr-1',
              label: 'HR6 0050789',
              subtitle: 'Connected — streaming its own reading.',
              state: MetricSourceState.connected,
            ),
            option(
              id: 'hr-2',
              label: 'TICKR 1234',
              subtitle: 'Not connected yet — tap to connect and use it here.',
              state: MetricSourceState.notConnected,
            ),
          ],
        ),
        width: 900,
      );

      // All three are on screen simultaneously — no sheet, no dropdown, no
      // opening interaction needed to see them — each with its own title...
      expect(find.text('Trainer'), findsOneWidget);
      expect(find.text('HR6 0050789'), findsOneWidget);
      expect(find.text('TICKR 1234'), findsOneWidget);
      // ...and its own subtitle, distinguishable from the others.
      expect(find.text("The trainer's own built-in reading."), findsOneWidget);
      expect(find.text('Connected — streaming its own reading.'), findsOneWidget);
      expect(find.text('Not connected yet — tap to connect and use it here.'), findsOneWidget);

      // Trainer is the first row in source order.
      expect(
        tester.getTopLeft(find.byKey(const Key('metric-card-source-option-trainer'))).dy,
        lessThan(tester.getTopLeft(find.byKey(const Key('metric-card-source-option-hr-1'))).dy),
      );
    });

    testWidgets('tapping a row invokes its own onSelect, not a shared handler', (tester) async {
      var trainerTapped = false;
      var sensorTapped = false;
      await pump(
        tester,
        MetricCard(
          icon: baseCard.icon,
          iconColor: baseCard.iconColor,
          label: baseCard.label,
          value: baseCard.value,
          unit: baseCard.unit,
          sources: [
            option(
              id: 'trainer',
              label: 'Trainer',
              state: MetricSourceState.trainer,
              selected: true,
              onSelect: () async => trainerTapped = true,
            ),
            option(
              id: 'hr-1',
              label: 'HR6 0050789',
              state: MetricSourceState.notConnected,
              onSelect: () async => sensorTapped = true,
            ),
          ],
        ),
        width: 900,
      );

      await tester.tap(find.byKey(const Key('metric-card-source-option-hr-1')));
      await tester.pumpAndSettle();

      expect(sensorTapped, isTrue);
      expect(trainerTapped, isFalse);
    });
  });

  group('the selected row is clearly marked', () {
    testWidgets('the selected row shows a check mark; unselected rows do not', (tester) async {
      await pump(
        tester,
        MetricCard(
          icon: baseCard.icon,
          iconColor: baseCard.iconColor,
          label: baseCard.label,
          value: baseCard.value,
          unit: baseCard.unit,
          sources: [
            option(id: 'trainer', label: 'Trainer', state: MetricSourceState.trainer),
            option(id: 'hr-1', label: 'HR6 0050789', state: MetricSourceState.connected, selected: true),
          ],
        ),
        width: 900,
      );

      expect(
        find.descendant(
          of: find.byKey(const Key('metric-card-source-option-hr-1')),
          matching: find.byIcon(LucideIcons.check),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('metric-card-source-option-trainer')),
          matching: find.byIcon(LucideIcons.check),
        ),
        findsNothing,
      );

      // Its `SelectedButton` also carries `value: true` — the row's own
      // (already-subtle) background tint, on top of the check mark.
      final selectedButton = tester.widget<SelectedButton>(find.byKey(const Key('metric-card-source-option-hr-1')));
      expect(selectedButton.value, isTrue);
    });
  });

  group('per-source dot state is distinguishable', () {
    testWidgets('trainer, connected, connecting, waiting, lost and not-connected all render their own colour', (
      tester,
    ) async {
      await pump(
        tester,
        MetricCard(
          icon: baseCard.icon,
          iconColor: baseCard.iconColor,
          label: baseCard.label,
          value: baseCard.value,
          unit: baseCard.unit,
          sources: [
            option(id: 'trainer', label: 'Trainer', state: MetricSourceState.trainer, selected: true),
            option(id: 'a', label: 'A', state: MetricSourceState.connected),
            option(id: 'b', label: 'B', state: MetricSourceState.connecting),
            option(id: 'c', label: 'C', state: MetricSourceState.waitingForFirstReading),
            option(id: 'd', label: 'D', state: MetricSourceState.lost),
            option(id: 'e', label: 'E', state: MetricSourceState.notConnected),
          ],
        ),
        width: 900,
      );

      final cs = Theme.of(tester.element(find.byType(MetricCard).first)).colorScheme;
      expect(dotColor(tester, 'trainer'), cs.mutedForeground);
      expect(dotColor(tester, 'a'), const Color(0xFF22C55E));
      expect(dotColor(tester, 'b'), const Color(0xFFF59E0B));
      expect(dotColor(tester, 'c'), const Color(0xFFF59E0B));
      expect(dotColor(tester, 'd'), const Color(0xFFEF4444));
      expect(dotColor(tester, 'e'), cs.mutedForeground);

      // Distinguishable from one another: connected/lost read as visibly
      // different colours side by side in the same tile, not just "not
      // muted".
      expect(dotColor(tester, 'a'), isNot(dotColor(tester, 'd')));
    });
  });

  testWidgets('hierarchy: every row label stays muted foreground, selected or not — only the dot/check carry state', (
    tester,
  ) async {
    await pump(
      tester,
      MetricCard(
        icon: baseCard.icon,
        iconColor: baseCard.iconColor,
        label: baseCard.label,
        value: baseCard.value,
        unit: baseCard.unit,
        sources: [
          option(id: 'trainer', label: 'Trainer', state: MetricSourceState.trainer),
          option(id: 'hr-1', label: 'HR6 0050789', state: MetricSourceState.lost, selected: true),
        ],
      ),
      width: 900,
    );

    final cs = Theme.of(tester.element(find.byType(MetricCard).first)).colorScheme;
    final unselected = tester.widget<Text>(find.text('Trainer'));
    final selected = tester.widget<Text>(find.text('HR6 0050789'));
    expect(unselected.style?.color, cs.mutedForeground);
    expect(selected.style?.color, cs.mutedForeground);
    // Small — well below the 28px hero value — so the control cannot
    // out-shout the number above it.
    expect(unselected.style?.fontSize, lessThan(16));
    expect(selected.style?.fontSize, lessThan(16));
  });

  testWidgets('long-press on a row invokes onDisconnect when set', (tester) async {
    var disconnected = false;
    await pump(
      tester,
      MetricCard(
        icon: baseCard.icon,
        iconColor: baseCard.iconColor,
        label: baseCard.label,
        value: baseCard.value,
        unit: baseCard.unit,
        sources: [
          option(id: 'trainer', label: 'Trainer', state: MetricSourceState.trainer),
          option(
            id: 'hr-1',
            label: 'HR6 0050789',
            state: MetricSourceState.connected,
            selected: true,
            onDisconnect: () async => disconnected = true,
          ),
        ],
      ),
      width: 900,
    );

    await tester.longPress(find.byKey(const Key('metric-card-source-option-hr-1')));
    await tester.pumpAndSettle();

    expect(disconnected, isTrue);
  });

  testWidgets('a row with no onDisconnect ignores long-press (Trainer, or an unselected sensor)', (tester) async {
    await pump(
      tester,
      MetricCard(
        icon: baseCard.icon,
        iconColor: baseCard.iconColor,
        label: baseCard.label,
        value: baseCard.value,
        unit: baseCard.unit,
        sources: [
          option(id: 'trainer', label: 'Trainer', state: MetricSourceState.trainer, selected: true),
          option(id: 'hr-1', label: 'HR6 0050789', state: MetricSourceState.notConnected),
        ],
      ),
      width: 900,
    );

    // Must not throw for lack of a handler.
    await tester.longPress(find.byKey(const Key('metric-card-source-option-trainer')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  group('narrow tile: a compact picker replaces the inline list', () {
    // Half of a phone-width grid leaves ~150px of content — an inline list
    // there only had room for truncated names and clipped subtitles, so the
    // tile shows just the current pick and opens the full list on demand.
    Finder picker() => find.byKey(const Key('metric-card-source-picker'));

    MetricCard card(List<MetricSourceOption> sources) => MetricCard(
      key: const Key('under-test'),
      icon: baseCard.icon,
      iconColor: baseCard.iconColor,
      label: baseCard.label,
      value: baseCard.value,
      unit: baseCard.unit,
      sources: sources,
    );

    testWidgets('shows only the current pick, below the value — no inline rows, no divider', (tester) async {
      await pump(
        tester,
        card([
          option(id: 'trainer', label: 'Trainer', state: MetricSourceState.trainer),
          option(id: 'hr-1', label: 'HR6 0050789', state: MetricSourceState.connected, selected: true),
        ]),
      );

      expect(picker(), findsOneWidget);
      expect(find.descendant(of: picker(), matching: find.text('HR6 0050789')), findsOneWidget);
      expect(find.byKey(const Key('metric-card-source-option-trainer')), findsNothing);
      expect(find.byKey(const Key('metric-card-source-option-hr-1')), findsNothing);
      expect(find.text('subtitle for hr-1'), findsNothing);
      expect(find.byKey(const Key('metric-card-source-divider')), findsNothing);
      expect(tester.getTopLeft(picker()).dy, greaterThan(tester.getBottomLeft(find.text('142')).dy));

      // The SOURCE header still says what the picker is for.
      final headerFinder = find.byKey(const Key('metric-card-source-header'));
      expect(headerFinder, findsOneWidget);
      expect(tester.getTopLeft(headerFinder).dy, lessThan(tester.getTopLeft(picker()).dy));
    });

    testWidgets("the picker's dot carries the current pick's state", (tester) async {
      await pump(
        tester,
        card([
          option(id: 'trainer', label: 'Trainer', state: MetricSourceState.trainer),
          option(id: 'hr-1', label: 'HR6 0050789', state: MetricSourceState.lost, selected: true),
        ]),
      );

      final dot = tester.widget<Container>(find.byKey(const Key('metric-card-source-picker-dot')));
      expect((dot.decoration as BoxDecoration?)?.color, const Color(0xFFEF4444));
    });

    testWidgets('tapping the picker opens every option with its subtitle', (tester) async {
      await pump(
        tester,
        card([
          option(id: 'trainer', label: 'Trainer', state: MetricSourceState.trainer, selected: true),
          option(
            id: 'hr-1',
            label: 'HR6 0050789',
            subtitle: 'Not connected yet — tap to connect and use it here.',
            state: MetricSourceState.notConnected,
          ),
        ]),
      );

      await tester.tap(picker());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('metric-card-source-option-trainer')), findsOneWidget);
      expect(find.byKey(const Key('metric-card-source-option-hr-1')), findsOneWidget);
      expect(find.text('Not connected yet — tap to connect and use it here.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets("picking a row closes the popover and runs only that row's onSelect", (tester) async {
      var trainerTapped = false;
      var sensorTapped = false;
      await pump(
        tester,
        card([
          option(
            id: 'trainer',
            label: 'Trainer',
            state: MetricSourceState.trainer,
            selected: true,
            onSelect: () async => trainerTapped = true,
          ),
          option(
            id: 'hr-1',
            label: 'HR6 0050789',
            state: MetricSourceState.notConnected,
            onSelect: () async => sensorTapped = true,
          ),
        ]),
      );

      await tester.tap(picker());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('metric-card-source-option-hr-1')));
      await tester.pumpAndSettle();

      expect(sensorTapped, isTrue);
      expect(trainerTapped, isFalse);
      expect(find.byKey(const Key('metric-card-source-option-hr-1')), findsNothing);
    });

    testWidgets('the picker shows a spinner until the picked source finishes connecting', (tester) async {
      final connect = Completer<void>();
      await pump(
        tester,
        card([
          option(id: 'trainer', label: 'Trainer', state: MetricSourceState.trainer, selected: true),
          option(
            id: 'hr-1',
            label: 'HR6 0050789',
            state: MetricSourceState.notConnected,
            onSelect: () => connect.future,
          ),
        ]),
      );

      await tester.tap(picker());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('metric-card-source-option-hr-1')));
      // Not `pumpAndSettle`: the spinner animates for as long as the connect
      // is in flight, so it would never settle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.descendant(of: picker(), matching: find.byType(SmallProgressIndicator)), findsOneWidget);

      connect.complete();
      await tester.pumpAndSettle();

      expect(find.descendant(of: picker(), matching: find.byType(SmallProgressIndicator)), findsNothing);
    });

    testWidgets('long-pressing the selected row in the popover disconnects it', (tester) async {
      var disconnected = false;
      await pump(
        tester,
        card([
          option(id: 'trainer', label: 'Trainer', state: MetricSourceState.trainer),
          option(
            id: 'hr-1',
            label: 'HR6 0050789',
            state: MetricSourceState.connected,
            selected: true,
            onDisconnect: () async => disconnected = true,
          ),
        ]),
      );

      await tester.tap(picker());
      await tester.pumpAndSettle();
      await tester.longPress(find.byKey(const Key('metric-card-source-option-hr-1')));
      await tester.pumpAndSettle();

      expect(disconnected, isTrue);
    });

    testWidgets('a long selected name ellipsizes instead of overflowing the half-width tile', (tester) async {
      const longName = 'A Very Long Sensor Display Name That Would Never Fit';
      await pump(
        tester,
        card([
          option(id: 'trainer', label: 'Trainer', state: MetricSourceState.trainer),
          option(id: 'long', label: longName, state: MetricSourceState.connected, selected: true),
        ]),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      final text = tester.widget<Text>(find.descendant(of: picker(), matching: find.text(longName)));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    });
  });

  group('layout: side-by-side vs picker', () {
    final sources = [
      option(id: 'trainer', label: 'Trainer', state: MetricSourceState.trainer, selected: true),
      option(id: 'hr-1', label: 'HR6 0050789', state: MetricSourceState.notConnected),
    ];

    testWidgets('wide (desktop-grid-width) card: the list sits to the RIGHT of the value', (tester) async {
      await pump(
        tester,
        MetricCard(
          icon: baseCard.icon,
          iconColor: baseCard.iconColor,
          label: baseCard.label,
          value: baseCard.value,
          unit: baseCard.unit,
          sources: sources,
        ),
        // 900px harness — each card lands at ~450px raw / ~422px content,
        // comfortably over the 240px breakpoint (see
        // `MetricCard._sideBySideBreakpoint`'s own doc comment for how that
        // number was measured against the real signals-grid layout).
        width: 900,
      );

      expect(find.byKey(const Key('metric-card-source-picker')), findsNothing);
      final valueTop = tester.getTopLeft(find.text('142'));
      final listTop = tester.getTopLeft(find.byKey(const Key('metric-card-source-option-trainer')));
      expect(listTop.dx, greaterThan(valueTop.dx));
      // Beside, not stacked further down the same column: the two starting
      // points sit within one row's height of each other.
      expect((listTop.dy - valueTop.dy).abs(), lessThan(30));
    });

    testWidgets('wide (side-by-side): a VERTICAL divider sits between value and list', (tester) async {
      await pump(
        tester,
        MetricCard(
          key: const Key('under-test'),
          icon: baseCard.icon,
          iconColor: baseCard.iconColor,
          label: baseCard.label,
          value: baseCard.value,
          unit: baseCard.unit,
          sources: sources,
        ),
        width: 900,
      );

      final dividerFinder = find.descendant(
        of: find.byKey(const Key('under-test')),
        matching: find.byKey(const Key('metric-card-source-divider')),
      );
      expect(dividerFinder, findsOneWidget);
      // No RenderFlex/layout overflow, and — the actual trap — no
      // "BoxConstraints forces an infinite height" from a bare
      // `VerticalDivider`: this Row always sits inside a scroll view in
      // real usage (`LiveMetricsSection`'s own doc comment), so its
      // incoming height is genuinely unbounded, not just generously
      // large. Proven by reproducing the crash with a literal
      // `VerticalDivider()` here before writing the real fix.
      expect(tester.takeException(), isNull);

      // Between the value and the list horizontally, not stacked below
      // either.
      final valueRight = tester.getTopRight(find.text('142')).dx;
      final dividerLeft = tester.getTopLeft(dividerFinder).dx;
      final listLeft = tester.getTopLeft(find.byKey(const Key('metric-card-source-option-trainer'))).dx;
      expect(dividerLeft, greaterThanOrEqualTo(valueRight));
      expect(listLeft, greaterThanOrEqualTo(dividerLeft));

      // Subtle — a hairline rule on the leading edge, not a bar: a real
      // `VerticalDivider` can't be used here at all (see this widget's own
      // build-method comment), so the vertical case is a bordered
      // container wrapping the list rather than a thin standalone line —
      // assert the border itself, not a narrow bounding box.
      final container = tester.widget<Container>(dividerFinder);
      final decoration = container.decoration as BoxDecoration?;
      final leftBorder = (decoration?.border as Border?)?.left;
      expect(leftBorder, isNotNull);
      expect(leftBorder!.width, lessThan(2));
      expect(leftBorder.color, isNot(Colors.transparent));
      // Taller than the value's own single line — it spans the full
      // side-by-side content height, not just a token-sized swatch.
      final size = tester.getSize(dividerFinder);
      expect(size.height, greaterThan(tester.getSize(find.text('142')).height));
    });
  });

  group('SOURCE header starts level with the label row (direct author feedback: '
      '"the list should begin at the same height as the \'Herz\' header itself")', () {
    // Measures both offsets directly (not "is the header present/above",
    // which the older "renders above the list" test already covers) — the
    // point of this group is catching a residual OFFSET between the two,
    // however small, not just ordering.
    void expectHeaderLevelWithLabel(WidgetTester tester) {
      final labelTop = tester
          .getTopLeft(
            find.descendant(of: find.byKey(const Key('under-test')), matching: find.byKey(const Key('metric-card-label-row'))),
          )
          .dy;
      final headerTop = tester
          .getTopLeft(
            find.descendant(
              of: find.byKey(const Key('under-test')),
              matching: find.byKey(const Key('metric-card-source-header')),
            ),
          )
          .dy;
      expect(headerTop, labelTop);
    }

    testWidgets('short list (two rows), value present', (tester) async {
      await pump(
        tester,
        MetricCard(
          key: const Key('under-test'),
          icon: baseCard.icon,
          iconColor: baseCard.iconColor,
          label: baseCard.label,
          value: baseCard.value,
          unit: baseCard.unit,
          sources: [
            option(id: 'trainer', label: 'Trainer', state: MetricSourceState.trainer, selected: true),
            option(id: 'hr-1', label: 'HR6 0050789', state: MetricSourceState.notConnected),
          ],
        ),
        width: 900,
      );

      expectHeaderLevelWithLabel(tester);
    });

    testWidgets('short list, value is "--" (null)', (tester) async {
      await pump(
        tester,
        MetricCard(
          key: const Key('under-test'),
          icon: baseCard.icon,
          iconColor: baseCard.iconColor,
          label: baseCard.label,
          value: null,
          unit: baseCard.unit,
          sources: [
            option(id: 'trainer', label: 'Trainer', state: MetricSourceState.trainer, selected: true),
            option(id: 'hr-1', label: 'HR6 0050789', state: MetricSourceState.notConnected),
          ],
        ),
        width: 900,
      );

      expectHeaderLevelWithLabel(tester);
    });

    testWidgets('long list (five rows)', (tester) async {
      await pump(
        tester,
        MetricCard(
          key: const Key('under-test'),
          icon: baseCard.icon,
          iconColor: baseCard.iconColor,
          label: baseCard.label,
          value: baseCard.value,
          unit: baseCard.unit,
          sources: [
            option(id: 'trainer', label: 'Trainer', state: MetricSourceState.trainer, selected: true),
            option(id: 'a', label: 'A', state: MetricSourceState.connected),
            option(id: 'b', label: 'B', state: MetricSourceState.connecting),
            option(id: 'c', label: 'C', state: MetricSourceState.waitingForFirstReading),
            option(id: 'd', label: 'D', state: MetricSourceState.lost),
          ],
        ),
        width: 900,
      );

      expectHeaderLevelWithLabel(tester);
    });
  });

  group('divider gutter (direct author feedback: "add more spacing next to the divider")', () {
    testWidgets('side-by-side: symmetric horizontal gutter separates the value/label column from the divider, '
        'and the divider from the list', (tester) async {
      await pump(
        tester,
        MetricCard(
          key: const Key('under-test'),
          icon: baseCard.icon,
          iconColor: baseCard.iconColor,
          label: baseCard.label,
          value: baseCard.value,
          unit: baseCard.unit,
          sources: [
            option(id: 'trainer', label: 'Trainer', state: MetricSourceState.trainer, selected: true),
            option(id: 'hr-1', label: 'HR6 0050789', state: MetricSourceState.notConnected),
          ],
        ),
        width: 900,
      );

      final columnRight = tester
          .getTopRight(
            find.descendant(
              of: find.byKey(const Key('under-test')),
              matching: find.byKey(const Key('metric-card-label-value-column')),
            ),
          )
          .dx;
      final dividerFinder = find.descendant(
        of: find.byKey(const Key('under-test')),
        matching: find.byKey(const Key('metric-card-source-divider')),
      );
      final dividerLeft = tester.getTopLeft(dividerFinder).dx;
      final listLeft = tester
          .getTopLeft(
            find.descendant(
              of: find.byKey(const Key('under-test')),
              matching: find.byKey(const Key('metric-card-source-option-trainer')),
            ),
          )
          .dx;

      // 16px each side — see `MetricCard._dividerGutter`'s own doc comment
      // for why 16 (not a new number: `--s-4` on the design system's own
      // 4/8/12/16/20 spacing scale). On the right, `dividerLeft` is the
      // divider CONTAINER's own outer edge, which is where its `Border`
      // (the visible rule, default `BorderSide` width 1px) is painted —
      // the padding gutter starts only after that rule, so content sits
      // `ruleWidth + gutter` from the container's own left, not `gutter`
      // alone.
      const ruleWidth = 1;
      expect(dividerLeft - columnRight, 16);
      expect(listLeft - dividerLeft, ruleWidth + 16);
    });
  });

  group('source list width cap (direct author feedback: '
      '"make the sensors list max 50% width of the parent card")', () {
    testWidgets('side-by-side: the source list never exceeds half the card content width, '
        'even with a long name that would otherwise push it wider', (tester) async {
      await pump(
        tester,
        MetricCard(
          key: const Key('under-test'),
          icon: baseCard.icon,
          iconColor: baseCard.iconColor,
          label: baseCard.label,
          value: baseCard.value,
          unit: baseCard.unit,
          sources: [
            option(id: 'trainer', label: 'Trainer', state: MetricSourceState.trainer, selected: true),
            option(
              id: 'long',
              label: 'A Very Long Sensor Display Name That Would Otherwise Crowd The Value',
              subtitle: 'An equally long subtitle sentence explaining what selecting this sensor does.',
              state: MetricSourceState.notConnected,
            ),
          ],
        ),
        // 900px harness, well over the 240px side-by-side breakpoint — see
        // the "layout: side-by-side vs picker" group above for why.
        width: 900,
      );
      await tester.pump();

      // Degrades gracefully under the cap rather than overflowing.
      expect(tester.takeException(), isNull);

      const cardPadding = 14.0;
      final cardWidth = tester.getSize(find.byKey(const Key('under-test'))).width;
      final contentWidth = cardWidth - cardPadding * 2;

      final listWidth = tester.getSize(find.byKey(const Key('metric-card-source-control'))).width;

      // Never more than half the card's own content width...
      expect(listWidth, lessThanOrEqualTo(contentWidth * 0.5));
      // ...and genuinely clamped there, not just coincidentally narrow: with
      // this much horizontal room and no cap, the list (which fills
      // whatever width it is given — see `MetricCard._sourceList`'s own
      // `SizedBox(width: double.infinity)`) would take almost everything
      // left after the compact label/value column, well past half.
      expect(listWidth, greaterThan(contentWidth * 0.35));

      final longNameText = tester.widget<Text>(
        find.text('A Very Long Sensor Display Name That Would Otherwise Crowd The Value'),
      );
      expect(longNameText.maxLines, 1);
      expect(longNameText.overflow, TextOverflow.ellipsis);
    });

    testWidgets('side-by-side: the value column takes the remaining width and the value is not clipped', (
      tester,
    ) async {
      await pump(
        tester,
        MetricCard(
          key: const Key('under-test'),
          icon: baseCard.icon,
          iconColor: baseCard.iconColor,
          label: baseCard.label,
          value: baseCard.value,
          unit: baseCard.unit,
          sources: [
            option(id: 'trainer', label: 'Trainer', state: MetricSourceState.trainer, selected: true),
            option(
              id: 'long',
              label: 'A Very Long Sensor Display Name That Would Otherwise Crowd The Value',
              state: MetricSourceState.notConnected,
            ),
          ],
        ),
        width: 900,
      );

      const cardPadding = 14.0;
      final cardWidth = tester.getSize(find.byKey(const Key('under-test'))).width;
      final contentWidth = cardWidth - cardPadding * 2;
      final columnWidth = tester.getSize(find.byKey(const Key('metric-card-label-value-column'))).width;

      // More than the column's own bare content needs (well under half at
      // this width for "HEART"/"142 bpm") — it is being handed the leftover
      // space the capped list gave up, not just sized to its own text.
      expect(columnWidth, greaterThan(contentWidth * 0.4));

      final valueText = tester.widget<Text>(find.text('142'));
      // No explicit clip/ellipsis on the hero value — nothing here truncates
      // it, and no overflow exception was thrown laying it out.
      expect(valueText.overflow, isNot(TextOverflow.ellipsis));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a single-source tile (no list at all) is unchanged by the cap', (tester) async {
      await pump(
        tester,
        MetricCard(
          key: const Key('under-test'),
          icon: baseCard.icon,
          iconColor: baseCard.iconColor,
          label: baseCard.label,
          value: baseCard.value,
          unit: baseCard.unit,
          sources: [option(id: 'trainer', label: 'Trainer', state: MetricSourceState.trainer, selected: true)],
        ),
        width: 900,
      );

      expect(find.byKey(const Key('metric-card-source-control')), findsNothing);
      expect(find.byKey(const Key('metric-card-source-divider')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('the value is fixed-width (direct author feedback: "otherwise the layout jumps around")', () {
    testWidgets('the big value carries tabularFigures so digit changes do not reflow the tile', (tester) async {
      await pump(tester, baseCard);

      final text = tester.widget<Text>(find.text('142'));
      expect(text.style?.fontFeatures, contains(const FontFeature.tabularFigures()));
    });

    testWidgets('the unit stays as-is — tabular figures are for the numeric value only', (tester) async {
      await pump(tester, baseCard);

      final text = tester.widget<Text>(find.text('bpm'));
      expect(text.style?.fontFeatures ?? const [], isNot(contains(const FontFeature.tabularFigures())));
    });
  });
}

/// The grid always lays two tiles per row — this fills the second slot so
/// the tile under test renders at its real half-width rather than the full
/// width of the harness's `SizedBox`.
class _FillerCard extends StatelessWidget {
  const _FillerCard();

  @override
  Widget build(BuildContext context) => const MetricCard(
    icon: LucideIcons.gauge,
    iconColor: Color(0xFF0EA5E9),
    label: 'SPEED',
    value: null,
    unit: 'km/h',
  );
}
