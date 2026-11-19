import 'dart:convert';
import 'dart:math' as math;

import 'package:bike_control/utils/keymap/buttons.dart';

/// What a tile on the companion page shows.
enum CompanionTileKind {
  /// A button that presses [CompanionTile.action].
  action,

  /// The gear in SIM (the target watts in ERG), with the mode as its label.
  gear,
  power,
  cadence,
  ratio,
  ergTarget,

  /// SIM or ERG, as a label — never a switch, so a missed tap can't change
  /// the trainer's mode mid-effort.
  mode,

  /// The gear overlay's card: gear, mode and the readings in one.
  rideCard;

  bool get isRideData => this != action;

  static CompanionTileKind? fromName(Object? name) {
    for (final k in values) {
      if (k.name == name) return k;
    }
    return null;
  }
}

/// One tile, placed on the grid in whole cells.
class CompanionTile {
  const CompanionTile({
    required this.id,
    required this.kind,
    this.action,
    required this.col,
    required this.row,
    required this.w,
    required this.h,
  });

  final String id;
  final CompanionTileKind kind;
  final InGameAction? action;
  final int col;
  final int row;
  final int w;
  final int h;

  int get right => col + w;
  int get bottom => row + h;

  bool overlaps(CompanionTile other) =>
      col < other.right && other.col < right && row < other.bottom && other.row < bottom;

  CompanionTile copyWith({int? col, int? row, int? w, int? h}) => CompanionTile(
    id: id,
    kind: kind,
    action: action,
    col: col ?? this.col,
    row: row ?? this.row,
    w: w ?? this.w,
    h: h ?? this.h,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    if (action != null) 'action': action!.name,
    'col': col,
    'row': row,
    'w': w,
    'h': h,
  };

  static CompanionTile? fromJson(Object? json) {
    if (json is! Map) return null;
    final kind = CompanionTileKind.fromName(json['kind']);
    if (kind == null) return null;
    InGameAction? action;
    if (kind == CompanionTileKind.action) {
      action = InGameAction.values.where((a) => a.name == json['action']).firstOrNull;
      if (action == null) return null;
    }
    final id = json['id'];
    final col = json['col'];
    final row = json['row'];
    final w = json['w'];
    final h = json['h'];
    if (id is! String || col is! int || row is! int || w is! int || h is! int) return null;
    if (col < 0 || row < 0 || w < 1 || h < 1 || col + w > CompanionLayout.gridColumns) return null;
    return CompanionTile(id: id, kind: kind, action: action, col: col, row: row, w: w, h: h);
  }

  @override
  bool operator ==(Object other) =>
      other is CompanionTile &&
      other.id == id &&
      other.kind == kind &&
      other.action == action &&
      other.col == col &&
      other.row == row &&
      other.w == w &&
      other.h == h;

  @override
  int get hashCode => Object.hash(id, kind, action, col, row, w, h);

  @override
  String toString() => 'CompanionTile($id, ${action?.name ?? kind.name}, $col,$row ${w}x$h)';
}

/// The companion page's layout for one orientation: tiles on a grid of
/// [columns] × [rows] cells that fills the screen. Tiles snap to whole cells
/// and never overlap. A layout taller than [rows] scrolls.
class CompanionLayout {
  CompanionLayout({required this.landscape, required List<CompanionTile> tiles}) : tiles = List.unmodifiable(tiles);

  static const int gridColumns = 12;
  static const int gridRows = 12;

  /// The smallest a tile can be resized to, in cells.
  static const int minSpan = 2;

  /// How far down a tile may go, so a runaway drag can't lose it.
  static const int maxRows = 60;

  final bool landscape;
  final List<CompanionTile> tiles;

  int get columns => gridColumns;
  int get rows => gridRows;

  /// The rows the tiles take up, at least one screen.
  int get usedRows => tiles.fold(rows, (m, t) => math.max(m, t.bottom));

  CompanionTile? tile(String id) => tiles.where((t) => t.id == id).firstOrNull;

  CompanionTile? tileFor(InGameAction action) =>
      tiles.where((t) => t.kind == CompanionTileKind.action && t.action == action).firstOrNull;

  bool _fits(CompanionTile candidate) =>
      candidate.col >= 0 &&
      candidate.row >= 0 &&
      candidate.right <= columns &&
      candidate.bottom <= maxRows &&
      !tiles.any((t) => t.id != candidate.id && t.overlaps(candidate));

