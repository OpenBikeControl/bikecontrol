import 'dart:ui' show SemanticsFlag;
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/services/network_self_test/network_check.dart';
import 'package:bike_control/services/network_self_test/network_probe_context.dart';
import 'package:bike_control/widgets/network_check_row.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../widget_snapshot.dart';

/// Pumps [child] inside a real [ShadcnApp] with the localization delegates
/// the row needs (it reads `AppLocalizations`, unlike `DiagnosticsSection`).
Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    ShadcnApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: [
        ...ShadcnLocalizations.localizationsDelegates,
        const OtherLocalizationsDelegate(),
        AppLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      home: Scaffold(child: child),
    ),
  );
}

Future<void> main() async {
  await ensureSnapshotHarness();

  testWidgets('a pass row shows no fix button', (tester) async {
    await _pump(
      tester,
      const NetworkCheckRow(
        check: NetworkCheck(id: NetworkCheckId.methodListening, verdict: NetworkVerdict.pass),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Button), findsNothing);
  });

  testWidgets('a fail row shows at most two fix buttons and tapping one fires onFix with the id', (tester) async {
    NetworkFixId? tapped;
    await _pump(
      tester,
      NetworkCheckRow(
        check: const NetworkCheck(
          id: NetworkCheckId.methodListening,
          verdict: NetworkVerdict.fail,
          fixes: [NetworkFixId.restartMethod, NetworkFixId.openFirewallSettings, NetworkFixId.switchToLocal],
        ),
        onFix: (fix) => tapped = fix,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Button), findsNWidgets(2));

    await tester.tap(find.byType(Button).first);
    await tester.pump();

    expect(tapped, NetworkFixId.restartMethod);
  });

  testWidgets('detail expands on chevron tap', (tester) async {
    await _pump(
      tester,
      const NetworkCheckRow(
        check: NetworkCheck(
          id: NetworkCheckId.tcpSelfConnect,
          verdict: NetworkVerdict.warn,
          detail: {'latencyMs': '42'},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('latencyMs'), findsNothing);

    // The whole row is the disclosure now, not a separate chevron button.
    await tester.tap(find.text(networkCheckTitle(
      tester.element(find.byType(NetworkCheckRow)),
      NetworkCheckId.tcpSelfConnect,
    )));
    await tester.pumpAndSettle();

    expect(find.textContaining('latencyMs'), findsOneWidget);
  });

  testWidgets('the expandable row is a button that reports its expanded state', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      const NetworkCheckRow(
        check: NetworkCheck(
          id: NetworkCheckId.tcpSelfConnect,
          verdict: NetworkVerdict.warn,
          detail: {'latencyMs': '42'},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final title = networkCheckTitle(tester.element(find.byType(NetworkCheckRow)), NetworkCheckId.tcpSelfConnect);
    final row = find.semantics.byPredicate((n) => n.label.contains(title) && n.hasFlag(SemanticsFlag.isButton));

    expect(row, containsSemantics(isButton: true, hasExpandedState: true, isExpanded: false, hasTapAction: true, isFocusable: true));
    tester.semantics.tap(row);
    await tester.pumpAndSettle();
    expect(row, containsSemantics(hasExpandedState: true, isExpanded: true));
    handle.dispose();
  });

  testWidgets('running shows the small progress indicator', (tester) async {
    await _pump(
      tester,
      const NetworkCheckRow(
        check: NetworkCheck(id: NetworkCheckId.guidedWatch, verdict: NetworkVerdict.unknown),
        running: true,
      ),
    );
    // The spinner animates forever; pumpAndSettle would hang.
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(SmallProgressIndicator), findsOneWidget);
  });

  testWidgets('watch mode shows the Skip button and fires onSkipWatch', (tester) async {
    var skipped = false;
    await _pump(
      tester,
      NetworkCheckRow(
        check: const NetworkCheck(id: NetworkCheckId.guidedWatch, verdict: NetworkVerdict.unknown),
        running: true,
        watch: const WatchProgress(browsed: false, resolved: false, addressAsks: 0, connected: false, remaining: Duration(seconds: 30)),
        onSkipWatch: () => skipped = true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Skip'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(skipped, isTrue);
  });

  testWidgets('isFixDisabled greys out just the fixes it names', (tester) async {
    NetworkFixId? tapped;
    await _pump(
      tester,
      NetworkCheckRow(
        check: const NetworkCheck(
          id: NetworkCheckId.tcpSelfConnect,
          verdict: NetworkVerdict.fail,
          fixes: [NetworkFixId.restartMethod, NetworkFixId.openFirewallSettings],
        ),
        onFix: (fix) => tapped = fix,
        isFixDisabled: (fix) => fix == NetworkFixId.restartMethod,
      ),
    );
    await tester.pumpAndSettle();

    final buttons = tester.widgetList<Button>(find.byType(Button)).toList();
    expect(buttons, hasLength(2));
    expect(buttons[0].onPressed, isNull, reason: 'restartMethod is disabled by the predicate');
    expect(buttons[1].onPressed, isNotNull);

    await tester.tap(find.byType(Button).first, warnIfMissed: false);
    await tester.pump();
    expect(tapped, isNull, reason: 'a disabled fix button must not fire onFix');

    await tester.tap(find.byType(Button).last);
    await tester.pump();
    expect(tapped, NetworkFixId.openFirewallSettings);
  });

  testWidgets('watch mode shows the localized remaining countdown', (tester) async {
    await _pump(
      tester,
      NetworkCheckRow(
        check: const NetworkCheck(id: NetworkCheckId.guidedWatch, verdict: NetworkVerdict.unknown),
        running: true,
        watch: const WatchProgress(browsed: false, resolved: false, addressAsks: 0, connected: false, remaining: Duration(seconds: 42)),
        onSkipWatch: () {},
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final l10n = AppLocalizations.of(tester.element(find.byType(NetworkCheckRow)));
    expect(find.text(l10n.networkWatchRemaining(42)), findsOneWidget);
  });
}
