// The Activity tab: the session's log as a grouped list ("Last minute",
// "Earlier"), errors in red with their fix as a link, Clear, a note on how
// much it keeps, and a friendly empty state.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/activity/activity_log.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

final DateTime _now = DateTime(2026, 9, 29, 10);

Future<ActivityLogController> _pumpLog(
  WidgetTester tester, {
  ActivityFixAction? fixAction,
}) async {
  tester.view.physicalSize = const Size(430, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = ActivityLogController();
  await tester.pumpWidget(
    ShadcnApp(
      localizationsDelegates: [
        ...ShadcnLocalizations.localizationsDelegates,
        const OtherLocalizationsDelegate(),
        AppLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      theme: BkTheme.build(Brightness.dark),
      home: Scaffold(
        child: SingleChildScrollView(
          child: Column(
            children: [
              ActivityClearButton(controller: controller),
              ActivityLogView(controller: controller, fixAction: fixAction ?? (_) => null),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return controller;
}

/// Unmounts the log, then stops its clock — a periodic timer left running
/// fails the test.
Future<void> _done(WidgetTester tester, ActivityLogController log) async {
  await tester.pumpWidget(const SizedBox());
  log.dispose();
}

const _plus = ControllerButton('shiftUpRight', action: InGameAction.shiftUp);

void main() {
  late AppLocalizations l;

  setUp(() async {
    await AppLocalizations.load(const Locale('en'));
    l = AppLocalizations.current;
    activityLogClock = () => _now;
  });

  tearDown(() => activityLogClock = DateTime.now);

  testWidgets('empty: says how something gets here, and nothing to clear', (tester) async {
    final log = await _pumpLog(tester);

    expect(find.text(l.activityEmptyTitle), findsOneWidget);
    expect(find.text(l.activityEmptyBody), findsOneWidget);
    expect(find.text(l.activityFooter(ActivityLogController.maxEntries)), findsNothing);
    final clear = tester.widget<Button>(find.byKey(const ValueKey('activity-clear')));
    expect(clear.onPressed, isNull);
    await _done(tester, log);
  });

  testWidgets('entries sit under "Last minute" or "Earlier", newest first, with the footer', (tester) async {
    final log = await _pumpLog(tester);
    log.insert(
      ActivityEntry(
        time: _now.subtract(const Duration(minutes: 3)),
        alertMessage: 'Connected to MyWhoosh',
        alertLevel: null,
      ),
    );
    log.insert(
      ActivityEntry(
        button: _plus,
        time: _now.subtract(const Duration(seconds: 6)),
        result: const Success('Shifted up to gear 12', button: _plus),
        deviceName: 'Zwift Play',
      ),
    );
    await tester.pumpAndSettle();

    final lastMinute = find.text(l.activityLastMinute.toUpperCase());
    final earlier = find.text(l.activityEarlier.toUpperCase());
    expect(lastMinute, findsOneWidget);
    expect(earlier, findsOneWidget);
    expect(tester.getTopLeft(lastMinute).dy, lessThan(tester.getTopLeft(find.text('Shifted up to gear 12')).dy));
    expect(tester.getTopLeft(find.text('Shifted up to gear 12')).dy, lessThan(tester.getTopLeft(earlier).dy));
    expect(tester.getTopLeft(earlier).dy, lessThan(tester.getTopLeft(find.text('Connected to MyWhoosh')).dy));
    // Which button, on which controller.
    expect(find.text('${_plus.displayName} · Zwift Play'), findsOneWidget);
    expect(find.text(l.activityFooter(ActivityLogController.maxEntries)), findsOneWidget);
    expect(find.text(l.activityEmptyTitle), findsNothing);
    await _done(tester, log);
  });

  testWidgets('an error reads in red and offers its fix as a link', (tester) async {
    var fixed = 0;
    final log = await _pumpLog(
      tester,
      fixAction: (entry) => entry.isError ? ('Configure button mapping', (_) => fixed++) : null,
    );
    log.insert(
      ActivityEntry(
        button: _plus,
        time: _now,
        result: const Error('Could not perform Z: No action assigned', button: _plus, type: ErrorType.noActionAssigned),
      ),
    );
    await tester.pumpAndSettle();

    final message = tester.widget<Text>(find.text('Could not perform Z: No action assigned'));
    final danger = BkStatusColors.of(tester.element(find.text('Could not perform Z: No action assigned'))).danger;
    expect(message.style?.color, danger);

    await tester.tap(find.text('Configure button mapping'));
    await tester.pump();
    expect(fixed, 1);
    await _done(tester, log);
  });

  testWidgets('Clear empties the log and brings the empty state back', (tester) async {
    final log = await _pumpLog(tester);
    log.insert(
      ActivityEntry(
        button: _plus,
        time: _now,
        result: const Success('Shifted up to gear 12', button: _plus),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(l.activityEmptyTitle), findsNothing);

    await tester.tap(find.byKey(const ValueKey('activity-clear')));
    await tester.pumpAndSettle();

    expect(log.entries, isEmpty);
    expect(find.text('Shifted up to gear 12'), findsNothing);
    expect(find.text(l.activityEmptyTitle), findsOneWidget);
    await _done(tester, log);
  });

  testWidgets('an entry moves from "Last minute" to "Earlier" as it ages', (tester) async {
    final log = await _pumpLog(tester);
    log.insert(
      ActivityEntry(
        button: _plus,
        time: _now,
        result: const Success('Shifted up to gear 12', button: _plus),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(l.activityLastMinute.toUpperCase()), findsOneWidget);

    activityLogClock = () => _now.add(const Duration(minutes: 2));
    log.clock.value = activityLogClock();
    await tester.pump();

    expect(find.text(l.activityLastMinute.toUpperCase()), findsNothing);
    expect(find.text(l.activityEarlier.toUpperCase()), findsOneWidget);
    await _done(tester, log);
  });
}
