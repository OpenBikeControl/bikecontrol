import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/utils/actions/base_actions.dart' show StubActions;
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/widgets/controller/trigger_conflict_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Choosing "Replace" in the one-action-per-button dialog wipes the button's
/// other actions. The dialog used to talk about "trigger types" and never
/// said which action would go; now it names each one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Keymap keymap;
  const button = ZwiftButtons.y;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
    await AppLocalizations.load(const Locale('en'));
    final app = CustomApp(profileName: 'Conflict');
    keymap = app.keymap
      ..keyPairs.add(
        KeyPair(buttons: [button], physicalKey: null, logicalKey: null, inGameAction: InGameAction.shiftUp),
      );
    core.actionHandler.init(app);
  });

  test('lists the actions replacing would remove, by trigger', () {
    expect(actionsRemovedByReplacing(keymap, button, ButtonTrigger.doubleClick), {
      ButtonTrigger.singleClick: InGameAction.shiftUp.title,
    });
    // The trigger being edited keeps its own action.
    expect(actionsRemovedByReplacing(keymap, button, ButtonTrigger.singleClick), isEmpty);
  });

  testWidgets('the dialog names what Replace removes', (tester) async {
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [
          ...ShadcnLocalizations.localizationsDelegates,
          OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) => buildTriggerConflictDialog(
            context: context,
            trigger: ButtonTrigger.doubleClick,
            offerPro: true,
            removes: actionsRemovedByReplacing(keymap, button, ButtonTrigger.doubleClick),
            onResolved: (_) {},
          ),
        ),
      ),
    );
    final l = AppLocalizations.current;
    expect(
      find.text(l.triggerConflictRemoves(ButtonTrigger.singleClick.title, InGameAction.shiftUp.title)),
      findsOneWidget,
    );
  });
}
