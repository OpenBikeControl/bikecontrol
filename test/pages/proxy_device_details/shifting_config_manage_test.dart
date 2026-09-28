// The profile picker's New / Manage dialogs: create, duplicate, rename and
// delete a Virtual Shifting profile. They are the app's own shadcn dialogs,
// not stock Material ones (which followed the phone's brightness rather than
// the app theme).
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/models/shifting_config.dart';
import 'package:bike_control/pages/proxy_device_details/shifting_config_picker.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l10n = await AppLocalizations.load(const Locale('en'));
  const trainer = 'kickr';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
    await core.shiftingConfigs.hydrateFromSync([
      ShiftingConfig.defaults(trainerKey: trainer, name: 'Road').copyWith(isActive: true),
      ShiftingConfig.defaults(trainerKey: trainer, name: 'Gravel'),
    ]);
  });

  List<String> names() => [for (final c in core.shiftingConfigs.configsFor(trainer)) c.name];

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ShadcnApp(
        theme: BkTheme.build(Brightness.light),
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: const Scaffold(
          child: Center(
            child: SizedBox(width: 700, child: ShiftingConfigPicker(trainerKey: trainer)),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> openManage(WidgetTester tester) async {
    await tester.tap(find.text(l10n.manageAction));
    await tester.pumpAndSettle();
    expect(find.text(l10n.manageShiftingConfigs), findsOneWidget);
    expect(find.byType(material.AlertDialog), findsNothing, reason: 'the app dialog, not Material');
    expect(find.byType(material.ListTile), findsNothing);
  }

  /// Taps the labelled icon button on [profile]'s row.
  Future<void> tapRowAction(WidgetTester tester, String profile, String label) async {
    final row = find.ancestor(of: find.text(profile), matching: find.byKey(ValueKey('shifting-config-$profile')));
    await tester.tap(find.descendant(of: row, matching: find.bySemanticsLabel(label)));
    await tester.pumpAndSettle();
  }

  Future<void> enterName(WidgetTester tester, String name) async {
    expect(find.byType(material.AlertDialog), findsNothing);
    await tester.enterText(find.byType(TextField).last, name);
    await tester.tap(find.text(l10n.ok));
    await tester.pumpAndSettle();
  }

  testWidgets('New creates a profile', (tester) async {
    await pump(tester);
    await tester.tap(find.text(l10n.newAction));
    await tester.pumpAndSettle();
    expect(find.text(l10n.newShiftingConfig), findsOneWidget);
    await enterName(tester, 'Climb');
    expect(names(), contains('Climb'));
  });

  testWidgets('Cancel leaves the profiles alone', (tester) async {
    await pump(tester);
    await tester.tap(find.text(l10n.newAction));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Nope');
    await tester.tap(find.text(l10n.cancel));
    await tester.pumpAndSettle();
    expect(names(), ['Road', 'Gravel']);
  });

  testWidgets('Manage renames, duplicates and deletes', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester);
    await openManage(tester);
    expect(find.text(l10n.active), findsOneWidget, reason: 'the active profile is marked');

    await tapRowAction(tester, 'Gravel', l10n.rename);
    await enterName(tester, 'Dirt');
    expect(names(), ['Road', 'Dirt']);
    expect(find.text('Dirt'), findsWidgets, reason: 'the list refreshes in place');

    await tapRowAction(tester, 'Road', l10n.duplicate);
    await enterName(tester, 'Road 2');
    expect(names(), containsAll(['Road', 'Dirt', 'Road 2']));

    await tapRowAction(tester, 'Dirt', l10n.delete);
    expect(names(), isNot(contains('Dirt')));

    await tester.tap(find.text(l10n.close));
    await tester.pumpAndSettle();
    expect(find.text(l10n.manageShiftingConfigs), findsNothing);
    handle.dispose();
  });

  testWidgets('the last profile cannot be deleted', (tester) async {
    await core.shiftingConfigs.remove(trainerKey: trainer, name: 'Gravel');
    final handle = tester.ensureSemantics();
    await pump(tester);
    await openManage(tester);
    expect(find.bySemanticsLabel(l10n.delete), findsNothing);
    handle.dispose();
  });
}
