import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/utils/reduced_motion.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_icon_button.dart';
import 'package:bike_control/widgets/ui/bk_pill_button.dart';
import 'package:bike_control/widgets/ui/bk_touch_target.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:video_player/video_player.dart';

/// The short feature demo loops the website plays on its feature cards and
/// pricing rows, served from bikecontrol.app. Each value is named after the
/// website's clip id, so the URL is derived from it.
enum PaywallFeatureClip {
  /// BikeControl shifting the trainer itself.
  smartTrainerVirtualShifting,

  /// Shifting the trainer app's own virtual gears with a controller.
  virtualGearShifting,

  /// Single click, double click and long press on one button.
  buttonGestures,

  /// Heart rate and other sensors, shared with the trainer app.
  heartRate,

  /// A button starting a command or shortcut.
  launchCommand,

  /// Media controls on the device.
  music,

  /// Screenshots and screen recordings.
  screenshots;

  static const _base = 'https://bikecontrol.app/videos/features';

  /// The looping MP4.
  String get videoUrl => '$_base/$name.mp4';

  /// The still shown before the clip plays.
  String get posterUrl => '$_base/$name.jpg';
}

/// The ▶ at the end of a paywall feature line: opens [clip] in a sheet.
/// At least 48×48 on phones; the line stays one line of text.
class PaywallClipButton extends StatelessWidget {
  PaywallClipButton({required this.clip, required this.feature, required this.onPressed})
    : super(key: ValueKey('paywall-clip-${clip.name}'));

  final PaywallFeatureClip clip;

  /// The feature line's text, for the spoken label.
  final String feature;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return BkTouchTarget(
      child: BkIconButton.ghost(
        icon: Icon(LucideIcons.circlePlay, size: 18, color: bkAccentText(context)),
        label: AppLocalizations.of(context).paywall_watchClip(feature),
        density: ButtonDensity.iconDense,
        onPressed: onPressed,
      ),
    );
  }
}

/// Opens [clip] over the paywall: a bottom sheet in the paywall's drawer, a
/// dialog anywhere else.
Future<void> showPaywallFeatureClip(
  BuildContext context, {
  required String title,
  required PaywallFeatureClip clip,
  ImageProvider? poster,
}) async {
  Widget body(BuildContext c) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 440, maxHeight: MediaQuery.sizeOf(c).height * 0.9),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: PaywallFeatureClipView(
          title: title,
          clip: clip,
          poster: poster,
          onClose: () => DrawerOverlay.maybeFind(c) != null ? closeSheet(c) : Navigator.of(c).pop(),
        ),
      ),
    ),
  );
  try {
    if (DrawerOverlay.maybeFind(context) != null) {
      await openSheet<void>(context: context, position: OverlayPosition.bottom, builder: body);
    } else {
      await showDialog<void>(
        context: context,
        builder: (c) => Card(child: body(c)),
      );
    }
  } catch (e, s) {
    recordError(e, s, context: 'Paywall feature clip ${clip.name}');
  }
}

/// A feature clip's sheet: its poster, then the loop playing inline.
///
/// Nothing is fetched before the sheet opens. On open the poster shows while
/// the clip loads; once ready it plays muted and looping, unless the rider asked
/// for less motion, in which case the poster stays with a play control. If the
/// clip can't play here, the sheet says so and offers the browser instead.
class PaywallFeatureClipView extends StatefulWidget {
  const PaywallFeatureClipView({
    super.key,
    required this.title,
    required this.clip,
    this.poster,
    this.onClose,
  });

  /// The feature line the clip belongs to.
  final String title;
  final PaywallFeatureClip clip;

  /// The poster to show; the clip's [PaywallFeatureClip.posterUrl] when null.
  final ImageProvider? poster;

  /// Shows a close button when set.
  final VoidCallback? onClose;

  @override
  State<PaywallFeatureClipView> createState() => _PaywallFeatureClipViewState();
}

class _PaywallFeatureClipViewState extends State<PaywallFeatureClipView> {
  late final ImageProvider _poster = widget.poster ?? NetworkImage(widget.clip.posterUrl);
  late final VideoPlayerController _video = VideoPlayerController.networkUrl(
    Uri.parse(widget.clip.videoUrl),
    // Muted, and never interrupting the rider's music or the app's own audio.
    videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
  );
  bool _posterErrorRecorded = false;

  /// The clip has loaded and the inline player owns its errors from now on.
  bool _ready = false;

  /// The rider (or autoplay) asked for playback: the video replaces the poster.
  bool _started = false;

  /// Play was tapped before the clip was ready.
  bool _playWhenReady = false;

