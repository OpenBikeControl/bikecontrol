// The Virtual Shifting profile picker is one row: the profile dropdown plus
// "New" and "Manage". On a 360–390 dp phone the two labelled buttons ate
// most of the settings section's width and the dropdown — the thing the
// rider actually reads — shrank to a few characters. Below a width
// threshold the buttons now stack vertically at equal width beside the
// dropdown; above it the single row is unchanged.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/models/shifting_config.dart';
import 'package:bike_control/pages/proxy_device_details/shifting_config_picker.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l10n = await AppLocalizations.load(const Locale('en'));

  // Real font metrics: flutter_test's fallback font renders every glyph as a
  // wide box, which alone makes "Manage" ~1.6x its shipped width and would
  // skew the share-of-row assertion below. (golden_screenshot's tree-scanning
  // tester.loadAssets() did not take effect here; loading up front does.)
  setUpAll(loadAppFonts);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
  });

  Future<void> pumpAt(WidgetTester tester, double width) async {
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(
          child: Center(
            child: SizedBox(
              width: width,
              child: const ShiftingConfigPicker(trainerKey: 'kickr'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  // The buttons are found by their label; the dropdown is the one Select in
  // the tree.
  Rect buttonRect(WidgetTester tester, String label) =>
      tester.getRect(find.ancestor(of: find.text(label), matching: find.byType(Button)).first);

  testWidgets('narrow: New and Manage stack at equal width and the dropdown keeps most of the row', (tester) async {
    const width = 320.0;
    await pumpAt(tester, width);

    final newRect = buttonRect(tester, l10n.newAction);
    final manageRect = buttonRect(tester, l10n.manageAction);
    expect(newRect.left, manageRect.left, reason: 'stacked buttons share a left edge');
    expect(newRect.width, manageRect.width, reason: 'stacked buttons stretch to the same width');
    expect(newRect.top, isNot(manageRect.top), reason: 'stacked, not side by side');

    final selectRect = tester.getRect(find.byType(Select<ShiftingConfig>));
    expect(selectRect.width, greaterThan(width / 2), reason: 'the dropdown gets the larger share');
    // The stack must not expand to the page's height and leave the dropdown
    // floating in the middle of it: it is centred on the two buttons.
    final stackMiddle = (newRect.top + manageRect.bottom) / 2;
    expect(selectRect.center.dy, moreOrLessEquals(stackMiddle, epsilon: 2));
  });

  testWidgets('wide: dropdown, New and Manage sit on one row', (tester) async {
    await pumpAt(tester, 700);

    final newRect = buttonRect(tester, l10n.newAction);
    final manageRect = buttonRect(tester, l10n.manageAction);
    final selectRect = tester.getRect(find.byType(Select<ShiftingConfig>));
    expect(newRect.top, manageRect.top, reason: 'single row');
    // The Row centers its children; the dropdown and the buttons differ in
    // height by a pixel or two, so compare centres rather than tops.
    expect(selectRect.center.dy, moreOrLessEquals(newRect.center.dy, epsilon: 2));
    expect(newRect.left, lessThan(manageRect.left), reason: 'New comes before Manage');
    expect(selectRect.right, lessThanOrEqualTo(newRect.left), reason: 'dropdown sits left of the buttons');
  });
}
