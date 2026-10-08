// Settings → Overlay: the overlay's own page, reached from the row that
// already existed (it used to push the trainer page and scroll it). A live
// preview of the pill sits on top and follows the field switches below it.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/settings/overlay_settings_page.dart';
import 'package:bike_control/pages/settings/settings_page.dart';
import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/services/overlay/trainer_overlay_service.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/widgets/overlay/trainer_overlay_view.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../helpers/fake_overlay_controller.dart';
import '../../helpers/live_trainer.dart';
import '../../widget_snapshot.dart';

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(430, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ShadcnApp(
      localizationsDelegates: [
        ...ShadcnLocalizations.localizationsDelegates,
        const OtherLocalizationsDelegate(),
        AppLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      theme: BkTheme.build(Brightness.dark),
      home: home,
    ),
  );
  await tester.pump();
}

Finder _switchFor(String title) => find.descendant(
  of: find.ancestor(of: find.text(title), matching: find.byType(Row)).first,
  matching: find.byType(Switch),
);

Future<void> main() async {
  await ensureSnapshotHarness();
  late AppLocalizations l;
  late FakeOverlayController overlay;

  setUp(() async {
    l = AppLocalizations.current;
    core.settings.setTrainerApp(MyWhoosh());
    overlay = FakeOverlayController();
    TrainerOverlayService.setForTest(overlay);
    TrainerOverlayService.debugSupportedPlatform = true;
    await core.settings.setOverlayFields({OverlayField.gearRatio, OverlayField.controls});
  });

  tearDown(() {
    TrainerOverlayService.resetForTest();
    TrainerOverlayService.debugSupportedPlatform = null;
    core.connection.devices.clear();
  });

  testWidgets('the Settings row opens the Overlay page', (tester) async {
    attachLiveTrainer();
    await _pump(
      tester,
      const Scaffold(
        child: SingleChildScrollView(padding: EdgeInsets.symmetric(horizontal: 12), child: SettingsPage()),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('settings-overlay')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(OverlaySettingsPage), findsOneWidget);
  });

  testWidgets('the preview sits on top and follows the field switches, power and cadence included', (tester) async {
    final (:proxy, :definition) = attachLiveTrainer();
    await _pump(tester, OverlaySettingsPage(device: proxy, definition: definition));

    final preview = find.byKey(const ValueKey('overlay-preview'));
    expect(preview, findsOneWidget);
    expect(find.descendant(of: preview, matching: find.byType(TrainerOverlayView)), findsOneWidget);
    expect(
      tester.getBottomLeft(preview).dy,
      lessThanOrEqualTo(tester.getTopLeft(find.text(l.overlayEnabled)).dy),
      reason: 'the preview heads the page',
    );
    // The live gear; watts and rpm only when their fields are on (off here).
    expect(find.descendant(of: preview, matching: find.text('${definition.currentGear.value}')), findsOneWidget);
    expect(find.descendant(of: preview, matching: find.textContaining('rpm')), findsNothing);

    // The fields are only offered while the overlay is on.
    expect(find.text(l.overlayFieldGearRatio), findsNothing);
    await tester.tap(_switchFor(l.overlayEnabled));
    await tester.pump();
    await tester.pump();
    expect(overlay.shows, 1);
    expect(find.text(l.overlayFieldGearRatio), findsOneWidget);
    expect(find.text(l.overlayFieldPower), findsOneWidget);
    expect(find.text(l.overlayFieldCadence), findsOneWidget);

    // Power and cadence are optional fields, and the preview follows them.
    Finder rpm() => find.descendant(of: preview, matching: find.textContaining('rpm'));
    Finder watts() => find.descendant(of: preview, matching: find.textContaining(' W'));
    await tester.tap(_switchFor(l.overlayFieldCadence));
    await tester.pump();
    await tester.pump();
    expect(rpm(), findsOneWidget);
    expect(core.settings.getOverlayFields(), contains(OverlayField.cadence));
    await tester.tap(_switchFor(l.overlayFieldPower));
    await tester.pump();
    await tester.pump();
    expect(watts(), findsOneWidget);
    await tester.tap(_switchFor(l.overlayFieldCadence));
    await tester.tap(_switchFor(l.overlayFieldPower));
    await tester.pump();
    await tester.pump();
    expect(rpm(), findsNothing);
    expect(watts(), findsNothing);

    Finder ratio() => find.descendant(of: preview, matching: find.textContaining('×'));
    Finder plus() => find.descendant(of: preview, matching: find.byIcon(LucideIcons.plus));
    expect(ratio(), findsOneWidget);
    expect(plus(), findsOneWidget);

    await tester.tap(_switchFor(l.overlayFieldGearRatio));
    await tester.pump();
    await tester.pump();
    expect(ratio(), findsNothing);

    await tester.tap(_switchFor(l.overlayFieldControls));
    await tester.pump();
    await tester.pump();
    expect(plus(), findsNothing);
    expect(core.settings.getOverlayFields(), isEmpty);
  });
}
