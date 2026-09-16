import 'package:bike_control/main.dart' show screenshotMode;
import 'package:bike_control/pages/home/chain_state.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The status vocabulary the whole home screen speaks: one colour, one icon and
/// one wash per [LinkStatus], used identically by the dot on a card's tile, the
/// status line under its title, and the banner at the top of the screen.
///
/// Green deliberately stays *in the dot*. A healthy screen is calm — ready
/// status lines are muted grey, not green — so that colour anywhere on this
/// screen always means "look here".
class AmpelStyle {
  const AmpelStyle({required this.color, required this.wash, required this.icon});

  final Color color;
  final Color wash;
  final IconData icon;

  static AmpelStyle of(BuildContext context, LinkStatus status) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // In dark mode a pastel wash turns into a glare, so the wash becomes a low
    // alpha of the status colour instead of a fixed tint.
    Color wash(Color base, Color light) => dark ? base.withAlpha(38) : light;

    return switch (status) {
      LinkStatus.ready => AmpelStyle(
        color: const Color(0xFF22C55E),
        wash: wash(const Color(0xFF22C55E), const Color(0xFFF0FDF4)),
        icon: LucideIcons.check,
      ),
      LinkStatus.attention => AmpelStyle(
        color: const Color(0xFFF59E0B),
        wash: wash(const Color(0xFFF59E0B), const Color(0xFFFFFBEB)),
        icon: LucideIcons.circleAlert,
      ),
      LinkStatus.problem => AmpelStyle(
        color: const Color(0xFFEF4444),
        wash: wash(const Color(0xFFEF4444), const Color(0xFFFEF2F2)),
        icon: LucideIcons.circleX,
      ),
      LinkStatus.off => AmpelStyle(
        color: dark ? const Color(0xFF64748B) : const Color(0xFFB7C0CB),
        wash: Theme.of(context).colorScheme.muted,
        icon: LucideIcons.minus,
      ),
    };
  }
}

/// The status dot. Pulses on [LinkStatus.attention] — the one state that means
/// "this is changing, or waiting on you" — and sits still otherwise, unless
/// [pulse] says different.
class Ampel extends StatefulWidget {
  const Ampel({super.key, required this.status, this.size = 13, this.ringColor, this.pulse});

  final LinkStatus status;
  final double size;

  /// Overrides the status-driven pulse. The Sensors page's Broadcast tile is
  /// the one green dot that means "transmitting right now" rather than
  /// "healthy and done", so it pulses while live; null keeps the default.
  final bool? pulse;

  /// The colour the dot is punched out of, so it reads cleanly when it overlaps
  /// a tile. Defaults to the card surface.
  final Color? ringColor;

  @override
  State<Ampel> createState() => _AmpelState();
}

class _AmpelState extends State<Ampel> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  /// The pulse runs a fixed number of times rather than forever. Forever would
  /// be wrong twice over: this app holds a wakelock so the home screen can sit
  /// lit on a handlebar for a whole ride, and an animation that never ends also
  /// never lets a frame loop go quiet — which hangs any widget test that
  /// renders an attention card. A short burst still catches the eye, and then
  /// the screen is calm again.
  static const int _pulseCycles = 6;

  bool _animationsAllowed = true;

  bool get _shouldPulse =>
      (widget.pulse ?? widget.status == LinkStatus.attention) && _animationsAllowed && !screenshotMode;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animationsAllowed = !MediaQuery.of(context).disableAnimations;
    _syncPulse(statusChanged: true);
  }

  @override
  void didUpdateWidget(covariant Ampel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse(statusChanged: oldWidget.status != widget.status || oldWidget.pulse != widget.pulse);
  }

  void _syncPulse({required bool statusChanged}) {
    if (!_shouldPulse) {
      if (_pulse.isAnimating) _pulse.stop();
      _pulse.value = 0;
      return;
    }
    // Re-arm only when the card actually entered the attention state, so an
    // unrelated rebuild doesn't restart the burst on a card the rider has
    // already noticed.
    if (statusChanged) _pulse.repeat(reverse: true, count: _pulseCycles);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = AmpelStyle.of(context, widget.status);
    final ring = widget.ringColor ?? Theme.of(context).colorScheme.card;

    final dot = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: style.color,
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: 2),
      ),
    );

    if (!_shouldPulse) return dot;

    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.35).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
      child: dot,
    );
  }
}

/// A card's visual tile — an icon or a logo — carrying its Ampel in the corner.
class TileWithAmpel extends StatelessWidget {
  const TileWithAmpel({super.key, required this.status, required this.child, this.size = 46, this.pulse});

  final LinkStatus status;
  final Widget child;
  final double size;

  /// Forwarded to [Ampel.pulse].
  final bool? pulse;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // Room for the dot, which overhangs the tile by 3px plus its 2px ring.
      width: size + 5,
      height: size + 5,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 5,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.muted,
                borderRadius: BorderRadius.circular(13),
              ),
              clipBehavior: Clip.antiAlias,
              child: Center(child: child),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Ampel(status: status, pulse: pulse),
          ),
        ],
      ),
    );
  }
}

/// The Ampel in words, under a card title.
///
/// [LinkStatus.ready] is deliberately NOT green text: green belongs to the dot,
/// so a healthy screen stays calm and the one card that needs attention is the
/// only coloured thing on it.
class StatusLine extends StatelessWidget {
  const StatusLine({super.key, required this.status, required this.label, this.meta, this.badges = const []});

  final LinkStatus status;
  final String label;
  final String? meta;

  /// Small warning glyphs shown inline after the status — a flat battery, a
  /// firmware update, a weak signal. They ride here rather than in the card
  /// body because they qualify "Connected": the device works, but not for
  /// much longer or not well.
  final List<Widget> badges;

  @override
  Widget build(BuildContext context) {
    final quiet = status == LinkStatus.ready || status == LinkStatus.off;
    final muted = Theme.of(context).colorScheme.mutedForeground;
    final metaText = meta;

    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Wrap(
        spacing: 7,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: quiet ? FontWeight.w500 : FontWeight.w700,
              color: quiet ? muted : AmpelStyle.of(context, status).color,
            ),
          ),
          if (metaText != null && metaText.isNotEmpty) ...[
            Container(
              width: 3,
              height: 3,
              decoration: BoxDecoration(color: muted.withAlpha(140), shape: BoxShape.circle),
            ),
            Text(metaText, style: TextStyle(fontSize: 12, color: muted)),
          ],
          ...badges,
        ],
      ),
    );
  }
}
