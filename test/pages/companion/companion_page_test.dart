// The companion page as a ride screen: buttons and ride data on a grid the
// rider arranges, a full-screen view, and − / + that shift BikeControl's own
// virtual shifting the way a controller does.
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/button_simulator.dart';
import 'package:bike_control/pages/companion/companion_layout.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/requirements/multi.dart' show Target;
import 'package:bike_control/widgets/ui/bk_page_header.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  setUp(() async {
    await core.settings.setCompanionLayout(null, landscape: false);
    await core.settings.setCompanionLayout(null, landscape: true);
  });

  void connectMyWhoosh() {
    core.settings.setTrainerApp(MyWhoosh());
    core.settings.setKeyMap(MyWhoosh());
    core.settings.setLastTarget(Target.thisDevice);
    core.settings.setMyWhooshLinkEnabled(true);
    core.whooshLink.isConnected.value = true;
    addTearDown(() {
      core.whooshLink.isConnected.value = false;
      core.settings.setMyWhooshLinkEnabled(false);
    });
  }

  /// A KICKR that BikeControl shifts itself, as with Rouvy over the bridge:
  /// no trainer app connection on this page at all.
  FitnessBikeDefinition connectVirtualShifting() {
    core.settings.setTrainerApp(Rouvy());
    core.settings.setKeyMap(Rouvy());
    final proxy =
        ProxyDevice(
            BleDevice(
              name: 'KICKR CORE',
              deviceId: '00:11:22:33:44:55',
              services: [FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID],
            ),
          )
          ..services = [BleService(FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID, [])]
          ..isConnected = true;
    final definition = FitnessBikeDefinition(
      connectedDevice: proxy.scanResult,
      connectedDeviceServices: proxy.services!,
      data: ValueNotifier(''),
    )..setMaxGear(24);
    // As a live session has it: on the page's listenable and on the
    // emulator, where a controller's shift lands.
    proxy.debugAttachFitnessBike(definition);
    proxy.emulator.composite.attach(definition);
    core.connection.devices.add(proxy);
    addTearDown(() {
      proxy.emulator.composite.detach(definition);
      proxy.debugAttachFitnessBike(null);
      core.connection.devices.remove(proxy);
    });
    return definition;
  }

  Future<void> render(
    WidgetTester tester, {
    String name = 'companion',
    double width = 414,
    double height = 860,
    bool fullScreen = false,
    Brightness brightness = Brightness.light,
  }) => captureWidget(
    tester,
    name: name,
    width: width,
    height: height,
    padding: EdgeInsets.zero,
    settle: false,
    brightness: brightness,
    outputDir: 'build/snapshots',
    builder: (_) => ButtonSimulator(startFullScreen: fullScreen),
  );

  Finder pad(InGameAction action) =>
      find.ancestor(of: find.text(action.title).first, matching: find.byType(Button)).first;

  testWidgets('with only virtual shifting, − and + shift its gears and the gear card shows', (tester) async {
    final definition = connectVirtualShifting();
    await render(tester, name: 'companion_vs');

    expect(find.text(AppLocalizations.current.trainerControlsNoConnection), findsNothing);
    final before = definition.currentGear.value;
    await tester.tap(pad(InGameAction.shiftUp));
    await tester.pump(const Duration(milliseconds: 50));
    expect(definition.currentGear.value, before + 1);
    await tester.tap(pad(InGameAction.shiftDown));
    await tester.pump(const Duration(milliseconds: 50));
    expect(definition.currentGear.value, before);
  });

  testWidgets('opened full screen from Ride: ride mode, no header, nothing else to tap', (tester) async {
    connectVirtualShifting();
    await render(tester, name: 'companion_ride_mode', fullScreen: true);

    expect(find.byType(BkPageHeader), findsNothing);
    final up = tester.getRect(pad(InGameAction.shiftUp));
    final down = tester.getRect(pad(InGameAction.shiftDown));
    expect(up.bottom, lessThan(down.top), reason: '+ on top, − at the bottom');
    expect(up.height, greaterThan(250));
    final gear = tester.getRect(find.byKey(const ValueKey('companion-info-gear')));
    expect(gear.top, greaterThan(up.bottom));
    expect(gear.bottom, lessThan(down.top));
    expect(find.text('SIM'), findsNothing, reason: 'the mode is part of the gear label, never a switch');

    await tester.tap(find.byKey(const ValueKey('companion-exit-full-screen')));
    await tester.pump();
    expect(find.byType(BkPageHeader), findsOneWidget);
  });

  testWidgets('landscape ride mode: − left, + right, readings between', (tester) async {
    connectVirtualShifting();
    await render(tester, name: 'companion_ride_mode_landscape', width: 860, height: 414, fullScreen: true);
    final up = tester.getRect(pad(InGameAction.shiftUp));
    final down = tester.getRect(pad(InGameAction.shiftDown));
    final gear = tester.getRect(find.byKey(const ValueKey('companion-info-gear')));
    expect(down.right, lessThan(gear.left));
    expect(gear.right, lessThan(up.left));
  });

  testWidgets('the full-screen button hides the page around the buttons', (tester) async {
    connectMyWhoosh();
    await render(tester);
    await tester.tap(find.byKey(const ValueKey('companion-full-screen')));
    await tester.pump();
    expect(find.byType(BkPageHeader), findsNothing);
    expect(find.text(AppLocalizations.current.keyboardShortcuts), findsNothing);
    expect(pad(InGameAction.shiftUp), findsOneWidget);
  });

  group('editing', () {
    CompanionLayout saved() =>
        CompanionLayout.tryParse(core.settings.getCompanionLayout(landscape: false)!, landscape: false)!;

    String idOf(WidgetTester tester, InGameAction action) {
      final key = tester
          .widgetList(find.ancestor(of: find.text(action.title).first, matching: find.byType(Positioned)))
          .map((w) => w.key)
          .whereType<ValueKey<String>>()
          .firstWhere((k) => k.value.startsWith('companion-tile-'));
      return key.value.substring('companion-tile-'.length);
    }

    testWidgets('a tile drags to a free spot, and the layout is saved', (tester) async {
      connectMyWhoosh();
      await render(tester, name: 'companion_editing');
      await tester.tap(find.byKey(const ValueKey('companion-edit')));
      await tester.pump();
      expect(find.text(AppLocalizations.current.companionEditHint), findsOneWidget);

      final id = idOf(tester, InGameAction.tuck);
      final before = tester.getRect(find.byKey(ValueKey('companion-tile-$id')));
      // Down a few rows, onto the empty space under the grid.
      await tester.drag(find.byKey(ValueKey('companion-move-$id')), const Offset(0, 140));
      await tester.pump();
      final after = tester.getRect(find.byKey(ValueKey('companion-tile-$id')));
      expect(after.top, greaterThan(before.top));
      expect(saved().tile(id)!.row, greaterThan(0));
    });

    testWidgets('dropping onto another tile leaves it where it was', (tester) async {
      connectMyWhoosh();
      await render(tester);
      await tester.tap(find.byKey(const ValueKey('companion-edit')));
      await tester.pump();
      final id = idOf(tester, InGameAction.shiftDown);
      final before = tester.getRect(find.byKey(ValueKey('companion-tile-$id')));
      await tester.drag(find.byKey(ValueKey('companion-move-$id')), Offset(before.width / 2, 0));
      await tester.pump();
      expect(tester.getRect(find.byKey(ValueKey('companion-tile-$id'))), before);
    });

    testWidgets('the corner handle resizes, the × removes', (tester) async {
      connectMyWhoosh();
      // Room under the tile to grow into.
      await core.settings.setCompanionLayout(
        CompanionLayout(
          landscape: false,
          tiles: const [
            CompanionTile(
              id: 'a',
              kind: CompanionTileKind.action,
              action: InGameAction.tuck,
              col: 0,
              row: 0,
              w: 4,
              h: 2,
            ),
          ],
        ).toJsonString(),
        landscape: false,
      );
      await render(tester);
      await tester.tap(find.byKey(const ValueKey('companion-edit')));
      await tester.pump();
      final id = idOf(tester, InGameAction.tuck);
      final before = tester.getRect(find.byKey(ValueKey('companion-tile-$id')));
      await tester.drag(find.byKey(ValueKey('companion-resize-$id')), const Offset(0, 120));
      await tester.pump();
      expect(tester.getRect(find.byKey(ValueKey('companion-tile-$id'))).height, greaterThan(before.height));

      await tester.tap(find.byKey(ValueKey('companion-remove-$id')));
      await tester.pump();
      expect(find.byKey(ValueKey('companion-tile-$id')), findsNothing);
      expect(saved().tileFor(InGameAction.tuck), isNull);
    });

    testWidgets('a removed button comes back from the add list', (tester) async {
      connectMyWhoosh();
      await render(tester);
      await tester.tap(find.byKey(const ValueKey('companion-edit')));
      await tester.pump();
      final id = idOf(tester, InGameAction.tuck);
      await tester.tap(find.byKey(ValueKey('companion-remove-$id')));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('companion-add')));
      await tester.pumpAndSettle();
      // Ride data needs virtual shifting: listed, but it can't be added.
      expect(find.text(AppLocalizations.current.companionRideDataHint), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('companion-add-${InGameAction.tuck.name}')));
      await tester.pumpAndSettle();
      expect(saved().tileFor(InGameAction.tuck), isNotNull);
    });

    testWidgets('ride data tiles are added while BikeControl shifts', (tester) async {
      connectVirtualShifting();
      await render(tester);
      await tester.tap(find.byKey(const ValueKey('companion-edit')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('companion-add')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('companion-add-cadence')));
      await tester.tap(find.byKey(const ValueKey('companion-add-cadence')));
      await tester.pumpAndSettle();
      expect(saved().tiles.where((t) => t.kind == CompanionTileKind.cadence), hasLength(1));
      expect(find.byKey(const ValueKey('companion-info-cadence')), findsOneWidget);
    });
  });

  testWidgets('a saved layout comes back next time', (tester) async {
    connectMyWhoosh();
    await core.settings.setCompanionLayout(
      CompanionLayout.rideMode(landscape: false, hasRideData: false).toJsonString(),
      landscape: false,
    );
    await render(tester);
    final up = tester.getRect(pad(InGameAction.shiftUp));
    final down = tester.getRect(pad(InGameAction.shiftDown));
    expect(up.bottom, lessThan(down.top));
    final tiles = find.byWidgetPredicate(
      (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('companion-tile-'),
    );
    expect(tiles, findsNWidgets(2), reason: 'only the saved − and +');
  });

  testWidgets('dark, ride mode with data → PNG', (tester) async {
    connectVirtualShifting();
    await render(tester, name: 'companion_ride_mode_dark', fullScreen: true, brightness: Brightness.dark);
    expect(find.byKey(const ValueKey('companion-info-power')), findsOneWidget);
  });
}
