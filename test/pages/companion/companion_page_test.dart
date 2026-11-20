// The companion page as a ride screen: buttons and ride data on a grid the
// rider arranges, a full-screen view, and − / + that shift BikeControl's own
// virtual shifting the way a controller does.
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/button_simulator.dart';
import 'package:bike_control/pages/companion/companion_layout.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/actions/desktop.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/utils/requirements/multi.dart' show Target;
import 'package:bike_control/widgets/ui/bk_page_header.dart';
import 'package:bike_control/widgets/ui/connection_method.dart' show ConnectionMethodWithoutSwitch;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/services.dart' show PhysicalKeyboardKey;
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

  /// Only [action], at the top left: room around it to move and grow.
  Future<void> seedOne(InGameAction action) => core.settings.setCompanionLayout(
    CompanionLayout(
      landscape: false,
      tiles: [
        CompanionTile(id: 'a', kind: CompanionTileKind.action, action: action, col: 0, row: 0, w: 4, h: 2),
      ],
    ).toJsonString(),
    landscape: false,
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
      await seedOne(InGameAction.tuck);
      await render(tester);
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
      // Up onto the + above it.
      await tester.drag(find.byKey(ValueKey('companion-move-$id')), Offset(0, -before.height / 2));
      await tester.pump();
      expect(tester.getRect(find.byKey(ValueKey('companion-tile-$id'))), before);
    });

    testWidgets('the corner handle resizes, the × removes', (tester) async {
      connectMyWhoosh();
      await seedOne(InGameAction.tuck);
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
      // Below ride mode's − and +, a scroll away.
      await tester.ensureVisible(find.byKey(ValueKey('companion-remove-$id')));
      await tester.pumpAndSettle();
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
      await tester.ensureVisible(find.byKey(const ValueKey('companion-add-ergTarget')));
      await tester.tap(find.byKey(const ValueKey('companion-add-ergTarget')));
      await tester.pumpAndSettle();
      expect(saved().tiles.where((t) => t.kind == CompanionTileKind.ergTarget), hasLength(1));
      expect(find.byKey(const ValueKey('companion-info-ergTarget')), findsOneWidget);
    });
  });

  testWidgets('one layout: edit gives add, reset and done, no layout switch', (tester) async {
    connectMyWhoosh();
    await render(tester);
    expect(find.byKey(const ValueKey('companion-layouts')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('companion-edit')));
    await tester.pump();
    expect(find.byKey(const ValueKey('companion-add')), findsOneWidget);
    expect(find.byKey(const ValueKey('companion-done')), findsOneWidget);
    expect(find.byKey(const ValueKey('companion-layouts')), findsNothing);

    await seedOne(InGameAction.tuck);
    await tester.tap(find.byKey(const ValueKey('companion-reset')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('companion-reset-confirm')));
    await tester.pumpAndSettle();
    expect(core.settings.getCompanionLayout(landscape: false), isNull);
  });

  testWidgets('ride mode first: − and + fill the screen, the other buttons below', (tester) async {
    connectMyWhoosh();
    await render(tester);
    final up = tester.getRect(pad(InGameAction.shiftUp));
    final down = tester.getRect(pad(InGameAction.shiftDown));
    expect(up.bottom, lessThan(down.top));
    expect(tester.getRect(pad(InGameAction.tuck)).top, greaterThan(down.bottom));
  });

  testWidgets('while editing, the mouse wheel still scrolls the page', (tester) async {
    connectMyWhoosh();
    await render(tester);
    await tester.tap(find.byKey(const ValueKey('companion-edit')));
    await tester.pump();
    final before = tester.getRect(pad(InGameAction.shiftUp)).top;
    final at = tester.getCenter(pad(InGameAction.shiftUp));
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(at));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, 300)));
    await tester.pump();
    expect(tester.getRect(pad(InGameAction.shiftUp)).top, lessThan(before));
  });

  testWidgets('a reading shrinks to a single row', (tester) async {
    connectVirtualShifting();
    await core.settings.setCompanionLayout(
      CompanionLayout(
        landscape: false,
        tiles: const [CompanionTile(id: 'c', kind: CompanionTileKind.cadence, col: 0, row: 0, w: 4, h: 2)],
      ).toJsonString(),
      landscape: false,
    );
    await render(tester);
    await tester.tap(find.byKey(const ValueKey('companion-edit')));
    await tester.pump();
    final before = tester.getRect(find.byKey(const ValueKey('companion-tile-c')));
    await tester.drag(find.byKey(const ValueKey('companion-resize-c')), Offset(0, -before.height * 0.6));
    await tester.pump();
    final after = tester.getRect(find.byKey(const ValueKey('companion-tile-c')));
    expect(after.height, lessThan(before.height * 0.7));
    expect(after.width, before.width);
    expect(find.byKey(const ValueKey('companion-info-cadence')), findsOneWidget);
  });

  testWidgets('music controls are added like any button and play/pause', (tester) async {
    connectMyWhoosh();
    await seedOne(InGameAction.tuck);
    await render(tester);
    // After the harness has set up its own.
    final previous = core.actionHandler;
    final pressed = <PhysicalKeyboardKey>[];
    core.actionHandler = _MusicActions(pressed);
    addTearDown(() => core.actionHandler = previous);
    await tester.tap(find.byKey(const ValueKey('companion-edit')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('companion-add')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('companion-add-music-playPause')));
    await tester.tap(find.byKey(const ValueKey('companion-add-music-playPause')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('companion-done')));
    await tester.pump();

    await tester.tap(find.text(AppLocalizations.current.playPause));
    await tester.pump(const Duration(milliseconds: 50));
    expect(pressed, [PhysicalKeyboardKey.mediaPlayPause]);
  });

  testWidgets('a connection that is down is one line in the header, its card a tap away', (tester) async {
    core.settings.setTrainerApp(MyWhoosh());
    core.settings.setKeyMap(MyWhoosh());
    core.settings.setLastTarget(Target.thisDevice);
    core.settings.setMyWhooshLinkEnabled(true);
    core.whooshLink.isConnected.value = false;
    addTearDown(() => core.settings.setMyWhooshLinkEnabled(false));
    await render(tester, name: 'companion_not_connected');

    expect(find.byType(ConnectionMethodWithoutSwitch), findsNothing);
    final status = find.byKey(const ValueKey('companion-connection-status'));
    expect(status, findsOneWidget);
    expect(find.descendant(of: status, matching: find.text(AppLocalizations.current.notConnected)), findsOneWidget);
    expect(find.textContaining('MyWhoosh'), findsNothing, reason: 'just the state, not the method');
    expect(tester.getRect(status).bottom, lessThan(tester.getRect(pad(InGameAction.shiftUp)).top + 1));
    await tester.tap(status);
    await tester.pumpAndSettle();
    expect(find.byType(ConnectionMethodWithoutSwitch), findsOneWidget);
  });

  testWidgets('close gaps pulls tiles up under each other', (tester) async {
    connectMyWhoosh();
    await core.settings.setCompanionLayout(
      CompanionLayout(
        landscape: false,
        tiles: const [
          CompanionTile(id: 'a', kind: CompanionTileKind.action, action: InGameAction.tuck, col: 0, row: 4, w: 4, h: 1),
        ],
      ).toJsonString(),
      landscape: false,
    );
    await render(tester);
    await tester.tap(find.byKey(const ValueKey('companion-edit')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('companion-compact')));
    await tester.pump();
    expect(
      CompanionLayout.tryParse(core.settings.getCompanionLayout(landscape: false)!, landscape: false)!.tile('a')!.row,
      0,
    );
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

/// Records the music keys the page sends.
class _MusicActions extends DesktopActions {
  _MusicActions(this.pressed);

  final List<PhysicalKeyboardKey> pressed;

  @override
  Future<ActionResult> performKeyPair(
    KeyPair keyPair, {
    required bool isKeyDown,
    required bool isKeyUp,
    String source = 'companion',
  }) async {
    pressed.add(keyPair.physicalKey!);
    return Success('', button: null);
  }
}
