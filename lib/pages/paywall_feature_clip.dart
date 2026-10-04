import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_icon_button.dart';
import 'package:bike_control/widgets/ui/bk_pill_button.dart';
import 'package:bike_control/widgets/ui/bk_touch_target.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

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
      await showDialog<void>(context: context, builder: (c) => Card(child: body(c)));
    }
  } catch (e, s) {
    recordError(e, s, context: 'Paywall feature clip ${clip.name}');
  }
}

/// A feature clip's sheet: its poster, and a control that plays the loop.
///
/// The app has no video player of its own, so the clip plays in the browser
/// and only when the rider asks for it: nothing starts on its own, which also
/// covers reduced motion. Nothing is fetched before the sheet opens; then only
/// the poster.
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
  bool _posterErrorRecorded = false;
  bool _playFailed = false;

  Future<void> _play() async {
    setState(() => _playFailed = false);
    final url = widget.clip.videoUrl;
    try {
      final opened = await launchUrlString(url, mode: LaunchMode.externalApplication);
      if (!opened) throw StateError('No app could open $url');
    } catch (e, s) {
      recordError(e, s, context: 'Paywall feature clip ${widget.clip.name}: play');
      if (mounted) setState(() => _playFailed = true);
    }
  }

  void _recordPosterError(Object error, StackTrace? stack) {
    if (_posterErrorRecorded) return;
    _posterErrorRecorded = true;
    recordError(error, stack, context: 'Paywall feature clip ${widget.clip.name}: poster');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
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
        ClipRRect(
          borderRadius: BorderRadius.circular(BkComponentThemes.cardRadius),
          child: AspectRatio(
            aspectRatio: 1,
            child: ColoredBox(
              color: cs.muted,
              child: Image(
                image: _poster,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                errorBuilder: (context, e, s) {
                  _recordPosterError(e, s);
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 8,
                        children: [
                          Icon(LucideIcons.imageOff, size: 28, color: cs.mutedForeground),
                          error,
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        BkPillButton(
          key: const ValueKey('paywall-clip-play'),
          leading: const Icon(LucideIcons.play, size: 18),
          trailing: const Icon(LucideIcons.externalLink, size: 16),
          onPressed: _play,
          child: Text(l10n.paywall_playClip),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.paywall_clipOpensInBrowser,
          textAlign: TextAlign.center,
          style: context.typography.xSmall.copyWith(color: cs.mutedForeground),
        ),
        if (_playFailed) ...[const SizedBox(height: 8), error],
      ],
    );
  }
}
