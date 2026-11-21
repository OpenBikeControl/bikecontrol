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
  rideCard,

  /// A music control: [CompanionTile.music] on whatever is playing.
  music;

  bool get isRideData => this != action && this != music;

  static CompanionTileKind? fromName(Object? name) {
    for (final k in values) {
      if (k.name == name) return k;
    }
    return null;
  }
}

/// What a music tile does to whatever is playing.
enum CompanionMusic {
  playPause,
  previous,
  next,
  volumeDown,
  volumeUp;

  static CompanionMusic? fromName(Object? name) => values.where((m) => m.name == name).firstOrNull;
}

/// One tile, placed on the grid in whole cells.
class CompanionTile {
  const CompanionTile({
    required this.id,
    required this.kind,
    this.action,
    this.music,
    required this.col,
    required this.row,
    required this.w,
    required this.h,
  });

  final String id;
  final CompanionTileKind kind;
  final InGameAction? action;
  final CompanionMusic? music;
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
    music: music,
    col: col ?? this.col,
    row: row ?? this.row,
    w: w ?? this.w,
    h: h ?? this.h,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    if (action != null) 'action': action!.name,
    if (music != null) 'music': music!.name,
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
    final music = kind == CompanionTileKind.music ? CompanionMusic.fromName(json['music']) : null;
    if (kind == CompanionTileKind.music && music == null) return null;
    final id = json['id'];
    final col = json['col'];
    final row = json['row'];
    final w = json['w'];
    final h = json['h'];
    if (id is! String || col is! int || row is! int || w is! int || h is! int) return null;
    if (col < 0 || row < 0 || w < 1 || h < 1 || col + w > CompanionLayout.gridColumns) return null;
    return CompanionTile(id: id, kind: kind, action: action, music: music, col: col, row: row, w: w, h: h);
  }

  @override
  bool operator ==(Object other) =>
      other is CompanionTile &&
      other.id == id &&
      other.kind == kind &&
      other.action == action &&
      other.music == music &&
      other.col == col &&
      other.row == row &&
      other.w == w &&
      other.h == h;

  @override
  int get hashCode => Object.hash(id, kind, action, music, col, row, w, h);

  @override
  String toString() => 'CompanionTile($id, ${action?.name ?? music?.name ?? kind.name}, $col,$row ${w}x$h)';
}

/// The companion page's layout for one orientation: tiles on a grid of
/// [columns] × [rows] cells that fills the screen. Tiles snap to whole cells
/// and never overlap. A layout taller than [rows] scrolls.
class CompanionLayout {
  CompanionLayout({required this.landscape, required List<CompanionTile> tiles}) : tiles = List.unmodifiable(tiles);

  static const int gridColumns = 12;
  static const int gridRows = 12;

  /// The narrowest a tile can be resized to, in cells. Any tile can be as
  /// low as one row.
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

  CompanionTile? tileForMusic(CompanionMusic music) =>
      tiles.where((t) => t.kind == CompanionTileKind.music && t.music == music).firstOrNull;

  bool _fits(CompanionTile candidate) =>
      candidate.col >= 0 &&
      candidate.row >= 0 &&
      candidate.right <= columns &&
      candidate.bottom <= maxRows &&
      !tiles.any((t) => t.id != candidate.id && t.overlaps(candidate));

  /// [id] moved to [col], [row] (clamped to the grid). Tiles in the way
  /// are pushed down under it. Null only when that would push one past
  /// [maxRows].
  CompanionLayout? moved(String id, {required int col, required int row}) {
    final t = tile(id);
    if (t == null) return null;
    return _placePushing(
      t.copyWith(
        col: col.clamp(0, columns - t.w),
        row: row.clamp(0, maxRows - t.h),
      ),
    );
  }

  /// [id] resized to [w] × [h] cells (at least [minSpan] wide and one row
  /// high, at most to the grid's edge). Tiles it grows into are pushed down.
  CompanionLayout? resized(String id, {required int w, required int h}) {
    final t = tile(id);
    if (t == null) return null;
    return _placePushing(
      t.copyWith(
        w: w.clamp(minSpan, columns - t.col),
        h: h.clamp(1, maxRows - t.row),
      ),
    );
  }

