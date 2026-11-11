import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/button_edit.dart';
import 'package:bike_control/utils/actions/base_actions.dart' show StubActions;
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/host_platform.dart';
import 'package:bike_control/utils/keymap/action_groups.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/training_peaks.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:bike_control/widgets/keymap/action_group_title.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

/// The action picker lists a trainer app's actions by what they are for
/// (gears, trainer, navigate, …), not under the connection that carries them.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      anonKey: 'grouped-actions-test-anon-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        detectSessionInUri: false,
        autoRefreshToken: false,
      ),
    );
  });

  setUp(() async {
    debugHostPlatformOverride = TargetPlatform.iOS;
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
    core.settings.setTrainerApp(TrainingPeaks());
    await core.settings.setLastTarget(Target.thisDevice);
    await core.settings.setObpMdnsEnabled(true);
    core.actionHandler.init(TrainingPeaks());
  });

  tearDown(() => debugHostPlatformOverride = null);

  Future<void> pumpEditor(WidgetTester tester, {Size size = const Size(400, 3000), KeyPair? keyPair}) async {
    await AppLocalizations.load(const Locale('en'));
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [
          ...ShadcnLocalizations.localizationsDelegates,
          OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        locale: const Locale('en'),
        theme: ThemeData(colorScheme: ColorSchemes.darkZinc, radius: 0.7),
        home: Align(
          alignment: Alignment.topLeft,
          child: ButtonEditPage(
            device: ZwiftRide(BleDevice(name: 'Zwift Ride', deviceId: 'grouped-actions-ride')),
            keyPair: keyPair ?? KeyPair(buttons: [ZwiftButtons.a], physicalKey: null, logicalKey: null),
            keymap: TrainingPeaks().keymap,
            trigger: ButtonTrigger.singleClick,
            onUpdate: () {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('actions sit under intent groups, not under the connection', (tester) async {
    await pumpEditor(tester);
    final groups = tester.widgetList<ActionGroupTitle>(find.byType(ActionGroupTitle)).map((t) => t.group).toList();
    expect(groups, containsAllInOrder([ActionGroup.gears, ActionGroup.trainer, ActionGroup.navigate]));
    expect(find.text('Gears'), findsOneWidget);
    expect(find.text('Navigate'), findsOneWidget);
    expect(find.text('OpenBikeControl actions'), findsNothing);
  });

  testWidgets('the trainer app\'s actions carry their translated names', (tester) async {
    await pumpEditor(tester);
    expect(find.text(InGameAction.shiftUp.title), findsOneWidget);
    expect(find.text('Left/Look Left'), findsNothing);
  });

  testWidgets('the head says what the click does now', (tester) async {
    await pumpEditor(
      tester,
      keyPair: KeyPair(
        buttons: [ZwiftButtons.a],
        physicalKey: null,
        logicalKey: null,
        inGameAction: InGameAction.shiftUp,
      ),
    );
    expect(find.textContaining('Now: '), findsOneWidget);
  });

  testWidgets('MyWhoosh\'s weak actions are marked, with one note per group, not one per card', (tester) async {
    core.settings.setTrainerApp(MyWhoosh());
    await core.settings.setObpBleEnabled(true);
    core.actionHandler.init(MyWhoosh());
    await pumpEditor(tester);
    final notes = find.text(AppLocalizations.current.markedActionsNotWellSupportedByMyWhoosh);
    expect(notes, findsWidgets);
    expect(
      notes.evaluate().length,
      lessThanOrEqualTo(tester.widgetList(find.byType(ActionGroupTitle)).length),
    );
    expect(find.text(AppLocalizations.current.notWellSupportedByMyWhoosh), findsNothing);
  });

  testWidgets('a one-line card is as tall as a two-line one', (tester) async {
    await pumpEditor(tester, size: const Size(390, 3000));
    final line = tester.getSize(find.text(InGameAction.lap.title)).height;
    // The title area of a card whose name fits one line still takes two.
    final titleArea = find.ancestor(of: find.text(InGameAction.lap.title), matching: find.byType(Stack)).first;
    expect(tester.getSize(titleArea).height, 2 * line);
  });

  testWidgets('no section mixes half- and full-width cards', (tester) async {
    core.settings.setTrainerApp(MyWhoosh());
    await core.settings.setObpBleEnabled(true);
    core.actionHandler.init(MyWhoosh());
    await pumpEditor(tester, size: const Size(390, 3000));
    final sections = find.descendant(of: find.byType(ButtonEditPage), matching: find.byType(Wrap));
    expect(sections, findsWidgets);
    for (final wrap in tester.widgetList<Wrap>(sections)) {
      final widths = wrap.children.whereType<SizedBox>().map((b) => b.width).toSet();
      expect(widths, hasLength(1), reason: 'cards of one section: $widths');
    }
  });
}
