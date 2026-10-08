import 'package:bike_control/pages/onboarding/widgets/onboarding_headline.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart' show BkIconTile, BkGroupedHeader;
import 'package:bike_control/widgets/ui/bk_pill_button.dart';
import 'package:bike_control/widgets/ui/bk_icon_button.dart';
import 'package:bike_control/main.dart' show screenshotMode, screenshotMotionPinned;
import 'package:bike_control/pages/onboarding/widgets/onboarding_theme.dart';
import 'package:bike_control/pages/onboarding/widgets/onboarding_reveal.dart';
import 'package:bike_control/pages/onboarding/widgets/vs_stage.dart';
import 'package:bike_control/pages/onboarding/widgets/onboarding_note.dart';
import 'package:bike_control/widgets/plan/vs_without_pro_note.dart';
import 'package:bike_control/widgets/ui/pro_badge.dart';
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

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

/// The amber box that says why this same device won't do for virtual
/// shifting.
Widget _sameDeviceWarning(BuildContext context, Widget child, {Key? key}) => Container(
  key: key,
  width: double.infinity,
  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(10),
    color: BkStatusColors.of(context).warningWash,
    border: Border.all(color: BkStatusColors.of(context).warning.withValues(alpha: 0.5)),
  ),
  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(LucideIcons.triangleAlert, size: 16, color: BkStatusColors.of(context).warning),
    Gap(10),
    Expanded(child: child),
  ]),
);

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
    bool virtualShiftingBlocked = false,
    bool needsSecondDevice = false}) {
  final bridged = trainers.where((t) => t.isBridged).toList();

  // The trainer app on this same device can't pick up a bridge here (see
  // [vsSameDeviceBlock]: Bluetooth only, or a Microsoft Store app on Windows)
  // — explain it and name the two setups that do work instead of silently
  // hiding the step. The block is only meaningful for a chosen app — its copy
  // names it.
  if (bridged.isEmpty && virtualShiftingBlocked && app != null) {
    final explainer = vsSameDeviceBlock(app) == VsSameDeviceBlock.storeAppIsolation
        ? context.i18n.onboardingVsBlockedExplainerStoreApp(app.name)
        : context.i18n.onboardingVsBlockedExplainer(app.name);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: onboardingReveal([
      OnboardingHeadline(context.i18n.onboardingVsBlockedTitle),
      Gap(6),
      Text(context.i18n.onboardingVsBlockedSubtitle(app.name)).small.muted,
      Gap(16),
      _sameDeviceWarning(context, Text(explainer).xSmall),
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
        onPressed: () => openVsBlogPost(context),
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
      OnboardingHeadline(context.i18n.onboardingTrainerConnectedTitle),
      Gap(6),
      Text(context.i18n.onboardingTrainerConnectedSubtitle).small.muted,
      Gap(18),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          BkIconTile(icon: onboardingTrainerIcon(t), color: BkStatusColors.of(context).success),
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
    // The PRO badge sits on the title itself: this is the Pro feature, and
    // the rider should know before connecting a trainer, not at the paywall.
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: OnboardingHeadline(context.i18n.onboardingTrainerTitle)),
      Gap(10),
      const Padding(padding: EdgeInsets.only(top: 4), child: ProBadge()),
    ]),
    Gap(6),
    Text(context.i18n.onboardingTrainerSubtitle).small.muted,
    Gap(16),
    // An app that can only ever run on a second device (FulGaz) was never asked
    // "this or another device" — say it here, before riders put it on the same
    // iPad and wait for a trainer that will never show up in it.
    if (needsSecondDevice && app != null) ...[
      _sameDeviceWarning(
        context,
        key: const ValueKey('onboarding-vs-second-device-note'),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.i18n.onboardingVsBlockedAltAppTitle(app.name)).xSmall.semiBold,
          Text(context.i18n.onboardingVsBlockedExplainer(app.name)).xSmall,
        ]),
      ),
      Gap(16),
    ],
    // Once a trainer is found, connecting it is the step's job: the list
    // (with Connect) moves above the animation so it is on the first screen.
    if (trainers.isNotEmpty) ...[
      _NearbyTrainers(trainers: trainers, onPick: onPick, onRescan: onRescan),
      Gap(16),
      OnboardingNote(
        vsWithoutProText(context, app),
        icon: LucideIcons.award,
        action: const VsWithoutProLearnMore(alignStart: true),
      ),
      Gap(14),
      const VirtualShiftingStage(),
    ] else ...[
      // What Virtual Shifting does, animated in the widgets it actually does
      // it with, instead of three lines of copy claiming the same thing.
      const VirtualShiftingStage(),
      Gap(14),
      OnboardingNote(
        vsWithoutProText(context, app),
        icon: LucideIcons.award,
        action: const VsWithoutProLearnMore(alignStart: true),
      ),
      Gap(10),
      _ScanCard(trainers: trainers, onPick: onPick, onRescan: onRescan),
    ],
    Gap(10),
    Button.ghost(
      onPressed: () => openVsBlogPost(context),
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

/// The trainers the scan found, each a device card of its own under a
/// "Nearby smart trainers" header with a primary Connect — so a found trainer
/// reads as the thing to do on this step, not as a line of its explanation.
class _NearbyTrainers extends StatelessWidget {
  const _NearbyTrainers({required this.trainers, required this.onPick, this.onRescan});

  final List<ProxyDevice> trainers;
  final void Function(ProxyDevice) onPick;
  final VoidCallback? onRescan;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(children: [
            Expanded(child: BkGroupedHeader(context.i18n.onboardingNearbyTrainers)),
            if (onRescan != null)
              BkIconButton.ghost(
                icon: Icon(LucideIcons.refreshCw, size: 15),
                label: context.i18n.a11yRefresh,
                onPressed: onRescan,
              ),
          ]),
        ),
        Gap(4),
        for (final (i, t) in trainers.indexed) ...[
          if (i > 0) Gap(8),
          _TrainerCard(trainer: t, onPick: onPick),
        ],
      ],
    );
  }
}

class _TrainerCard extends StatelessWidget {
  const _TrainerCard({required this.trainer, required this.onPick});

  final ProxyDevice trainer;
  final void Function(ProxyDevice) onPick;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = trainer;
    return ValueListenableBuilder<bool>(
      valueListenable: t.isStarting,
      builder: (context, starting, _) => Container(
        key: ValueKey('onboarding-trainer-${t.uniqueId}'),
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: BoxDecoration(color: cs.card, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          BkIconTile(icon: onboardingTrainerIcon(t), color: onboardingAccent(context)),
          Gap(12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
              Text(t.name, maxLines: 2, overflow: TextOverflow.ellipsis).base.semiBold,
              Text(onboardingTrainerSubtitleFor(context, t)).xSmall.muted,
            ]),
          ),
          Gap(10),
          if (starting) ...[
            Text(context.i18n.onboardingDeviceConnecting).xSmall.muted,
            Gap(8),
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(size: 16)),
          ] else
            BkPillButton(
              expand: false,
              onPressed: () => onPick(t),
              child: Text(context.i18n.connect),
            ),
        ]),
      ),
    );
  }
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
        borderRadius: BorderRadius.circular(16),
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
                BkIconButton.ghost(
                  icon: Icon(LucideIcons.refreshCw, size: 15),
                  label: context.i18n.a11yRefresh,
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

  bool get _still => screenshotMotionPinned || MediaQuery.of(context).disableAnimations;

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