  /// [placed] where it is, every other tile it lands on moved down just
  /// below it, and so on down the grid: the others keep their order and
  /// columns.
  CompanionLayout? _placePushing(CompanionTile placed) {
    final settled = <CompanionTile>[placed];
    final others = tiles.where((t) => t.id != placed.id).toList()
      ..sort((a, b) => a.row != b.row ? a.row.compareTo(b.row) : a.col.compareTo(b.col));
    for (final t in others) {
      var next = t;
      while (true) {
        final hits = settled.where((s) => s.overlaps(next));
        if (hits.isEmpty) break;
        next = next.copyWith(row: hits.map((s) => s.bottom).reduce(math.max));
      }
      if (next.bottom > maxRows) return null;
      settled.add(next);
    }
    return CompanionLayout(
      landscape: landscape,
      tiles: [for (final t in tiles) settled.firstWhere((s) => s.id == t.id)],
    );
  }

  /// Every tile moved up as far as it goes, top to bottom, so the empty rows
  /// and gaps between them close. Columns and sizes stay.
  CompanionLayout compacted() {
    final placed = <CompanionTile>[];
    final order = [...tiles]..sort((a, b) => a.row != b.row ? a.row.compareTo(b.row) : a.col.compareTo(b.col));
    for (final t in order) {
      var next = t;
      while (next.row > 0) {
        final up = next.copyWith(row: next.row - 1);
        if (placed.any((p) => p.overlaps(up))) break;
        next = up;
      }
      placed.add(next);
    }
    return CompanionLayout(
      landscape: landscape,
      tiles: [for (final t in tiles) placed.firstWhere((p) => p.id == t.id)],
    );
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
    CompanionTileKind.action || CompanionTileKind.music => (landscape ? 3 : 4, landscape ? 3 : 2),
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
  CompanionLayout added({required CompanionTileKind kind, InGameAction? action, CompanionMusic? music}) {
    final (w, h) = _startSize(kind);
    final id = _nextId();
    for (var row = 0; row <= maxRows - h; row++) {
      for (var col = 0; col <= columns - w; col++) {
        final candidate = CompanionTile(
          id: id,
          kind: kind,
          action: action,
          music: music,
          col: col,
          row: row,
          w: w,
          h: h,
        );
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

  /// The page before the rider changes it: ride mode (when it has − and +
  /// to show), then every other of [actions] below it, a scroll away —
  /// steering side by side, actions that take a value (camera angle, emote)
  /// half a row wide with room for their two last values, the rest an even
  /// grid.
  factory CompanionLayout.initial({
    required List<InGameAction> actions,
    required bool landscape,
    required bool hasRideData,
  }) {
    final hasShift = actions.contains(InGameAction.shiftUp) && actions.contains(InGameAction.shiftDown);
    final base = hasShift || hasRideData
        ? CompanionLayout.rideMode(landscape: landscape, hasRideData: hasRideData)
        : CompanionLayout(landscape: landscape, tiles: const []);
    final tiles = [...base.tiles];
    var n = tiles.length;
    String id() => 't${n++}';
    var row = base.tiles.isEmpty ? 0 : base.usedRows;
    var col = 0;
    var rowHeight = 0;
    const half = gridColumns ~/ 2;
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

    final rest = actions.where((a) => !tiles.any((t) => t.action == a)).toList();
    for (final action in rest.where((a) => a == InGameAction.steerLeft || a == InGameAction.steerRight)) {
      place(action, half, 2);
    }
    for (final action in rest.where((a) => a.possibleValues != null)) {
      place(action, half, landscape ? 4 : 3);
    }
    for (final action in rest.where(
      (a) => a.possibleValues == null && a != InGameAction.steerLeft && a != InGameAction.steerRight,
    )) {
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
