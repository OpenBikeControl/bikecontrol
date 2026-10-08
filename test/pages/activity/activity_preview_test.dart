// Ride's latest-events preview (its right column from 840): the section header with See all, then the newest few
// entries — or, before anything has happened, the log's own empty state, so
// the column never reads as a blank gap.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/activity/activity_log.dart';
import 'package:bike_control/pages/activity/activity_preview.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

final DateTime _now = DateTime(2026, 9, 29, 10);
const _plus = ControllerButton('shiftUpRight', action: InGameAction.shiftUp);

void main() {
  late AppLocalizations l;

  setUp(() async {
    await AppLocalizations.load(const Locale('en'));
    l = AppLocalizations.current;
    activityLogClock = () => _now;
  });
  tearDown(() => activityLogClock = DateTime.now);

  Future<ActivityLogController> pump(WidgetTester tester, {ActivityFixAction? fixAction}) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final log = ActivityLogController();
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
            child: RideActivityPreview(controller: log, onSeeAll: () {}, fixAction: fixAction ?? (_) => null),
          ),
        ),
      ),
    );
    await tester.pump();
    return log;
  }

  Future<void> done(WidgetTester tester, ActivityLogController log) async {
    await tester.pumpWidget(const SizedBox());
    log.dispose();
  }

  testWidgets('empty: the header and the log\'s empty state, not nothing', (tester) async {
    final log = await pump(tester);
    expect(find.text(l.activity.toUpperCase()), findsOneWidget);
    expect(find.byType(ActivityEmptyState), findsOneWidget);
    await done(tester, log);
  });

  testWidgets('entries replace the empty state as they arrive', (tester) async {
    final log = await pump(tester);
    log.insert(
      ActivityEntry(
        button: _plus,
        time: _now.subtract(const Duration(seconds: 6)),
        result: const Success('Shifted up to gear 12', button: _plus),
        deviceName: 'Zwift Play',
      ),
    );
    await tester.pump();
    expect(find.byType(ActivityEmptyState), findsNothing);
    expect(find.byType(ActivityRow), findsOneWidget);
    await done(tester, log);
  });

  testWidgets('an error row carries its fix link, the same row as the Activity tab', (tester) async {
    var fixed = 0;
    final log = await pump(
      tester,
      fixAction: (entry) => entry.isError ? ('Configure button mapping', (_) => fixed++) : null,
    );
    log.insert(
      ActivityEntry(
        button: _plus,
        time: _now,
        result: const Error('Could not perform Z: No action assigned', button: _plus, type: ErrorType.noActionAssigned),
        deviceName: 'Zwift Play',
      ),
    );
    await tester.pump();
    // Identical to the Activity tab's row: the button and controller line too.
    expect(find.text('${_plus.displayName} · Zwift Play'), findsOneWidget);
    await tester.tap(find.text('Configure button mapping'));
    await tester.pump();
    expect(fixed, 1);
    await done(tester, log);
  });
}
