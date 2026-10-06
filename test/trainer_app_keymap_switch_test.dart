import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/utils/actions/base_actions.dart' show StubActions;
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:bike_control/utils/keymap/manager.dart';
import 'package:bike_control/utils/trainer_setup.dart';
import 'package:bike_control/widgets/keymap/trainer_app_keymap_prompt.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Editing one button copies the trainer app's built-in mapping into the
/// rider's own. Switching trainer app afterwards used to keep that copy
/// without a word — so Zwift got MyWhoosh's shortcuts. Now the switch asks,
/// unless the copy was made from the app being picked.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
  });

  /// The rider picks MyWhoosh, then edits a button (which makes the copy).
  Future<void> editAButtonOnMyWhoosh() async {
    await applyTrainerAppSelection(MyWhoosh());
    await KeymapManager().duplicate(null, 'MyWhoosh', skipName: 'MyWhoosh (Copy)');
    expect(core.actionHandler.supportedApp, isA<CustomApp>());
  }

  test('a copy remembers the app it was made from', () async {
    await editAButtonOnMyWhoosh();
    expect(core.settings.getCustomKeymapOrigin('MyWhoosh (Copy)'), 'MyWhoosh');
  });

  test('switching to another app asks; switching to the same app does not', () async {
    await editAButtonOnMyWhoosh();
    expect(customKeymapToConfirmFor(Zwift()), 'MyWhoosh (Copy)');
    expect(customKeymapToConfirmFor(MyWhoosh()), isNull);
  });

  test("using the new app's buttons switches the mapping and keeps the copy around", () async {
    await editAButtonOnMyWhoosh();
    await applyTrainerAppSelection(Zwift(), keymapChoice: KeymapSwitchChoice.useAppButtons);
    expect(core.actionHandler.supportedApp, isA<Zwift>());
    expect(core.settings.getKeyMap(), isA<Zwift>());
    expect(core.settings.getCustomAppProfiles(), contains('MyWhoosh (Copy)'));
  });

  test('keeping my buttons leaves the copy active', () async {
    await editAButtonOnMyWhoosh();
    await applyTrainerAppSelection(Rouvy(), keymapChoice: KeymapSwitchChoice.keepCustom);
    expect(core.actionHandler.supportedApp?.name, 'MyWhoosh (Copy)');
    expect(core.settings.getTrainerApp(), isA<Rouvy>());
  });

  test('a copy saved before origins were recorded is recognised by its name', () async {
    SharedPreferences.setMockInitialValues({
      'app': 'MyWhoosh (Copy)',
      'customapp_MyWhoosh (Copy)': <String>[],
    });
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler.init(core.settings.getKeyMap());
    expect(customKeymapToConfirmFor(MyWhoosh()), isNull);
    expect(customKeymapToConfirmFor(Zwift()), 'MyWhoosh (Copy)');
  });

  test('a copy of a copy, or a renamed copy, keeps the original app', () async {
    await editAButtonOnMyWhoosh();
    await KeymapManager().duplicate(null, 'MyWhoosh (Copy)', skipName: 'Race');
    expect(core.settings.getCustomKeymapOrigin('Race'), 'MyWhoosh');

    // Renaming is a copy under the new name, then deleting the old one.
    await core.settings.duplicateCustomAppProfile('Race', 'Sprint');
    await core.settings.deleteCustomAppProfile('Race');
    expect(core.settings.getCustomKeymapOrigin('Sprint'), 'MyWhoosh');
    expect(core.settings.getCustomKeymapOrigin('Race'), isNull);
  });

  testWidgets('the prompt defaults to the new app and can keep the custom buttons', (tester) async {
    await editAButtonOnMyWhoosh();
    KeymapSwitchChoice? choice;
    var asked = false;
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          child: Builder(
            builder: (context) => Button.primary(
              onPressed: () async {
                choice = await askKeymapForTrainerApp(context, Zwift());
                asked = true;
              },
              child: const Text('pick'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('pick'));
    await tester.pumpAndSettle();
    final l = AppLocalizations.current;
    final useNew = find.text(l.keymapSwitchUseAppButtons('Zwift'));
    expect(useNew, findsOneWidget);
    expect(find.ancestor(of: useNew, matching: find.byType(PrimaryButton)), findsOneWidget);
    await tester.tap(find.text(l.keymapSwitchKeepCustom));
    await tester.pumpAndSettle();
    expect(asked, isTrue);
    expect(choice, KeymapSwitchChoice.keepCustom);
  });

  testWidgets('no prompt when the copy belongs to the picked app', (tester) async {
    await editAButtonOnMyWhoosh();
    KeymapSwitchChoice? choice;
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(
          child: Builder(
            builder: (context) => Button.primary(
              onPressed: () async => choice = await askKeymapForTrainerApp(context, MyWhoosh()),
              child: const Text('pick'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('pick'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(choice, KeymapSwitchChoice.keepCustom);
  });
}
