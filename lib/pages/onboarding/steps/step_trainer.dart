import 'package:bike_control/main.dart' show screenshotMode;
import 'package:bike_control/pages/onboarding/widgets/onboarding_theme.dart';
import 'package:bike_control/pages/onboarding/widgets/onboarding_reveal.dart';
import 'package:bike_control/pages/onboarding/widgets/vs_stage.dart';
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

bool onboardingTrainerBridged(List<ProxyDevice> trainers) => trainers.any((t) => t.isBridged);

/// The icon that says how BikeControl talks to this trainer. The same physical
/// trainer is regularly discovered twice — once over BLE, once over mDNS/DirCon
/// — and the rows are otherwise identical, so the leading icon carries the
/// transport rather than the generic bike mark.
IconData onboardingTrainerIcon(ProxyDevice trainer) =>
    trainer.isWifiUpstream ? LucideIcons.wifi : LucideIcons.bluetooth;

/// `WiFi · Supports virtual shifting` — the constant meta line alone is
/// identical for both duplicates of one trainer, which is exactly what made
/// the list unpickable.
String onboardingTrainerSubtitleFor(BuildContext context, ProxyDevice trainer) {
  final transport = trainer.isWifiUpstream ? context.i18n.connectionWifi : context.i18n.connectionBluetooth;
  return '$transport · ${context.i18n.onboardingTrainerMeta}';
}

Widget _alternative(BuildContext context, IconData icon, String title, String body) {
  final scheme = Theme.of(context).colorScheme;
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
    decoration: BoxDecoration(color: scheme.muted, borderRadius: BorderRadius.circular(10)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 18, color: onboardingAccent(context)),
      Gap(12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title).small.semiBold,
          Text(body).xSmall.muted,
        ]),
      ),
    ]),
  );
}

/// [app] is optional: the home screen's trainer picker is reachable before a
/// trainer app was ever chosen (skipped onboarding), and the list itself does
/// not depend on one. Only the app-naming copy is dropped when it is null.
Widget onboardingTrainerBody(BuildContext context,
    {required SupportedApp? app,
    required List<ProxyDevice> trainers,
    required void Function(ProxyDevice) onPick,
    VoidCallback? onRescan,
    bool virtualShiftingBlocked = false}) {
  final bridged = trainers.where((t) => t.isBridged).toList();

  // MyWhoosh on Android can't see a network virtual bike, so a bridge on this
  // same device would never be found — explain it and name the two setups
  // that do work instead of silently hiding the step. The block is only
  // meaningful for a chosen app — its copy names it.
  if (bridged.isEmpty && virtualShiftingBlocked && app != null) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: onboardingReveal([
      Text(context.i18n.onboardingVsBlockedTitle).h4,
      Gap(6),
      Text(context.i18n.onboardingVsBlockedSubtitle(app.name)).small.muted,
      Gap(16),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: const Color(0x1AF59E0B),
          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(LucideIcons.triangleAlert, size: 16, color: const Color(0xFFF59E0B)),
          Gap(10),
          Expanded(child: Text(context.i18n.onboardingVsBlockedExplainer(app.name)).xSmall),
        ]),
      ),
      Gap(16),
      Text(context.i18n.onboardingVsBlockedAlternatives).xSmall.semiBold.muted,
      Gap(8),
      _alternative(context, LucideIcons.monitorSmartphone, context.i18n.onboardingVsBlockedAltAppTitle(app.name),
          context.i18n.onboardingVsBlockedAltAppBody(app.name)),
      _alternative(context, LucideIcons.bluetooth, context.i18n.onboardingVsBlockedAltBtTitle,
          context.i18n.onboardingVsBlockedAltBtBody(app.name)),
      Gap(6),
      Button.ghost(
        style: ButtonStyle.ghost().withPadding(padding: EdgeInsets.zero),
        onPressed: () => launchUrlString(
            'https://bikecontrol.app/blog/virtual-shifting-with-and-without-bikecontrol/',
            mode: LaunchMode.externalApplication),
        child: Row(children: [
          Icon(LucideIcons.bookOpen, size: 15),
          Gap(8),
          Flexible(child: Text(context.i18n.onboardingTrainerHowItWorks).small),
          Gap(6),
          Icon(LucideIcons.externalLink, size: 13),
        ]),
      ),
    ]));
  }

  if (bridged.isNotEmpty) {
    final t = bridged.first;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: onboardingReveal([
      Text(context.i18n.onboardingTrainerConnectedTitle).h4,
      Gap(6),
      Text(context.i18n.onboardingTrainerConnectedSubtitle).small.muted,
      Gap(18),
      Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF22C55E), width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(onboardingTrainerIcon(t), size: 20, color: const Color(0xFF22C55E)),
          Gap(12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.name).small.semiBold,
              Text(onboardingTrainerSubtitleFor(context, t)).xSmall.muted,
            ]),
          ),
          SecondaryBadge(child: Text(context.i18n.onboardingDeviceConnected)),
        ]),
      ),
      if (app != null) ...[
        Gap(12),
        Text(context.i18n.onboardingTrainerNextStepNote(app.name)).xSmall.muted,
      ],
    ]));
  }

  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: onboardingReveal([
    Text(context.i18n.onboardingTrainerTitle).h4,
    Gap(6),
    Text(context.i18n.onboardingTrainerSubtitle).small.muted,
    Gap(16),
    // What Virtual Shifting does, animated in the widgets it actually does it
    // with, instead of three lines of copy claiming the same thing.
    const VirtualShiftingStage(),
    Gap(14),
    _ScanCard(trainers: trainers, onPick: onPick, onRescan: onRescan),
    Gap(10),
    Button.ghost(
      onPressed: () => launchUrlString('https://bikecontrol.app/blog/virtual-shifting-with-and-without-bikecontrol/', mode: LaunchMode.externalApplication),
      child: Row(children: [
        Icon(LucideIcons.bookOpen, size: 15),
        Gap(8),
        Flexible(child: Text(context.i18n.onboardingTrainerHowItWorks).small),
        Gap(6),
        Icon(LucideIcons.externalLink, size: 13),
      ]),
    ),
  ]));
}