  CompanionLayout _replace(CompanionTile tile) =>
      CompanionLayout(landscape: landscape, tiles: [for (final t in tiles) t.id == tile.id ? tile : t]);

  /// [id] moved to [col], [row] (clamped to the grid), or null when it would
  /// land on another tile.
  CompanionLayout? moved(String id, {required int col, required int row}) {
    final t = tile(id);
    if (t == null) return null;
    final next = t.copyWith(
      col: col.clamp(0, columns - t.w),
      row: row.clamp(0, maxRows - t.h),
    );
    if (!_fits(next)) return null;
    return _replace(next);
  }

  /// [id] resized to [w] × [h] cells (at least [minSpan], at most to the
  /// grid's edge), or null when it would cover another tile.
  CompanionLayout? resized(String id, {required int w, required int h}) {
    final t = tile(id);
    if (t == null) return null;
    final next = t.copyWith(
      w: w.clamp(minSpan, columns - t.col),
      h: h.clamp(minSpan, maxRows - t.row),
    );
    if (!_fits(next)) return null;
    return _replace(next);
  }

  CompanionLayout removed(String id) => CompanionLayout(
    landscape: landscape,
    tiles: [
      for (final t in tiles)
        if (t.id != id) t,
    ],
  );

  /// The size a new tile of [kind] starts at.
  (int, int) _startSize(CompanionTileKind kind) => switch (kind) {
    CompanionTileKind.rideCard => (landscape ? 6 : 12, 3),
    CompanionTileKind.action => (landscape ? 3 : 4, landscape ? 3 : 2),
    _ => (landscape ? 3 : 4, landscape ? 3 : 2),
  };

  String _nextId() {
    final used = tiles.map((t) => t.id).toSet();
    var i = tiles.length;
    while (used.contains('t$i')) {
      i++;
    }
    return 't$i';
  }

  /// A new tile in the first free spot, reading order; below everything when
  /// the screen is full.
  CompanionLayout added({required CompanionTileKind kind, InGameAction? action}) {
    final (w, h) = _startSize(kind);
    final id = _nextId();
    for (var row = 0; row <= maxRows - h; row++) {
      for (var col = 0; col <= columns - w; col++) {
        final candidate = CompanionTile(id: id, kind: kind, action: action, col: col, row: row, w: w, h: h);
        if (_fits(candidate)) {
          return CompanionLayout(landscape: landscape, tiles: [...tiles, candidate]);
        }
      }
    }
    return this;
  }

  String toJsonString() => jsonEncode({
    'v': 1,
    'tiles': [for (final t in tiles) t.toJson()],
  });

  /// The layout saved as [raw], or null when it isn't one. Tiles this version
  /// doesn't know (an action since removed) are dropped, as are tiles that
  /// would overlap one read before them.
  static CompanionLayout? tryParse(String raw, {required bool landscape}) {
    Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (json is! Map || json['tiles'] is! List) return null;
    final tiles = <CompanionTile>[];
    for (final entry in json['tiles'] as List) {
      final t = CompanionTile.fromJson(entry);
      if (t == null || tiles.any((o) => o.id == t.id || o.overlaps(t))) continue;
      tiles.add(t);
    }
    return CompanionLayout(landscape: landscape, tiles: tiles);
  }

