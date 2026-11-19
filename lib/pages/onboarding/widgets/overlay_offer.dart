import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/widgets/overlay/trainer_overlay_view.dart';
import 'package:bike_control/widgets/ui/bk_pill_button.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Step 3's gear overlay offer: the app keeps drawing its own gear number,
/// which isn't the gear BikeControl rides, and the overlay is what shows the
/// real one. Shows the overlay itself (over a stand-in for the app) so the
/// rider sees what they are switching on.
class OnboardingOverlayOffer extends StatefulWidget {
  const OnboardingOverlayOffer({super.key, required this.app, required this.onShow});

  final SupportedApp app;
  final VoidCallback onShow;

  @override
  State<OnboardingOverlayOffer> createState() => _OnboardingOverlayOfferState();
}

class _OnboardingOverlayOfferState extends State<OnboardingOverlayOffer> {
  // A still picture of the overlay: a gear mid-cassette and a ride's worth of
  // numbers, not the live trainer, which reads 0 W before the ride starts.
  final _preview = ValueNotifier(
    const TrainerOverlayState(
      gear: 14,
      maxGear: 24,
      gearRatio: 2.43,
      mode: TrainerMode.simMode,
      powerW: 178,
      cadenceRpm: 86,
      ergTargetW: null,
      fields: {OverlayField.power, OverlayField.cadence},
    ),
  );

  @override
  void dispose() {
    _preview.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final app = widget.app;
    return Container(
      key: const ValueKey('onboarding-overlay-offer'),
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: cs.card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The app behind the overlay, in the theme's own greys, with its
          // name where its own HUD would be.
          Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [cs.muted, cs.card],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 14,
                  top: 10,
                  child: Text(app.name).xSmall.semiBold.muted,
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 20, 12, 8),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(
                        width: TrainerOverlayView.fitWindowSizeOf(context, _preview.value, drag: false).width,
                        child: IgnorePointer(child: TrainerOverlayView(state: _preview, pill: true)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.i18n.onboardingOverlayTitle(app.name)).small.semiBold,
                const Gap(4),
                Text(context.i18n.onboardingDoneOverlayNote(app.name)).small.muted,
                const Gap(12),
                BkPillButton(
                  key: const ValueKey('onboarding-done-show-overlay'),
                  expand: false,
                  leading: const Icon(LucideIcons.layers, size: 16),
                  onPressed: widget.onShow,
                  child: Text(context.i18n.onboardingDoneShowOverlay),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
