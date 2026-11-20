// The companion page's layout: tiles on a snapping grid that the rider
// moves, resizes, adds and removes, saved per orientation.
import 'package:bike_control/pages/companion/companion_layout.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const actions = [
    InGameAction.shiftUp,
    InGameAction.shiftDown,
    InGameAction.steerLeft,
    InGameAction.steerRight,
    InGameAction.tuck,
    InGameAction.uturn,
    InGameAction.toggleUi,
    InGameAction.cameraAngle,
  ];

  void expectNoOverlap(CompanionLayout layout) {
    for (final a in layout.tiles) {
      expect(a.col, greaterThanOrEqualTo(0));
      expect(a.row, greaterThanOrEqualTo(0));
      expect(a.col + a.w, lessThanOrEqualTo(layout.columns), reason: '${a.id} inside the columns');
      for (final b in layout.tiles) {
        if (identical(a, b)) continue;
        expect(a.overlaps(b), isFalse, reason: '${a.id} overlaps ${b.id}');
      }
    }
  }

  group('JSON', () {
    test('round-trips every tile kind', () {
      final layout = CompanionLayout(
        landscape: true,
        tiles: [
          const CompanionTile(
            id: 'a',
            kind: CompanionTileKind.action,
            action: InGameAction.shiftUp,
            col: 0,
            row: 0,
            w: 4,
            h: 3,
          ),
          for (final (i, kind) in CompanionTileKind.values.where((k) => k.isRideData).indexed)
            CompanionTile(id: 'i$i', kind: kind, col: 4 + i % 2 * 4, row: i * 2, w: 4, h: 2),
          const CompanionTile(
            id: 'm',
            kind: CompanionTileKind.music,
            music: CompanionMusic.playPause,
            col: 0,
            row: 4,
            w: 4,
            h: 2,
          ),
        ],
      );
      final back = CompanionLayout.tryParse(layout.toJsonString(), landscape: true);
      expect(back, isNotNull);
      expect(back!.tiles, layout.tiles);
    });

    test('a broken or unknown value parses to null, unknown tiles are dropped', () {
      expect(CompanionLayout.tryParse('{nope', landscape: false), isNull);
      expect(CompanionLayout.tryParse('[]', landscape: false), isNull);
      final partial = CompanionLayout.tryParse(
        '{"v":1,"tiles":[{"id":"x","kind":"warpDrive","col":0,"row":0,"w":2,"h":2},'
        '{"id":"y","kind":"action","action":"shiftUp","col":0,"row":0,"w":2,"h":2},'
        '{"id":"z","kind":"action","action":"noSuchAction","col":2,"row":0,"w":2,"h":2}]}',
        landscape: false,
      );
      expect(partial!.tiles.map((t) => t.id), ['y']);
    });
  });

  group('default layout', () {
    test('ride mode first, every other button a scroll below it', () {
      final layout = CompanionLayout.initial(actions: actions, landscape: false, hasRideData: false);
      final up = layout.tileFor(InGameAction.shiftUp)!;
      final down = layout.tileFor(InGameAction.shiftDown)!;
      expect(up.row, 0);
      expect(up.w, layout.columns);
      expect(down.row + down.h, layout.rows);
      for (final action in actions.where((a) => a != InGameAction.shiftUp && a != InGameAction.shiftDown)) {
        expect(layout.tileFor(action)!.row, greaterThanOrEqualTo(layout.rows), reason: '$action below one screen');
      }
      expect(layout.tiles.where((t) => t.kind == CompanionTileKind.action).length, actions.length);
      expectNoOverlap(layout);
    });

    test('with ride data the readings sit between − and +', () {
      final layout = CompanionLayout.initial(actions: actions, landscape: false, hasRideData: true);
      final gear = layout.tiles.firstWhere((t) => t.kind == CompanionTileKind.gear);
      expect(gear.row, greaterThan(layout.tileFor(InGameAction.shiftUp)!.row));
      expect(gear.row, lessThan(layout.tileFor(InGameAction.shiftDown)!.row));
      expectNoOverlap(layout);
    });

    test('a trainer app without − and + starts with its buttons from the top', () {
      final layout = CompanionLayout.initial(
        actions: const [InGameAction.tuck, InGameAction.uturn],
        landscape: true,
        hasRideData: false,
      );
      expect(layout.tiles, hasLength(2));
      expect(layout.tileFor(InGameAction.tuck)!.row, 0);
    });
  });

  group('ride mode', () {
    test('portrait: + fills the top, − the bottom, the readings a strip between', () {
      final layout = CompanionLayout.rideMode(landscape: false, hasRideData: true);
      final up = layout.tileFor(InGameAction.shiftUp)!;
      final down = layout.tileFor(InGameAction.shiftDown)!;
      expect(up.row, 0);
      expect(up.w, layout.columns);
      expect(down.w, layout.columns);
      expect(down.row + down.h, layout.rows);
      final info = layout.tiles.where((t) => t.kind != CompanionTileKind.action).toList();
      expect(
        info.map((t) => t.kind),
        containsAll([CompanionTileKind.gear, CompanionTileKind.power, CompanionTileKind.cadence]),
      );
      for (final t in info) {
        expect(t.row, greaterThanOrEqualTo(up.row + up.h));
        expect(t.row + t.h, lessThanOrEqualTo(down.row));
      }
      expect(up.h * up.w, greaterThan(layout.columns * layout.rows / 3), reason: 'most of the screen is the buttons');
      expectNoOverlap(layout);
    });

    test('landscape: − left, + right, readings in the centre', () {
      final layout = CompanionLayout.rideMode(landscape: true, hasRideData: true);
      final up = layout.tileFor(InGameAction.shiftUp)!;
      final down = layout.tileFor(InGameAction.shiftDown)!;
      expect(down.col, 0);
      expect(up.col + up.w, layout.columns);
      expect(up.h, layout.rows);
      for (final t in layout.tiles.where((t) => t.kind != CompanionTileKind.action)) {
        expect(t.col, greaterThanOrEqualTo(down.col + down.w));
        expect(t.col + t.w, lessThanOrEqualTo(up.col));
      }
      expectNoOverlap(layout);
    });

    test('without ride data the two buttons share the whole screen', () {
      final layout = CompanionLayout.rideMode(landscape: false, hasRideData: false);
      expect(layout.tiles, hasLength(2));
      expect(layout.tiles.fold<int>(0, (sum, t) => sum + t.w * t.h), layout.columns * layout.rows);
    });

    test('SIM/ERG is never a button in ride mode', () {
      for (final landscape in [false, true]) {
        final layout = CompanionLayout.rideMode(landscape: landscape, hasRideData: true);
        expect(layout.tileFor(InGameAction.trainerSwitchMode), isNull);
      }
    });
  });

  group('editing', () {
    final base = CompanionLayout(
      landscape: false,
      tiles: const [
        CompanionTile(
          id: 'a',
          kind: CompanionTileKind.action,
          action: InGameAction.shiftDown,
          col: 0,
          row: 0,
          w: 6,
          h: 3,
        ),
        CompanionTile(
          id: 'b',
          kind: CompanionTileKind.action,
          action: InGameAction.shiftUp,
          col: 6,
          row: 0,
          w: 6,
          h: 3,
        ),
      ],
    );

    test('a move onto another tile is refused, a free spot is taken', () {
      expect(base.moved('a', col: 4, row: 0), isNull);
      final moved = base.moved('a', col: 0, row: 5)!;
      expect(moved.tile('a')!.row, 5);
    });

    test('a move is clamped to the grid', () {
      final right = base.moved('a', col: 99, row: 10)!.tile('a')!;
      expect(right.col, base.columns - right.w);
      expect(right.row, 10);
      final top = base.moved('a', col: 0, row: -4)!.tile('a')!;
      expect(top.row, 0);
    });

    test('a reading goes down to one row, a button stays two', () {
      final withGear = base.added(kind: CompanionTileKind.cadence);
      final cadence = withGear.tiles.last;
      final low = withGear.resized(cadence.id, w: 0, h: 0)!.tile(cadence.id)!;
      expect(low.h, 1);
      expect(low.w, CompanionLayout.minSpan);
      expect(base.resized('a', w: 6, h: 1)!.tile('a')!.h, CompanionLayout.minSpan);
    });

    test('resizing keeps a minimum size and stops at a neighbour', () {
      final small = base.resized('a', w: 0, h: 0)!;
      expect(small.tile('a')!.w, CompanionLayout.minSpan);
      expect(small.tile('a')!.h, CompanionLayout.minSpan);
      expect(base.resized('a', w: 8, h: 3), isNull, reason: 'would cover b');
      expect(base.resized('a', w: 6, h: 6)!.tile('a')!.h, 6);
    });

    test('added tiles land in the first free spot and removing frees it', () {
      final added = base.added(kind: CompanionTileKind.gear);
      expectNoOverlap(added);
      final gear = added.tiles.last;
      expect(gear.kind, CompanionTileKind.gear);
      expect(gear.row, 3);
      final removed = added.removed(gear.id);
      expect(removed.tiles, base.tiles);
    });

    test('a new tile on a full screen goes below, the canvas grows', () {
      final full = CompanionLayout.rideMode(landscape: false, hasRideData: false);
      final added = full.added(kind: CompanionTileKind.action, action: InGameAction.tuck);
      expectNoOverlap(added);
      expect(added.tiles.last.row, greaterThanOrEqualTo(full.rows));
      expect(added.usedRows, greaterThan(full.rows));
    });

    test('new ids never collide', () {
      var layout = base;
      for (var i = 0; i < 5; i++) {
        layout = layout.added(kind: CompanionTileKind.power);
      }
      expect(layout.tiles.map((t) => t.id).toSet(), hasLength(layout.tiles.length));
    });
  });
}
