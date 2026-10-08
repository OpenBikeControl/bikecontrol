// The Click V2 / Ride V2 unlock status inside the controller card: no nested
// bordered box, the state as a status dot plus words, pill buttons, and the
// debug reset carrying a reset icon (not the language glyph).
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/ui/bk_pill_button.dart';
import 'package:bike_control/widgets/ui/bk_status_dot.dart';
import 'package:bike_control/widgets/ui/warning.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:prop/prop.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

ZwiftClickV2 _clickV2() => ZwiftClickV2(BleDevice(deviceId: 'click-v2', name: 'Zwift Click'))..isConnected = true;

Widget _host(Widget Function(BuildContext context) builder) => ShadcnApp(
  localizationsDelegates: const [AppLocalizations.delegate],
  supportedLocales: const [Locale('en')],
  home: Scaffold(
    child: SingleChildScrollView(
      child: SizedBox(width: 400, child: Builder(builder: builder)),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.actionHandler = StubActions();
    core.settings.prefs = await SharedPreferences.getInstance();
    propPrefs.initialize(core.settings.prefs);
    await AppLocalizations.load(const Locale('en'));
    await initializeDateFormatting();
  });

  testWidgets('a locked controller shows a danger status dot and a pill "Unlock now", no nested box', (tester) async {
    final click = _clickV2();
    await tester.pumpWidget(_host((context) => Column(children: click.showAdditionalInformation(context))));
    await tester.pump();

    expect(find.byType(Warning), findsNothing);
    final dot = tester.widget<BkStatusDot>(find.byType(BkStatusDot));
    expect(dot.label, AppLocalizations.current.unlock_deviceIsCurrentlyLocked);
    expect(dot.tone, BkStatusTone.danger);
    expect(
      find.ancestor(of: find.text(AppLocalizations.current.unlock_unlockNow), matching: find.byType(BkPillButton)),
      findsOneWidget,
    );
    final unlockNow = tester.getSize(
      find.ancestor(of: find.text(AppLocalizations.current.unlock_unlockNow), matching: find.byType(BkPillButton)),
    );
    expect(unlockNow.height, greaterThanOrEqualTo(48));
  });

  testWidgets('an unlocked controller shows a success status dot, a pill "Unlock again" and a reset icon', (
    tester,
  ) async {
    final click = _clickV2();
    propPrefs.setZwiftClickV2LastUnlock('click-v2', DateTime.now(), keyPrefix: click.unlockKeyPrefix);
    await tester.pumpWidget(_host((context) => Column(children: click.showAdditionalInformation(context))));
    await tester.pump();

    expect(find.byType(Warning), findsNothing);
    final dot = tester.widget<BkStatusDot>(find.byType(BkStatusDot));
    expect(dot.label, contains('Unlocked until around'));
    expect(dot.tone, BkStatusTone.success);
    expect(
      find.ancestor(of: find.text(AppLocalizations.current.unlockAgain), matching: find.byType(BkPillButton)),
      findsOneWidget,
    );
    // The debug-only reset (tests run in debug mode).
    expect(find.byIcon(LucideIcons.languages), findsNothing);
    expect(find.byIcon(LucideIcons.rotateCcw), findsOneWidget);
  });
}