  /// Today's page as a layout: the ride card when there is ride data, − and
  /// + side by side as the biggest targets, steering under them, then the
  /// other [actions] as an even grid.
  factory CompanionLayout.standard({
    required List<InGameAction> actions,
    required bool landscape,
    required bool hasRideData,
  }) {
    final tiles = <CompanionTile>[];
    var row = 0;
    var n = 0;
    String id() => 't${n++}';
    if (hasRideData) {
      tiles.add(CompanionTile(id: id(), kind: CompanionTileKind.rideCard, col: 0, row: 0, w: gridColumns, h: 3));
      row = 3;
    }
    final hasShift = actions.contains(InGameAction.shiftUp) && actions.contains(InGameAction.shiftDown);
    final hasSteer = actions.contains(InGameAction.steerLeft) && actions.contains(InGameAction.steerRight);
    const half = gridColumns ~/ 2;
    if (hasShift) {
      final h = landscape ? 5 : 4;
      tiles
        ..add(
          CompanionTile(
            id: id(),
            kind: CompanionTileKind.action,
            action: InGameAction.shiftDown,
            col: 0,
            row: row,
            w: half,
            h: h,
          ),
        )
        ..add(
          CompanionTile(
            id: id(),
            kind: CompanionTileKind.action,
            action: InGameAction.shiftUp,
            col: half,
            row: row,
            w: half,
            h: h,
          ),
        );
      row += h;
    }
    if (hasSteer) {
      tiles
        ..add(
          CompanionTile(
            id: id(),
            kind: CompanionTileKind.action,
            action: InGameAction.steerLeft,
            col: 0,
            row: row,
            w: half,
            h: 2,
          ),
        )
        ..add(
          CompanionTile(
            id: id(),
            kind: CompanionTileKind.action,
            action: InGameAction.steerRight,
            col: half,
            row: row,
            w: half,
            h: 2,
          ),
        );
      row += 2;
    }
    final rest = actions.where(
      (a) =>
          !(hasShift && (a == InGameAction.shiftUp || a == InGameAction.shiftDown)) &&
          !(hasSteer && (a == InGameAction.steerLeft || a == InGameAction.steerRight)),
    );
    // Actions that take a value (camera angle, emote) are half a row wide:
    // their name and the two values used last sit in them. The rest are an
    // even grid under them.
    var col = 0;
    var rowHeight = 0;
    void place(InGameAction action, int w, int h) {
      if (col + w > gridColumns || (rowHeight != 0 && rowHeight != h)) {
        col = 0;
        row += rowHeight;
        rowHeight = 0;
      }
      tiles.add(
        CompanionTile(id: id(), kind: CompanionTileKind.action, action: action, col: col, row: row, w: w, h: h),
      );
      col += w;
      rowHeight = h;
    }

    for (final action in rest.where((a) => a.possibleValues != null)) {
      place(action, half, landscape ? 4 : 3);
    }
    for (final action in rest.where((a) => a.possibleValues == null)) {
      place(action, landscape ? 3 : 4, landscape ? 3 : 2);
    }
    return CompanionLayout(landscape: landscape, tiles: tiles);
  }

  /// Big − and + taking most of the screen, the readings between them:
  /// + on top and − at the bottom in portrait, − left and + right in
  /// landscape. Nothing else to tap.
  factory CompanionLayout.rideMode({required bool landscape, required bool hasRideData}) {
    const c = gridColumns;
    const r = gridRows;
    CompanionTile button(String id, InGameAction action, int col, int row, int w, int h) =>
        CompanionTile(id: id, kind: CompanionTileKind.action, action: action, col: col, row: row, w: w, h: h);
    CompanionTile info(String id, CompanionTileKind kind, int col, int row, int w, int h) =>
        CompanionTile(id: id, kind: kind, col: col, row: row, w: w, h: h);
    if (!hasRideData) {
      return CompanionLayout(
        landscape: landscape,
        tiles: landscape
            ? [
                button('t0', InGameAction.shiftDown, 0, 0, c ~/ 2, r),
                button('t1', InGameAction.shiftUp, c ~/ 2, 0, c ~/ 2, r),
              ]
            : [
                button('t0', InGameAction.shiftUp, 0, 0, c, r ~/ 2),
                button('t1', InGameAction.shiftDown, 0, r ~/ 2, c, r ~/ 2),
              ],
      );
    }
    if (landscape) {
      return CompanionLayout(
        landscape: true,
        tiles: [
          button('t0', InGameAction.shiftDown, 0, 0, 4, r),
          info('t1', CompanionTileKind.gear, 4, 0, 4, 6),
          info('t2', CompanionTileKind.power, 4, 6, 2, 3),
          info('t3', CompanionTileKind.cadence, 6, 6, 2, 3),
          info('t4', CompanionTileKind.ratio, 4, 9, 4, 3),
          button('t5', InGameAction.shiftUp, 8, 0, 4, r),
        ],
      );
    }
    return CompanionLayout(
      landscape: false,
      tiles: [
        button('t0', InGameAction.shiftUp, 0, 0, c, 5),
        info('t1', CompanionTileKind.gear, 0, 5, 3, 2),
        info('t2', CompanionTileKind.power, 3, 5, 3, 2),
        info('t3', CompanionTileKind.cadence, 6, 5, 3, 2),
        info('t4', CompanionTileKind.ratio, 9, 5, 3, 2),
        button('t5', InGameAction.shiftDown, 0, 7, c, 5),
      ],
    );
  }
}