/// The scan, as its own card: a pulsing radar, what the scan is doing right
/// now, and the trainers themselves listed inside it. Keeping the found
/// devices in the same card as the radar is what makes this the step's main
/// element rather than a footnote under the pitch.
class _ScanCard extends StatelessWidget {
  const _ScanCard({required this.trainers, required this.onPick, this.onRescan});

  final List<ProxyDevice> trainers;
  final void Function(ProxyDevice) onPick;
  final VoidCallback? onRescan;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = onboardingAccent(context);
    return Container(
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: trainers.isEmpty ? accent.withValues(alpha: 0.3) : cs.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 12, 10, 12),
            child: Row(children: [
              _Radar(accent: accent),
              Gap(12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(trainers.isEmpty
                          ? context.i18n.lookingForSmartTrainers
                          : context.i18n.onboardingTrainersFound(trainers.length))
                      .small
                      .semiBold,
                  Text(context.i18n.onboardingNearbyTrainers).xSmall.muted,
                ]),
              ),
              if (onRescan != null)
                IconButton.ghost(
                  icon: Icon(LucideIcons.refreshCw, size: 15),
                  onPressed: onRescan,
                ),
            ]),
          ),
          for (final t in trainers)
            Container(
              decoration: BoxDecoration(border: Border(top: BorderSide(color: cs.border))),
              child: Button.ghost(
                style: ButtonStyle.ghost().withPadding(padding: const EdgeInsets.fromLTRB(13, 11, 13, 11)),
                onPressed: t.isStarting.value ? null : () => onPick(t),
                child: Row(children: [
                  Icon(onboardingTrainerIcon(t), size: 18, color: accent),
                  Gap(12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t.name).small.semiBold,
                      Text(onboardingTrainerSubtitleFor(context, t)).xSmall.muted,
                    ]),
                  ),
                  if (t.isStarting.value) ...[
                    Text(context.i18n.onboardingDeviceConnecting).xSmall.muted,
                    Gap(8),
                    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(size: 14)),
                  ] else ...[
                    Text(context.i18n.connect).xSmall.semiBold,
                    Icon(LucideIcons.chevronRight, size: 14),
                  ],
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

/// Three rings expanding out of the Bluetooth mark, one behind the other.
/// Renders as the plain mark under reduced motion and in [screenshotMode].
class _Radar extends StatefulWidget {
  const _Radar({required this.accent});

  final Color accent;

  @override
  State<_Radar> createState() => _RadarState();
}

class _RadarState extends State<_Radar> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  bool get _still => screenshotMode || MediaQuery.of(context).disableAnimations;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Never leave a ticker running where motion is off — a repeating
    // controller would also keep `pumpAndSettle` from ever returning.
    if (_still) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = _still;
    final mark = Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(shape: BoxShape.circle, color: widget.accent.withValues(alpha: 0.16)),
      child: Icon(LucideIcons.bluetooth, size: 17, color: widget.accent),
    );
    if (still) return SizedBox(width: 40, height: 40, child: Center(child: mark));
    return SizedBox(
      width: 40,
      height: 40,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Stack(
          alignment: Alignment.center,
          children: [
            for (final phase in const [0.0, 0.33, 0.66])
              Builder(builder: (context) {
                final t = (_c.value + phase) % 1.0;
                return Transform.scale(
                  scale: 0.55 + t * 1.35,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: widget.accent.withValues(alpha: 0.55 * (1 - t))),
                    ),
                  ),
                );
              }),
            mark,
          ],
        ),
      ),
    );
  }
}
