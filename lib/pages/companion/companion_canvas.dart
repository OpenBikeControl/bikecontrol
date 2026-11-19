import 'package:bike_control/pages/companion/companion_layout.dart';
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
    this.gap = 8,
  });

  final CompanionLayout layout;
  final double rowHeight;
  final bool editing;
  final ValueChanged<CompanionLayout> onChanged;
  final Widget Function(BuildContext context, CompanionTile tile) tileBuilder;

  /// The remove button's accessibility label for [tile].
  final String Function(CompanionTile tile) removeLabel;

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
      _delta = Offset.zero;
      _resizing = local.dx >= size.width - _handle && local.dy >= size.height - _handle;
    });
  }

  void _end() => setState(() {
    _activeId = null;
    _start = null;
  });

  void _drag(Offset delta, double cellWidth) {
    final resize = _resizing;
    final start = _start;
    if (start == null) return;
    _delta += delta;
    final dc = (_delta.dx / cellWidth).round();
    final dr = (_delta.dy / widget.rowHeight).round();
    final next = resize
        ? widget.layout.resized(start.id, w: start.w + dc, h: start.h + dr)
        : widget.layout.moved(start.id, col: start.col + dc, row: start.row + dr);
    if (next == null) return;
    final now = widget.layout.tile(start.id);
    if (next.tile(start.id) == now) return;
    widget.onChanged(next);
  }

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
      builder: (context, constraints) => GestureDetector(
        key: ValueKey('companion-move-${tile.id}'),
        behavior: HitTestBehavior.opaque,
        onPanDown: (d) => _begin(tile, d.localPosition, constraints.biggest),
        onPanUpdate: (d) => _drag(d.delta, cellWidth),
        onPanEnd: (_) => _end(),
        onPanCancel: _end,
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
                    borderRadius: BorderRadius.circular(16),
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
