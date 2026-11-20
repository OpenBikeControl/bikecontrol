import 'package:bike_control/pages/companion/companion_layout.dart';
import 'package:flutter/gestures.dart' show DeviceGestureSettings, PanGestureRecognizer;
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Lays [layout]'s tiles out on its grid, [rowHeight] tall per row and the
/// full width across. While [editing], each tile can be dragged to another
/// cell, resized from its corner handle and removed; every change that fits
/// goes to [onChanged]. Outside editing the tiles are just their content.
class CompanionCanvas extends StatefulWidget {
  const CompanionCanvas({
    super.key,
    required this.layout,
    required this.rowHeight,
    required this.editing,
    required this.onChanged,
    required this.tileBuilder,
    required this.removeLabel,
    this.radiusOf,
    this.gap = 8,
  });

  final CompanionLayout layout;
  final double rowHeight;
  final bool editing;
  final ValueChanged<CompanionLayout> onChanged;
  final Widget Function(BuildContext context, CompanionTile tile) tileBuilder;

  /// The remove button's accessibility label for [tile].
  final String Function(CompanionTile tile) removeLabel;

  /// The corner radius [tile]'s content draws with, so the edit outline
  /// follows it.
  final double Function(CompanionTile tile)? radiusOf;

  /// Space between tiles.
  final double gap;

  @override
  State<CompanionCanvas> createState() => _CompanionCanvasState();
}

class _CompanionCanvasState extends State<CompanionCanvas> {
  /// The tile being dragged or resized, where it started and how far the
  /// finger has gone since.
  String? _activeId;
  CompanionTile? _start;

  /// The layout as the drag found it: every step of the drag is worked out
  /// from it, so a tile pushed aside slides back once the drag moves on.
  CompanionLayout? _startLayout;
  Offset _delta = Offset.zero;
  bool _resizing = false;

  /// The corner of a tile that resizes it rather than moving it.
  static const double _handle = 44;

  /// One drag recognizer per tile: a drag that starts in its bottom-right
  /// corner resizes, any other moves. (A second recognizer on the handle
  /// lost the gesture arena to the tile's.)
  void _begin(CompanionTile tile, Offset local, Size size) {
    setState(() {
      _activeId = tile.id;
      _start = tile;
      _startLayout = widget.layout;
      _delta = Offset.zero;
      _resizing = local.dx >= size.width - _handle && local.dy >= size.height - _handle;
    });
  }

  void _end() => setState(() {
    _activeId = null;
    _start = null;
    _startLayout = null;
  });

  void _drag(Offset delta, double cellWidth) {
    final resize = _resizing;
    final start = _start;
    final base = _startLayout;
    if (start == null || base == null) return;
    _delta += delta;
    final dc = (_delta.dx / cellWidth).round();
    final dr = (_delta.dy / widget.rowHeight).round();
    final next = resize
        ? base.resized(start.id, w: start.w + dc, h: start.h + dr)
        : base.moved(start.id, col: start.col + dc, row: start.row + dr);
    if (next == null || _same(next, widget.layout)) return;
    widget.onChanged(next);
  }

  static bool _same(CompanionLayout a, CompanionLayout b) =>
      a.tiles.length == b.tiles.length && a.tiles.every((t) => b.tile(t.id) == t);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cellWidth = width / widget.layout.columns;
        final rows = widget.layout.usedRows + (widget.editing ? 2 : 0);
        final half = widget.gap / 2;
        return SizedBox(
          width: width,
          height: rows * widget.rowHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (widget.editing)
                Positioned.fill(
                  child: CustomPaint(
                    key: const ValueKey('companion-grid'),
                    painter: _GridPainter(
                      columns: widget.layout.columns,
                      cellWidth: cellWidth,
                      rowHeight: widget.rowHeight,
                      color: cs.border,
                    ),
                  ),
                ),
              for (final tile in widget.layout.tiles)
                Positioned(
                  key: ValueKey('companion-tile-${tile.id}'),
                  left: tile.col * cellWidth + half,
                  top: tile.row * widget.rowHeight + half,
                  width: tile.w * cellWidth - widget.gap,
                  height: tile.h * widget.rowHeight - widget.gap,
                  child: widget.editing ? _editable(context, tile, cellWidth) : widget.tileBuilder(context, tile),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _editable(BuildContext context, CompanionTile tile, double cellWidth) {
    final cs = Theme.of(context).colorScheme;
    final active = _activeId == tile.id;
    return LayoutBuilder(
      builder: (context, constraints) => RawGestureDetector(
        key: ValueKey('companion-move-${tile.id}'),
        behavior: HitTestBehavior.opaque,
        gestures: {
          _TileDragRecognizer: GestureRecognizerFactoryWithHandlers<_TileDragRecognizer>(
            () => _TileDragRecognizer(debugOwner: this),
            (r) => r
              ..onDown = ((d) => _begin(tile, d.localPosition, constraints.biggest))
              ..onUpdate = ((d) => _drag(d.delta, cellWidth))
              ..onEnd = ((_) => _end())
              ..onCancel = _end,
          ),
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 120),
                  opacity: active ? 0.7 : 0.9,
                  child: widget.tileBuilder(context, tile),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.radiusOf?.call(tile) ?? 16),
                    border: Border.all(
                      color: active ? cs.primary : cs.mutedForeground.withValues(alpha: 0.6),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
            // The handles sit inside the tile: a touch outside its box never
            // reaches it.
            PositionedDirectional(
              top: 0,
              end: 0,
              child: Semantics(
                button: true,
                label: widget.removeLabel(tile),
                child: GestureDetector(
                  key: ValueKey('companion-remove-${tile.id}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.onChanged(widget.layout.removed(tile.id)),
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: Center(
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(color: cs.destructive, shape: BoxShape.circle),
                        child: Icon(LucideIcons.x, size: 16, color: cs.background),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                key: ValueKey('companion-resize-${tile.id}'),
                child: SizedBox(
                  width: _handle,
                  height: _handle,
                  child: Center(
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                      child: Icon(LucideIcons.moveDiagonal2, size: 14, color: cs.primaryForeground),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A tile's drag. It claims the pointer after a shorter move than the page's
/// scroll does, so a drag that starts on a tile moves the tile while one on
/// the empty grid (or the mouse wheel) still scrolls the page.
class _TileDragRecognizer extends PanGestureRecognizer {
  _TileDragRecognizer({super.debugOwner}) {
    gestureSettings = const DeviceGestureSettings(touchSlop: 4);
  }
}

/// Faint dots at the cell corners while editing, so the snap is visible.
class _GridPainter extends CustomPainter {
  _GridPainter({required this.columns, required this.cellWidth, required this.rowHeight, required this.color});

  final int columns;
  final double cellWidth;
  final double rowHeight;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var y = 0.0; y <= size.height + 0.5; y += rowHeight) {
      for (var c = 0; c <= columns; c++) {
        canvas.drawCircle(Offset(c * cellWidth, y), 1.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.columns != columns || old.cellWidth != cellWidth || old.rowHeight != rowHeight || old.color != color;
}