  /// The clip can't play here: the browser is offered instead.
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _video.addListener(_onVideoChanged);
    _load();
  }

  @override
  void dispose() {
    _video.removeListener(_onVideoChanged);
    _guard(_video.dispose(), 'dispose');
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await _video.setVolume(0);
      await _video.setLooping(true);
      await _video.initialize();
      if (!mounted) return;
      setState(() => _ready = true);
      if (_playWhenReady || !prefersReducedMotion(context)) await _play();
    } catch (e, s) {
      _fail(e, s, 'load');
    }
  }

  /// Errors while playing, after the clip has loaded.
  void _onVideoChanged() {
    final value = _video.value;
    if (_ready && value.hasError) {
      _fail(StateError(value.errorDescription ?? 'playback error'), StackTrace.current, 'play');
    }
  }

  void _fail(Object error, StackTrace stack, String step) {
    if (_failed) return;
    _failed = true;
    recordError(error, stack, context: 'Paywall feature clip ${widget.clip.name}: $step');
    if (mounted) setState(() {});
  }

  Future<void> _play() async {
    setState(() => _started = true);
    await _video.play();
  }

  void _toggle() {
    if (!_ready) {
      setState(() => _playWhenReady = true);
    } else if (_video.value.isPlaying) {
      _guard(_video.pause(), 'pause');
    } else {
      _guard(_play(), 'play');
    }
  }

  void _guard(Future<void> future, String step) {
    future.catchError((Object e, StackTrace s) => _fail(e, s, step));
  }

  Future<void> _openInBrowser() async {
    final url = widget.clip.videoUrl;
    try {
      final opened = await launchUrlString(url, mode: LaunchMode.externalApplication);
      if (!opened) throw StateError('No app could open $url');
    } catch (e, s) {
      recordError(e, s, context: 'Paywall feature clip ${widget.clip.name}: browser');
    }
  }

  void _recordPosterError(Object error, StackTrace? stack) {
    if (_posterErrorRecorded) return;
    _posterErrorRecorded = true;
    recordError(error, stack, context: 'Paywall feature clip ${widget.clip.name}: poster');
  }

  Widget _media(BuildContext context, VideoPlayerValue value) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final showVideo = _started && value.isInitialized && !_failed;
    final loading =
        !_failed &&
        ((!_ready && (_playWhenReady || !prefersReducedMotion(context))) || (showVideo && value.isBuffering));
    final playing = showVideo && value.isPlaying;
    final control = BkTouchTarget(
      child: playing
          ? BkIconButton.secondary(
              key: const ValueKey('paywall-clip-toggle'),
              icon: const Icon(LucideIcons.pause, size: 20),
              label: l10n.paywall_pauseClip,
              onPressed: _toggle,
            )
          : BkIconButton.primary(
              key: const ValueKey('paywall-clip-toggle'),
              icon: const Icon(LucideIcons.play, size: 24),
              label: l10n.paywall_playClip,
              size: ButtonSize.large,
              shape: ButtonShape.circle,
              onPressed: _toggle,
            ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(BkComponentThemes.cardRadius),
      child: AspectRatio(
        aspectRatio: value.isInitialized && value.aspectRatio > 0 ? value.aspectRatio : 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: cs.muted,
              child: Image(
                image: _poster,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                errorBuilder: (context, e, s) {
                  _recordPosterError(e, s);
                  return Center(child: Icon(LucideIcons.imageOff, size: 28, color: cs.mutedForeground));
                },
              ),
            ),
            if (showVideo) ExcludeSemantics(child: VideoPlayer(_video)),
            if (loading) const Center(child: CircularProgressIndicator(size: 28)),
            if (!_failed && !loading)
              playing ? Positioned(right: 4, bottom: 4, child: control) : Center(child: control),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final error = Text(
      l10n.paywall_clipLoadError,
      textAlign: TextAlign.center,
      style: context.typography.small.copyWith(color: BkStatusColors.of(context).danger),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          spacing: 8,
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  widget.title,
                  style: context.typography.large.copyWith(fontWeight: FontWeight.w600, height: 1.3),
                ),
              ),
            ),
            if (widget.onClose != null)
              BkTouchTarget(
                child: BkIconButton.secondary(
                  icon: const Icon(LucideIcons.x, size: 20),
                  label: l10n.close,
                  onPressed: widget.onClose,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: _video,
          builder: (context, value, _) => _media(context, value),
        ),
        if (_failed) ...[
          const SizedBox(height: 12),
          error,
          const SizedBox(height: 12),
          BkPillButton.secondary(
            key: const ValueKey('paywall-clip-open-browser'),
            leading: const Icon(LucideIcons.externalLink, size: 18),
            onPressed: _openInBrowser,
            child: Text(l10n.paywall_openClipInBrowser),
          ),
        ],
      ],
    );
  }
}
